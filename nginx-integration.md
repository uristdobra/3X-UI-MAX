# NGINX + 3X-UI INTEGRATION GUIDE

## 🔄 Интеграция Nginx с 3x-ui для совместной работы

Этот документ описывает, как правильно настроить Nginx для работы с 3x-ui и всеми транспортами.

---

## 📋 Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                    ИНТЕРНЕТ / CDN                      │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
    ПОРТ 80                      ПОРТ 443
    (HTTP)                       (HTTPS/TLS)
        │                             │
        └──────────────┬──────────────┘
                       │
                       ▼
                   ┌─────────────┐
                   │   NGINX     │
                   │   Reverse   │
                   │   Proxy     │
                   └──────┬──────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
    LOCALHOST:8080    LOCALHOST:10001-  LOCALHOST:443
    (Admin Panel)     10007 (Direct)    (Direct)
        │                 │                 │
        └─────────────────┴─────────────────┘
                       │
                       ▼
                   ┌──────────────┐
                   │   3x-ui      │
                   │   Container  │
                   │   (Docker)   │
                   └──────────────┘
                       │
                       ▼
                   ┌──────────────┐
                   │  Xray Core   │
                   │  Inbounds    │
                   └──────────────┘
```

---

## ⚙️ Nginx конфигурация

### 1. HTTP → HTTPS редирект

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location ~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}
```

### 2. Admin Panel (HTTPS)

