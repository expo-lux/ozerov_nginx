Вывод `nginx -V` с хостов `lb1` и `lb2`:
```
nginx version: nginx/1.18.0 (Ubuntu)
built with OpenSSL 1.1.1f  31 Mar 2020
TLS SNI support enabled
configure arguments: --with-cc-opt='-g -O2 -fdebug-prefix-map=/opt/nginx-1.18.0=. -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -fPIC' --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-compat --with-pcre-jit --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_v2_module --with-http_dav_module --with-http_slice_module --with-threads --add-module=/opt/nginx_upstream_check_module --with-http_addition_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_xslt_module=dynamic --with-stream=dynamic --with-stream_ssl_module --with-mail=dynamic --with-mail_ssl_module
```

Файл `/etc/nginx/nginx.conf` (одинаковый на всех хостах):
```
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 768;
}

http {
	log_format format '"$request" $request_time $upstream_response_time';
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log debug;

	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	server_names_hash_bucket_size 128;
	client_max_body_size   16M;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	ssl_dhparam /etc/nginx/dhparam.pem;	
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_prefer_server_ciphers on;
	
	gzip on;
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
```
Конфигурационый файл `/etc/nginx/sites-enabled/http.lb1.conf` c хоста `lb1` обслуживает сервер на 80-м порту (незащищенные соединения):
```
server {
    listen 80 default_server;
    server_name app lb1 _;
    real_ip_header X-Forwarded-For;
    set_real_ip_from lb2;

    location /.well-known/ {
        alias /opt/www/acme/.well-known/;
    }

    location / {
        return 301 https://app$request_uri;
    }
}
```
На хост `lb1` приходят (проксируются) `.well-known` запросы от `lb2` и, чтобы в access-логе отображались реальные IP-адреса запросов, здесь указаны директивы `real_ip_header` и `set_real_ip_from`.

Конфигурационный файл `/etc/nginx/sites-enabled/http.lb2.conf` с хоста `lb2`:
```
server {
    listen 80 default_server;
    server_name app lb2 _;

    location /.well-known/ {
        proxy_pass http://lb1/.well-known/;
        proxy_http_version      1.1;
        proxy_set_header X-Forwarded-For        $proxy_add_x_forwarded_for;
        proxy_connect_timeout 30s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;
    }

    location / {
        return 301 https://app$request_uri;
    }
}
```
Как уже было указано выше, чтобы  `.well-known` запросы приходили всегда на один и тот же хост на `lb2` настроено проксирование таких запросов на `lb1`.

Конфигурационный файл `/etc/nginx/sites-enabled/https.lb.conf` (одинаковый для `lb1` и `lb2`) - обслуживает сервер на 443 порту (защищенные соединения):
```
upstream backend {
    server app1;
    server app2;
    check interval=2000 rise=1 fall=2 timeout=1000 type=http;
    check_http_send "GET / HTTP/1.0\r\n\r\n";
    check_http_expect_alive http_2xx;
}

server {
    listen 443 ssl default_server;
    server_name app;
    access_log /var/log/nginx/app.access.log format;

    ssl_certificate /etc/letsencrypt/live/app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;
    ssl_protocols TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    ssl_stapling on;
    ssl_stapling_verify on;

    location = /app {
        proxy_pass http://backend/;
        proxy_http_version      1.1;
        proxy_set_header Host   $host;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_connect_timeout 30s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;
    }    
    location / {
        return 404;
    }
}
```

Для получения SSL-сертификатов запускается следующая команда на `lb1`:
```
certbot certonly --webroot -w /opt/www/acme/ -d app.4aff587bc0fcd4ea34ba57420d093b6.kis.im
```
Чтобы содержимое папок `/etc/letsencrypt/live` и  `/etc/letsencrypt/archive` на обоих хостах `lb1`, `lb2` было одинаковым, на `lb1` поднят демон `lsyncd`, который переливает файлы с `lb1` на `lb2` с помощью `rsync`.

Конфигурационный файл `/etc/nginx/sites-enabled/http.app.conf` с хоста `app1`:
```
server {
    listen 80 default_server;
    real_ip_header X-Forwarded-For;
    set_real_ip_from lb1;
    set_real_ip_from lb2;
    server_name app1;

    if ($http_x_forwarded_for = "") {
        set $chain $realip_remote_addr;
    }
    if ($http_x_forwarded_for != "") {
        set $chain "$http_x_forwarded_for, $realip_remote_addr";
    }

    location / {
        proxy_pass http://X.X.X.X:8080;
        proxy_http_version      1.1;
        proxy_set_header Host   $host;
        proxy_set_header X-Forwarded-For   $chain;
        proxy_connect_timeout 30s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;
    }
}
```
Конфигурация для хоста `app2` отличается только строкой `server_name app2;`

