
# Чтение файлов с builder-скриптами
files_content = {}

file_paths = {
    'buildVlessRealityXhttp.js': 'file:1',
    'buildVlessRealityTcp.js': 'file:2', 
    'buildTrojanRealityTcp.js': 'file:3',
    'buildVmessTcp.js': 'file:4',
    'buildShadowsocksTcp.js': 'file:5',
    'buildVlessWs.js': 'file:6',
    'buildVlessRealityGrpc.js': 'file:7'
}

# Выведу структуру как пример
print("""
=== СТРУКТУРА BUILDER-СКРИПТОВ ===
Для создания интерактивного инсталлятора нужно понять,
как эти скрипты формируют конфигурации инбаундов.

Типичная структура для 3x-ui inbound:
- protocol: 'vless', 'vmess', 'trojan', 'shadowsocks'
- port: номер порта
- settings: { clients: [], fallbacks: [] }
- streamSettings: { network: 'tcp'/'ws'/'grpc'/'httpupgrade', 
                   security: 'none'/'tls'/'reality' }
- sniffing: { enabled: true, destOverride: [...] }

Протоколы к установке:
1. VLESS + REALITY TCP (базовый stealth)
2. VLESS + REALITY gRPC (для DPI bypass)
3. VLESS + REALITY XHTTP (httpupgrade маскировка)
4. VLESS + WebSocket TLS (CDN-friendly)
5. VMess TCP (совместимость)
6. Trojan REALITY TCP (альтернативный stealth)
7. ShadowSocks TCP (лёгкий протокол)
""")
