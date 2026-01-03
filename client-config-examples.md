# CLIENT CONFIGURATION EXAMPLES

## 📱 Примеры конфигураций для клиентов

После успешной установки 3x-ui, вы можете получить ссылки подписки из панели администратора.

---

## 🔗 VLESS + REALITY TCP

**Порт:** 10001  
**Безопасность:** REALITY  
**Транспорт:** TCP  
**Flow:** xtls-rprx-vision (опционально)

### Sing-box конфиг:
```json
{
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "server": "your-server-ip",
      "server_port": 10001,
      "uuid": "YOUR_UUID_HERE",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      },
      "reality": {
        "enabled": true,
        "public_key": "YOUR_PUBLIC_KEY_HERE",
        "short_id": ""
      }
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "VLESS-REALITY-TCP"
    type: vless
    server: your-server-ip
    port: 10001
    uuid: YOUR_UUID_HERE
    flow: xtls-rprx-vision
    tls: true
    servername: www.microsoft.com
    reality-opts:
      public-key: YOUR_PUBLIC_KEY_HERE
      short-id: ""
    udp: true

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - "VLESS-REALITY-TCP"
```

---

## 🔗 VLESS + REALITY gRPC

**Порт:** 10002  
**Безопасность:** REALITY  
**Транспорт:** gRPC  

### Sing-box конфиг:
```json
{
  "outbounds": [
    {
      "type": "vless",
      "server": "your-server-ip",
      "server_port": 10002,
      "uuid": "YOUR_UUID_HERE",
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      },
      "reality": {
        "enabled": true,
        "public_key": "YOUR_PUBLIC_KEY_HERE",
        "short_id": ""
      },
      "transport": {
        "type": "grpc",
        "service_name": "xray"
      }
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "VLESS-REALITY-gRPC"
    type: vless
    server: your-server-ip
    port: 10002
    uuid: YOUR_UUID_HERE
    tls: true
    servername: www.microsoft.com
    grpc: true
    grpc-opts:
      grpc-service-name: xray
    reality-opts:
      public-key: YOUR_PUBLIC_KEY_HERE
      short-id: ""
    udp: true
```

---

## 🔗 VLESS + REALITY XHTTP

**Порт:** 10003  
**Безопасность:** REALITY  
**Транспорт:** HTTP Upgrade / XHTTP  
**Путь:** /xhttp  

### Sing-box конфиг:
```json
{
  "outbounds": [
    {
      "type": "vless",
      "server": "your-server-ip",
      "server_port": 10003,
      "uuid": "YOUR_UUID_HERE",
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      },
      "reality": {
        "enabled": true,
        "public_key": "YOUR_PUBLIC_KEY_HERE",
        "short_id": ""
      },
      "transport": {
        "type": "httpupgrade",
        "host": "panel.example.com",
        "path": "/xhttp"
      }
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "VLESS-REALITY-XHTTP"
    type: vless
    server: your-server-ip
    port: 10003
    uuid: YOUR_UUID_HERE
    tls: true
    servername: www.microsoft.com
    http-opts:
      method: GET
      path: /xhttp
      headers:
        Host: panel.example.com
    reality-opts:
      public-key: YOUR_PUBLIC_KEY_HERE
      short-id: ""
    udp: true
```

---

## 🌐 VLESS + WebSocket + TLS (CDN-friendly)

**Порт:** 443 (через Nginx)  
**Безопасность:** TLS  
**Транспорт:** WebSocket  
**Путь:** /ws  
**Хост:** panel.example.com  

### Sing-box конфиг:
```json
{
  "outbounds": [
    {
      "type": "vless",
      "server": "panel.example.com",
      "server_port": 443,
      "uuid": "YOUR_UUID_HERE",
      "tls": {
        "enabled": true,
        "server_name": "panel.example.com"
      },
      "transport": {
        "type": "ws",
        "host": "panel.example.com",
        "path": "/ws"
      }
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "VLESS-WS-TLS-CDN"
    type: vless
    server: panel.example.com
    port: 443
    uuid: YOUR_UUID_HERE
    tls: true
    ws: true
    ws-opts:
      path: /ws
      headers:
        Host: panel.example.com
    udp: false

# Для использования Cloudflare:
# В DNS записях Cloudflare установите "Proxied" (оранжевое облако)
```

---

## 💬 VMess + TCP

**Порт:** 10005  
**Безопасность:** Без TLS  
**Транспорт:** TCP  
**AlterID:** 0  

### Sing-box конфиг:
```json
{
  "outbounds": [
    {
      "type": "vmess",
      "server": "your-server-ip",
      "server_port": 10005,
      "uuid": "YOUR_UUID_HERE",
      "security": "zero",
      "authenticated_length": 0
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "VMess-TCP"
    type: vmess
    server: your-server-ip
    port: 10005
    uuid: YOUR_UUID_HERE
    alterId: 0
    cipher: auto
    udp: true
```

### v2rayN конфиг:
```json
{
  "v": 2,
  "ps": "VMess-TCP",
  "add": "your-server-ip",
  "port": 10005,
  "id": "YOUR_UUID_HERE",
  "aid": 0,
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": "",
  "sni": ""
}
```

---

## 🔐 Trojan + REALITY TCP

**Порт:** 10006  
**Безопасность:** REALITY  
**Транспорт:** TCP  
**Пароль:** YOUR_TROJAN_PASSWORD  

