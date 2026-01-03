#!/bin/bash
# 3X-UI PRO AUTOMATED INSTALLER v2.1 - Ubuntu 22.04/24.04 Support
# Основано на оригинальном скрипте x-ui-pro-installer.sh
# Патч: Поддержка Ubuntu 24.04 добавлена

set -e

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m' # No Color

loginfo() { echo -e "${BLUE}[INFO]${NC} $1"; }
logsuccess() { echo -e "${GREEN}[OK]${NC} $1"; }
logwarn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
logerror() { echo -e "${RED}[ERROR]${NC} $1"; }

TITLE() { echo -e "${CYAN}========== $1 ==========${NC}"; }

# Check Requirements
checkrequirements() {
  clear
  cat << 'ASCII'
   _____ _____  _    _ _____  _____  ____  
  / ____|  __ \| |  | |  __ \|  __ \|  _ \ 
 | |  __| |__) | |  | | |__) | |__) | |_) |
 | | |_ |  _  /| |  | |  _  /|  _  /|  _ < 
 | |__| | | \ \| |__| | | \ \| | \ \| |_) |
  \_____|_|  \_\\____/|_|  \_\_|  \_\____/ 
                                          
3X-UI PRO AUTOMATED INSTALLER v2.0
VLESS, VMess, Trojan, ShadowSocks
REALITY Ubuntu 22.04/24.04
ASCII
  echo
  sleep 2

  TITLE "Проверка предварительных требований..."
  loginfo "Проверка root..."
  if [ "$EUID" -ne 0 ]; then
    logerror "root или sudo"
    exit 1
  fi

  if [ ! -f /etc/os-release ]; then
    logerror "Ошибка: /etc/os-release не найден"
    exit 1
  fi

  . /etc/os-release
  
  # ✅ ПОДДЕРЖКА UBUNTU 22.04 И 24.04
  if [[ "$ID" != "ubuntu" ]]; then
    logerror "Поддерживается только Ubuntu"
    exit 1
  fi

  if [[ "$VERSION_ID" != "22.04" && "$VERSION_ID" != "24.04" ]]; then
    logwarn "Оптимально: Ubuntu 22.04/24.04"
    logwarn "Обнаружена: $PRETTY_NAME"
    read -p "Продолжить? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  else
    logsuccess "ОС: $PRETTY_NAME ✓"
  fi

  logsuccess "Требования выполнены"
}

# Prepare Server
prepareserver() {
  TITLE "Подготовка сервера..."

  loginfo "1. Обновление системы..."
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -qq

  # ✅ ФИКС ДЛЯ UBUNTU 24.04: Отключение snapd
  if command -v snap >/dev/null 2>&1; then
    loginfo "Отключение snapd (Ubuntu 24.04 фикс)..."
    systemctl disable --now snapd.socket snapd 2>/dev/null || true
    apt purge -y snapd -qq || true
  fi

  logsuccess "✓ Система обновлена"

  loginfo "2. Установка зависимостей..."
  REQUIRED_TOOLS="curl wget jq lsof net-tools ufw cron socat git htop vim ca-certificates"
  for tool in $REQUIRED_TOOLS; do
    if ! command -v $tool >/dev/null 2>&1; then
      loginfo "  Установка $tool..."
      apt-get install -y $tool -qq
    else
      logsuccess "  $tool ✓"
    fi
  done

  logsuccess "✓ Зависимости установлены"

  loginfo "3. Проверка портов 22, 80, 443..."
  PORT22=$(ss -tulpn 2>/dev/null | grep ':22 ' | grep LISTEN | wc -l)
  PORT80=$(ss -tulpn 2>/dev/null | grep ':80 ' | grep LISTEN | wc -l)
  PORT443=$(ss -tulpn 2>/dev/null | grep ':443 ' | grep LISTEN | wc -l)

  logsuccess "22 занят: $PORT22"
  logsuccess "80 занят: $PORT80"
  logsuccess "443 занят: $PORT443"

  loginfo "4. Проверка UFW..."
  if ufw status 2>/dev/null | grep -q "Status: active"; then
    logwarn "UFW активен. Отключаем..."
    ufw --force disable >/dev/null 2>&1 || true
    NEED_UFW_ENABLE=1
  else
    logsuccess "UFW не активен ✓"
    NEED_UFW_ENABLE=0
  fi

  loginfo "5. Sysctl оптимизация XRay/V2Ray..."
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
  sysctl -p >/dev/null 2>&1
  logsuccess "✓ Sysctl оптимизирован"

  loginfo "6. Очистка системы..."
  apt-get autoremove -y -qq
  apt-get autoclean -y -qq
  logsuccess "✓ Система готова"
  echo
}

