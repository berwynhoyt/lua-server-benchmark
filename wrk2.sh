#Best benchmarking tool of all. Fastest, works well with all servers
#Unfortunate that it's build also builds LuaJIT with lots of warnings. But we don't use its Lua so it's ok.
#Only minor gripe is it doesn't accept a -n parameter; only a timed run, so have to convert to n req/sec to match other tools
for i in 8080 8081 8082 8083 8084 8085; do
  echo Port $i
  wrk2/wrk -d5 -c10 -t10 -R 1000000 "http://localhost:$i/multiply?a=2&b=3" "$@"
done
