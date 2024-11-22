#!/bin/bash

# Initialize a string for the mapping (key=value pairs separated by a delimiter)
my_map="api-reference/analyst-reports-raw-text-api_api=Analyst Reports Raw Text|
api-reference/calendar_api=Calendars|
api-reference/data-api-proxy_api=Data API Proxy|
api-reference/earnings-call-transcripts-api_api=Earnings Call Transcripts|
api-reference/logo-api_api=Logos|
api-reference/newsquantified-api_api=NewsQuantified|
api-reference/ticker-trends-api_api=Ticker Trends"

# Array to store JSON output
output_array=()

# Process each OpenAPI file
for file in ./openapi/*.yml; do
  if [ ! -f "$file" ]; then
    echo "No OpenAPI files found."
    exit 1
  fi

  filename=$(basename "$file" .spec.yml)
  mkdir -p "api-reference/$filename"
  cd ./api-reference/"$filename"

  # Run mintlify-scrape and process output
  command_output=$(mintlify-scrape openapi-file "../../$file" | tail -n +2)

  # Merge pages
  merged_pages=$(echo "$command_output" | jq -s '[.[][] | .pages[]]')
  if ! jq -e . >/dev/null 2>&1 <<<"$merged_pages"; then
    echo "Invalid JSON in merged_pages" >&2
    exit 1
  fi

  # Create JSON output
  output=$(jq -n --argjson pages "$merged_pages" --arg filename "api-reference/$filename" \
    '{"group": $filename, "pages": $pages}')
  output=$(echo "$output" | jq --arg group "$(echo "$output" | jq -r '.group')" '.pages |= map("\($group)/\(.)")')

  # Extract the group from the JSON output
  group=$(echo "$output" | jq -r '.group')

  # Look up the group in the flat string map (delimiter-separated)
  mapped_value=$(echo "$my_map" | grep -E "^$group=" | cut -d'=' -f2 | sed 's/|$//')

  # Check if mapped value was found
  if [ -z "$mapped_value" ]; then
    echo "Error: Group key '$group' not found in the map."
    exit 1
  fi

  # Replace the group key value with the mapped value in the JSON object
  output=$(echo "$output" | jq --arg newGroup "$mapped_value" '.group = $newGroup')

  # Append the JSON output to the array
  output_array+=("$output")

  cd ../../
done

# Serialize the JSON array to a string
json_array=$(printf '%s\n' "${output_array[@]}" | jq -s '.')

# Print the final JSON array
#echo "$json_array"

# Serialize the JSON array to a string
json_array=$(echo "$json_array" | jq -c -r '.[] | @json' | paste -sd, -)

# Create the new mint.json file
echo "$json_array" > temp.json
sed "/{{REPLACE_HERE}}/r temp.json" mint.json.tpl > mint.json.new
sed -i '' -e 's/{{REPLACE_HERE}}//g' mint.json.new

#Delete the old mint.json if it exists
if [ -f "mint.json" ]; then
  rm -f mint.json
fi

cat mint.json.new

# Move the new mint.json to the correct location
jq . mint.json.new > mint.json

# Clean up
rm mint.json.new
rm temp.json