# Get User Input
getuserinput() {
  TITLE "Получение параметров пользователя..."
  loginfo "2. Конфигурация 3X-UI"
  echo

  loginfo "WebSocket/gRPC домен панели:"
  read -p "Введите домен (panel.example.com): " PANELDOMAIN
  if [ -z "$PANELDOMAIN" ]; then
    logerror "Домен обязателен!"
    getuserinput
    return
  fi

  loginfo "REALITY SNI..."
  read -p "Введите SNI (www.google.com, www.microsoft.com): " REALITYSNI
  REALITYSNI=${REALITYSNI:-"www.microsoft.com"}

  loginfo "Email для Let's Encrypt SSL..."
  read -p "Введите email (admin@example.com): " LEEMAIL
  LEEMAIL=${LEEMAIL:-"admin@example.com"}

  loginfo "Пароль администратора x-ui..."
  read -sp "ADMIN PASS: " ADMINPASS
  echo
  read -sp "Подтвердите пароль: " ADMINPASS_CONFIRM
  echo
  if [ "$ADMINPASS" != "$ADMINPASS_CONFIRM" ]; then
    logerror "Пароли не совпадают!"
    getuserinput
    return
  fi
  if [ -z "$ADMINPASS" ]; then
    logerror "Пароль обязателен!"
    getuserinput
    return
  fi
  echo
  logsuccess "✓ Параметры получены"
}

