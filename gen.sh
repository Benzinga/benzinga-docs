echo '[' > out.json
  for i in {1..2}; do
    echo "{\"group\":\"calendar_api\",\"pages\":[\"conference_calls/get-conference-calls\",\"dividends/get-dividends\",\"earnings/get-earnings\",\"economics/get-economics\",\"events/get-events\",\"fda/get-fda\",\"guidance/get-guidance\",\"ipos/get-ipos\",\"ma/get-merger-and-acquisition\",\"offerings/get-offerings\",\"ratings/get-ratings\",\"ratings_analysts/get-ratings-analysts\",\"ratings_firms/get-ratings-firms\",\"splits/get-splits\"]}" >> out.json
    if [ $i -ne 2 ]; then
      echo ',' >> out.json
    fi
  done
echo ']' >> out.json
