# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

loops := 50000

SHELL := /bin/bash

# Version of Lua to use with nginx-lws
LWS_LUA_VERSION := 5.4

REQUEST :=
REQUEST := multiply?a=2&b=3

PORT_apache := 8080
PORT_resty := 8081
PORT_fcgi := 8082
PORT_uwsgi := 8083
PORT_lws := 8084
PORT_redbean := 8085

export SOCKET_FCGI := /tmp/nginx-fcgi-benchmark.sock
export SOCKET_UWSGI := /tmp/nginx-uwsgi-benchmark.sock

export LUA_PATH := www/?.lua;;
export LUA_INIT :=
LUA=$(shell which lua)
NGINX := nginx
RESTY := openresty
APACHE := apache2

# Note: wrk2 is like Apache Benchmark but faster and supports HTTP1.1, which allows keep-alive to work with redbean server.
# weighttp is another but it sometimes weirdly delays extra seconds at the end if -c != -t
# You can set BENCHMARKER to httpress but:
# - that fails to recognize keep-alive from redbean (I think it's a but in http-parser)
# - the following patch works around this bug for redbean, but causes it to fail the other benchmarks
#   - Patch: sed -i 's/ || !conn->keep_alive//g' httpress/httpress.c
# - also fails some requests if -c >10
# - and httpress has horrendous dependencies
# wrk2 is best, but its results have to be converted to time for 50000 iterations to match other results
# The important thing is that all 3 tools give very similar results, which works as a validator
# Select wrk2, weighttp, or httpress:
BENCHMARKER := wrk2
BENCHMARK := weighttp/src/weighttp -k -n$(loops) -c10 -t10
ifeq ($(BENCHMARKER), httpress)
  BENCHMARK := httpress/bin/Release/httpress -kq -n$(loops) -c20 -p2
endif
ifeq ($(BENCHMARKER), wrk2)
  # Optimal is approx -c10 and -t10. Much more than 40 and apache starts getting timeouts
  BENCHMARK := wrk2/wrk -d2 -c10 -t10 -R 1000000
endif

# make sure CPU is cool before each benchmark
CPUCOOL := sleep 5


#The following line should, in theory, be faster with --async 100 or --processes 7, but it's slower. What am I missing about servers running in parallel on multiple cores?
UWSGI_PLUGIN_DIR = uwsgi/lua5.1

RUN_APACHE := $(APACHE) -f "$(shell pwd)/apache/httpd.conf"
STOP_APACHE := $(RUN_APACHE) -k stop

RUN_RESTY := $(RESTY) -p nginx -e logs/error-resty.log -c conf/resty.conf
STOP_RESTY := $(RUN_RESTY) -s quit

RUN_NGINX := $(NGINX) -p nginx -e logs/error-nginx.log -c conf/nginx.conf
STOP_NGINX := $(RUN_NGINX) -s quit

RUN_FCGI := spawn-fcgi -F 1 -s $(SOCKET_FCGI) -P fcgi.pid -d www -- $(LUA) fcgi-run.lua
STOP_FCGI := kill -9 `cat fcgi.pid` && rm -f fcgi.pid

RUN_UWSGI = (uwsgi/uwsgi --plugin-dir $(UWSGI_PLUGIN_DIR) --ini uwsgi.ini &) && sleep 0.1
STOP_UWSGI := killall uwsgi

RUN_REDBEAN := ./redbean.com -p $(PORT_redbean) -d -D www
STOP_REDBEAN := killall redbean.com

IS_APACHE = $(shell lsof -i TCP:$(PORT_apache) &>/dev/null && echo yes)
IS_RESTY = $(shell lsof -i TCP:$(PORT_resty) &>/dev/null && echo yes)
IS_NGINX = $(shell lsof -i TCP:$(PORT_lws) &>/dev/null && echo yes)
IS_FCGI = $(shell lsof -a -U -- $(SOCKET_FCGI) &>/dev/null && echo yes)
IS_UWSGI = $(shell lsof -a -U -- $(SOCKET_UWSGI) &>/dev/null && echo yes)
IS_REDBEAN = $(shell lsof -i TCP:$(PORT_redbean) &>/dev/null && echo yes)

