# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

SHELL := /bin/bash

REQUEST :=
#REQUEST := multiply?a=2&b=3

PORT_RESTY := 8081
PORT_FCGI := 8082
FCGI_SOCKET := /tmp/nginx-fcgi-benchmark.sock

LUA=$(shell which lua)
NGINX := $(shell which nginx >/dev/null && echo nginx || echo /usr/local/openresty/nginx/sbin/nginx)
RUN_NGINX := $(NGINX) -p nginx -c conf/nginx.conf
STOP_NGINX := $(RUN_NGINX) -s quit

RUN_FCGI := spawn-fcgi -F 5 -s $(FCGI_SOCKET) -P fcgi.pid -d www -- $(LUA) run.lua
STOP_FCGI := kill -9 `cat fcgi.pid` && rm -f fcgi.pid

IS_NGINX = $(shell lsof -i TCP:$(PORT_RESTY) &>/dev/null && echo yes)
IS_FCGI = $(shell lsof -a -U -- $(FCGI_SOCKET) &>/dev/null && echo yes)

$(shell mkdir -p nginx/logs)

all: benchmark
start: nginx fcgi
stop: stop-fcgi stop-nginx
reload: | force-reload .reload
force-reload:
	@touch nginx/conf/nginx.conf

nginx: nginx/logs/nginx.pid .reload
	$(if $(IS_NGINX), , $(RUN_NGINX))
nginx/logs/nginx.pid:
	$(RUN_NGINX)
.reload: nginx/conf/nginx.conf Makefile www/app.lua
	@echo Reloading server config
	@touch .reload
	$(if $(IS_NGINX), $(RUN_NGINX) -s reload && sleep 0.1, $(RUN_NGINX))
	$(if $(IS_FCGI), $(STOP_FCGI))
	$(RUN_FCGI)
	@echo
stop-nginx:
	$(if $(IS_NGINX), $(STOP_NGINX))


fcgi: .reload
	$(if $(IS_FCGI), , $(RUN_FCGI))
stop-fcgi:
	$(if $(IS_FCGI), $(STOP_FCGI))

test: test-resty test-fcgi
test-resty: nginx
	@echo Testing resty server
	curl -fs "http://localhost:$(PORT_RESTY)/$(REQUEST)"
test-fcgi: nginx fcgi
	@echo Testing fcgi server
	curl -fs "http://localhost:$(PORT_FCGI)/$(REQUEST)"

benchmarks benchmark: benchmark-resty benchmark-fcgi
benchmark-resty: test-resty
	@echo Benchmarking openresty LuaJIT
	ab -k -c1000 -n50000 -S "http://localhost:$(PORT_RESTY)/$(REQUEST)" 2> >(grep -v " requests")
benchmark-fcgi: test-fcgi
	@echo Benchmarking FastCGI $(shell $(LUA) -e 'print(_VERSION)')
	ab -k -c1000 -n50000 -S "http://localhost:$(PORT_FCGI)/$(REQUEST)" 2> >(grep -v " requests")
summary:
	@$(MAKE) benchmark | egrep "^ab|Time taken"

# Define a newline macro -- only way to use use \n in info output. Note: needs two newlines after 'define' line
define \n


endef
vars:
	$(info $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), $(\n)$(v)=$(value $(v))) ))

.PHONY: all benchmark
.PHONY: stop start reload force-reload
.PHONY: nginx stop-nginx
.PHONY: fcgi stop-fcgi
.PHONY: test test-resty test-fcgi
.PHONY: benchmarks benchmark benchmark-resty benchmark-fcgi summary
