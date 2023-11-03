#Best benchmarking tool of all. Fastest, works well with all servers
#Unfortunate that it's build also builds LuaJIT with lots of warnings. But we don't use its Lua so it's ok.
#More importantly, don't specify more than 100 threads, and keep an eye on its maths to make sure it says 
#it's testing for as many seconds as you specified, so that you don't get "833071 requests in 1.25ms" when 
#you told it to test for 5s (this will give you wildly high req/s). 
#See the end of this article for more detail and for cross-checking with weighttp.
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  wrk2/wrk -d5 -c10 -t10 -R 1000000 "http://localhost:$i/multiply?a=2&b=3" "$@"
done
