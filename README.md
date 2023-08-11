# Lua benchmark: OpenResty vs NGINX+WSAPI

## Installation

Install OpenResty [like this](https://openresty.org/en/installation.html).

Add this to your .bashrc and restart bash:

```shell
export PATH=$PATH:/usr/local/openresty/nginx/sbin
```

Start your server:

```shell
make nginx
```

Test that it's working:

```shell
make test
```

Benchmark:

```shell
make benchmark
```