UWSGI_SOURCE := https://github.com/unbit/uwsgi.git

WEIGHTTP_SOURCE := https://github.com/lighttpd/weighttp.git
WRK2_SOURCE := https://github.com/giltene/wrk2.git
LWS_SOURCE := https://github.com/anaef/nginx-lws.git

$(shell mkdir -p nginx/logs apache/logs nginx/modules)

all: summary
start: resty nginx apache uwsgi fcgi redbean
stop: redbean-stop fcgi-stop uwsgi-stop apache-stop nginx-stop resty-stop
reload:
	@# Force .reload target to run
	@touch nginx/conf/resty.conf
	$(MAKE) .reload  --no-print-directory
build: build-nginx-lws resty nginx apache fcgi redbean uwsgi

summary: build
	@# The sed filter below converts weighttp output to decimal seconds, zero-padding and converting ms to decimal
	@# The awk filter below converts wrk2 output to speed of 50,000 requests -- to match results of other tools
	@$(MAKE) benchmark | egrep --line-buffered "finished|weighttp/|Requests/sec:|loops:|Non-2xx|errors|Benchmarking [^l]|^[ ]$$" \
		| sed -uE 's/ sec, ([0-9]+) millisec/\.00\1s/;s/\.0*([0-9]{3,})/\.\1/' \
		| awk '!/^Requests.sec/ {print} /^Requests.sec: +[0-9.]+/ {printf "50000 requests in %fs\n",50000/$$2}'
benchmarks benchmark: benchmark-redbean benchmark-resty benchmark-lws benchmark-apache benchmark-fcgi
	@$(MAKE) benchmark-uwsgi-lua5.1  --no-print-directory
	@$(MAKE) benchmark-uwsgi-lua5.4  --no-print-directory
	@$(MAKE) benchmark-uwsgi-luajit  --no-print-directory
benchmark-redbean: test-redbean $(BENCHMARKER)
	@echo "Benchmarking Redbean $(shell ./redbean.com -e 'print(_VERSION) os.exit()')"
	@$(CPUCOOL)
	$(BENCHMARK) "http://localhost:$($(subst benchmark-,PORT_,$@))/$(REQUEST)"
	@echo " "
benchmark-resty: test-resty $(BENCHMARKER)
	@echo "Benchmarking openresty LuaJIT"
	@$(CPUCOOL)
	$(BENCHMARK) "http://localhost:$($(subst benchmark-,PORT_,$@))/$(REQUEST)"
	@echo " "
benchmark-lws: test-lws $(BENCHMARKER)
	@echo "Benchmarking nginx-lws (Lua Web Services)"
	@$(CPUCOOL)
	$(BENCHMARK) "http://localhost:$($(subst benchmark-,PORT_,$@))/$(REQUEST)"
	@echo " "
benchmark-apache: test-apache $(BENCHMARKER)
	@echo "Benchmarking apache mod-lua"
	@$(CPUCOOL)
	$(BENCHMARK) "http://localhost:$($(subst benchmark-,PORT_,$@))/$(REQUEST)"
	@echo " "
benchmark-fcgi: test-fcgi $(BENCHMARKER)
	@echo "Benchmarking FastCGI $(shell $(LUA) -e 'print(_VERSION)')"
	@$(CPUCOOL)
	$(BENCHMARK) "http://localhost:$($(subst benchmark-,PORT_,$@))/$(REQUEST)"
	@echo " "
benchmark-uwsgi: test-uwsgi $(BENCHMARKER)
	@echo "Benchmarking $(UWSGI_PLUGIN_DIR)"
	@$(CPUCOOL)
	$(BENCHMARK) "http://localhost:$($(subst benchmark-,PORT_,$@))/$(REQUEST)"
	@echo " "
