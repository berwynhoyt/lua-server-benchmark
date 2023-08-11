# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

NGINX:=/usr/local/openresty/nginx/sbin/nginx

$(shell mkdir -p resty/logs)

all: benchmark

nginx: resty/logs/nginx.pid
resty/logs/nginx.pid:
	$(NGINX) -p resty -c conf/nginx.conf
stop: nginx
	$(NGINX) -p resty -c conf/nginx.conf -s quit


test: nginx
	curl http://localhost:8080/

benchmark: nginx
	ab -k -c10 -n50000 http://localhost:8080/


.PHONY: stop test benchmark
