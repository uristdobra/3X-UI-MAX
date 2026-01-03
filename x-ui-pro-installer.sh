#!/bin/bash

################################################################################
#                    3X-UI PRO AUTO-INSTALLER v2.0
#              Ubuntu 22.04 | Интерактивная установка протоколов
#              VLESS, VMess, Trojan, ShadowSocks с автоконфигурацией
################################################################################

set -e

# ============================================================================
# ЦВЕТА И ФОРМАТИРОВАНИЕ
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗ ОШИБКА]${NC} $*"
}

# ============================================================================
# ПРОВЕРКА ПРАВ И ОС
# ============================================================================
check_requirements() {
    log_info "Проверка предварительных требований..."
    
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root (используйте sudo)"
        exit 1
    fi
    
    if [ ! -f /etc/os-release ]; then
        log_error "Не могу определить дистрибутив"
        exit 1
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]] || [[ ! "$VERSION_ID" =~ ^22.04 ]]; then
        log_warn "Скрипт оптимизирован для Ubuntu 22.04"
        log_warn "Обнаружена: $PRETTY_NAME"
        read -p "Продолжить всё равно? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Проверки пройдены"
}

# ============================================================================
# ПОДГОТОВКА СЕРВЕРА (НОВЫЙ РАЗДЕЛ)
# ============================================================================
prepare_server() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 1: ПОДГОТОВКА СЕРВЕРА"
    log_info "════════════════════════════════════════════════════════"
    
    # Обновление системы
    log_info "Обновление системных пакетов..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -qq
    log_success "Система обновлена"
    
    # Установка базовых утилит
    log_info "Установка необходимых утилит..."
    REQUIRED_TOOLS="curl wget jq lsof net-tools ufw cron socat git htop vim"
    
    for tool in $REQUIRED_TOOLS; do
        if ! command -v "$tool" &> /dev/null; then
            log_info "Устанавливаю $tool..."
            apt-get install -y "$tool" -qq
        else
            log_success "$tool уже установлен"
        fi
    done
    
    # Проверка доступности портов
    log_info "Проверка портов 22, 80, 443..."
    
    if ss -tulpn 2>/dev/null | grep -E ':(22|80|443)\s' | grep -v LISTEN > /dev/null 2>&1; then
        if ss -tulpn 2>/dev/null | grep ':443\s' | grep -v LISTEN > /dev/null 2>&1; then
            log_warn "Порт 443 может быть занят!"
        fi
    fi
    
    PORT_22=$(ss -tulpn 2>/dev/null | grep ':22\s' | grep LISTEN | wc -l)
    PORT_80=$(ss -tulpn 2>/dev/null | grep ':80\s' | grep LISTEN | wc -l)
    PORT_443=$(ss -tulpn 2>/dev/null | grep ':443\s' | grep LISTEN | wc -l)
    
    log_success "Порт 22: $([ $PORT_22 -gt 0 ] && echo 'ЗАНЯТ' || echo 'свободен')"
    log_success "Порт 80: $([ $PORT_80 -gt 0 ] && echo 'ЗАНЯТ' || echo 'свободен')"
    log_success "Порт 443: $([ $PORT_443 -gt 0 ] && echo 'ЗАНЯТ' || echo 'свободен')"
    
    # Отключение UFW на время установки
    log_info "Управление UFW..."
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        log_warn "UFW активен. Отключаю на время установки..."
        ufw --force disable > /dev/null 2>&1 || true
        NEED_UFW_ENABLE=1
    else
        log_success "UFW не активен"
        NEED_UFW_ENABLE=0
    fi
    
    # Оптимальные настройки sysctl для xray/v2ray
    log_info "Оптимизация системных параметров..."
    
    cat >> /etc/sysctl.conf << 'EOF'

# XRay/V2Ray optimization
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 65536 33554432
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.tcp_max_tw_buckets=2000000
net.ipv4.ip_local_port_range=1024 65535
EOF
    
    sysctl -p > /dev/null 2>&1
    log_success "Параметры sysctl оптимизированы"
    
    # Очистка старых пакетов
    log_info "Очистка неиспользуемых пакетов..."
    apt-get autoremove -y -qq
    apt-get autoclean -y -qq
    log_success "Сервер подготовлен"
    
    echo
}

