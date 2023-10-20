# Fails against OpenResty. Also not the fastest.
httperf --num-conns 10 --server localhost --port 8085 --uri "/multiply?a=2&b=3" --num-calls=5000 "$@"