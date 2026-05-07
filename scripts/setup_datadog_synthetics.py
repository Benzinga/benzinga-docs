#!/usr/bin/env python3
"""
Setup Datadog Synthetics API monitoring for all Benzinga API endpoints.

Parses all OpenAPI spec files in the /openapi folder and creates a Datadog
Synthetic API (HTTP) test for each endpoint, with alerting configured.

Prerequisites:
    pip install -r scripts/requirements_synthetics.txt

Environment variables:
    DD_API_KEY           (required) Datadog API key
    DD_APP_KEY           (required) Datadog Application key
    DD_SITE              (optional) Datadog site, e.g. datadoghq.com (default) or datadoghq.eu
    BENZINGA_API_TOKEN   (optional) Real Benzinga token — if set, asserts HTTP 2xx;
                                   otherwise asserts status != 5xx (safe for staging)
    ALERT_EMAIL          (optional) Email handle for @-mentions in monitor alerts
                                   e.g. "alerts@yourcompany.com"
    ALERT_SLACK_CHANNEL  (optional) Slack channel for alerts, e.g. "#api-alerts"

Usage:
    # Dry run — list endpoints that would be monitored without creating anything
    python scripts/setup_datadog_synthetics.py --dry-run

    # Create all Synthetic tests
    DD_API_KEY=xxx DD_APP_KEY=yyy ALERT_EMAIL=ops@yourco.com \\
        python scripts/setup_datadog_synthetics.py

    # Target a different openapi folder
    python scripts/setup_datadog_synthetics.py --openapi-dir ./openapi

    # Delete all previously created tests (cleanup)
    python scripts/setup_datadog_synthetics.py --delete
"""

import argparse
import glob
import json
import os
import sys
import time

import yaml

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

BASE_URL = "https://api.benzinga.com"

# Monitoring locations — pick at least 2 for redundancy
DEFAULT_LOCATIONS = [
    "aws:us-east-1",
    "aws:us-west-2",
    "aws:eu-west-1",
]

# How often each test runs (seconds)
TICK_EVERY = 300  # 5 minutes

# Max response time before alerting (ms)
MAX_RESPONSE_TIME_MS = 10_000  # 10 seconds

# Tags applied to every created test
BASE_TAGS = ["benzinga", "api-monitoring", "synthetic", "env:production"]

# Datadog stores previously created test public_ids in this file so --delete works
STATE_FILE = ".datadog_synthetics_state.json"


# ---------------------------------------------------------------------------
# OpenAPI parsing
# ---------------------------------------------------------------------------

def _substitute_path_params(path: str) -> str:
    """Replace {param} placeholders with safe test values."""
    import re
    return re.sub(r"\{[^}]+\}", "1", path)


def parse_openapi_file(filepath: str):
    """
    Parse an OpenAPI 3.x YAML file and return a list of endpoint dicts:
        {api_title, spec_file, path, constructed_path, method, op_id, summary, url}
    """
    with open(filepath) as f:
        spec = yaml.safe_load(f)

    api_title = spec.get("info", {}).get("title", os.path.basename(filepath))
    endpoints = []

    for path, path_item in (spec.get("paths") or {}).items():
        if not isinstance(path_item, dict):
            continue

        for method, operation in path_item.items():
            if method.lower() not in ("get", "post", "put", "delete", "patch", "head"):
                continue
            if not isinstance(operation, dict):
                continue

            op_id = operation.get("operationId") or f"{method.upper()}-{path}"
            raw_summary = operation.get("summary") or operation.get("description") or op_id
            summary = raw_summary[:80].strip()

            constructed_path = _substitute_path_params(path)
            full_url = f"{BASE_URL}{constructed_path}"

            endpoints.append(
                {
                    "api_title": api_title,
                    "spec_file": os.path.basename(filepath),
                    "path": path,
                    "constructed_path": constructed_path,
                    "method": method.upper(),
                    "op_id": op_id,
                    "summary": summary,
                    "url": full_url,
                }
            )

    return endpoints


def collect_all_endpoints(openapi_dir: str):
    patterns = [
        os.path.join(openapi_dir, "*.yml"),
        os.path.join(openapi_dir, "*.yaml"),
    ]
    spec_files = []
    for p in patterns:
        spec_files.extend(glob.glob(p))
    spec_files = sorted(set(spec_files))

    if not spec_files:
        print(f"[ERROR] No OpenAPI spec files found in: {openapi_dir}")
        sys.exit(1)

    all_endpoints = []
    for spec_file in spec_files:
        try:
            endpoints = parse_openapi_file(spec_file)
            all_endpoints.extend(endpoints)
            print(f"  {os.path.basename(spec_file):50s}  {len(endpoints):3d} endpoints")
        except Exception as exc:
            print(f"  [WARN] Failed to parse {spec_file}: {exc}")

    return all_endpoints


# ---------------------------------------------------------------------------
# Datadog Synthetics test payload builder
# ---------------------------------------------------------------------------

