# Runner-up tool fast and reliable.
# Is quite verbose about the number of threads started; otherwise very good
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  weighttp/src/weighttp -k -n50000 "http://localhost:$i/multiply?a=2&b=3" -c50 -t8 "$@" | egrep "finished|status"
done