benchmark-uwsgi-lua5.1: UWSGI_PLUGIN_DIR=uwsgi/lua5.1
benchmark-uwsgi-lua5.1: benchmark-uwsgi
benchmark-uwsgi-lua5.4: UWSGI_PLUGIN_DIR=uwsgi/lua5.4
benchmark-uwsgi-lua5.4: benchmark-uwsgi
benchmark-uwsgi-luajit:  UWSGI_PLUGIN_DIR=uwsgi/luajit
benchmark-uwsgi-luajit:  benchmark-uwsgi

test: test-resty test-lws test-apache test-fcgi test-redbean test-uwsgi
	@echo Testing uWSGI server with Lua5.1
	@$(MAKE) test-uwsgi-lua5.1  --no-print-directory
	@echo Testing uWSGI server with Lua5.4
	@$(MAKE) test-uwsgi-lua5.4  --no-print-directory
	@echo Testing uWSGI server with LuaJIT
	@$(MAKE) test-uwsgi-luajit  --no-print-directory
test-resty: resty
	@echo "Testing resty server"
	curl -fsS "http://localhost:$($(subst test-,PORT_,$@))/$(REQUEST)"
test-lws: nginx
	@echo "Testing nginx-lws (Lua Web Services) server"
	curl -fsS "http://localhost:$($(subst test-,PORT_,$@))/$(REQUEST)"
test-apache: apache
	@echo "Testing apache server"
	curl -fsS "http://localhost:$($(subst test-,PORT_,$@))/$(REQUEST)"
test-fcgi: resty fcgi
	@echo "Testing fcgi server"
	curl -fsS "http://localhost:$($(subst test-,PORT_,$@))/$(REQUEST)"
test-redbean: redbean
	@echo "Testing redbean server"
	curl -fsS "http://localhost:$($(subst test-,PORT_,$@))/$(REQUEST)"
test-uwsgi: resty uwsgi
	@echo "Testing uWSGI server"
	curl -fsS "http://localhost:$($(subst test-,PORT_,$@))/$(REQUEST)"
test-uwsgi-lua5.1: UWSGI_PLUGIN_DIR=uwsgi/lua5.1
test-uwsgi-lua5.1: test-uwsgi
test-uwsgi-lua5.4: UWSGI_PLUGIN_DIR=uwsgi/lua5.4
test-uwsgi-lua5.4: test-uwsgi
test-uwsgi-luajit:  UWSGI_PLUGIN_DIR=uwsgi/luajit
test-uwsgi-luajit:  test-uwsgi

resty: nginx/logs/resty.pid .reload
	$(if $(IS_RESTY), , $(RUN_RESTY))
nginx/logs/resty.pid:
	$(RUN_RESTY)
