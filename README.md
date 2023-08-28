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

## Troubleshooting

### Too many open files

If you get this error when you run `make benchmark` then the benchmarking is trying to make more simultaneous requests than your user allows. Check the number of requests your user is allowed as follows:

```shell
$ ulimit -Hn
1048576
$ ulimit -Sn
1024
```

These numbers should be significantly greater than the `-c<connections>` parameter in the `ab` command run by `make benchmark`. If not, see how to increase your open file limit [here](https://www.cyberciti.biz/faq/linux-unix-nginx-too-many-open-files/) or [here for Ubuntu](https://manage.accuwebhosting.com/knowledgebase/3334/How-to-Increase-Open-Files-Limit-in-Ubuntu.html).