```nginx
upstream 3xui_admin {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name panel.example.com;
    
    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/panel.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/panel.example.com/privkey.pem;
    
    # SSL security headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5:!3DES;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=admin_limit:10m rate=10r/s;
    limit_req zone=admin_limit burst=20 nodelay;
    
    # Proxy to admin panel
    location / {
        proxy_pass http://3xui_admin;
        proxy_http_version 1.1;
        proxy_set_header Connection "upgrade";
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_buffering off;
        proxy_request_buffering off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 3. WebSocket endpoint (/ws)

```nginx
upstream 3xui_ws {
    server 127.0.0.1:10004;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name panel.example.com;
    
    ssl_certificate /etc/letsencrypt/live/panel.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/panel.example.com/privkey.pem;
    
    # WebSocket endpoint for VLESS WS clients
    location /ws {
        proxy_pass http://3xui_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
        
        # Disable client certificate verification (optional)
        # proxy_ssl_verify off;
    }
}
```

### 4. gRPC endpoint (/grpc)

```nginx
upstream 3xui_grpc {
    server 127.0.0.1:10002;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name panel.example.com;
    http2_max_field_size 16k;
    http2_max_header_size 32k;
    
    ssl_certificate /etc/letsencrypt/live/panel.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/panel.example.com/privkey.pem;
    
    # gRPC endpoint for VLESS gRPC clients
    location /xray {
        proxy_pass grpc://3xui_grpc;
        proxy_http_version 2.0;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

### 5. XHTTP endpoint (/xhttp)

```nginx
upstream 3xui_xhttp {
    server 127.0.0.1:10003;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name panel.example.com;
    
    ssl_certificate /etc/letsencrypt/live/panel.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/panel.example.com/privkey.pem;
    
    # HTTP Upgrade endpoint for VLESS XHTTP clients
    location /xhttp {
        proxy_pass http://3xui_xhttp;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

### 6. Полная конфигурация одного файла

Для удобства можно поместить все в один файл `/etc/nginx/sites-available/3xui-complete`:

```nginx
# HTTP redirect to HTTPS
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location ~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# Upstream backends
upstream 3xui_admin {
    server 127.0.0.1:8080;
    keepalive 32;
}

upstream 3xui_ws {
    server 127.0.0.1:10004;
    keepalive 32;
}

upstream 3xui_grpc {
    server 127.0.0.1:10002;
}

upstream 3xui_xhttp {
    server 127.0.0.1:10003;
    keepalive 32;
}

# Main HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name panel.example.com;
    http2_max_field_size 16k;
    http2_max_header_size 32k;
    
    # SSL/TLS Configuration
    ssl_certificate /etc/letsencrypt/live/panel.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/panel.example.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/panel.example.com/chain.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
    # Logging
    access_log /var/log/nginx/3xui_access.log;
    error_log /var/log/nginx/3xui_error.log warn;
    
    # Limit requests
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=30r/s;
    limit_req_zone $binary_remote_addr zone=admin_limit:10m rate=10r/s;
    
    # Admin Panel
    location / {
        limit_req zone=admin_limit burst=20 nodelay;
        
        proxy_pass http://3xui_admin;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # WebSocket for VLESS WS
    location /ws {
        limit_req zone=api_limit burst=50 nodelay;
        
        proxy_pass http://3xui_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
    
    # gRPC for VLESS gRPC
    location /xray {
        limit_req zone=api_limit burst=50 nodelay;
        
        proxy_pass grpc://3xui_grpc;
        proxy_http_version 2.0;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
    
    # HTTP Upgrade for VLESS XHTTP
    location /xhttp {
        limit_req zone=api_limit burst=50 nodelay;
        
        proxy_pass http://3xui_xhttp;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
    
    # Block dangerous requests
    location ~ /\.(?!well-known) {
        deny all;
    }
}
```

---

## 🔧 Как включить конфигурацию

```bash
# 1. Создать/отредактировать конфиг
sudo nano /etc/nginx/sites-available/3xui-complete

# 2. Включить сайт
sudo ln -sf /etc/nginx/sites-available/3xui-complete /etc/nginx/sites-enabled/3xui-complete

# 3. Отключить стандартный сайт (если нужно)
sudo rm /etc/nginx/sites-enabled/default

# 4. Проверить синтаксис
sudo nginx -t

# 5. Перезагрузить Nginx
sudo systemctl reload nginx

# 6. Проверить статус
sudo systemctl status nginx
```

---

## 📊 Мониторинг и логирование

### Проверка логов:

```bash
# Real-time логи доступа
tail -f /var/log/nginx/3xui_access.log

# Real-time логи ошибок
tail -f /var/log/nginx/3xui_error.log

# Фильтр по статус коду (ошибки)
tail -f /var/log/nginx/3xui_access.log | grep -E '5[0-9]{2}|4[0-4]{2}'

# Самые частые IP
cut -d' ' -f1 /var/log/nginx/3xui_access.log | sort | uniq -c | sort -rn | head -10
```

### Статистика трафика:

```bash
# Total requests per endpoint
awk '{print $7}' /var/log/nginx/3xui_access.log | sort | uniq -c | sort -rn

# Трафик по протоколам
grep -c 'POST /ws' /var/log/nginx/3xui_access.log
grep -c 'CONNECT' /var/log/nginx/3xui_access.log

# Средний размер ответа
awk '{sum+=$10; count++} END {print "Average response size:", sum/count/1024, "KB"}' /var/log/nginx/3xui_access.log
```

---

## 🔐 Дополнительная безопасность

### 1. Ограничение по странам (GeoIP)

```bash
# Установить GeoIP module
sudo apt install geoip-bin geoip-database

# В конфиге:
geo $country {
    default ZZ;
    include /etc/nginx/geo/countries.conf;
}

location / {
    if ($country = "CN") {
        return 403;
    }
    # ...
}
```

### 2. Защита от DDoS

```nginx
limit_req_zone $binary_remote_addr zone=general:10m rate=50r/s;
limit_conn_zone $binary_remote_addr zone=addr:10m;

limit_req zone=general burst=100 nodelay;
limit_conn addr 10;
```

### 3. Защита от сканирования

```nginx
location ~ /xmlrpc\.php|wp-admin|wp-login {
    deny all;
}
```

---

## ✅ Проверка конфигурации

```bash
# Проверить Nginx
sudo nginx -t

# Посмотреть открытые порты
sudo ss -tulpn | grep nginx

# Проверить соединения к upstream
sudo netstat -ant | grep 8080

# Проверить SSL сертификат
openssl s_client -connect panel.example.com:443 -servername panel.example.com

# Проверить дни до истечения сертификата
echo | openssl s_client -servername panel.example.com -connect panel.example.com:443 2>/dev/null | openssl x509 -noout -dates
```

---

## 🔄 Автоматическое обновление SSL

Добавить в crontab:

```bash
0 2 * * * certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

Или с логированием:

```bash
0 2 * * * certbot renew --quiet >> /var/log/certbot-renew.log 2>&1 && systemctl reload nginx
```

---

## 📈 Оптимизация производительности

### Buffer settings:

```nginx
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
client_max_body_size 50M;
```

### Gzip compression:

```nginx
gzip on;
gzip_min_length 1000;
gzip_types text/plain text/css text/javascript application/json application/javascript;
gzip_disable "msie6";
```

### TCP optimization:

```nginx
tcp_nopush on;
tcp_nodelay on;
keepalive_timeout 65;
types_hash_max_size 2048;
client_header_buffer_size 128;
large_client_header_buffers 4 256k;
```

---

## 📋 Checklist для production

- [ ] SSL сертификат установлен и валиден
- [ ] Все upstream серверы доступны
- [ ] Rate limiting настроен
- [ ] Security headers установлены
- [ ] Логирование работает
- [ ] Certbot scheduled для обновления
- [ ] Firewall настроен (UFW/iptables)
- [ ] SSH порт измен с 22 на другой
- [ ] Резервные копии конфигурации
- [ ] Мониторинг настроен
