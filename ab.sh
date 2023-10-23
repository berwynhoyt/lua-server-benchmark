# Good, but surpassed by speed of weighttp
# Also, it's only an HTTP1.0 client, so keep-alive doesn't work with redbean
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  ab -kq -n50000 -c50 "http://localhost:$i/multiply?a=2&b=3" "$@" | egrep -i "seconds|failed"
done
