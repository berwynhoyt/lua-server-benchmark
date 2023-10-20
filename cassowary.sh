# Fails to resty when c>1
./cassowary run -c 1 -n 50000 -u "http://localhost:8081/multiply?a=2&b=3" "$@"
