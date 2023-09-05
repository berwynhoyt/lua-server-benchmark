# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

SHELL := /bin/bash

REQUEST :=
REQUEST := multiply?a=2&b=3

export PORT_RESTY := 8081
export PORT_FCGI := 8082
export PORT_UWSGI := 8083
export SOCKET_FCGI := /tmp/nginx-fcgi-benchmark.sock
export SOCKET_UWSGI := /tmp/nginx-uwsgi-benchmark.sock

LUA=$(shell which lua)
export LUA_PATH := www/?.lua;;
NGINX := $(shell which nginx >/dev/null && echo nginx || echo /usr/local/openresty/nginx/sbin/nginx)
RUN_NGINX := $(NGINX) -p nginx -c conf/nginx.conf
STOP_NGINX := $(RUN_NGINX) -s quit

RUN_FCGI := spawn-fcgi -F 1 -s $(SOCKET_FCGI) -P fcgi.pid -d www -- $(LUA) fcgi-run.lua
STOP_FCGI := kill -9 `cat fcgi.pid` && rm -f fcgi.pid

#The following line should, in theory, be faster with --async 100 or --processes 7, but it's slower. What am I missing about servers running in parallel on multiple cores?
PLUGIN_DIR = uwsgi/lua5.1
RUN_UWSGI = (uwsgi/uwsgi --plugin-dir $(PLUGIN_DIR) --ini uwsgi.ini &) && sleep 0.1
STOP_UWSGI := killall uwsgi

IS_NGINX = $(shell lsof -i TCP:$(PORT_RESTY) &>/dev/null && echo yes)
IS_FCGI = $(shell lsof -a -U -- $(SOCKET_FCGI) &>/dev/null && echo yes)
IS_UWSGI = $(shell lsof -a -U -- $(SOCKET_UWSGI) &>/dev/null && echo yes)

UWSGI_SOURCE := https://github.com/unbit/uwsgi.git

$(shell mkdir -p nginx/logs)

all: summary
start: nginx fcgi
stop: fcgi-stop nginx-stop uwsgi-stop
reload:
	@touch nginx/conf/nginx.conf
	@$(MAKE) .reload  --no-print-directory

summary:
	@$(MAKE) benchmark 1> >(egrep "^ab|Time taken|Benchmarking [^l]|^[ ]$$") 2> >(grep -v " requests")
benchmarks benchmark: benchmark-resty benchmark-fcgi
	@$(MAKE) benchmark-uwsgi-lua5.1  --no-print-directory
	@$(MAKE) benchmark-uwsgi-luajit  --no-print-directory
benchmark-resty: test-resty
	@echo "Benchmarking openresty LuaJIT"
	ab -k -c1000 -n50000 -S "http://localhost:$(PORT_RESTY)/$(REQUEST)"
	@echo " "
benchmark-fcgi: test-fcgi
	@echo "Benchmarking FastCGI $(shell $(LUA) -e 'print(_VERSION)')"
	ab -k -c100 -n50000 -S "http://localhost:$(PORT_FCGI)/$(REQUEST)"
	@echo " "
benchmark-uwsgi-lua5.1: PLUGIN_DIR=uwsgi/lua5.1
benchmark-uwsgi-lua5.1: benchmark-uwsgi
benchmark-uwsgi-luajit: PLUGIN_DIR=uwsgi/luajit
benchmark-uwsgi-luajit: benchmark-uwsgi
benchmark-uwsgi: test-uwsgi
	@echo "Benchmarking $(PLUGIN_DIR)"
	ab -k -c100 -n50000 -S "http://localhost:$(PORT_UWSGI)/$(REQUEST)"
	@echo " "

test: test-resty test-fcgi
	@$(MAKE) test-uwsgi-lua5.1  --no-print-directory
	@$(MAKE) test-uwsgi-luajit  --no-print-directory
test-resty: nginx
	@echo Testing resty server
	curl -fsS "http://localhost:$(PORT_RESTY)/$(REQUEST)"
	@echo
test-fcgi: nginx fcgi
	@echo Testing fcgi server
	curl -fsS "http://localhost:$(PORT_FCGI)/$(REQUEST)"
	@echo
test-uwsgi-lua5.1: PLUGIN_DIR=uwsgi/lua5.1
test-uwsgi-lua5.1: test-uwsgi
test-uwsgi-luajit: PLUGIN_DIR=uwsgi/luajit
test-uwsgi-luajit: test-uwsgi
test-uwsgi: nginx uwsgi
	@echo Testing uwsgi server
	curl -fsS "http://localhost:$(PORT_UWSGI)/$(REQUEST)"
	@echo

nginx: nginx/logs/nginx.pid .reload
	$(if $(IS_NGINX), , $(RUN_NGINX))
nginx/logs/nginx.pid:
	$(RUN_NGINX)
.reload: nginx/conf/nginx.conf Makefile www/fcgi-app.lua www/uwsgi-app.lua
	@echo Reloading server config
	@touch .reload
	$(if $(IS_NGINX), $(RUN_NGINX) -s reload && sleep 0.1, $(RUN_NGINX))
	$(if $(IS_FCGI), $(STOP_FCGI))
	$(RUN_FCGI)
	@echo
nginx-stop:
	$(if $(IS_NGINX), $(STOP_NGINX))

fcgi: .reload
	$(if $(IS_FCGI), , $(RUN_FCGI))
fcgi-stop:
	$(if $(IS_FCGI), $(STOP_FCGI))

# set PLUGIN_DIR before invoking this target:
uwsgi: build-uwsgi uwsgi-stop
	$(RUN_UWSGI)
uwsgi-stop:
	$(if $(IS_UWSGI), $(STOP_UWSGI))
build-uwsgi: uwsgi/uwsgi uwsgi/lua5.1/lua_plugin.so uwsgi/luajit/lua_plugin.so
uwsgi/uwsgi: uwsgi/Makefile
	$(MAKE) -C uwsgi all PROFILE=core --no-print-directory
uwsgi/lua5.1/lua_plugin.so: uwsgi/Makefile
	$(MAKE) -C uwsgi plugin.lua PROFILE=core UWSGICONFIG_LUAPC=lua5.1 plugin.lua --no-print-directory
	mkdir -p uwsgi/lua5.1
	mv uwsgi/lua_plugin.so uwsgi/lua5.1
uwsgi/luajit/lua_plugin.so: uwsgi/Makefile
	$(MAKE) -C uwsgi plugin.lua PROFILE=core UWSGICONFIG_LUAPC=luajit  --no-print-directory
	mkdir -p uwsgi/luajit
	mv uwsgi/lua_plugin.so uwsgi/luajit
uwsgi/Makefile:
	@echo Fetching $(dir $@)
	git clone "$(UWSGI_SOURCE)" $(dir $@)
.PRECIOUS: uwsgi/Makefile


clean: stop
	rm -f fcgi.pid uwsgi.log nginx/logs/nginx.pid
	rm -rf uwsgi/uwsgi uwsgi/lua5.1 uwsgi/luajit
	$(MAKE) -C uwsgi clean  --no-print-directory

# Define a newline macro -- only way to use use \n in info output. Note: needs two newlines after 'define' line
define \n


endef
vars:
	$(info $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), $(\n)$(v)=$(value $(v))) ))

.PHONY: all start stop reload force-reload
.PHONY: test test-resty test-fcgi test-uwsgi%
.PHONY: summary benchmarks benchmark benchmark-resty benchmark-fcgi benchmark-uwsgi%
.PHONY: nginx nginx-stop
.PHONY: fcgi fcgi-stop
.PHONY: uwsgi uwsgi-stop build-uwsgi
