#Works well, but produces results that are ~50% slower than some other tools
gohttpbench -k -c 10 -n 50000 -G 8 "http://localhost:8082/multiply?a=2&b=3" "$@"
