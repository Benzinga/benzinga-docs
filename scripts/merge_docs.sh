#!/bin/bash
set -euo pipefail

# Ensure jq and yq are installed
if ! command -v jq &>/dev/null || ! command -v yq &>/dev/null; then
  echo "Please install jq and yq to use this script."
  exit 1
fi

# Input and output paths
OUTPUT_FILE="benzinga_openapi.yaml"  # Final merged OpenAPI spec
FILES=(openapi/*.yml)  # OpenAPI spec files in the ./openapi folder

# Base structure of the merged OpenAPI spec
MERGED='
openapi: "3.0.0"
info:
  title: "Benzinga API"
  version: "1.0.0"
paths: {}
components: {}
'

# Start with an empty merged spec
echo "$MERGED" > "$OUTPUT_FILE"

# Temporary files for storing merged paths and components
TMP_PATHS_FILE="tmp_paths.yaml"
TMP_COMPONENTS_FILE="tmp_components.yaml"

# Initialize temporary files with empty sections
echo "paths: {}" > "$TMP_PATHS_FILE"
echo "components: {}" > "$TMP_COMPONENTS_FILE"

# Extract and merge paths and components
for FILE in "${FILES[@]}"; do
  echo "Processing $FILE..."

  # Extract the `paths` and `components` sections from the current file
  EXTRACTED_PATHS=$(yq eval '.paths' "$FILE")
  EXTRACTED_COMPONENTS=$(yq eval '.components' "$FILE")

  # Merge paths (add them to the tmp_paths.yaml)
  if [[ "$EXTRACTED_PATHS" != "null" && -n "$EXTRACTED_PATHS" ]]; then
    echo "Merging paths from $FILE..."
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' "$TMP_PATHS_FILE" <(echo "$EXTRACTED_PATHS") > tmp_merge_paths.yaml
    mv tmp_merge_paths.yaml "$TMP_PATHS_FILE"
  fi

  # Merge components (add them to the tmp_components.yaml)
  if [[ "$EXTRACTED_COMPONENTS" != "null" && -n "$EXTRACTED_COMPONENTS" ]]; then
    echo "Merging components from $FILE..."
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' "$TMP_COMPONENTS_FILE" <(echo "$EXTRACTED_COMPONENTS") > tmp_merge_components.yaml
    mv tmp_merge_components.yaml "$TMP_COMPONENTS_FILE"
  fi
done

# Merge the final paths and components into the base structure
yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' <(echo "$MERGED") "$TMP_PATHS_FILE" > tmp_final.yaml
yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' tmp_final.yaml "$TMP_COMPONENTS_FILE" > "$OUTPUT_FILE"

# Clean up temporary files
rm "$TMP_PATHS_FILE" "$TMP_COMPONENTS_FILE" tmp_final.yaml

echo "Merged OpenAPI spec written to $OUTPUT_FILE"
