# Makefile to test performance of Lua in OpenResty vs NGINX+WSAPI+Lua5.4

loops := 50000

SHELL := /bin/bash

# Version of Lua to use with nginx-lws
LWS_LUA_VERSION := 5.4

REQUEST :=
REQUEST := multiply?a=2&b=3

PORT_APACHE := 8080
PORT_RESTY := 8081
PORT_FCGI := 8082
PORT_UWSGI := 8083
PORT_LWS := 8084
PORT_REDBEAN := 8085

export SOCKET_FCGI := /tmp/nginx-fcgi-benchmark.sock
export SOCKET_UWSGI := /tmp/nginx-uwsgi-benchmark.sock

export LUA_PATH := www/?.lua;;
export LUA_INIT :=
LUA=$(shell which lua)
NGINX := nginx
RESTY := openresty
APACHE := apache2

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

RUN_REDBEAN := ./redbean.com -p $(PORT_REDBEAN) -d -D www
STOP_REDBEAN := killall redbean.com

IS_APACHE = $(shell lsof -i TCP:$(PORT_APACHE) &>/dev/null && echo yes)
IS_RESTY = $(shell lsof -i TCP:$(PORT_RESTY) &>/dev/null && echo yes)
IS_NGINX = $(shell lsof -i TCP:$(PORT_LWS) &>/dev/null && echo yes)
IS_FCGI = $(shell lsof -a -U -- $(SOCKET_FCGI) &>/dev/null && echo yes)
IS_UWSGI = $(shell lsof -a -U -- $(SOCKET_UWSGI) &>/dev/null && echo yes)
IS_REDBEAN = $(shell lsof -i TCP:$(PORT_REDBEAN) &>/dev/null && echo yes)

UWSGI_SOURCE := https://github.com/unbit/uwsgi.git

$(shell mkdir -p nginx/logs apache/logs nginx/modules)

all: summary
start: resty nginx apache uwsgi fcgi redbean
stop: redbean-stop fcgi-stop uwsgi-stop apache-stop nginx-stop resty-stop
reload: 
	@# Force .reload target to run
	@touch nginx/conf/resty.conf
	$(MAKE) .reload  --no-print-directory
fetch: nginx-lws/config nginx-source/configure redbean.com
build: build-nginx-lws

summary:
	@$(MAKE) benchmark 2> >(grep -v " requests") 1> >(egrep "^ab|Time taken|Benchmarking [^l]|^[ ]$$")
benchmarks benchmark: benchmark-resty benchmark-lws benchmark-apache benchmark-fcgi
	@$(MAKE) benchmark-uwsgi-lua5.1  --no-print-directory
	@$(MAKE) benchmark-uwsgi-lua5.4  --no-print-directory
	@$(MAKE) benchmark-uwsgi-luajit  --no-print-directory
benchmark-resty: test-resty
	@echo "Benchmarking openresty LuaJIT"
	ab -k -c25 -n$(loops) -S "http://localhost:$(PORT_RESTY)/$(REQUEST)"
	@echo " "
benchmark-lws: test-lws
	@echo "Benchmarking nginx-lws (Lua Web Services)"
	ab -k -c25 -n$(loops) -S "http://localhost:$(PORT_LWS)/$(REQUEST)"
	@echo " "
benchmark-apache: test-apache
	@echo "Benchmarking apache mod-lua"
	ab -k -c30 -n$(loops) -S "http://localhost:$(PORT_APACHE)/$(REQUEST)"
	@echo " "
benchmark-fcgi: test-fcgi
	@echo "Benchmarking FastCGI $(shell $(LUA) -e 'print(_VERSION)')"
	ab -k -c10 -n$(loops) -S "http://localhost:$(PORT_FCGI)/$(REQUEST)"
	@echo " "
benchmark-redbean: test-redbean
	@echo "Benchmarking Redbean $(shell ./redbean.com -e 'print(_VERSION) os.exit()')"
	ab -k -c10 -n$(loops) -S "http://localhost:$(PORT_REDBEAN)/$(REQUEST)"
	@echo " "
benchmark-uwsgi-lua5.1: UWSGI_PLUGIN_DIR=uwsgi/lua5.1
benchmark-uwsgi-lua5.1: benchmark-uwsgi
benchmark-uwsgi-lua5.4: UWSGI_PLUGIN_DIR=uwsgi/lua5.4
benchmark-uwsgi-lua5.4: benchmark-uwsgi
benchmark-uwsgi-luajit:  UWSGI_PLUGIN_DIR=uwsgi/luajit
benchmark-uwsgi-luajit:  benchmark-uwsgi
benchmark-uwsgi: test-uwsgi
	@echo "Benchmarking $(UWSGI_PLUGIN_DIR)"
	ab -k -c100 -n$(loops) -S "http://localhost:$(PORT_UWSGI)/$(REQUEST)"
	@echo " "

test: test-resty test-apache test-fcgi
	@echo Testing uWSGI server with Lua5.1
	@$(MAKE) test-uwsgi-lua5.1  --no-print-directory
	@echo Testing uWSGI server with Lua5.4
	@$(MAKE) test-uwsgi-lua5.4  --no-print-directory
	@echo Testing uWSGI server with LuaJIT
	@$(MAKE) test-uwsgi-luajit  --no-print-directory
