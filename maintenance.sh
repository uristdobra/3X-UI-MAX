#!/bin/bash

################################################################################
#                    3X-UI MAINTENANCE & MONITORING TOOLS
#                  Резервное копирование, мониторинг и утилиты
################################################################################

set -e

# ============================================================================
# ЦВЕТА
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# РЕЗЕРВНОЕ КОПИРОВАНИЕ
# ============================================================================

backup_3xui() {
    local BACKUP_DIR="/opt/3xui/backups"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="$BACKUP_DIR/3xui-backup-$TIMESTAMP.tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    echo -e "${BLUE}[INFO]${NC} Создание резервной копии..."
    
    tar -czf "$BACKUP_FILE" \
        /opt/3xui/db/ \
        /opt/3xui/certs/ \
        /etc/nginx/sites-available/3xui-panel \
        /etc/letsencrypt/live/ \
        2>/dev/null || true
    
    if [ -f "$BACKUP_FILE" ]; then
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        echo -e "${GREEN}[✓]${NC} Резервная копия создана: $BACKUP_FILE ($SIZE)"
        
        # Удалить старые резервные копии (старше 30 дней)
        find "$BACKUP_DIR" -name "3xui-backup-*.tar.gz" -mtime +30 -delete
        echo -e "${GREEN}[✓]${NC} Старые резервные копии очищены"
    else
        echo -e "${RED}[✗]${NC} Ошибка при создании резервной копии"
        return 1
    fi
}

backup_remote() {
    local BACKUP_FILE=$1
    local REMOTE_HOST=$2
    local REMOTE_PATH=$3
    
    if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_PATH" ]; then
        echo -e "${YELLOW}[WARN]${NC} Параметры удаленного хоста не установлены"
        return 1
    fi
    
    echo -e "${BLUE}[INFO]${NC} Отправка резервной копии на удаленный сервер..."
    
    scp -P 22 "$BACKUP_FILE" "$REMOTE_HOST:$REMOTE_PATH/" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓]${NC} Резервная копия отправлена на $REMOTE_HOST"
    else
        echo -e "${RED}[✗]${NC} Ошибка при отправке на удаленный сервер"
        return 1
    fi
}

restore_backup() {
    local BACKUP_FILE=$1
    
    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}[✗]${NC} Файл резервной копии не найден: $BACKUP_FILE"
        return 1
    fi
    
    echo -e "${YELLOW}[WARN]${NC} Восстановление будет перезаписывать текущие данные"
    read -p "Вы уверены? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${BLUE}[INFO]${NC} Отмена операции"
        return 0
    fi
    
    echo -e "${BLUE}[INFO]${NC} Остановка контейнера..."
    docker-compose -f /opt/3xui/docker-compose.yml stop 3xui
    
    echo -e "${BLUE}[INFO]${NC} Восстановление файлов..."
    tar -xzf "$BACKUP_FILE" -C /
    
    echo -e "${BLUE}[INFO]${NC} Запуск контейнера..."
    docker-compose -f /opt/3xui/docker-compose.yml up -d
    
    sleep 5
    
    echo -e "${GREEN}[✓]${NC} Восстановление завершено"
}

# ============================================================================
# МОНИТОРИНГ
# ============================================================================

check_system_health() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}СИСТЕМНОЕ ЗДОРОВЬЕ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo -e "CPU: ${YELLOW}${CPU_USAGE}%${NC}"
    
    # RAM
    RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    RAM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", ($3/$2)*100}')
    echo -e "RAM: ${YELLOW}${RAM_USED} / ${RAM_TOTAL}${NC} (${RAM_PERCENT}%)"
    
    # DISK
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    echo -e "DISK: ${YELLOW}${DISK_USED} / ${DISK_TOTAL}${NC} (${DISK_USAGE})"
    
    # Uptime
    UPTIME=$(uptime -p | sed 's/up //')
    echo -e "UPTIME: ${YELLOW}${UPTIME}${NC}"
    
    # Network
    RX=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null || echo "0")
    TX=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null || echo "0")
    echo -e "RX: ${YELLOW}$(numfmt --to=iec-i --suffix=B $RX 2>/dev/null || echo "$RX bytes")${NC}"
    echo -e "TX: ${YELLOW}$(numfmt --to=iec-i --suffix=B $TX 2>/dev/null || echo "$TX bytes")${NC}"
    
    echo
}

