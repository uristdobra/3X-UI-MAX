# 3X-UI PRO AUTO-INSTALLER v2.0

Полностью автоматизированный bash-скрипт для установки **3x-ui** (Xray core) на **Ubuntu 22.04** с поддержкой интерактивного выбора протоколов и автоматической настройкой через Nginx.

## 📋 Функциональность

### ✅ Разделы установки:

1. **Подготовка сервера**
   - Обновление системы (`apt update && full-upgrade`)
   - Установка базовых утилит (curl, wget, jq, net-tools, ufw, cron и т.д.)
   - Проверка доступности портов (22, 80, 443)
   - Временное отключение UFW на время установки
   - Оптимизация системных параметров (sysctl: TCP, BBR, rmem/wmem)
   - Очистка неиспользуемых пакетов

2. **Интерактивный ввод параметров**
   - Домен для панели и WebSocket/gRPC
   - Домен/SNI для REALITY
   - Email для Let's Encrypt
   - Пароль администратора 3x-ui

3. **Выбор протоколов**
   - VLESS + REALITY TCP (основной stealth-трафик)
   - VLESS + REALITY gRPC (для DPI bypass)
   - VLESS + REALITY XHTTP (HttpUpgrade маскировка)
   - VLESS + WebSocket + TLS (CDN-friendly)
   - VMess + TCP (совместимость)
   - Trojan + REALITY TCP (альтернативный stealth)
   - ShadowSocks + TCP (лёгкий протокол)

4. **Установка зависимостей**
   - Docker и Docker Compose
   - Nginx (для reverse proxy)
   - Certbot для автоматического SSL

5. **Установка 3x-ui**
   - Развёртывание через Docker
   - Автоматическая настройка портов

6. **Конфигурирование Nginx**
   - Получение SSL сертификата через Let's Encrypt
   - Настройка reverse proxy для всех транспортов
   - Поддержка WebSocket, gRPC, XHTTP endpoints

7. **Создание инбаундов**
   - Автоматическая генерация REALITY ключей
   - Создание всех выбранных протоколов через REST API
   - Сохранение учетных данных

8. **Финальные проверки**
   - Проверка запуска контейнеров
   - Проверка Nginx и портов
   - Проверка SSL сертификата

---

## 🚀 Быстрый старт

### Требования:
- Ubuntu 22.04 LTS
- 2+ GB RAM
- 10+ GB свободного места
- Доступ в интернет
- Зарегистрированный доменное имя (или поддомен)
- SSH доступ с правами root

### Установка:

```bash
# 1. Загрузите скрипт
curl -fsSL https://your-server.com/x-ui-pro-installer.sh -o /tmp/x-ui-pro-installer.sh

# 2. Дайте права на выполнение
chmod +x /tmp/x-ui-pro-installer.sh

# 3. Запустите от root
sudo /tmp/x-ui-pro-installer.sh
```

**Или одной строкой:**
```bash
sudo bash -c "curl -fsSL https://your-server.com/x-ui-pro-installer.sh | bash"
```

---

## 📝 Пример интерактивного диалога

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           3X-UI PRO AUTOMATED INSTALLER v2.0                ║
║     VLESS • VMess • Trojan • ShadowSocks • REALITY           ║
║                                                              ║
║              Ubuntu 22.04 | Интерактивная установка         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

[INFO] Проверка предварительных требований...
[✓] Проверки пройдены

════════════════════════════════════════════════════════════
РАЗДЕЛ 1: ПОДГОТОВКА СЕРВЕРА
════════════════════════════════════════════════════════════
[INFO] Обновление системных пакетов...
[✓] Система обновлена
...

════════════════════════════════════════════════════════════
РАЗДЕЛ 2: ПАРАМЕТРЫ УСТАНОВКИ
════════════════════════════════════════════════════════════
Введите доменное имя для панели и WebSocket:
Домен (например: panel.example.com): panel.example.com
...

════════════════════════════════════════════════════════════
РАЗДЕЛ 3: ВЫБОР ПРОТОКОЛОВ
════════════════════════════════════════════════════════════
Выберите протоколы для установки:

1. [Y] VLESS + REALITY TCP (основной stealth-трафик)
2. [Y] VLESS + REALITY gRPC (для DPI bypass)
3. [Y] VLESS + REALITY XHTTP/HttpUpgrade
4. [Y] VLESS + WebSocket + TLS (CDN-friendly)
5. [N] VMess + TCP (совместимость)
6. [N] Trojan + REALITY TCP
7. [N] ShadowSocks + TCP (лёгкий)

Введите номера протоколов через запятую (например: 1,2,4)
Или просто Enter для установки протоколов по умолчанию (1,2,3,4)
Ваш выбор: 1,2,3,4,5,6,7
```

---

## 📦 Структура каталогов после установки

```
/opt/3xui/
├── docker-compose.yml          # Docker Compose конфиг
├── db/                          # БД 3x-ui (x-ui.db)
├── certs/                       # SSL сертификаты
├── installation-config.txt      # Информация об установке
├── credentials.txt              # Сохраненные пароли
└── x-ui/                        # Клон репозитория 3x-ui

/etc/nginx/
├── sites-available/3xui-panel   # Основная конфиг
├── sites-enabled/3xui-panel     # Симлинк на конфиг
└── ...