test-resty: resty
	@echo "Testing resty server"
	curl -fsS "http://localhost:$(PORT_RESTY)/$(REQUEST)"
test-lws: build nginx
	@echo "Testing nginx-lws (Lua Web Services) server"
	curl -fsS "http://localhost:$(PORT_LWS)/$(REQUEST)"
test-apache: apache
	@echo "Testing apache server"
	curl -fsS "http://localhost:$(PORT_APACHE)/$(REQUEST)"
test-fcgi: resty fcgi
	@echo "Testing fcgi server"
	curl -fsS "http://localhost:$(PORT_FCGI)/$(REQUEST)"
test-redbean: redbean
	@echo "Testing redbean server"
	curl -fsS "http://localhost:$(PORT_REDBEAN)/$(REQUEST)"
test-uwsgi-lua5.1: UWSGI_PLUGIN_DIR=uwsgi/lua5.1
test-uwsgi-lua5.1: test-uwsgi
test-uwsgi-lua5.4: UWSGI_PLUGIN_DIR=uwsgi/lua5.4
test-uwsgi-lua5.4: test-uwsgi
test-uwsgi-luajit:  UWSGI_PLUGIN_DIR=uwsgi/luajit
test-uwsgi-luajit:  test-uwsgi
test-uwsgi: resty uwsgi
	@echo "Testing uWSGI server"
	curl -fsS "http://localhost:$(PORT_UWSGI)/$(REQUEST)"

resty: nginx/logs/resty.pid .reload
	$(if $(IS_RESTY), , $(RUN_RESTY))
nginx/logs/resty.pid:
	$(RUN_RESTY)
.reload: nginx/conf/resty.conf nginx/conf/nginx.conf apache/httpd.conf Makefile www/*.lua
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
nginx-stop:
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
#export LUAJIT_LIB="/usr/local/openresty/luajit/lib/"
#export LUAJIT_INC="../LuaJIT-2.1-20230410/src/"
nginx-source/Makefile: nginx-source/configure nginx-lws/config
	sed -ie "s/lws_lua=lua.*/lws_lua=lua$(LWS_LUA_VERSION)/" nginx-lws/config
	cd nginx-source && ./configure --with-compat --with-threads --add-dynamic-module=../nginx-lws $(DEBUG_LOGGING)
#export LUAJIT_LIB=../luajit2/src
#export LUAJIT_INC=../luajit2/src
#./configure --with-ld-opt="-Wl,-rpath,../luajit2/src" --add-module=../ngx_devel_kit --add-module=../lua-nginx-module --with-compat --with-threads --add-dynamic-module=../nginx-lws
#--with-cc-opt="-I/usr/include/lua5.4"  --with-ld-opt="-llua5.4"
# --prefix=/opt/nginx --with-ld-opt="-Wl,-rpath,/path/to/luajit/lib" --add-module=/path/to/ngx_devel_kit --add-module=/path/to/lua-nginx-module
# --prefix=/usr/local/openresty/nginx --with-cc-opt='-O2 -DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/zlib/include -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl111/include' --add-module=../ngx_devel_kit-0.3.2 --add-module=../echo-nginx-module-0.63 --add-module=../xss-nginx-module-0.06 --add-module=../ngx_coolkit-0.2 --add-module=../set-misc-nginx-module-0.33 --add-module=../form-input-nginx-module-0.12 --add-module=../encrypted-session-nginx-module-0.09 --add-module=../srcache-nginx-module-0.33 --add-module=../ngx_lua-0.10.25 --add-module=../ngx_lua_upstream-0.07 --add-module=../headers-more-nginx-module-0.34 --add-module=../array-var-nginx-module-0.06 --add-module=../memc-nginx-module-0.19 --add-module=../redis2-nginx-module-0.15 --add-module=../redis-nginx-module-0.3.9 --add-module=../ngx_stream_lua-0.0.13 --with-ld-opt='-Wl,-rpath,/usr/local/openresty/luajit/lib -L/usr/local/openresty/zlib/lib -L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl111/lib -Wl,-rpath,/usr/local/openresty/zlib/lib:/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl111/lib' --with-pcre-jit --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_v2_module --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --with-http_stub_status_module --with-http_realip_module --with-http_addition_module --with-http_auth_request_module --with-http_secure_link_module --with-http_random_index_module --with-http_gzip_static_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-threads --with-stream --with-http_ssl_module
nginx-source/configure:
	curl https://$(NGINX_NAME).org/download/$(NGINX_VERSION).tar.gz >$(NGINX_VERSION).tar.gz
	tar -xzf $(NGINX_VERSION).tar.gz
	mv $(NGINX_VERSION) nginx-source
nginx-lws/config:
	git clone https://github.com/anaef/nginx-lws.git


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

clean:
	rm -f fcgi.pid uwsgi.log nginx/logs/*.pid
	rm -rf uwsgi/uwsgi uwsgi/lua5.1 uwsgi/luajit
	rm -f nginx-*.tar.gz
	rm -rf nginx-source/Makefile nginx-source/objs nginx/modules/lws_module.so
	rm -f redbean.com
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
.PHONY: build build-nginx-lws fetch
