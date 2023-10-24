for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  echo "GET http://localhost:$i/multiply?a=2&b=3" | vegeta attack -duration=1s -rate=0 -max-workers=50 "$@" \
    | vegeta report -type=text | egrep "Requests|Success"
done
