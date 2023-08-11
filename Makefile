# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

NGINX:=/usr/local/openresty/nginx/sbin/nginx

mkdir -p resty/logs

all:

nginx:
	$(NGINX) -p $(shell pwd)/resty -c conf/nginx.conf

test:
	curl http://localhost:8080/

benchmark: http_load
	./http_load -p 10 -s 5 http://localhost:8080/

# build http_load

http_load_url:=http://www.acme.com/software/http_load/http_load-09Mar2016.tar.gz
http_load_zip:=$(notdir $(http_load_url))
http_load_dir:=$(basename $(basename $(http_load_zip)))

http_load: $(http_load_zip)
	tar -xzf $(http_load_zip)
	make -C $(http_load_dir)
	cp $(http_load_dir)/http_load .
$(http_load_zip):
	wget $(http_load_url)


.PHONY: nginx