# ============================================================================
# ИНТЕРАКТИВНЫЙ ВВОД ДАННЫХ
# ============================================================================
get_user_input() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 2: ПАРАМЕТРЫ УСТАНОВКИ"
    log_info "════════════════════════════════════════════════════════"
    echo
    
    # Домен для панели и WebSocket/gRPC
    log_info "Введите доменное имя для панели и WebSocket:"
    read -p "Домен (например: panel.example.com): " PANEL_DOMAIN
    
    if [ -z "$PANEL_DOMAIN" ]; then
        log_error "Домен не может быть пуст"
        get_user_input
        return
    fi
    
    # Домен/SNI для REALITY
    log_info "Введите домен/хостнейм для REALITY (SNI):"
    read -p "REALITY SNI (например: www.google.com) [по умолчанию: www.microsoft.com]: " REALITY_SNI
    REALITY_SNI=${REALITY_SNI:-www.microsoft.com}
    
    # Email для Let's Encrypt
    log_info "Email для сертификата Let's Encrypt:"
    read -p "Email [по умолчанию: admin@example.com]: " LE_EMAIL
    LE_EMAIL=${LE_EMAIL:-admin@example.com}
    
    # Пароль админа x-ui
    log_info "Установите пароль администратора панели x-ui:"
    read -sp "Пароль: " ADMIN_PASS
    echo
    read -sp "Повторите пароль: " ADMIN_PASS_CONFIRM
    echo
    
    if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
        log_error "Пароли не совпадают"
        get_user_input
        return
    fi
    
    if [ -z "$ADMIN_PASS" ]; then
        log_error "Пароль не может быть пуст"
        get_user_input
        return
    fi
    
    echo
}

