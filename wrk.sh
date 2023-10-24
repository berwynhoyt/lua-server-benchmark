# Unfortunately, it turns out that the wrk results are incredibly bogus. If I let it test for only 1 second the results magically become far better, and if I give it 2000 threads, it supposedly reaches 15M requests per second - which I simply cannot believe!
# Seems to be a calibration issue for runs shorter than 10s (see note in wrk2 docs)
# Is overly verbose about the number of threads started
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  weighttp/src/weighttp -k -n50000 "http://localhost:$i/multiply?a=2&b=3" -c50 -t8 "$@" | egrep "finished|status"
done
