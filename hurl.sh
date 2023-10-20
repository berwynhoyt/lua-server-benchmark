# Runner up best tool. Good results, but have to tune amount of parallel requests or there are slowdowns and failures:
#  (.e.g Apache is twice as fast with -p <= 4, FCGI at -p <= 10, uWSGI fails responses unless -p <= 12; other servers best at -p15)
# Note: must specify -U5 to get accurate results
hurl/build/src/hurl/hurl "http://localhost:8080/multiply?a=2&b=3" -U5 -f50000 -t8 -p4 "$@" | egrep "seconds| --"
hurl/build/src/hurl/hurl "http://localhost:8081/multiply?a=2&b=3" -U5 -f50000 -t8 -p15 "$@" | egrep "seconds| --"
hurl/build/src/hurl/hurl "http://localhost:8082/multiply?a=2&b=3" -U5 -f50000 -t5 -p10 "$@" | egrep "seconds| --"
hurl/build/src/hurl/hurl "http://localhost:8083/multiply?a=2&b=3" -U5 -f50000 -t8 -p10 "$@" | egrep "seconds| --"
hurl/build/src/hurl/hurl "http://localhost:8084/multiply?a=2&b=3" -U5 -f50000 -t8 -p15 "$@" | egrep "seconds| --"
hurl/build/src/hurl/hurl "http://localhost:8085/multiply?a=2&b=3" -U5 -f50000 -t8 -p15 "$@" | egrep "seconds| --"