.reload: nginx/conf/resty.conf nginx/conf/nginx.conf apache/httpd.conf Makefile www/*.lua redbean.com
	@echo Reloading server config
	@touch .reload
	$(if $(IS_RESTY), $(RUN_RESTY) -s reload && sleep 0.1, $(RUN_RESTY))
	$(if $(IS_NGINX), $(RUN_NGINX) -s reload && sleep 0.1, $(RUN_NGINX))
	$(if $(IS_APACHE), $(RUN_APACHE) -k restart && sleep 0.1, $(RUN_APACHE))
	$(if $(IS_UWSGI), $(STOP_UWSGI))
	$(RUN_UWSGI)
	$(if $(IS_FCGI), $(STOP_FCGI))
	$(RUN_FCGI)
	$(if $(IS_REDBEAN), $(STOP_REDBEAN))
	$(RUN_REDBEAN)
	@echo
resty-stop:
	$(if $(IS_RESTY), $(STOP_RESTY))

nginx: nginx/logs/nginx.pid .reload
	$(if $(IS_NGINX), , $(RUN_NGINX))
nginx/logs/nginx.pid:
	$(RUN_NGINX)
nginx-stop: build-nginx-lws
	$(if $(IS_NGINX), $(STOP_NGINX))

apache: apache/logs/apache.pid .reload
	$(if $(IS_APACHE), , $(RUN_APACHE))
apache/logs/apache.pid:
	$(RUN_APACHE)
apache-stop:
	$(if $(IS_APACHE), $(STOP_APACHE))

fcgi: .reload
	$(if $(IS_FCGI), , $(RUN_FCGI))
fcgi-stop:
	$(if $(IS_FCGI), $(STOP_FCGI))

# set UWSGI_PLUGIN_DIR before invoking this target:
uwsgi: build-uwsgi
	$(if $(IS_UWSGI), , $(RUN_UWSGI))
uwsgi-stop:
	$(if $(IS_UWSGI), $(STOP_UWSGI))
build-uwsgi: uwsgi/uwsgi uwsgi/lua5.1/lua_plugin.so uwsgi/lua5.4/lua_plugin.so uwsgi/luajit/lua_plugin.so
uwsgi/uwsgi: uwsgi/Makefile
	$(MAKE) -C uwsgi all PROFILE=core --no-print-directory
uwsgi/lua5.1/lua_plugin.so: uwsgi/Makefile
	$(MAKE) -C uwsgi plugin.lua PROFILE=core UWSGICONFIG_LUAPC=lua5.1 plugin.lua --no-print-directory
	mkdir -p uwsgi/lua5.1
	mv uwsgi/lua_plugin.so uwsgi/lua5.1
uwsgi/lua5.4/lua_plugin.so: uwsgi/Makefile
	$(MAKE) -C uwsgi plugin.lua PROFILE=core UWSGICONFIG_LUAPC=lua5.4 plugin.lua --no-print-directory
	mkdir -p uwsgi/lua5.4
	mv uwsgi/lua_plugin.so uwsgi/lua5.4
uwsgi/luajit/lua_plugin.so: uwsgi/Makefile
	$(MAKE) -C uwsgi plugin.lua PROFILE=core UWSGICONFIG_LUAPC=luajit  --no-print-directory
	mkdir -p uwsgi/luajit
	mv uwsgi/lua_plugin.so uwsgi/luajit
uwsgi/Makefile:
	@echo Fetching $(dir $@)
	git clone "$(UWSGI_SOURCE)" $(dir $@)
.PRECIOUS: uwsgi/Makefile

redbean: redbean.com
	$(if $(IS_REDBEAN), , $(RUN_REDBEAN))
redbean-stop:
	$(if $(IS_REDBEAN), $(STOP_REDBEAN))

# Fetch nginx source and use it to build nginx-lws
# (Instructions taken from https://github.com/anaef/nginx-lws/blob/main/doc/Installation.md)
NGINX_VERSION := $(shell $(NGINX) -v 2>&1 | sed -E 's|.*version: ([/a-zA-Z]+)/([0-9.]+).*|\1-\2|')
NGINX_NAME    := $(shell $(NGINX) -v 2>&1 | sed -E 's|.*version: ([/a-zA-Z]+)/([0-9.]+).*|\1|')
#DEBUG_LOGGING := --with-debug
build-nginx-lws: nginx-source/objs/lws_module.so
nginx-source/objs/lws_module.so: nginx-source/Makefile
	$(MAKE) -C nginx-source modules
	cp $@ nginx/modules/lws_module.so
nginx-source/Makefile: nginx-source/configure nginx-lws/config
	sed -ie "s/lws_lua=lua.*/lws_lua=lua$(LWS_LUA_VERSION)/" nginx-lws/config
	cd nginx-source && ./configure --with-compat --with-threads --add-dynamic-module=../nginx-lws $(DEBUG_LOGGING)
nginx-source/configure:
	curl https://$(NGINX_NAME).org/download/$(NGINX_VERSION).tar.gz >$(NGINX_VERSION).tar.gz
	tar -xzf $(NGINX_VERSION).tar.gz
	mv $(NGINX_VERSION) nginx-source
