# Lua benchmark: OpenResty vs NGINX+WSAPI

## Installation

Install OpenResty [like this](https://openresty.org/en/installation.html).

Install apache's benchmark tester `ab`:

```shell
apt install apache2-utils
```

Start your server:

```shell
make nginx
```

Test that it's working:

```shell
$ make test
curl http://localhost:8080/
<p>hello, world</p>
```

Benchmark:

```shell
make benchmark
```