Здесь добавлена переменная `$chain`, в которой будет содержаться адрес клиента и проксирующих серверов, через которые прошел запрос. Переменная `$chain` записывается в заголовок `X-Forwarded-For`.

Конфигурация `nginxlog-exporter` с `lb1` / `lb2`:
```
listen {
  port = 8080
}

namespace "nginx" {
  source_files = ["/var/log/nginx/app.access.log"]

  format = "\"$request\" $request_time $upstream_response_time"

  labels {
    app = "default"
  }
}
```

Пример запроса, который проходит через реверс-прокси `lb1 ` и `app1 `:
```
$curl -D - https://app/app
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Fri, 23 Sep 2022 16:28:55 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 345
Connection: keep-alive

Hostname: app1
IP: X.X.X.X
IP: ::1
IP: X.X.X.X
IP: X.X.X.X
IP: fe80::d1:69ff:fe48:3f80
IP: X.X.X.X
IP: fe80::3:baff:fee0:1290
RemoteAddr: X.X.X.X:37830
GET / HTTP/1.1
Host: app
User-Agent: curl/7.68.0
Accept: */*
Connection: close
X-Forwarded-For: X.X.X.X, X.X.X.X
```
Еще один запрос, который проходит через `lb2 ` и `app2 `:
```
$curl -D - https://app/app
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Fri, 23 Sep 2022 16:38:41 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 350
Connection: keep-alive

Hostname: app2
IP: X.X.X.X
IP: ::1
IP: X.X.X.X
IP: X.X.X.X
IP: fe80::8c82:ebff:fe2f:97c9
IP: X.X.X.X
IP: fe80::cc43:bbff:fe90:6947
RemoteAddr: X.X.X.X:60432
GET / HTTP/1.1
Host: app
User-Agent: curl/7.68.0
Accept: */*
Connection: close
X-Forwarded-For: X.X.X.X, X.X.X.X
```

### Логи

`/var/lob/nginx/access.log` с `lb1`:
```
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:17:02:12 +0300] "GET /app HTTP/1.1" 301 178 "-" "curl/7.68.0"
```


`/var/lob/nginx/access.log` c `lb2`:
```
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:16:50:02 +0300] "GET /.well-known/acme-challenge/UtTf8Kaszsbt3K_gPCsGVj9hwLvBCT5RB1qB4CCVURc HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
X.X.X.X - - [23/Sep/2022:17:06:45 +0300] "GET /app HTTP/1.1" 301 178 "-" "Go-http-client/1.1"
X.X.X.X - - [23/Sep/2022:17:06:45 +0300] "GET /app HTTP/1.1" 301 178 "-" "Go-http-client/1.1"
```

`/var/lob/nginx/app.access.log` c `lb1` (логирование запросов на апстрим серверы):
```
"GET /app HTTP/1.1" 0.008 0.008 
"GET /app HTTP/1.1" 0.006 0.008
"GET /app HTTP/1.1" 0.006 0.004
```

`/var/lob/nginx/app.access.log` c `lb2` (логирование запросов на апстрим серверы):
```
"GET /test HTTP/1.1" 0.000 -
"GET / HTTP/1.1" 0.000 -
"GET /app HTTP/1.1" 0.008 0.012
```


`/var/log/nginx/access.log` c `app1`:
```
X.X.X.X - - [23/Sep/2022:17:02:16 +0300] "GET / HTTP/1.1" 200 345 "-" "curl/7.68.0"
X.X.X.X - - [23/Sep/2022:17:02:18 +0300] "GET / HTTP/1.0" 200 324 "-" "-"
X.X.X.X - - [23/Sep/2022:17:02:18 +0300] "GET / HTTP/1.0" 200 324 "-" "-"
```

`/var/log/nginx/access.log` c `app2`:
```
X.X.X.X - - [23/Sep/2022:17:51:42 +0300] "GET / HTTP/1.0" 200 329 "-" "-"
X.X.X.X - - [23/Sep/2022:17:51:44 +0300] "GET / HTTP/1.0" 200 329 "-" "-"
X.X.X.X - - [23/Sep/2022:17:51:44 +0300] "GET / HTTP/1.1" 200 350 "-" "curl/7.68.0"
```