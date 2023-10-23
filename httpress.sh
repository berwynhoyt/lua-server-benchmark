#Claims to improve weighttp, but thinks redbean isn't recognizing its keep-alive so redbean takes 10x longer
# (Workaround: see patch in Makefile)
#Fails some requests if concurrent connections (-c) is above about 10
#Plus, the many build dependencies are horrendous to build
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  httpress/bin/Release/httpress -kq -n50000 -c10 -p2 "http://localhost:$i/multiply?a=2&b=3" "$@"
done

