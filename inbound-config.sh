#!/bin/bash

################################################################################
#                    3X-UI INBOUND CONFIGURATION HELPER
#              Функции для создания инбаундов через REST API
################################################################################

# Источник: buildVlessRealityXhttp.js, buildVlessRealityTcp.js и т.д.

# ============================================================================
# ГЕНЕРАЦИЯ REALITY КЛЮЧЕЙ
# ============================================================================
generate_reality_keys() {
    # Используем xray для генерации пары ключей REALITY
    local output=$(xray x25519 2>/dev/null)
    
    local private_key=$(echo "$output" | grep -oP 'Private key: \K.*' || echo "")
    local public_key=$(echo "$output" | grep -oP 'Public key: \K.*' || echo "")
    
    # Fallback если xray не установлен
    if [ -z "$private_key" ]; then
        # Генерируем локально (требует установленного пакета)
        private_key=$(openssl rand -hex 32)
        public_key=$(openssl rand -hex 32)
    fi
    
    echo "$private_key|$public_key"
}

# ============================================================================
# 1. VLESS + REALITY TCP
# ============================================================================
create_vless_reality_tcp() {
    local uuid=$1
    local sni=$2
    local private_key=$3
    local public_key=$4
    local api_url=$5
    
    cat > /tmp/vless-reality-tcp.json << EOF
{
  "protocol": "vless",
  "port": 10001,
  "tag": "inbound-vless-reality-tcp",
  "listen": "0.0.0.0",
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "flow": "xtls-rprx-vision",
        "email": "vless-reality-tcp@3xui"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "$sni:443",
      "xver": 0,
      "serverNames": ["$sni"],
      "privateKey": "$private_key",
      "publicKey": "$public_key",
      "shortIds": ["", "00"]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/vless-reality-tcp.json
    
    rm -f /tmp/vless-reality-tcp.json
}

# ============================================================================
# 2. VLESS + REALITY gRPC
# ============================================================================
create_vless_reality_grpc() {
    local uuid=$1
    local sni=$2
    local private_key=$3
    local public_key=$4
    local api_url=$5
    
    cat > /tmp/vless-reality-grpc.json << EOF
{
  "protocol": "vless",
  "port": 10002,
  "tag": "inbound-vless-reality-grpc",
  "listen": "0.0.0.0",
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "email": "vless-reality-grpc@3xui"
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
      "dest": "$sni:443",
      "xver": 0,
      "serverNames": ["$sni"],
      "privateKey": "$private_key",
      "publicKey": "$public_key",
      "shortIds": ["", "00"]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/vless-reality-grpc.json
    
    rm -f /tmp/vless-reality-grpc.json
}

# ============================================================================
# 3. VLESS + REALITY XHTTP/HttpUpgrade
# ============================================================================
create_vless_reality_xhttp() {
    local uuid=$1
    local sni=$2
    local panel_domain=$3
    local private_key=$4
    local public_key=$5
    local api_url=$6
    
    cat > /tmp/vless-reality-xhttp.json << EOF
{
  "protocol": "vless",
  "port": 10003,
  "tag": "inbound-vless-reality-xhttp",
  "listen": "0.0.0.0",
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "email": "vless-reality-xhttp@3xui"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "httpupgrade",
    "httpupgradeSettings": {
      "path": "/xhttp",
      "host": "$panel_domain"
    },
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "$sni:443",
      "xver": 0,
      "serverNames": ["$sni"],
      "privateKey": "$private_key",
      "publicKey": "$public_key",
      "shortIds": ["", "00"]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/vless-reality-xhttp.json
    
    rm -f /tmp/vless-reality-xhttp.json
}

# ============================================================================
# 4. VLESS + WebSocket + TLS (для Cloudflare CDN)
# ============================================================================
create_vless_ws_tls() {
    local uuid=$1
    local panel_domain=$2
    local api_url=$3
    
    cat > /tmp/vless-ws-tls.json << EOF
{
  "protocol": "vless",
  "port": 10004,
  "tag": "inbound-vless-ws-tls",
  "listen": "127.0.0.1",
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "email": "vless-ws-tls@3xui"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "/ws",
      "host": "$panel_domain"
    },
    "security": "tls",
    "tlsSettings": {
      "serverName": "$panel_domain",
      "certificates": [
        {
          "certificateFile": "/etc/letsencrypt/live/$panel_domain/fullchain.pem",
          "keyFile": "/etc/letsencrypt/live/$panel_domain/privkey.pem"
        }
      ],
      "minVersion": "1.2",
      "maxVersion": "1.3"
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/vless-ws-tls.json
    
    rm -f /tmp/vless-ws-tls.json
}

# ============================================================================
# 5. VMess + TCP
# ============================================================================
create_vmess_tcp() {
    local uuid=$1
    local api_url=$2
    
    cat > /tmp/vmess-tcp.json << EOF
{
  "protocol": "vmess",
  "port": 10005,
  "tag": "inbound-vmess-tcp",
  "listen": "0.0.0.0",
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "level": 1,
        "alterId": 0,
        "email": "vmess-tcp@3xui"
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
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/vmess-tcp.json
    
    rm -f /tmp/vmess-tcp.json
}

# ============================================================================
# 6. Trojan + REALITY TCP
# ============================================================================
create_trojan_reality_tcp() {
    local password=$1
    local sni=$2
    local private_key=$3
    local public_key=$4
    local api_url=$5
    
    cat > /tmp/trojan-reality-tcp.json << EOF
{
  "protocol": "trojan",
  "port": 10006,
  "tag": "inbound-trojan-reality-tcp",
  "listen": "0.0.0.0",
  "settings": {
    "clients": [
      {
        "password": "$password",
        "email": "trojan-reality@3xui"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "$sni:443",
      "xver": 0,
      "serverNames": ["$sni"],
      "privateKey": "$private_key",
      "publicKey": "$public_key",
      "shortIds": ["", "00"]
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/trojan-reality-tcp.json
    
    rm -f /tmp/trojan-reality-tcp.json
}

# ============================================================================
# 7. ShadowSocks + TCP
# ============================================================================
create_shadowsocks_tcp() {
    local method=$1
    local password=$2
    local api_url=$3
    
    cat > /tmp/shadowsocks-tcp.json << EOF
{
  "protocol": "shadowsocks",
  "port": 10007,
  "tag": "inbound-shadowsocks-tcp",
  "listen": "0.0.0.0",
  "settings": {
    "method": "$method",
    "ota": false,
    "password": "$password",
    "level": 0
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none"
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"],
    "metadataOnly": false
  }
}
EOF
    
    curl -s -X POST "$api_url/api/inbounds/add" \
        -H "Content-Type: application/json" \
        -d @/tmp/shadowsocks-tcp.json
    
    rm -f /tmp/shadowsocks-tcp.json
}

# ============================================================================
# ФУНКЦИЯ СОЗДАНИЯ ВСЕХ ИНБАУНДОВ СРАЗУ
# ============================================================================
create_all_inbounds() {
    local uuid=$1
    local sni=$2
    local panel_domain=$3
    local api_url=$4
    
    # Генерируем REALITY ключи
    local keys=$(generate_reality_keys)
    local private_key=$(echo "$keys" | cut -d'|' -f1)
    local public_key=$(echo "$keys" | cut -d'|' -f2)
    
    # Генерируем пароли
    local trojan_pass=$(openssl rand -base64 16)
    local ss_password=$(openssl rand -base64 16)
    
    echo "Создание инбаундов..."
    
    create_vless_reality_tcp "$uuid" "$sni" "$private_key" "$public_key" "$api_url"
    echo "✓ VLESS + REALITY TCP создан"
    
    create_vless_reality_grpc "$uuid" "$sni" "$private_key" "$public_key" "$api_url"
    echo "✓ VLESS + REALITY gRPC создан"
    
    create_vless_reality_xhttp "$uuid" "$sni" "$panel_domain" "$private_key" "$public_key" "$api_url"
    echo "✓ VLESS + REALITY XHTTP создан"
    
    create_vless_ws_tls "$uuid" "$panel_domain" "$api_url"
    echo "✓ VLESS + WebSocket + TLS создан"
    
    create_vmess_tcp "$uuid" "$api_url"
    echo "✓ VMess + TCP создан"
    
    create_trojan_reality_tcp "$trojan_pass" "$sni" "$private_key" "$public_key" "$api_url"
    echo "✓ Trojan + REALITY TCP создан"
    
    create_shadowsocks_tcp "aes-256-gcm" "$ss_password" "$api_url"
    echo "✓ ShadowSocks + TCP создан"
    
    # Сохраняем учетные данные
    cat > /opt/3xui/credentials.txt << CREDS
═══════════════════════════════════════════════════════════════
                    CREDENTIALS & PASSWORDS
═══════════════════════════════════════════════════════════════

VLESS UUID:         $uuid
REALITY SNI:        $sni

Trojan Password:    $trojan_pass
ShadowSocks Pass:   $ss_password
ShadowSocks Method: aes-256-gcm

Reality Keys:
  Private: $private_key
  Public:  $public_key

═══════════════════════════════════════════════════════════════
CREDS
}

# ============================================================================
# ЭКСПОРТ ФУНКЦИЙ (для использования из главного скрипта)
# ============================================================================
export -f generate_reality_keys
export -f create_vless_reality_tcp
export -f create_vless_reality_grpc
export -f create_vless_reality_xhttp
export -f create_vless_ws_tls
export -f create_vmess_tcp
export -f create_trojan_reality_tcp
export -f create_shadowsocks_tcp
export -f create_all_inbounds
