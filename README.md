# Lua benchmark: OpenResty vs NGINX+WSAPI

## Installation

Here are instructions to install [OpenResty](https://openresty.org/en/installation.html) and [LuaRocks](https://luarocks.org/#quick-start).

Next install what we need for our specific benchmarks. These instructions work on Ubuntu (otherwise see troubleshooting note on missing packages below):

```shell
apt install apache2-utils  # supplies ab, the apache benchmark tool
apt install libfcgi-dev    # supplies fcgi_stdio.h
sudo luarocks install wsapi-fcgi
apt install lua5.1 liblua5.1-dev      # required to build uWSGI with lua support
apt install luajit libluajit-5.1-dev  # required to build uWSGI with luajit support
```

Start your nginx and fcgi servers:

```shell
make start
```

Test that nginx is working:

```shell
$ make test
curl http://localhost:8081/ && echo Success
<p>hello, world</p>
Success
curl http://localhost:8082/ && echo Success
<html><body><p>Hello Wsapi!</p><p>PATH_INFO: /</p><p>SCRIPT_NAME: /run.lua</p></body></html>
Success
```

Run the benchmarks:

```shell
make benchmarks
```

## Results

The benchmark results on a quad-core i7-8565 @1.8GHz are as follows, where 8081 is port serving OpenResty's Lua and 8082 is PUC Lua via FastCGI:

```shell
$ make summary
Benchmarking openresty LuaJIT
ab -k -c1000 -n50000 -S "http://localhost:8081/multiply?a=2&b=3"
Time taken for tests:   0.442 seconds
 
Benchmarking FastCGI Lua 5.4
ab -k -c100 -n50000 -S "http://localhost:8082/multiply?a=2&b=3"
Time taken for tests:   2.864 seconds
 
Benchmarking uwsgi/lua5.1
ab -k -c100 -n50000 -S "http://localhost:8083/multiply?a=2&b=3"
Time taken for tests:   2.657 seconds
 
Benchmarking uwsgi/luajit
ab -k -c100 -n50000 -S "http://localhost:8083/multiply?a=2&b=3"
Time taken for tests:   2.635 seconds
```

In short, OpenResty's Lua solution is about **6.5× faster** than Lua via FastCGI protocol and  **6× faster** than Lua via uWSGI's WSAPI protocol. As you can see, it makes no difference whether we use Lua or LuaJIT in this case – presumably because the Lua program is so small, its speed is swamped by WSAPI protocol overhead.

## Troubleshooting

### Deprecation warning

Please note that although uWSGI is used as a benchmark comparison point, it is already in maintenance mode and building it already has deprecation warnings for use of old ssl and python distutils functions. Because of this, it requires python < 3.12 and it is not clear what version of libssl-dev will drop support.

### Missing packages

If your OS does have the specified Lua packages, you may need to build them from source. In that case, you will need to change the Makefile to specify locations to them. See [uWSGI notes on using Lua](https://uwsgi-docs.readthedocs.io/en/latest/Lua.html#:~:text=If%20you%20do%20not%20want%20to%20rely%20on%20the%20pkg%2Dconfig%20tool).

### Too many open files

If you get this error when you run `make benchmark` then the benchmarking is trying to make more simultaneous requests than your user allows. Check the number of requests your user is allowed as follows:

```shell
$ ulimit -Hn
1048576
$ ulimit -Sn
1024
```

These numbers should be significantly greater than the `-c<connections>` parameter in the `ab` command run by `make benchmark`. If not, see how to increase your open file limit [here](https://www.cyberciti.biz/faq/linux-unix-nginx-too-many-open-files/) or [here for Ubuntu](https://manage.accuwebhosting.com/knowledgebase/3334/How-to-Increase-Open-Files-Limit-in-Ubuntu.html).

