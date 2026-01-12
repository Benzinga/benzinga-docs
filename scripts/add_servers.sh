#!/bin/bash
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required but not installed or not on PATH" >&2
  exit 1
fi

# Detect yq version
YQ_VERSION="unknown"
if yq --version 2>&1 | grep -q "mikefarah"; then
    YQ_VERSION="mikefarah"
elif yq --help 2>&1 | grep -q "jq wrapper"; then
    YQ_VERSION="kislyuk"
else
    # Fallback/Guess based on behavior or help
    if yq --version 2>&1 | grep -q "yq [0-9]"; then
       # Assume kislyuk or compatible if it looks like a standard version string not containing mikefarah
       # But let's look for known flags in help if possible, or just default to one and warn.
       # Using a simpler heuristic: mikefarah's yq says "yq (https://github.com/mikefarah/yq/)"
       # Python yq usually says "yq <version>"
       YQ_VERSION="kislyuk"
    fi
fi

echo "Detected yq flavor: $YQ_VERSION"

# Define the OpenAPI directory
OPENAPI_DIR="./openapi"

# Iterate through all YAML and JSON files in the directory
find "$OPENAPI_DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) | while read -r file; do
    # Check if the 'servers' array already exists in the file
    if ! grep -q "servers:" "$file"; then
        echo "Adding servers array to: $file"

        # Determine the server URL(s) based on the filename
        filename=$(basename "$file")
        case "$filename" in
            "calendar_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "logo-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "news-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "newsquantified-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com/api/v2", "description": "V2"}
                ]'
                ;;
            "ticker-trends-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "data-api-proxy_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "earnings-call-transcripts-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com/api/v1", "description": "V1"}
                ]'
                ;;
            "analyst-reports-raw-text-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "webhook_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com", "description": "PROD"}
                ]'
                ;;
            "delivery_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com/api/v1", "description": "PROD"}
                ]'
                ;;
            *)
                # Default servers if filename doesn't match
                servers='[
                  {"url": "https://api.benzinga.com", "description": "Default"}
                ]'
                ;;
        esac

        # Add the servers section to the OpenAPI file
        if [[ "$file" == *.yaml || "$file" == *.yml ]]; then
            if [ "$YQ_VERSION" == "mikefarah" ]; then
                yq eval -i ".servers = $servers" "$file"
            else
                # Python yq (kislyuk)
                # Pass servers json as arg to avoid quoting issues
                yq -i -y --argjson s "$servers" '.servers = $s' "$file"
            fi
        fi
    else
        echo "Skipping (servers array already exists): $file"
    fi
done
