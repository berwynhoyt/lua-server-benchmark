# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

PORT := 8080
NGINX := /usr/local/openresty/nginx/sbin/nginx -p resty -c conf/nginx.conf
START_NGINX := $(NGINX)
STOP_NGINX := $(NGINX) -s quit

$(shell mkdir -p resty/logs)


all: benchmark

nginx: resty/logs/nginx.pid .reload
	@lsof -i TCP:$(PORT) | grep -q ^nginx || $(START_NGINX)
resty/logs/nginx.pid:
	$(START_NGINX)
.reload: resty/conf/nginx.conf
	touch .reload
	$(NGINX) -s reload
stop: nginx
	$(STOP_NGINX)

test: nginx
	curl http://localhost:$(PORT)/

benchmark: nginx
	ab -k -c1000 -n50000 http://localhost:$(PORT)/


.PHONY: all nginx stop test benchmark
