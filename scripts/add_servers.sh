#!/bin/bash

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
                  {"url": "https://api.benzinga.com/api/v1", "description": "V1"},
                  {"url": "https://api.benzinga.com/api/v2", "description": "V2"},
                  {"url": "https://api.benzinga.com/api/v2.1", "description": "V2.1"},
                  {"url": "https://api.benzinga.com/api/v2.2", "description": "V2.2"}
                ]'
                ;;
            "logo-api_api.spec.yml")
                servers='[
                  {"url": "https://api.benzinga.com/api/v2", "description": "V2"},
                  {"url": "https://api.benzinga.com/api/v2.1", "description": "V2.1"}
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
            yq eval -i ".servers = $servers" "$file"
        fi
    else
        echo "Skipping (servers array already exists): $file"
    fi
done