nginx-lws/config:
	git clone $(LWS_SOURCE) nginx-lws


wrk2: wrk2/Makefile
	$(MAKE) -c wrk2
wrk2/Makefile:
	git clone $(WRK2_SOURCE) wrk2

UBUNTU_BASED := $(shell grep UBUNTU /etc/os-release)
REDBEAN_VERSION := latest
redbean.com:
	curl https://redbean.dev/redbean-$(REDBEAN_VERSION).com >redbean.com
	chmod +x redbean.com
 #UBUNTU problem workaround
 ifneq (,$(UBUNTU_BASED))
  ifeq (,$(wildcard /proc/sys/fs/binfmt_misc/APE))
	@echo
	@echo The next command works around an Ubuntu problem in running APE executables.
	@echo You may need to enter your root password.
	sudo sh -c "echo ':APE:M::MZqFpD::/bin/sh:' >/proc/sys/fs/binfmt_misc/register"
  endif
 endif
	./redbean.com --assimilate

weighttp: weighttp/src/weighttp
weighttp/src/weighttp: weighttp/Makefile.am
	cd weighttp && ./autogen.sh && ./configure
	$(MAKE) -C weighttp
weighttp/Makefile.am:
	@echo Fetching $(dir $@)
	git clone "$(WEIGHTTP_SOURCE)" $(dir $@)

# Built httpress -- complicated because of all its dependencies
HP_INCLUDES := C_INCLUDE_PATH="$$C_INCLUDE_PATH../libparserutils/include" LIBRARY_PATH="$$LIBRARY_PATH:../libparserutils/release/lib"  
httpress: httpress/bin/Release/httpress
httpress/bin/Release/httpress: httpress/Makefile libparserutils
	$(HP_INCLUDES) $(MAKE) -C httpress  CC="gcc -Wno-format -Wno-deprecated-declarations"
httpress/Makefile:
	git clone https://github.com/virtuozzo/httpress.git
libparserutils: libparserutils/Makefile
	$(MAKE) -C libparserutils install PREFIX=release NSSHARED=../buildsystem
libparserutils/Makefile:
	git clone https://git.netsurf-browser.org/buildsystem.git  # required to build libparserutils
	git clone git://git.netsurf-browser.org/libparserutils.git

#Legacy builds no longer needed with: apt install libhttp-parser-dev libuchardet-dev 
http-parser: http-parser/Makefile
	$(MAKE) -C http-parser library
http-parser/Makefile:
	git clone https://github.com/nodejs/http-parser.git
uchardet: uchardet/uchardet/uchardet.h
uchardet/uchardet/uchardet.h: uchardet/CMakeLists.txt
	cd uchardet && ln -sf src uchardet
uchardet/CMakeLists.txt:
	git clone https://github.com/BYVoid/uchardet.git

clean:
	rm -f uwsgi.log
	rm -rf uwsgi/uwsgi uwsgi/lua5.1 uwsgi/luajit
	rm -f nginx-*.tar.gz
	rm -rf nginx-source/Makefile nginx-source/objs nginx/modules/lws_module.so
	rm -f redbean.com
	rm -rf weighttp
	rm -rf hp httpress libparseutils
	$(MAKE) -C uwsgi clean  --no-print-directory

# Define a newline macro -- only way to use use \n in info output. Note: needs two newlines after 'define' line
define \n


endef

vars:
	$(info $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), $(\n)$(v)=$(value $(v))) ))

#Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
.DELETE_ON_ERROR:

.PHONY: all start stop reload force-reload
.PHONY: test test-resty test-fcgi test-uwsgi%
.PHONY: summary benchmarks benchmark benchmark-resty benchmark-fcgi benchmark-uwsgi%
.PHONY: nginx nginx-stop resty resty-stop
.PHONY: fcgi fcgi-stop
.PHONY: uwsgi uwsgi-stop build-uwsgi
.PHONY: build build-nginx-lws
.PHONY: httpress libparserutils http-parser uchardet
.PHONY: weighttp