### Sing-box конфиг:
```json
{
  "outbounds": [
    {
      "type": "trojan",
      "server": "your-server-ip",
      "server_port": 10006,
      "password": "YOUR_TROJAN_PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      },
      "reality": {
        "enabled": true,
        "public_key": "YOUR_PUBLIC_KEY_HERE",
        "short_id": ""
      }
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "Trojan-REALITY"
    type: trojan
    server: your-server-ip
    port: 10006
    password: YOUR_TROJAN_PASSWORD
    tls: true
    servername: www.microsoft.com
    reality-opts:
      public-key: YOUR_PUBLIC_KEY_HERE
      short-id: ""
    udp: true
```

---

## 🛡️ ShadowSocks + TCP

**Порт:** 10007  
**Метод:** aes-256-gcm  
**Пароль:** YOUR_SS_PASSWORD  

### Sing-box конфиг:
```json
{
  "outbounds": [
    {
      "type": "shadowsocks",
      "server": "your-server-ip",
      "server_port": 10007,
      "method": "aes-256-gcm",
      "password": "YOUR_SS_PASSWORD"
    }
  ]
}
```

### Clash Meta конфиг:
```yaml
proxies:
  - name: "ShadowSocks"
    type: ss
    server: your-server-ip
    port: 10007
    cipher: aes-256-gcm
    password: YOUR_SS_PASSWORD
    udp: true
```

### Shadowsocks CLI:
```bash
sslocal -s your-server-ip \
        -p 10007 \
        -k YOUR_SS_PASSWORD \
        -m aes-256-gcm \
        -l 1080 \
        -d
```

---

## 📋 Получение ссылок из панели

### Через веб-панель:

1. Откройте https://panel.example.com
2. Авторизуйтесь с паролем администратора
3. Перейдите в **Inbounds**
4. Для каждого инбаунда нажмите **Share** или **Export**
5. Скопируйте ссылку (vless://, trojan://, ss://, vmess://)

### Пример ссылки VLESS:
```
vless://YOUR_UUID@your-server-ip:10001?encryption=none&flow=xtls-rprx-vision&sni=www.microsoft.com&type=tcp&security=reality#VLESS-REALITY-TCP
```

### Пример ссылки Trojan:
```
trojan://YOUR_TROJAN_PASSWORD@your-server-ip:10006?sni=www.microsoft.com&type=tcp&security=reality#Trojan-REALITY
```

### Пример ссылки ShadowSocks:
```
ss://aes-256-gcm:YOUR_SS_PASSWORD@your-server-ip:10007#ShadowSocks-TCP
```

---

## 🔄 Путём подписки (Subscription)

После создания пользователя в панели вы получите ссылку подписки:

```
https://panel.example.com/api/v1/subscription/YOUR_SUBSCRIPTION_TOKEN?format=sing-box
```

Поддерживаемые форматы:
- `format=sing-box` - для Sing-box
- `format=clash` - для Clash Meta
- `format=v2rayn` - для v2rayN (base64)
- `format=quantumult-x` - для Quantumult X

---

## ⚙️ Основные параметры для разных клиентов

| Параметр | VLESS REALITY TCP | VLESS REALITY gRPC | VLESS WS+TLS | Trojan | VMess | SS |
|----------|------|------|------|------|------|-----|
| **Server** | IP сервера | IP сервера | panel.example.com | IP сервера | IP сервера | IP сервера |
| **Port** | 10001 | 10002 | 443 | 10006 | 10005 | 10007 |
| **Security** | REALITY | REALITY | TLS | REALITY | none | none |
| **Transport** | TCP | gRPC | WebSocket | TCP | TCP | TCP |
| **SNI** | www.microsoft.com | www.microsoft.com | panel.example.com | www.microsoft.com | - | - |
| **Path** | - | - | /ws | - | - | - |
| **Password** | - | - | - | TROJAN_PASS | - | SS_PASS |
| **UUID/ID** | UUID | UUID | UUID | - | UUID | - |

---

## 🧪 Тестирование подключения

### Проверка доступности портов:
```bash
# С локальной машины
nc -zv your-server-ip 10001
nc -zv your-server-ip 10002
nc -zv your-server-ip 10003
curl -I https://panel.example.com:443
```

### Проверка на сервере:
```bash
# На сервере
ss -tulpn | grep -E ':(10001|10002|10003|10004|10005|10006|10007)'
docker logs 3xui | grep -i error
```

### Тестирование VLESS:
```bash
# Используя sing-box
sing-box run -c config.json

# Используя clash
clash -f config.yaml -d .
```

---

## 📱 Популярные клиенты

### iOS:
- Shadowrocket
- Quantumult X
- Stash

### Android:
- v2rayNG
- Clash for Android
- SagerNet

### Windows/macOS:
- Clash for Windows
- v2rayN / v2rayA
- Sing-box GUI

### Linux:
- Clash (CLI)
- sing-box (CLI)
- v2ray (CLI)

---

## 🔧 Решение проблем

### Проблема: Не подключается через VLESS REALITY
**Решение:**
- Убедитесь, что публичный ключ правильный
- Проверьте SNI (должен быть доступен и поддерживать REALITY)
- Обновите клиент до последней версии

### Проблема: WebSocket не работает
**Решение:**
- Проверьте доступ к panel.example.com
- Убедитесь, что Nginx работает: `systemctl status nginx`
- Проверьте пути в конфиге: `/ws`

### Проблема: ShadowSocks медленный
**Решение:**
- Используйте более быстрый метод: `aes-256-gcm` вместо `chacha20-poly1305`
- Проверьте ping до сервера
- Убедитесь, что UDP включен

---

## 📚 Дополнительные ресурсы

- [Sing-box документация](https://sing-box.sagernet.org)
- [Clash Meta документация](https://github.com/MetaCubeX/mihomo)
- [Xray Core документация](https://xtls.github.io)
- [3x-ui GitHub](https://github.com/MHSanaei/3x-ui)