/etc/letsencrypt/
├── live/
│   └── panel.example.com/
│       ├── fullchain.pem
│       ├── privkey.pem
│       └── ...
```

---

## 🔌 Порты инбаундов

После установки доступны следующие порты (за Nginx):

| Протокол | Порт | Назначение |
|----------|------|-----------|
| VLESS REALITY TCP | 10001 | Direct (REALITY stealth) |
| VLESS REALITY gRPC | 10002 | REALITY через gRPC |
| VLESS REALITY XHTTP | 10003 | REALITY через HttpUpgrade |
| VLESS WebSocket | 10004 | Через Cloudflare CDN |
| VMess TCP | 10005 | Legacy compatibility |
| Trojan REALITY TCP | 10006 | Trojan + REALITY |
| ShadowSocks TCP | 10007 | Lightweight protocol |

**Внешние (через Nginx):**
- **80** - HTTP redirect
- **443** - HTTPS (панель + WebSocket/gRPC endpoints)

---

## 🛠️ Полезные команды

### Просмотр логов контейнера:
```bash
docker logs -f 3xui
```

### Перезагрузка 3x-ui:
```bash
cd /opt/3xui && docker-compose restart
```

### Проверка статуса сервисов:
```bash
systemctl status nginx
systemctl status docker
docker ps | grep 3xui
```

### Проверка открытых портов:
```bash
ss -tulpn | grep -E ':(80|443|10000|10007)'
```

### Проверка конфига Nginx:
```bash
nginx -t
```

### Просмотр SSL сертификата:
```bash
openssl x509 -in /etc/letsencrypt/live/panel.example.com/fullchain.pem -text -noout
```

### Ручное обновление SSL:
```bash
certbot renew --force-renewal --quiet
systemctl reload nginx
```

### Резервная копия конфигурации:
```bash
tar -czf /backups/3xui-backup-$(date +%Y%m%d).tar.gz /opt/3xui/db/
```

---

## 📊 Информация о конфигурации

После завершения установки все параметры сохраняются в:
```
/opt/3xui/installation-config.txt
```

Содержит:
- Доменные имена и emails
- Пароли (Trojan, ShadowSocks)
- Пути к файлам
- UUID и ключи
- Список установленных протоколов
- Полезные команды

---

## 🔐 Безопасность

### Сразу после установки:

1. **Смените пароль администратора**
   - Вход в панель https://panel.example.com
   - Измените стандартный пароль

2. **Включите UFW (если нужен)**
   ```bash
   sudo ufw reset
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 443/udp
   sudo ufw allow 10001:10007/tcp
   sudo ufw enable
   ```

3. **Измените SSH порт** (опционально)
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Измените Port 22 на другой
   sudo systemctl restart sshd
   ```

4. **Включите автоматическое обновление SSL**
   ```bash
   crontab -e
   # Добавьте строку:
   0 2 * * * certbot renew --quiet && systemctl reload nginx
   ```

5. **Регулярные резервные копии**
   ```bash
   0 3 * * * tar -czf /backups/3xui-$(date +\%Y\%m\%d).tar.gz /opt/3xui/db/
   ```

---

## 🐛 Troubleshooting

### Проблема: Порт 443 уже занят
```bash
# Найти процесс на порту 443
sudo lsof -i :443
# Завершить процесс
sudo kill -9 <PID>
```

### Проблема: Ошибка сертификата
```bash
# Перепроверить домен
dig panel.example.com
nslookup panel.example.com

# Получить новый сертификат
sudo certbot certonly --standalone -d panel.example.com
```

### Проблема: 3x-ui не запускается
```bash
# Проверить логи
docker logs 3xui

# Перезагрузить контейнер
docker-compose -f /opt/3xui/docker-compose.yml restart

# Проверить ресурсы
free -h
df -h
```

### Проблема: Nginx ошибка
```bash
# Проверить синтаксис
nginx -t

# Просмотреть логи
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

---

## 📚 Структура builder-скриптов

Скрипт использует конфигурационные структуры из:
- `buildVlessRealityXhttp.js` - VLESS REALITY XHTTP
- `buildVlessRealityTcp.js` - VLESS REALITY TCP
- `buildVlessRealityGrpc.js` - VLESS REALITY gRPC
- `buildVlessWs.js` - VLESS WebSocket
- `buildVmessTcp.js` - VMess TCP
- `buildTrojanRealityTcp.js` - Trojan REALITY
- `buildShadowsocksTcp.js` - ShadowSocks

Все конфигурации адаптированы для 3x-ui REST API.

---

## 🔄 Обновление скрипта

Чтобы обновить 3x-ui до последней версии:

```bash
cd /opt/3xui
docker-compose down
docker pull ghcr.io/mhsanaei/3x-ui:latest
docker-compose up -d
```

---

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи:
   ```bash
   docker logs 3xui | tail -50
   tail -20 /var/log/nginx/error.log
   ```

2. Проверьте доступность домена:
   ```bash
   curl -I https://panel.example.com
   ```

3. Перезагрузите сервис:
   ```bash
   systemctl restart docker
   cd /opt/3xui && docker-compose restart
   ```

---

## 📄 Лицензия

Скрипт основан на официальных репозиториях:
- [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui)
- [GFW4Fun/x-ui-pro](https://github.com/GFW4Fun/x-ui-pro)

---

## 🎯 Версия

**3X-UI PRO AUTO-INSTALLER v2.0**
- Дата: 2026-01-03
- ОС: Ubuntu 22.04 LTS
- Ядро: Xray
- Панель: 3x-ui / x-ui-pro
- Транспорты: REALITY, WebSocket, gRPC, XHTTP, TCP
- Протоколы: VLESS, VMess, Trojan, ShadowSocks