check_service_status() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}СТАТУС СЕРВИСОВ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    
    # Docker
    if systemctl is-active --quiet docker; then
        echo -e "Docker: ${GREEN}✓ Running${NC}"
    else
        echo -e "Docker: ${RED}✗ Stopped${NC}"
    fi
    
    # Nginx
    if systemctl is-active --quiet nginx; then
        echo -e "Nginx: ${GREEN}✓ Running${NC}"
    else
        echo -e "Nginx: ${RED}✗ Stopped${NC}"
    fi
    
    # 3xui Container
    if docker ps | grep -q "3xui"; then
        echo -e "3xui Container: ${GREEN}✓ Running${NC}"
    else
        echo -e "3xui Container: ${RED}✗ Stopped${NC}"
    fi
    
    # SSL Certificate
    CERT_FILE="/etc/letsencrypt/live/$(hostname -f)/fullchain.pem"
    if [ -f "$CERT_FILE" ]; then
        EXPIRE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        DAYS_LEFT=$(( ($(date -d "$EXPIRE" +%s) - $(date +%s)) / 86400 ))
        
        if [ $DAYS_LEFT -gt 30 ]; then
            echo -e "SSL Certificate: ${GREEN}✓ Valid (expires in $DAYS_LEFT days)${NC}"
        elif [ $DAYS_LEFT -gt 0 ]; then
            echo -e "SSL Certificate: ${YELLOW}⚠ Expiring soon ($DAYS_LEFT days)${NC}"
        else
            echo -e "SSL Certificate: ${RED}✗ Expired${NC}"
        fi
    else
        echo -e "SSL Certificate: ${YELLOW}? Not found${NC}"
    fi
    
    echo
}

check_ports() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}СОСТОЯНИЕ ПОРТОВ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    
    local PORTS=(22 80 443 8080 54321 10001 10002 10003 10004 10005 10006 10007)
    
    for port in "${PORTS[@]}"; do
        if ss -tulpn 2>/dev/null | grep -q ":$port "; then
            echo -e "Port $port: ${GREEN}✓ OPEN${NC}"
        else
            echo -e "Port $port: ${RED}✗ CLOSED${NC}"
        fi
    done
    
    echo
}

show_statistics() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}СТАТИСТИКА ТРАФИКА (Nginx)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    
    if [ -f /var/log/nginx/3xui_access.log ]; then
        TOTAL_REQUESTS=$(wc -l < /var/log/nginx/3xui_access.log)
        echo -e "Всего запросов: ${YELLOW}$TOTAL_REQUESTS${NC}"
        
        WS_REQUESTS=$(grep -c "GET /ws" /var/log/nginx/3xui_access.log || echo "0")
        GRPC_REQUESTS=$(grep -c "POST /xray" /var/log/nginx/3xui_access.log || echo "0")
        XHTTP_REQUESTS=$(grep -c "POST /xhttp" /var/log/nginx/3xui_access.log || echo "0")
        
        echo -e "WebSocket запросы: ${YELLOW}$WS_REQUESTS${NC}"
        echo -e "gRPC запросы: ${YELLOW}$GRPC_REQUESTS${NC}"
        echo -e "XHTTP запросы: ${YELLOW}$XHTTP_REQUESTS${NC}"
        
        # Top IPs
        echo -e "\n${BLUE}Топ IP адресов:${NC}"
        cut -d' ' -f1 /var/log/nginx/3xui_access.log | sort | uniq -c | sort -rn | head -5 | \
            awk '{print "  " $2 ": " $1 " запросов"}'
    else
        echo -e "${YELLOW}Лог-файл не найден${NC}"
    fi
    
    echo
}

