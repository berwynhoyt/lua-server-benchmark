#Only measures to 1s resolution which puts all the other stats out, too.
time gobench -k -c 10 -r 5000 -u "http://localhost:8080/multiply?a=2&b=3" "$@"
