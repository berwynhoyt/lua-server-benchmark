# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

SHELL := /bin/bash

REQUEST :=
#REQUEST := multiply?a=2&b=3

PORT_RESTY := 8081
PORT_FCGI := 8082
PORT_UWSGI := 8083
SOCKET_FCGI := /tmp/nginx-fcgi-benchmark.sock
SOCKET_UWSGI := /tmp/nginx-uwsgi-benchmark.sock

LUA=$(shell which lua)
NGINX := $(shell which nginx >/dev/null && echo nginx || echo /usr/local/openresty/nginx/sbin/nginx)
RUN_NGINX := $(NGINX) -p nginx -c conf/nginx.conf
STOP_NGINX := $(RUN_NGINX) -s quit

RUN_FCGI := spawn-fcgi -F 10 -s $(SOCKET_FCGI) -P fcgi.pid -d www -- $(LUA) fcgi-run.lua
STOP_FCGI := kill -9 `cat fcgi.pid` && rm -f fcgi.pid

RUN_UWSGI := build/uwsgi/uwsgi --http :8083 --http-modifier1 6 --lua www/uwsgi-app.lua -L --async 10 --processes 8 &
#RUN_UWSGI := build/uwsgi/uwsgi --socket $(SOCKET_UWSGI) --lua www/uwsgi-app.lua -L --async 10 --processes 8 &
STOP_UWSGI := killall uwsgi

IS_NGINX = $(shell lsof -i TCP:$(PORT_RESTY) &>/dev/null && echo yes)
IS_FCGI = $(shell lsof -a -U -- $(SOCKET_FCGI) &>/dev/null && echo yes)
IS_UWSGI = $(shell lsof -i TCP:$(PORT_UWSGI) &>/dev/null && echo yes)
#IS_UWSGI = $(shell lsof -a -U -- $(SOCKET_UWSGI) &>/dev/null && echo yes)

UWSGI_SOURCE := https://github.com/unbit/uwsgi.git

$(shell mkdir -p nginx/logs)
$(shell mkdir -p build)

all: benchmark
start: nginx fcgi
stop: fcgi-stop nginx-stop uwsgi-stop
reload: | force-reload .reload
force-reload:
	@touch nginx/conf/nginx.conf

benchmarks benchmark: benchmark-resty benchmark-fcgi
benchmark-resty: test-resty
	@echo Benchmarking openresty LuaJIT
	ab -k -c1000 -n50000 -S "http://localhost:$(PORT_RESTY)/$(REQUEST)" 2> >(grep -v " requests")
benchmark-fcgi: test-fcgi
	@echo Benchmarking FastCGI $(shell $(LUA) -e 'print(_VERSION)')
	ab -k -c100 -n50000 -S "http://localhost:$(PORT_FCGI)/$(REQUEST)" 2> >(grep -v " requests")
benchmark-uwsgi: test-uwsgi
	@echo Benchmarking uWSGI
	ab -k -c100 -n50000 -S "http://localhost:$(PORT_UWSGI)/$(REQUEST)" 2> >(grep -v " requests")
summary:
	@$(MAKE) benchmark | egrep "^ab|Time taken"

test: test-resty test-fcgi
test-resty: nginx
	@echo Testing resty server
	curl -f "http://localhost:$(PORT_RESTY)/$(REQUEST)"
test-fcgi: nginx fcgi
	@echo Testing fcgi server
	curl -f "http://localhost:$(PORT_FCGI)/$(REQUEST)"
test-uwsgi: nginx uwsgi
	@echo Testing uwsgi server
	curl -f "http://localhost:$(PORT_UWSGI)/$(REQUEST)"

nginx: nginx/logs/nginx.pid .reload
	$(if $(IS_NGINX), , $(RUN_NGINX))
nginx/logs/nginx.pid:
	$(RUN_NGINX)
.reload: nginx/conf/nginx.conf Makefile build/uwsgi/uwsgi www/fcgi-app.lua www/uwsgi-app.lua
	@echo Reloading server config
	@touch .reload
	$(if $(IS_NGINX), $(RUN_NGINX) -s reload && sleep 0.1, $(RUN_NGINX))
	$(if $(IS_FCGI), $(STOP_FCGI))
	$(RUN_FCGI)
	$(if $(IS_UWSGI), $(STOP_UWSGI))
	$(RUN_UWSGI)
	@sleep 0.1
	@echo
nginx-stop:
	$(if $(IS_NGINX), $(STOP_NGINX))

fcgi: .reload
	$(if $(IS_FCGI), , $(RUN_FCGI))
fcgi-stop:
	$(if $(IS_FCGI), $(STOP_FCGI))

uwsgi: build/uwsgi/uwsgi .reload
	$(if $(IS_UWSGI), , $(RUN_UWSGI))
	@sleep 0.1
uwsgi-stop:
	$(if $(IS_UWSGI), $(STOP_UWSGI))
build/uwsgi/uwsgi: build/uwsgi/Makefile
	$(MAKE) -C build/uwsgi lua  --no-print-directory
build/uwsgi/Makefile:
	@echo Fetching $(dir $@)
	git clone "$(UWSGI_SOURCE)" $(dir $@)
.PRECIOUS: build/uwsgi/Makefile


clean: stop
	rm -f fcgi.pid uwsgi.log nginx/logs/nginx.pid
	$(MAKE) -C build/uwsgi clean  --no-print-directory

# Define a newline macro -- only way to use use \n in info output. Note: needs two newlines after 'define' line
define \n


endef
vars:
	$(info $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), $(\n)$(v)=$(value $(v))) ))

.PHONY: all start stop reload force-reload
.PHONY: test test-resty test-fcgi
.PHONY: benchmarks benchmark benchmark-resty benchmark-fcgi summary
.PHONY: nginx nginx-stop
.PHONY: fcgi fcgi-stop
.PHONY: uwsgi uwsgi-stop
