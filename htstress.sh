#slower than weighttp -- almost half at times
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  htstress/htstress -n50000 "http://localhost:$i/multiply?a=2&b=3" -c10 -t8 "$@" | egrep "good requests|seconds"
done