show_docker_logs() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}ПОСЛЕДНИЕ ЛОГИ 3XUI${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    
    docker logs --tail=20 3xui 2>/dev/null || echo "Контейнер не запущен"
    
    echo
}

# ============================================================================
# УТИЛИТЫ
# ============================================================================

update_certificates() {
    echo -e "${BLUE}[INFO]${NC} Обновление SSL сертификатов..."
    
    certbot renew --quiet --deploy-hook "systemctl reload nginx"
    
    echo -e "${GREEN}[✓]${NC} Сертификаты обновлены"
}

restart_services() {
    echo -e "${BLUE}[INFO]${NC} Перезагрузка сервисов..."
    
    systemctl restart docker
    sleep 5
    docker-compose -f /opt/3xui/docker-compose.yml restart 3xui
    systemctl reload nginx
    
    sleep 5
    
    echo -e "${GREEN}[✓]${NC} Сервисы перезагружены"
}

optimize_system() {
    echo -e "${BLUE}[INFO]${NC} Оптимизация системы..."
    
    # Очистить кэш пакетов
    apt-get clean -y -qq
    apt-get autoclean -y -qq
    apt-get autoremove -y -qq
    
    # Очистить логи
    find /var/log -type f -name "*.log" -mtime +30 -delete
    
    # Очистить временные файлы
    rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    
    echo -e "${GREEN}[✓]${NC} Система оптимизирована"
}

show_usage() {
    cat << 'EOF'
3X-UI Maintenance & Monitoring Tool

ИСПОЛЬЗОВАНИЕ:
  ./maintenance.sh [КОМАНДА] [ПАРАМЕТРЫ]

КОМАНДЫ:

Резервное копирование:
  backup                 - Создать резервную копию
  backup-remote <host>   - Отправить копию на удаленный хост (ssh)
  restore <file>         - Восстановить из резервной копии

Мониторинг:
  health                 - Показать здоровье системы
  status                 - Показать статус сервисов
  ports                  - Показать состояние портов
  stats                  - Показать статистику трафика
  logs                   - Показать логи 3xui
  monitor                - Полный мониторинг (все команды выше)

Утилиты:
  update-certs           - Обновить SSL сертификаты
  restart                - Перезагрузить сервисы
  optimize               - Оптимизировать систему
  
Помощь:
  help                   - Показать эту справку

ПРИМЕРЫ:
  sudo ./maintenance.sh backup
  sudo ./maintenance.sh monitor
  sudo ./maintenance.sh restore /opt/3xui/backups/3xui-backup-20260103_120000.tar.gz
  
EOF
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    case "$1" in
        backup)
            backup_3xui
            ;;
        backup-remote)
            if [ -n "$2" ]; then
                LATEST_BACKUP=$(ls -t /opt/3xui/backups/3xui-backup-*.tar.gz 2>/dev/null | head -1)
                backup_remote "$LATEST_BACKUP" "$2" "/backups"
            else
                echo "Укажите удаленный хост"
            fi
            ;;
        restore)
            if [ -n "$2" ]; then
                restore_backup "$2"
            else
                echo "Укажите файл резервной копии"
            fi
            ;;
        health)
            check_system_health
            ;;
        status)
            check_service_status
            ;;
        ports)
            check_ports
            ;;
        stats)
            show_statistics
            ;;
        logs)
            show_docker_logs
            ;;
        monitor)
            check_system_health
            check_service_status
            check_ports
            show_statistics
            show_docker_logs
            ;;
        update-certs)
            update_certificates
            ;;
        restart)
            restart_services
            ;;
        optimize)
            optimize_system
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "Неизвестная команда: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