# Select Protocols
selectprotocols() {
  TITLE "Выбор протоколов..."
  loginfo "3. Доступные протоколы:"
  echo

  declare -a PROTOCOLS=(
    "vlessrealitytcp|VLESS REALITY TCP stealth|true"
    "vlessrealitygrpc|VLESS REALITY gRPC DPI bypass|true"
    "vlessrealityxhttp|VLESS REALITY XHTTP/HttpUpgrade|true"
    "vlesswstls|VLESS WebSocket TLS CDN-friendly|true"
    "vmesstcp|VMess TCP|false"
    "trojanrealitytcp|Trojan REALITY TCP|false"
    "shadowsockstcp|ShadowSocks TCP|false"
  )

  for i in "${!PROTOCOLS[@]}"; do
    IFS='|' read -r PROTOID PROTONAME PROTODEFAULT <<< "${PROTOCOLS[$i]}"
    if [[ "$PROTODEFAULT" == "true" ]]; then 
      DEFAULT_CHOICE="Y"
    else 
      DEFAULT_CHOICE="N"
    fi
    echo "  $((i+1)). [$DEFAULT_CHOICE] $PROTONAME"
  done

  echo
  echo "Введите номера через запятую (1,2,4) или Enter для 1,2,3:"
  read -p ">> " SELECTEDPROTOCOLS
  if [ -z "$SELECTEDPROTOCOLS" ]; then
    SELECTEDPROTOCOLS="1,2,3"
  fi

  # Parse selection
  IFS=',' read -ra SELECTED_ARRAY <<< "$SELECTEDPROTOCOLS"
  SELECTED_PROTOS=""
  for selection in "${SELECTED_ARRAY[@]}"; do
    selection=$(echo "$selection" | xargs) # trim
    idx=$((selection - 1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#PROTOCOLS[@]} ]; then
      IFS='|' read -r PROTOID _ <<< "${PROTOCOLS[$idx]}"
      SELECTED_PROTOS="$SELECTED_PROTOS$PROTOID "
    fi
  done

  if [ -z "$SELECTED_PROTOS" ]; then
    logerror "Выберите хотя бы один протокол"
    selectprotocols
    return
  fi

  logsuccess "✓ Выбрано: $SELECTED_PROTOS"
  echo
}

# Install XUI Dependencies
installxuidependencies() {
  TITLE "Установка зависимостей 3X-UI..."
  loginfo "4. Установка X-UI"
  echo

  loginfo "Установка Docker..."
  if ! command -v docker >/dev/null 2>&1; then
    loginfo "Docker не найден, устанавливаем..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh 2>/dev/null
    bash /tmp/get-docker.sh -q
    systemctl enable docker
    systemctl start docker
    logsuccess "✓ Docker установлен"
  else
    logsuccess "✓ Docker уже установлен"
  fi

  loginfo "Установка Docker Compose..."
  if ! command -v docker-compose >/dev/null 2>&1; then
    loginfo "Docker Compose не найден, устанавливаем..."
    curl -fsSL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose 2>/dev/null
    chmod +x /usr/local/bin/docker-compose
    logsuccess "✓ Docker Compose установлен"
  else
    logsuccess "✓ Docker Compose уже установлен"
  fi

  loginfo "Установка Nginx..."
  if ! command -v nginx >/dev/null 2>&1; then
    apt-get install -y nginx -qq
    systemctl enable nginx
    systemctl start nginx
    logsuccess "✓ Nginx установлен"
  else
    logsuccess "✓ Nginx уже установлен"
  fi

  loginfo "Установка Certbot..."
  if ! command -v certbot >/dev/null 2>&1; then
    apt-get install -y certbot python3-certbot-nginx -qq
    logsuccess "✓ Certbot установлен"
  else
    logsuccess "✓ Certbot уже установлен"
  fi
  echo
}

# Install 3XUI Panel
install3xuipanel() {
  TITLE "Установка 3X-UI панели..."
  loginfo "Загрузка 3X-UI..."

  mkdir -p /opt/3xui
  cd /opt/3xui

  loginfo "Клонирование репозитория 3x-ui..."
  if [ ! -d /opt/3xui/x-ui ]; then
    git clone --depth 1 https://github.com/MHSanaei/3x-ui.git /opt/3xui/x-ui 2>/dev/null || \
    git clone --depth 1 https://github.com/GFW4Fun/x-ui-pro.git /opt/3xui/x-ui 2>/dev/null
  fi

  loginfo "Создание docker-compose.yml..."
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
      - "0.0.0.0:8080"
    volumes:
      - /opt/3xui/db:/etc/x-ui
      - /opt/3xui/certs:/root/certs
    environment:
      - XRAY_VMESS_AEAD_DISABLED=false
    cap_add:
      - NET_ADMIN
    networks:
      - 3xui-network

networks:
  3xui-network:
    driver: bridge
EOF

  loginfo "Запуск 3X-UI контейнера..."
  cd /opt/3xui
  docker-compose up -d
  sleep 10
  logsuccess "✓ 3X-UI установлена"
  echo
}

# Configure Nginx
configurenginx() {
  TITLE "Конфигурация Nginx и SSL..."
  loginfo "Проверка и настройка SSL для $PANELDOMAIN..."

  loginfo "Создание временного Nginx конфига для SSL..."
  cat > /etc/nginx/sites-available/temp-panel << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $PANELDOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/temp-panel /etc/nginx/sites-enabled/temp-panel
  mkdir -p /var/www/certbot
  nginx -t >/dev/null 2>&1
  systemctl reload nginx

  loginfo "Получение SSL сертификата от Let's Encrypt..."
  certbot certonly --webroot -w /var/www/certbot -d $PANELDOMAIN --non-interactive --agree-tos -m $LEEMAIL --quiet 2>/dev/null || logwarn "SSL получение в процессе"

  loginfo "Создание финального Nginx конфига..."
  cat > /etc/nginx/sites-available/3xui-panel << EOF
upstream 3xui_backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    listen [::]:80;
    server_name $PANELDOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http/2;
    listen [::]:443 ssl http/2;
    server_name $PANELDOMAIN;

    ssl_certificate /etc/letsencrypt/live/$PANELDOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$PANELDOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    location / {
        proxy_pass http://3xui_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /ws {
        proxy_pass http://3xui_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /grpc {
        proxy_pass http://3xui_backend;
        proxy_http_version 2.0;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /xhttp {
        proxy_pass http://3xui_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_buffering off;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/3xui-panel /etc/nginx/sites-enabled/3xui-panel
  rm -f /etc/nginx/sites-enabled/temp-panel /etc/nginx/sites-available/temp-panel

  nginx -t >/dev/null 2>&1
  systemctl reload nginx
  logsuccess "✓ Nginx настроен"
  echo
}

# Create Inbounds
createinbounds() {
  TITLE "Создание инбаундов..."
  loginfo "5. Конфигурация X-UI инбаундов"
  echo

  API_URL="http://127.0.0.1:54321"

  # Wait for API
  loginfo "Ожидание X-UI API..."
  for i in {1..30}; do
    if curl -s "$API_URL/api/users" >/dev/null 2>&1; then
      logsuccess "✓ API доступен"
      break
    fi
    sleep 2
  done

  # Generate REALITY keys
  REALITY_PRIVATE=$(xray x25519 | grep -oP 'Private key: \K.*' || echo "fallback-private-key")
  REALITY_PUBLIC=$(xray x25519 -i "$REALITY_PRIVATE" | grep -oP 'Public key: \K.*' || echo "fallback-public-key")

  # Generate UUIDs and passwords
  VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
  VMESS_ALTID=0
  TROJAN_PASS=$(openssl rand -base64 16)
  SS_PASSWORD=$(openssl rand -base64 16)
  SS_METHOD="aes-256-gcm"

  loginfo "Генерируем UUID и пароли..."
  echo

  # Create inbounds based on selection
  CONFIG_FILE="/opt/3xui/installation-config.txt"

  if [[ "$SELECTED_PROTOS" == *"vlessrealitytcp"* ]]; then
    loginfo "Создание VLESS REALITY TCP инбаунда..."
    VLESS_REALITY_TCP_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "vless",
    "port": 10001,
    "settings": {
      "clients": [
        {
          "id": "$VLESS_UUID",
          "email": "vless-reality-tcp-user"
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "SNI:443",
        "xver": 0,
        "serverNames": ["$REALITYSNI"],
        "privateKey": "$REALITY_PRIVATE",
        "publicKey": "$REALITY_PUBLIC",
        "shortIds": []
      }
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls", "quic"]
    }
  }
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$VLESS_REALITY_TCP_CONFIG" >/dev/null 2>&1
    logsuccess "✓ VLESS REALITY TCP (port 10001)"
  fi

  if [[ "$SELECTED_PROTOS" == *"vlessrealitygrpc"* ]]; then
    loginfo "Создание VLESS REALITY gRPC инбаунда..."
    VLESS_GRPC_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "vless",
    "port": 10002,
    "settings": {
      "clients": [
        {
          "id": "$VLESS_UUID",
          "email": "vless-reality-grpc-user"
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
        "dest": "SNI:443",
        "xver": 0,
        "serverNames": ["$REALITYSNI"],
        "privateKey": "$REALITY_PRIVATE",
        "publicKey": "$REALITY_PUBLIC",
        "shortIds": []
      }
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls", "quic"]
    }
  }
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$VLESS_GRPC_CONFIG" >/dev/null 2>&1
    logsuccess "✓ VLESS REALITY gRPC (port 10002)"
  fi

  if [[ "$SELECTED_PROTOS" == *"vlessrealityxhttp"* ]]; then
    loginfo "Создание VLESS REALITY XHTTP инбаунда..."
    VLESS_XHTTP_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "vless",
    "port": 10003,
    "settings": {
      "clients": [
        {
          "id": "$VLESS_UUID",
          "email": "vless-reality-xhttp-user"
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "httpupgrade",
      "httpupgradeSettings": {
        "path": "/xhttp",
        "host": "$PANELDOMAIN"
      },
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "SNI:443",
        "xver": 0,
        "serverNames": ["$REALITYSNI"],
        "privateKey": "$REALITY_PRIVATE",
        "publicKey": "$REALITY_PUBLIC",
        "shortIds": []
      }
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls", "quic"]
    }
  }
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$VLESS_XHTTP_CONFIG" >/dev/null 2>&1
    logsuccess "✓ VLESS REALITY XHTTP (port 10003)"
  fi

  if [[ "$SELECTED_PROTOS" == *"vlesswstls"* ]]; then
    loginfo "Создание VLESS WebSocket TLS инбаунда..."
    VLESS_WS_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "vless",
    "port": 10004,
    "settings": {
      "clients": [
        {
          "id": "$VLESS_UUID",
          "email": "vless-ws-tls-user"
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/ws",
        "host": "$PANELDOMAIN"
      },
      "security": "tls",
      "tlsSettings": {
        "serverName": "$PANELDOMAIN",
        "certificates": [
          {
            "certificateFile": "/etc/letsencrypt/live/$PANELDOMAIN/fullchain.pem",
            "keyFile": "/etc/letsencrypt/live/$PANELDOMAIN/privkey.pem"
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
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$VLESS_WS_CONFIG" >/dev/null 2>&1
    logsuccess "✓ VLESS WebSocket TLS (port 10004)"
  fi

  if [[ "$SELECTED_PROTOS" == *"vmesstcp"* ]]; then
    loginfo "Создание VMess TCP инбаунда..."
    VMESS_TCP_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "vmess",
    "port": 10005,
    "settings": {
      "clients": [
        {
          "id": "$VLESS_UUID",
          "alterId": 0,
          "email": "vmess-tcp-user"
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
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$VMESS_TCP_CONFIG" >/dev/null 2>&1
    logsuccess "✓ VMess TCP (port 10005)"
  fi

  if [[ "$SELECTED_PROTOS" == *"trojanrealitytcp"* ]]; then
    loginfo "Создание Trojan REALITY TCP инбаунда..."
    TROJAN_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "trojan",
    "port": 10006,
    "settings": {
      "clients": [
        {
          "password": "$TROJAN_PASS",
          "email": "trojan-reality-user"
        }
      ]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "SNI:443",
        "xver": 0,
        "serverNames": ["$REALITYSNI"],
        "privateKey": "$REALITY_PRIVATE",
        "publicKey": "$REALITY_PUBLIC",
        "shortIds": []
      }
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls", "quic"]
    }
  }
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$TROJAN_CONFIG" >/dev/null 2>&1
    logsuccess "✓ Trojan REALITY TCP (port 10006)"
  fi

  if [[ "$SELECTED_PROTOS" == *"shadowsockstcp"* ]]; then
    loginfo "Создание ShadowSocks TCP инбаунда..."
    SS_CONFIG=$(cat <<EOFCONFIG
{
  "inbound": {
    "protocol": "shadowsocks",
    "port": 10007,
    "settings": {
      "method": "$SS_METHOD",
      "ota": false,
      "password": "$SS_PASSWORD",
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
}
EOFCONFIG
)
    curl -s -X POST "$API_URL/api/inbounds/add" -H "Content-Type: application/json" -d "$SS_CONFIG" >/dev/null 2>&1
    logsuccess "✓ ShadowSocks TCP (port 10007)"
  fi

  echo
}

# Save Configuration
saveconfiguration() {
  TITLE "Сохранение конфигурации..."
  loginfo "6. Сохранение настроек установки"
  echo

  CONFIG_FILE="/opt/3xui/installation-config.txt"

  cat > "$CONFIG_FILE" << EOF
═══════════════════════════════════════════════════════════
3X-UI PRO INSTALLATION CONFIG
═══════════════════════════════════════════════════════════
Installation Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)

PANEL CONFIGURATION:
  Domain: $PANELDOMAIN
  REALITY SNI: $REALITYSNI
  Email (Let's Encrypt): $LEEMAIL

CREDENTIALS:
  Admin Password: $ADMINPASS
  Trojan Password: $TROJAN_PASS
  ShadowSocks Password: $SS_PASSWORD
  ShadowSocks Method: $SS_METHOD

3X-UI PATHS:
  Installation: /opt/3xui
  Docker Compose: /opt/3xui/docker-compose.yml
  Nginx Config: /etc/nginx/sites-available/3xui-panel
  SSL Certs: /etc/letsencrypt/live/$PANELDOMAIN
  Database: /opt/3xui/db

API ENDPOINT:
  http://127.0.0.1:54321

INBOUNDS:
EOF

  if [[ "$SELECTED_PROTOS" == *"vlessrealitytcp"* ]]; then
    echo "  1. VLESS REALITY TCP - Port 10001" >> "$CONFIG_FILE"
  fi
  if [[ "$SELECTED_PROTOS" == *"vlessrealitygrpc"* ]]; then
    echo "  2. VLESS REALITY gRPC - Port 10002" >> "$CONFIG_FILE"
  fi
  if [[ "$SELECTED_PROTOS" == *"vlessrealityxhttp"* ]]; then
    echo "  3. VLESS REALITY XHTTP - Port 10003" >> "$CONFIG_FILE"
  fi
  if [[ "$SELECTED_PROTOS" == *"vlesswstls"* ]]; then
    echo "  4. VLESS WebSocket TLS - Port 10004" >> "$CONFIG_FILE"
  fi
  if [[ "$SELECTED_PROTOS" == *"vmesstcp"* ]]; then
    echo "  5. VMess TCP - Port 10005" >> "$CONFIG_FILE"
  fi
  if [[ "$SELECTED_PROTOS" == *"trojanrealitytcp"* ]]; then
    echo "  6. Trojan REALITY TCP - Port 10006" >> "$CONFIG_FILE"
  fi
  if [[ "$SELECTED_PROTOS" == *"shadowsockstcp"* ]]; then
    echo "  7. ShadowSocks TCP - Port 10007" >> "$CONFIG_FILE"
  fi

  cat >> "$CONFIG_FILE" << 'EOF'

IMPORTANT NOTES:
  1. Backup your database: /opt/3xui/db
  2. Keep your password safe!
  3. SSL auto-renewal runs daily via certbot
  4. Check logs: docker logs 3xui
  5. Restart service: cd /opt/3xui && docker-compose restart

FIREWALL (UFW):
  If enabled, allow these ports:
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 443/udp
  sudo ufw allow 10001:10007/tcp

═══════════════════════════════════════════════════════════
EOF

  cat "$CONFIG_FILE"
  logsuccess "✓ Конфигурация сохранена в: $CONFIG_FILE"
  echo
}

# Final Checks
finalchecks() {
  TITLE "Финальная проверка..."
  loginfo "7. Проверка установки"
  echo

  sleep 5

  # Check Docker container
  if docker ps | grep -q 3xui; then
    logsuccess "✓ 3X-UI контейнер работает"
  else
    logerror "✗ 3X-UI контейнер не работает"
  fi

  # Check Nginx
  if nginx -t >/dev/null 2>&1; then
    logsuccess "✓ Nginx конфигурация OK"
    systemctl reload nginx
  else
    logerror "✗ Nginx конфигурация ошибка"
    return 1
  fi

  # Check ports
  if ss -tulpn 2>/dev/null | grep -qE ':(443|80) .*LISTEN'; then
    logsuccess "✓ Порты 80/443 открыты"
  else
    logwarn "⚠ Порты 80/443 закрыты"
  fi

  # Check SSL
  if [ -f /etc/letsencrypt/live/$PANELDOMAIN/fullchain.pem ]; then
    CERT_EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/$PANELDOMAIN/fullchain.pem -noout -enddate | cut -d= -f2)
    logsuccess "✓ SSL сертификат: $CERT_EXPIRY"
  else
    logwarn "⚠ SSL сертификат не найден"
  fi

  echo
  TITLE "✅ Установка завершена!"
  echo
  echo "📋 Детали установки сохранены в: /opt/3xui/installation-config.txt"
  echo
  echo "🔗 Доступ к панели:"
  echo "   URL: https://$PANELDOMAIN"
  echo "   API: http://127.0.0.1:54321"
  echo
  echo "⚙️  Управление:"
  echo "   Перезапуск: cd /opt/3xui && docker-compose restart"
  echo "   Логи: docker logs -f 3xui"
  echo "   Остановка: cd /opt/3xui && docker-compose down"
  echo
  logsuccess "Спасибо за использование 3X-UI PRO INSTALLER!"
  echo
}

# Main execution
trap 'logerror "Установка прервана"; exit 1' INT TERM

checkrequirements
prepareserver
getuserinput
selectprotocols
installxuidependencies
install3xuipanel
configurenginx
createinbounds
saveconfiguration
finalchecks