def _build_test_payload(
    endpoint: dict,
    alert_email: str,
    alert_slack: str,
    benzinga_token: str,
) -> dict:
    """Build the JSON body for POST /api/v1/synthetics/tests."""

    method = endpoint["method"]
    url = endpoint["url"]

    # Auth — Benzinga APIs use ?token= query param
    if benzinga_token:
        separator = "&" if "?" in url else "?"
        request_url = f"{url}{separator}token={benzinga_token}"
    else:
        # Reference a Datadog Global Variable (set it up once in the DD UI or API)
        separator = "&" if "?" in url else "?"
        request_url = f"{url}{separator}token={{{{BENZINGA_API_TOKEN}}}}"

    # Assertions
    if benzinga_token:
        status_assertion = {
            "operator": "is",
            "type": "statusCode",
            "target": 200,
        }
    else:
        # Without a real token we still want to confirm the server is alive
        # (it will return 401/403, NOT 5xx)
        status_assertion = {
            "operator": "isNot",
            "type": "statusCode",
            "target": 500,
        }

    assertions = [
        status_assertion,
        {
            "operator": "lessThan",
            "type": "responseTime",
            "target": MAX_RESPONSE_TIME_MS,
        },
    ]

    # Alert message
    recipients = []
    if alert_email:
        recipients.append(f"@{alert_email}")
    if alert_slack:
        slack = alert_slack if alert_slack.startswith("@") else f"@{alert_slack}"
        recipients.append(slack)

    recipient_str = " ".join(recipients) if recipients else "@webhook-default"

    monitor_message = (
        f"{{{{#is_alert}}}}\n"
        f"🚨 Benzinga API endpoint is DOWN or erroring!\n\n"
        f"**Endpoint:** `{method} {endpoint['url']}`\n"
        f"**API:** {endpoint['api_title']}\n"
        f"**Operation:** `{endpoint['op_id']}`\n\n"
        f"{recipient_str}\n"
        f"{{{{/is_alert}}}}\n\n"
        f"{{{{#is_recovery}}}}\n"
        f"✅ Benzinga API endpoint has recovered: `{method} {endpoint['url']}`\n"
        f"{recipient_str}\n"
        f"{{{{/is_recovery}}}}"
    )

    # Tags
    api_tag = endpoint["api_title"].lower().replace(" ", "-").replace("/", "-")
    tags = BASE_TAGS + [f"api:{api_tag}", f"operation:{endpoint['op_id']}"]

    test_name = f"[Benzinga] {endpoint['api_title']} — {endpoint['summary']}"
    if len(test_name) > 100:
        test_name = test_name[:97] + "..."

    payload = {
        "name": test_name,
        "type": "api",
        "subtype": "http",
        "status": "live",
        "locations": DEFAULT_LOCATIONS,
        "tags": tags,
        "message": monitor_message,
        "config": {
            "request": {
                "method": method,
                "url": request_url,
                "headers": {
                    "Accept": "application/json",
                },
                "timeout": 30,
            },
            "assertions": assertions,
        },
        "options": {
            "tick_every": TICK_EVERY,
            "min_failure_duration": 0,
            "min_location_failed": 1,
            "retry": {
                "count": 2,
                "interval": 300,
            },
            "monitor_options": {
                "notify_audit": False,
                "renotify_interval": 60,  # re-alert every 60 minutes if still failing
            },
        },
    }

    return payload


# ---------------------------------------------------------------------------
# Datadog REST API client (uses requests to avoid SDK version issues)
# ---------------------------------------------------------------------------

import urllib.request
import urllib.error


class DatadogSyntheticsClient:
    def __init__(self, api_key: str, app_key: str, site: str = "datadoghq.com"):
        self.api_key = api_key
        self.app_key = app_key
        self.base = f"https://api.{site}"

    def _request(self, method: str, path: str, body=None) -> dict:
        url = f"{self.base}{path}"
        data = json.dumps(body).encode() if body else None
        req = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Content-Type": "application/json",
                "DD-API-KEY": self.api_key,
                "DD-APPLICATION-KEY": self.app_key,
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as exc:
            body_text = exc.read().decode(errors="replace")
            raise RuntimeError(f"HTTP {exc.code} {exc.reason}: {body_text}") from exc

    def create_test(self, payload: dict) -> dict:
        return self._request("POST", "/api/v1/synthetics/tests", payload)

    def delete_tests(self, public_ids) -> dict:
        return self._request(
            "POST",
            "/api/v1/synthetics/tests/delete",
            {"public_ids": public_ids},
        )

    def list_tests(self):
        result = self._request("GET", "/api/v1/synthetics/tests")
        return result.get("tests", [])


# ---------------------------------------------------------------------------
# State persistence (so --delete can clean up)
# ---------------------------------------------------------------------------