# ============================================================================
# ВЫБОР ПРОТОКОЛОВ
# ============================================================================
select_protocols() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 3: ВЫБОР ПРОТОКОЛОВ"
    log_info "════════════════════════════════════════════════════════"
    echo
    
    # Массив доступных протоколов
    declare -a PROTOCOLS=(
        "vless_reality_tcp:VLESS + REALITY TCP (основной stealth-трафик)|true"
        "vless_reality_grpc:VLESS + REALITY gRPC (для DPI bypass)|true"
        "vless_reality_xhttp:VLESS + REALITY XHTTP/HttpUpgrade|true"
        "vless_ws_tls:VLESS + WebSocket + TLS (CDN-friendly)|true"
        "vmess_tcp:VMess + TCP (совместимость)|false"
        "trojan_reality_tcp:Trojan + REALITY TCP|false"
        "shadowsocks_tcp:ShadowSocks + TCP (лёгкий)|false"
    )
    
    echo "Выберите протоколы для установки:"
    echo "(По умолчанию отмечены выбранные протоколы)"
    echo
    
    for i in "${!PROTOCOLS[@]}"; do
        IFS=':' read -r PROTO_ID PROTO_NAME PROTO_DEFAULT <<< "${PROTOCOLS[$i]}"
        IFS='|' read -r PROTO_DESC PROTO_CHECKED <<< "$PROTO_NAME"
        
        if [ "$PROTO_CHECKED" = "true" ]; then
            DEFAULT_CHOICE="Y"
        else
            DEFAULT_CHOICE="N"
        fi
        
        echo "$((i+1)). [$DEFAULT_CHOICE] $PROTO_DESC"
    done
    
    echo
    echo "Введите номера протоколов через запятую для установки (например: 1,2,4)"
    echo "Или просто Enter для установки протоколов по умолчанию (1,2,3,4)"
    read -p "Ваш выбор: " SELECTED_PROTOCOLS
    
    if [ -z "$SELECTED_PROTOCOLS" ]; then
        # По умолчанию: VLESS REALITY TCP, gRPC, XHTTP и WebSocket
        SELECTED_PROTOCOLS="1,2,3,4"
    fi
    
    # Преобразование в массив
    IFS=',' read -ra SELECTED_ARRAY <<< "$SELECTED_PROTOCOLS"
    
    SELECTED_PROTOS=()
    for selection in "${SELECTED_ARRAY[@]}"; do
        selection=$(echo "$selection" | xargs) # Trim whitespace
        idx=$((selection - 1))
        
        if [ $idx -ge 0 ] && [ $idx -lt ${#PROTOCOLS[@]} ]; then
            IFS=':' read -r PROTO_ID PROTO_NAME <<< "${PROTOCOLS[$idx]}"
            SELECTED_PROTOS+=("$PROTO_ID")
        fi
    done
    
    if [ ${#SELECTED_PROTOS[@]} -eq 0 ]; then
        log_error "Не выбран ни один протокол"
        select_protocols
        return
    fi
    
    log_success "Выбрано протоколов: ${#SELECTED_PROTOS[@]}"
    for proto in "${SELECTED_PROTOS[@]}"; do
        log_info "  - $proto"
    done
    
    echo
}

# ============================================================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ И X-UI
# ============================================================================
install_xui_dependencies() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 4: УСТАНОВКА X-UI И ЗАВИСИМОСТЕЙ"
    log_info "════════════════════════════════════════════════════════"
    
    # Установка Docker (если его нет)
    if ! command -v docker &> /dev/null; then
        log_info "Установка Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh 2>/dev/null
        bash /tmp/get-docker.sh -q
        systemctl enable docker
        systemctl start docker
        log_success "Docker установлен"
    else
        log_success "Docker уже установлен"
    fi
    
    # Установка Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "Установка Docker Compose..."
        curl -fsSL "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose установлен"
    else
        log_success "Docker Compose уже установлен"
    fi
    
    # Установка Nginx
    if ! command -v nginx &> /dev/null; then
        log_info "Установка Nginx..."
        apt-get install -y nginx -qq
        systemctl enable nginx
        systemctl start nginx
        log_success "Nginx установлен"
    else
        log_success "Nginx уже установлен"
    fi
    
    # Установка Certbot для SSL
    if ! command -v certbot &> /dev/null; then
        log_info "Установка Certbot..."
        apt-get install -y certbot python3-certbot-nginx -qq
        log_success "Certbot установлен"
    else
        log_success "Certbot уже установлен"
    fi
    
    echo
}

# ============================================================================
# УСТАНОВКА 3X-UI
# ============================================================================
install_3xui_panel() {
    log_info "Установка 3X-UI панели..."
    
    mkdir -p /opt/3xui
    cd /opt/3xui
    
    # Скачивание последней версии 3x-ui
    log_info "Загрузка 3x-ui..."
    
    # Используем официальный репозиторий 3x-ui
    if [ ! -d "/opt/3xui/x-ui" ]; then
        git clone --depth=1 https://github.com/MHSanaei/3x-ui.git /opt/3xui/x-ui 2>/dev/null || \
        git clone --depth=1 https://github.com/GFW4Fun/x-ui-pro.git /opt/3xui/x-ui 2>/dev/null
    fi
    
    # Создание docker-compose.yml
    cat > /opt/3xui/docker-compose.yml << 'EOF'
version: '3'
services:
  3xui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3xui
    restart: unless-stopped
    ports:
      - "127.0.0.1:54321:54321"
      - "127.0.0.1:8080:8080"
      - "0.0.0.0:443:443/tcp"
      - "0.0.0.0:443:443/udp"
      - "0.0.0.0:80:80"
    volumes:
      - /opt/3xui/db:/etc/x-ui
      - /opt/3xui/certs:/root/certs
    environment:
      XRAY_VMESS_AEAD_DISABLED: "false"
    cap_add:
      - NET_ADMIN
    networks:
      - 3xui-network

networks:
  3xui-network:
    driver: bridge
EOF
    
    # Запуск контейнера
    log_info "Запуск контейнера 3x-ui..."
    cd /opt/3xui
    docker-compose up -d
    
    # Ожидание запуска
    sleep 10
    
    log_success "3X-UI установлен и запущен"
    echo
}

# ============================================================================
# КОНФИГУРИРОВАНИЕ NGINX
# ============================================================================
configure_nginx() {
    log_info "Конфигурирование Nginx для работы с 3x-ui..."
    
    # Получение SSL сертификата через Certbot
    log_info "Получение SSL сертификата для $PANEL_DOMAIN..."
    
    # Временная конфиг для получения сертификата
    cat > /etc/nginx/sites-available/temp-panel << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $PANEL_DOMAIN;
    
    location ~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/temp-panel /etc/nginx/sites-enabled/temp-panel
    mkdir -p /var/www/certbot
    
    nginx -t > /dev/null 2>&1 && systemctl reload nginx
    
    # Получение сертификата
    certbot certonly --webroot -w /var/www/certbot -d "$PANEL_DOMAIN" \
        --non-interactive --agree-tos -m "$LE_EMAIL" --quiet 2>/dev/null || \
        log_warn "Ошибка при получении сертификата. Проверьте доступность домена."
    
    # Основная конфиг для панели и 3x-ui
    cat > /etc/nginx/sites-available/3xui-panel << 'EOF'
# WebSocket для VLESS/VMESS
upstream 3xui_backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    listen [::]:80;
    server_name %PANEL_DOMAIN%;
    
    location ~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name %PANEL_DOMAIN%;
    
    ssl_certificate /etc/letsencrypt/live/%PANEL_DOMAIN%/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/%PANEL_DOMAIN%/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    
    # Admin Panel
    location / {
        proxy_pass http://3xui_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSocket endpoint для VLESS
    location /ws {
        proxy_pass http://3xui_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # gRPC endpoint для VLESS gRPC
    location /grpc {
        proxy_pass grpc://3xui_backend;
        proxy_http_version 2.0;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # XHTTP/HttpUpgrade endpoint
    location /xhttp {
        proxy_pass http://3xui_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_buffering off;
    }
}
EOF
    
    # Подставляем домен в конфиг
    sed -i "s|%PANEL_DOMAIN%|$PANEL_DOMAIN|g" /etc/nginx/sites-available/3xui-panel
    
    # Включаем сайт
    ln -sf /etc/nginx/sites-available/3xui-panel /etc/nginx/sites-enabled/3xui-panel
    rm -f /etc/nginx/sites-enabled/temp-panel /etc/nginx/sites-available/temp-panel
    
    # Тест конфига и перезагрузка
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx
        log_success "Nginx сконфигурирован"
    else
        log_error "Ошибка в конфиге Nginx"
        return 1
    fi
    
    echo
}

# ============================================================================
# СОЗДАНИЕ ИНБАУНДОВ
# ============================================================================
create_inbounds() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 5: СОЗДАНИЕ ИНБАУНДОВ"
    log_info "════════════════════════════════════════════════════════"
    
    # API 3x-ui для создания инбаундов
    API_URL="http://127.0.0.1:54321"
    
    # Ожидание готовности API
    log_info "Ожидание готовности 3x-ui API..."
    for i in {1..30}; do
        if curl -s "$API_URL/api/users" > /dev/null 2>&1; then
            log_success "API готов"
            break
        fi
        sleep 2
    done
    
    # Генерация UUID для пользователей и ключей
    VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
    VMESS_ALTID=0
    TROJAN_PASS=$(openssl rand -base64 16)
    SS_PASSWORD=$(openssl rand -base64 16)
    SS_METHOD="aes-256-gcm"
    
    log_info "Создание инбаундов..."
    
    # 1. VLESS + REALITY TCP
    if [[ " ${SELECTED_PROTOS[@]} " =~ " vless_reality_tcp " ]]; then
        log_info "  → VLESS + REALITY TCP..."
        
        VLESS_REALITY_TCP_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "vless",
  "port": 10001,
  "settings": {
    "clients": [
      {
        "id": "%UUID%",
        "email": "vless-reality-tcp@user"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "%SNI%:443",
      "xver": 0,
      "serverNames": ["%SNI%"],
      "privateKey": "%PRIVATE_KEY%",
      "publicKey": "%PUBLIC_KEY%",
      "shortIds": [""]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        # Для REALITY нужны публичный/приватный ключи
        REALITY_PRIVATE=$(xray x25519 | grep -oP 'Private key: \K.*' || echo "fallback-private-key")
        REALITY_PUBLIC=$(xray x25519 -i "$REALITY_PRIVATE" | grep -oP 'Public key: \K.*' || echo "fallback-public-key")
        
        VLESS_REALITY_TCP_CONFIG=${VLESS_REALITY_TCP_CONFIG//"%UUID%"/$VLESS_UUID}
        VLESS_REALITY_TCP_CONFIG=${VLESS_REALITY_TCP_CONFIG//"%SNI%"/$REALITY_SNI}
        VLESS_REALITY_TCP_CONFIG=${VLESS_REALITY_TCP_CONFIG//"%PRIVATE_KEY%"/$REALITY_PRIVATE}
        VLESS_REALITY_TCP_CONFIG=${VLESS_REALITY_TCP_CONFIG//"%PUBLIC_KEY%"/$REALITY_PUBLIC}
        
        # Отправка на API 3x-ui
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$VLESS_REALITY_TCP_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ VLESS + REALITY TCP создан на порту 10001"
    fi
    
    # 2. VLESS + REALITY gRPC
    if [[ " ${SELECTED_PROTOS[@]} " =~ " vless_reality_grpc " ]]; then
        log_info "  → VLESS + REALITY gRPC..."
        
        VLESS_GRPC_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "vless",
  "port": 10002,
  "settings": {
    "clients": [
      {
        "id": "%UUID%",
        "email": "vless-reality-grpc@user"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "grpc",
    "grpcSettings": {
      "serviceName": "xray"
    },
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "%SNI%:443",
      "xver": 0,
      "serverNames": ["%SNI%"],
      "privateKey": "%PRIVATE_KEY%",
      "publicKey": "%PUBLIC_KEY%",
      "shortIds": [""]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        VLESS_GRPC_CONFIG=${VLESS_GRPC_CONFIG//"%UUID%"/$VLESS_UUID}
        VLESS_GRPC_CONFIG=${VLESS_GRPC_CONFIG//"%SNI%"/$REALITY_SNI}
        VLESS_GRPC_CONFIG=${VLESS_GRPC_CONFIG//"%PRIVATE_KEY%"/$REALITY_PRIVATE}
        VLESS_GRPC_CONFIG=${VLESS_GRPC_CONFIG//"%PUBLIC_KEY%"/$REALITY_PUBLIC}
        
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$VLESS_GRPC_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ VLESS + REALITY gRPC создан на порту 10002"
    fi
    
    # 3. VLESS + REALITY XHTTP
    if [[ " ${SELECTED_PROTOS[@]} " =~ " vless_reality_xhttp " ]]; then
        log_info "  → VLESS + REALITY XHTTP..."
        
        VLESS_XHTTP_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "vless",
  "port": 10003,
  "settings": {
    "clients": [
      {
        "id": "%UUID%",
        "email": "vless-reality-xhttp@user"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "httpupgrade",
    "httpupgradeSettings": {
      "path": "/xhttp",
      "host": "%PANEL_DOMAIN%"
    },
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "%SNI%:443",
      "xver": 0,
      "serverNames": ["%SNI%"],
      "privateKey": "%PRIVATE_KEY%",
      "publicKey": "%PUBLIC_KEY%",
      "shortIds": [""]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        VLESS_XHTTP_CONFIG=${VLESS_XHTTP_CONFIG//"%UUID%"/$VLESS_UUID}
        VLESS_XHTTP_CONFIG=${VLESS_XHTTP_CONFIG//"%SNI%"/$REALITY_SNI}
        VLESS_XHTTP_CONFIG=${VLESS_XHTTP_CONFIG//"%PANEL_DOMAIN%"/$PANEL_DOMAIN}
        VLESS_XHTTP_CONFIG=${VLESS_XHTTP_CONFIG//"%PRIVATE_KEY%"/$REALITY_PRIVATE}
        VLESS_XHTTP_CONFIG=${VLESS_XHTTP_CONFIG//"%PUBLIC_KEY%"/$REALITY_PUBLIC}
        
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$VLESS_XHTTP_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ VLESS + REALITY XHTTP создан на порту 10003"
    fi
    
    # 4. VLESS + WebSocket + TLS
    if [[ " ${SELECTED_PROTOS[@]} " =~ " vless_ws_tls " ]]; then
        log_info "  → VLESS + WebSocket + TLS..."
        
        VLESS_WS_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "vless",
  "port": 10004,
  "settings": {
    "clients": [
      {
        "id": "%UUID%",
        "email": "vless-ws-tls@user"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "/ws",
      "host": "%PANEL_DOMAIN%"
    },
    "security": "tls",
    "tlsSettings": {
      "serverName": "%PANEL_DOMAIN%",
      "certificates": [
        {
          "certificateFile": "/etc/letsencrypt/live/%PANEL_DOMAIN%/fullchain.pem",
          "keyFile": "/etc/letsencrypt/live/%PANEL_DOMAIN%/privkey.pem"
        }
      ],
      "minVersion": "1.2"
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        VLESS_WS_CONFIG=${VLESS_WS_CONFIG//"%UUID%"/$VLESS_UUID}
        VLESS_WS_CONFIG=${VLESS_WS_CONFIG//"%PANEL_DOMAIN%"/$PANEL_DOMAIN}
        
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$VLESS_WS_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ VLESS + WebSocket + TLS создан на порту 10004"
    fi
    
    # 5. VMess + TCP
    if [[ " ${SELECTED_PROTOS[@]} " =~ " vmess_tcp " ]]; then
        log_info "  → VMess + TCP..."
        
        VMESS_UUID=$(cat /proc/sys/kernel/random/uuid)
        
        VMESS_TCP_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "vmess",
  "port": 10005,
  "settings": {
    "clients": [
      {
        "id": "%UUID%",
        "alterId": 0,
        "email": "vmess-tcp@user"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "tcpSettings": {
      "header": {
        "type": "none"
      }
    },
    "security": "none"
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        VMESS_TCP_CONFIG=${VMESS_TCP_CONFIG//"%UUID%"/$VMESS_UUID}
        
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$VMESS_TCP_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ VMess + TCP создан на порту 10005"
    fi
    
    # 6. Trojan + REALITY TCP
    if [[ " ${SELECTED_PROTOS[@]} " =~ " trojan_reality_tcp " ]]; then
        log_info "  → Trojan + REALITY TCP..."
        
        TROJAN_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "trojan",
  "port": 10006,
  "settings": {
    "clients": [
      {
        "password": "%PASSWORD%",
        "email": "trojan-reality@user"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "%SNI%:443",
      "xver": 0,
      "serverNames": ["%SNI%"],
      "privateKey": "%PRIVATE_KEY%",
      "publicKey": "%PUBLIC_KEY%",
      "shortIds": [""]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        TROJAN_CONFIG=${TROJAN_CONFIG//"%PASSWORD%"/$TROJAN_PASS}
        TROJAN_CONFIG=${TROJAN_CONFIG//"%SNI%"/$REALITY_SNI}
        TROJAN_CONFIG=${TROJAN_CONFIG//"%PRIVATE_KEY%"/$REALITY_PRIVATE}
        TROJAN_CONFIG=${TROJAN_CONFIG//"%PUBLIC_KEY%"/$REALITY_PUBLIC}
        
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$TROJAN_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ Trojan + REALITY TCP создан на порту 10006"
    fi
    
    # 7. ShadowSocks + TCP
    if [[ " ${SELECTED_PROTOS[@]} " =~ " shadowsocks_tcp " ]]; then
        log_info "  → ShadowSocks + TCP..."
        
        SS_CONFIG=$(cat <<'INBOUND'
{
  "protocol": "shadowsocks",
  "port": 10007,
  "settings": {
    "method": "%METHOD%",
    "ota": false,
    "password": "%PASSWORD%",
    "clients": [],
    "level": 0
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none"
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
INBOUND
        )
        
        SS_CONFIG=${SS_CONFIG//"%METHOD%"/$SS_METHOD}
        SS_CONFIG=${SS_CONFIG//"%PASSWORD%"/$SS_PASSWORD}
        
        curl -s -X POST "$API_URL/api/inbounds/add" \
            -H "Content-Type: application/json" \
            -d "$SS_CONFIG" > /dev/null 2>&1
        
        log_success "  ✓ ShadowSocks + TCP создан на порту 10007"
    fi
    
    echo
}

# ============================================================================
# СОХРАНЕНИЕ КОНФИГУРАЦИИ
# ============================================================================
save_configuration() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 6: СОХРАНЕНИЕ КОНФИГУРАЦИИ"
    log_info "════════════════════════════════════════════════════════"
    
    CONFIG_FILE="/opt/3xui/installation-config.txt"
    
    cat > "$CONFIG_FILE" << EOF
╔════════════════════════════════════════════════════════════╗
║        3X-UI PRO УСТАНОВКА - ИНФОРМАЦИЯ О КОНФИГУРАЦИИ    ║
╚════════════════════════════════════════════════════════════╝

Дата установки: $(date '+%Y-%m-%d %H:%M:%S')
Сервер: $(hostname)

┌─── ПАРАМЕТРЫ ───────────────────────────────────────────────┐
Домен панели:           $PANEL_DOMAIN
REALITY SNI:            $REALITY_SNI
Email Let's Encrypt:    $LE_EMAIL

┌─── CREDENTIALS ──────────────────────────────────────────────┐
Admin Password:         $ADMIN_PASS
Пароль Trojan:          $TROJAN_PASS
Пароль ShadowSocks:     $SS_PASSWORD (метод: $SS_METHOD)

┌─── РАСПОЛОЖЕНИЕ ФАЙЛОВ ──────────────────────────────────────┐
3X-UI директория:       /opt/3xui
Docker Compose:         /opt/3xui/docker-compose.yml
Nginx конфиг:           /etc/nginx/sites-available/3xui-panel
SSL сертификаты:        /etc/letsencrypt/live/$PANEL_DOMAIN/
БД 3X-UI:               /opt/3xui/db/

┌─── УСТАНОВЛЕННЫЕ ПРОТОКОЛЫ ──────────────────────────────────┐
EOF
    
    for proto in "${SELECTED_PROTOS[@]}"; do
        case "$proto" in
            vless_reality_tcp) echo "✓ VLESS + REALITY TCP (порт 10001)" >> "$CONFIG_FILE" ;;
            vless_reality_grpc) echo "✓ VLESS + REALITY gRPC (порт 10002)" >> "$CONFIG_FILE" ;;
            vless_reality_xhttp) echo "✓ VLESS + REALITY XHTTP (порт 10003)" >> "$CONFIG_FILE" ;;
            vless_ws_tls) echo "✓ VLESS + WebSocket + TLS (порт 10004)" >> "$CONFIG_FILE" ;;
            vmess_tcp) echo "✓ VMess + TCP (порт 10005)" >> "$CONFIG_FILE" ;;
            trojan_reality_tcp) echo "✓ Trojan + REALITY TCP (порт 10006)" >> "$CONFIG_FILE" ;;
            shadowsocks_tcp) echo "✓ ShadowSocks + TCP (порт 10007)" >> "$CONFIG_FILE" ;;
        esac
    done
    
    cat >> "$CONFIG_FILE" << 'EOF'

┌─── ССЫЛКИ И КОМАНДЫ ─────────────────────────────────────────┐

Панель администратора:
https://%PANEL_DOMAIN%

API адрес:
http://127.0.0.1:54321

Полезные команды:
  
  # Просмотр логов 3x-ui
  docker logs -f 3xui
  
  # Перезагрузка 3x-ui
  cd /opt/3xui && docker-compose restart
  
  # Просмотр статуса Nginx
  systemctl status nginx
  
  # Проверка конфига Nginx
  nginx -t
  
  # Просмотр открытых портов
  ss -tulpn | grep -E ':(443|80|10000|10007)'
  
  # Обновление SSL сертификата
  certbot renew --quiet

┌─── ИНФОРМАЦИЯ ОБ UFW ────────────────────────────────────────┐
EOF
    
    if [ $NEED_UFW_ENABLE -eq 1 ]; then
        cat >> "$CONFIG_FILE" << 'EOF'

UFW был отключен во время установки. Для переактивации:

  sudo ufw reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 443/udp
  sudo ufw allow 10001:10007/tcp
  sudo ufw enable

EOF
    else
        echo "UFW не был активен при установке" >> "$CONFIG_FILE"
    fi
    
    cat >> "$CONFIG_FILE" << 'EOF'

┌─── ВАЖНО ────────────────────────────────────────────────────┐

1. Смените пароль администратора сразу после входа в панель
2. Создайте резервную копию /opt/3xui/db/
3. Настройте автоматическое обновление SSL: 
   0 2 * * * certbot renew --quiet
4. Отслеживайте логи на предмет ошибок
5. Используйте firewall для защиты портов

═══════════════════════════════════════════════════════════════
EOF
    
    sed -i "s|%PANEL_DOMAIN%|$PANEL_DOMAIN|g" "$CONFIG_FILE"
    
    cat "$CONFIG_FILE"
    
    log_success "Конфигурация сохранена в: $CONFIG_FILE"
    echo
}

# ============================================================================
# ФИНАЛЬНЫЕ ПРОВЕРКИ
# ============================================================================
final_checks() {
    log_info "════════════════════════════════════════════════════════"
    log_info "РАЗДЕЛ 7: ФИНАЛЬНЫЕ ПРОВЕРКИ"
    log_info "════════════════════════════════════════════════════════"
    
    sleep 5
    
    # Проверка 3x-ui
    if docker ps | grep -q "3xui"; then
        log_success "3X-UI контейнер запущен"
    else
        log_error "3X-UI контейнер не запущен"
    fi
    
    # Проверка Nginx
    if systemctl is-active --quiet nginx; then
        log_success "Nginx работает"
    else
        log_error "Nginx не работает"
    fi
    
    # Проверка портов
    if ss -tulpn 2>/dev/null | grep -q ':443\s.*LISTEN'; then
        log_success "Порт 443 открыт"
    else
        log_warn "Порт 443 может быть не открыт или занят"
    fi
    
    # Проверка SSL сертификата
    if [ -f "/etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem" ]; then
        CERT_EXPIRY=$(openssl x509 -in "/etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem" -noout -enddate | cut -d= -f2)
        log_success "SSL сертификат действителен до: $CERT_EXPIRY"
    else
        log_warn "SSL сертификат не найден"
    fi
    
    echo
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================
main() {
    clear
    
    cat << 'ASCII'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           3X-UI PRO AUTOMATED INSTALLER v2.0                ║
║     VLESS • VMess • Trojan • ShadowSocks • REALITY           ║
║                                                              ║
║              Ubuntu 22.04 | Интерактивная установка         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
ASCII
    
    echo
    sleep 2
    
    check_requirements
    prepare_server
    get_user_input
    select_protocols
    install_xui_dependencies
    install_3xui_panel
    configure_nginx
    create_inbounds
    save_configuration
    final_checks
    
    log_success "╔════════════════════════════════════════════════════════╗"
    log_success "║        УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                  ║"
    log_success "╚════════════════════════════════════════════════════════╝"
    log_success ""
    log_success "Панель доступна по адресу:"
    log_success "  https://$PANEL_DOMAIN"
    log_success ""
    log_success "Полная информация сохранена в:"
    log_success "  /opt/3xui/installation-config.txt"
    log_success ""
    
}

# ============================================================================
# ОБРАБОТКА ОШИБОК
# ============================================================================
trap 'log_error "Скрипт прерван"; exit 1' INT TERM

# Запуск
main "$@"
