# Lua benchmark: OpenResty vs NGINX+WSAPI

## Results

![Requests/sec](https://docs.google.com/spreadsheets/d/e/2PACX-1vRk18zYXH0Yvx6KKWqO0Ypkedfg06G99nfV5l8uMVQc8s_hxS1N84vXetsiQE9S6teU3PoIYwPjVRHU/pubchart?oid=795106361&format=image)

(You can view this graph as [time-for-50,000-requests](https://docs.google.com/spreadsheets/d/e/2PACX-1vRk18zYXH0Yvx6KKWqO0Ypkedfg06G99nfV5l8uMVQc8s_hxS1N84vXetsiQE9S6teU3PoIYwPjVRHU/pubchart?oid=734804502&format=image) here).

The benchmark results on a quad-core i7-8565 @1.8GHz are as follows, where 8081 is port serving OpenResty's Lua and 8082 is PUC Lua via FastCGI:

```shell
Benchmarking Redbean Lua 5.4
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8085/multiply?a=2&b=3"
Requests/sec: 177811.23
 
Benchmarking openresty LuaJIT
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8081/multiply?a=2&b=3"
Requests/sec: 113018.85
 
Benchmarking nginx-lws (Lua Web Services)
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8084/multiply?a=2&b=3"
Requests/sec:  84172.28
 
Benchmarking apache mod-lua
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8080/multiply?a=2&b=3"
Requests/sec:  51086.05
 
Benchmarking FastCGI Lua 5.4
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8082/multiply?a=2&b=3"
Requests/sec:  18427.28
 
Benchmarking uwsgi/lua5.1
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8083/multiply?a=2&b=3"
Requests/sec:  30894.79
 
Benchmarking uwsgi/lua5.4
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8083/multiply?a=2&b=3"
Requests/sec:  30727.90
 
Benchmarking uwsgi/luajit
wrk2/wrk -d2 -c10 -t10 -R 1000000 "http://localhost:8083/multiply?a=2&b=3"
Requests/sec:  30579.44
```

In short, LWS is as good as OpenResty for raw speed of requests. Since our Lua program is so small and simple, it makes no difference whether we use Lua 5.1, Lua 5.4 or LuaJIT:

- **1.6×**: Redbean - impressive Lua server, but less generic (e.g. doesn't support Python apps)
- **1×**: OpenResty - fastest general purpose server
- **0.8×**: NGINX-LWS - close runner up
- **0.4×**: Apache
- **0.3×**: uWSGI - with WSAPI protocol
- **0.3×**: FastCGI protocol

**Notes:**

1. The uWSGI and FASTCGI options are slow because they use a protocol to serialize commands sent to Lua.
2. It's possible that there is a way to double the speed of my FastCGI and WSAPI benchmarks, because those benchmarks only use about half of each CPU core (according to htop), whereas the other benchmarks use almost 100% of every core. I don't know why NGINX doesn't parallel those up sufficiently to use 100% CPU. There may be a better server config, but I've tried various ones and I can't find it.
3. Not many benchmark tools are fast enough to produce good results. I have found only 3 that are fastest and produce very similar results: `wrk2`, `weighttp`, `httpress`.

## Installation

* Install Lua 5.1 and 5.4 (for Lua version comparison).
* Perform these instructions to install [LuaRocks](https://luarocks.org/#quick-start) (so that you can get wsapi-fcgi below).
* Install  [OpenResty](https://openresty.org/en/installation.html) and also [standard NGINX](https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/)
  * This will install NGINX twice: one invoked as `openresty` and the other invoked with `nginx`.
  * Most of the benchmarks are performed with openresty, but standard nginx is also necessary to benchmark `nginx-lws`, which doesn't work with OpenResty out of the box.

* Fetch and build `nginx-lws` against the Nginx source using:

```shell
make fetch build
```

Next install what we need for our specific benchmarks. These instructions work on Ubuntu (otherwise see troubleshooting note on missing packages below):

```shell
apt install apache2-utils  # supplies ab, the apache benchmark tool
apt install libfcgi-dev    # supplies fcgi_stdio.h
sudo luarocks install wsapi-fcgi
apt install lua5.1 liblua5.1-dev      # required to build uWSGI with lua5.1 support
apt install lua5.4 liblua5.4-dev      # required to build uWSGI with lua5.4 support
apt install luajit libluajit-5.1-dev  # required to build uWSGI with luajit support
apt install apache2  # needed for benchmark with apache and Lua
```

Start your nginx and fcgi servers:

```shell
make start
```

Test that nginx is working:

```shell
$ make test
Testing resty server
curl -fsS "http://localhost:8081/multiply?a=2&b=3"
<html><body><p>Hello NGINX-Lua!</p><p>PATH=/multiply</p><p>RESULT: 2*3=6</p></body></html>

Testing fcgi server
curl -fsS "http://localhost:8082/multiply?a=2&b=3"
<html><body><p>Hello WSAPI!</p><p>PATH=/multiply</p><p>RESULT: 2*3=6</p></body></html>

...
```

Run the benchmarks:

```shell
make summary  # or try make benchmarks for more info
make stop  # when you're done testing, stop the servers make started
```

Peruse the `Makefile` for other useful make targets if you want to test specific things.

If you want to experiment with different benchmark tools, I have left builders in the Makefile for `weighttp` and `httpress` which produce almost identical results. But you'll need:

```shell
apt install libev-dev libhttp-parser-dev libuchardet-dev gnutls-dev
```

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