def load_state() -> dict:
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"public_ids": []}


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    print(f"  State saved to {STATE_FILE}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description="Create Datadog Synthetics API tests for all Benzinga API endpoints."
    )
    parser.add_argument(
        "--openapi-dir",
        default=os.path.join(os.path.dirname(__file__), "..", "openapi"),
        help="Directory containing OpenAPI YAML spec files (default: ../openapi relative to script)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse specs and print endpoints without creating any Datadog tests.",
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help=f"Delete all tests recorded in {STATE_FILE} (cleanup).",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.3,
        help="Seconds to wait between API calls to avoid rate-limiting (default: 0.3).",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # ---- env config --------------------------------------------------------
    dd_api_key = os.environ.get("DD_API_KEY", "")
    dd_app_key = os.environ.get("DD_APP_KEY", "")
    dd_site = os.environ.get("DD_SITE", "datadoghq.com")
    benzinga_token = os.environ.get("BENZINGA_API_TOKEN", "")
    alert_email = os.environ.get("ALERT_EMAIL", "")
    alert_slack = os.environ.get("ALERT_SLACK_CHANNEL", "")

    # ---- dry run shortcut --------------------------------------------------
    if args.dry_run:
        openapi_dir = os.path.abspath(args.openapi_dir)
        print(f"\nParsing OpenAPI specs in: {openapi_dir}\n")
        endpoints = collect_all_endpoints(openapi_dir)
        print(f"\n{'─'*70}")
        print(f"Total endpoints found: {len(endpoints)}\n")
        for ep in endpoints:
            print(f"  [{ep['method']:6s}] {ep['url']}")
        print(f"\n[DRY RUN] No tests created.")
        return

    # ---- delete mode -------------------------------------------------------
    if args.delete:
        if not dd_api_key or not dd_app_key:
            print("[ERROR] DD_API_KEY and DD_APP_KEY are required for --delete")
            sys.exit(1)
        state = load_state()
        public_ids = state.get("public_ids", [])
        if not public_ids:
            print("No previously created tests found in state file. Nothing to delete.")
            return
        client = DatadogSyntheticsClient(dd_api_key, dd_app_key, dd_site)
        print(f"Deleting {len(public_ids)} Synthetic tests...")
        # Datadog allows up to 100 IDs per delete call
        chunk_size = 100
        for i in range(0, len(public_ids), chunk_size):
            chunk = public_ids[i : i + chunk_size]
            client.delete_tests(chunk)
            print(f"  Deleted {len(chunk)} tests.")
        save_state({"public_ids": []})
        print("Done.")
        return

    # ---- create mode -------------------------------------------------------
    if not dd_api_key or not dd_app_key:
        print("[ERROR] DD_API_KEY and DD_APP_KEY environment variables are required.")
        print("  export DD_API_KEY=<your-datadog-api-key>")
        print("  export DD_APP_KEY=<your-datadog-application-key>")
        sys.exit(1)

    openapi_dir = os.path.abspath(args.openapi_dir)
    print(f"\nParsing OpenAPI specs in: {openapi_dir}\n")
    endpoints = collect_all_endpoints(openapi_dir)
    print(f"\nTotal endpoints to monitor: {len(endpoints)}")

    if benzinga_token:
        print("  Auth: using BENZINGA_API_TOKEN — asserting HTTP 200")
    else:
        print("  Auth: no BENZINGA_API_TOKEN — asserting status != 500")
        print("        (set BENZINGA_API_TOKEN for full authenticated checks)")

    if alert_email:
        print(f"  Alert email: {alert_email}")
    if alert_slack:
        print(f"  Alert Slack: {alert_slack}")

    print(f"\nCreating Datadog Synthetic API tests on {dd_site}...\n")

    client = DatadogSyntheticsClient(dd_api_key, dd_app_key, dd_site)
    state = load_state()
    created_ids = state.get("public_ids", [])

    created = 0
    failed = 0

    for i, endpoint in enumerate(endpoints, 1):
        prefix = f"[{i:3d}/{len(endpoints)}]"
        try:
            payload = _build_test_payload(endpoint, alert_email, alert_slack, benzinga_token)
            result = client.create_test(payload)
            public_id = result.get("public_id", "?")
            created_ids.append(public_id)
            print(f"  {prefix} ✓  [{endpoint['method']:6s}] {endpoint['url']}")
            created += 1
        except Exception as exc:
            print(f"  {prefix} ✗  [{endpoint['method']:6s}] {endpoint['url']}")
            print(f"             Error: {exc}")
            failed += 1

        if args.delay > 0:
            time.sleep(args.delay)

    # Persist created IDs for future --delete
    save_state({"public_ids": created_ids})

    print(f"\n{'─'*70}")
    print(f"Done!  Created: {created}  |  Failed: {failed}")
    print(f"  • View tests: https://app.{dd_site}/synthetics/tests")
    print(f"  • To clean up, run:  python scripts/setup_datadog_synthetics.py --delete")


if __name__ == "__main__":
    main()
