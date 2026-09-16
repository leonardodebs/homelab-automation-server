#!/usr/bin/env bash

# ============================================================
# MOTD dinâmico — Lenovo Automation Server
# Leonardo Debs
#
# Instalado em /etc/update-motd.d/01-lenovo-automation, roda a
# cada login SSH. Mostra o estado dos serviços em Docker e,
# quando o cluster k3s está no ar, também os workloads de lá
# (JobOps, Finance).
# ============================================================

export LC_ALL=C.UTF-8

RESET='\033[0m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'

INNER_WIDTH=74

# ------------------------------------------------------------
# Funções visuais
# ------------------------------------------------------------

repeat_character() {
    local character="$1"
    local amount="$2"
    local result=""

    printf -v result '%*s' "$amount" ''
    printf '%s' "${result// /$character}"
}

border_top() {
    printf "${CYAN}┌"
    repeat_character "─" "$INNER_WIDTH"
    printf "┐${RESET}\n"
}

border_middle() {
    printf "${CYAN}├"
    repeat_character "─" "$INNER_WIDTH"
    printf "┤${RESET}\n"
}

border_bottom() {
    printf "${CYAN}└"
    repeat_character "─" "$INNER_WIDTH"
    printf "┘${RESET}\n"
}

line() {
    local text="$1"
    local text_length="${#text}"
    local padding=$((INNER_WIDTH - text_length - 1))

    [ "$padding" -lt 0 ] && padding=0

    printf "${CYAN}│${RESET} %s%*s${CYAN}│${RESET}\n" \
        "$text" "$padding" ""
}

header_line() {
    local text="LD / LENOVO AUTOMATION SERVER ONLINE"
    local text_length="${#text}"
    local left_padding=$(((INNER_WIDTH - text_length) / 2))
    local right_padding=$((INNER_WIDTH - text_length - left_padding))

    printf "${CYAN}│${RESET}"
    printf '%*s' "$left_padding" ""
    printf "${YELLOW}%s${RESET}" "$text"
    printf '%*s' "$right_padding" ""
    printf "${CYAN}│${RESET}\n"
}

# ------------------------------------------------------------
# Informações do sistema
# ------------------------------------------------------------

HOST="$(hostname)"

IP="$(
    ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{
        for (i=1; i<=NF; i++) {
            if ($i == "src") {
                print $(i+1)
                exit
            }
        }
    }'
)"

if [ -z "$IP" ]; then
    IP="$(hostname -I | awk '{print $1}')"
fi

# ------------------------------------------------------------
# Uptime
# ------------------------------------------------------------

UP_SECONDS="$(cut -d. -f1 /proc/uptime)"

UP_DAYS=$((UP_SECONDS / 86400))
UP_HOURS=$(((UP_SECONDS % 86400) / 3600))
UP_MINUTES=$(((UP_SECONDS % 3600) / 60))

if [ "$UP_DAYS" -gt 0 ]; then
    UPTIME="${UP_DAYS}d ${UP_HOURS}h ${UP_MINUTES}min"
else
    UPTIME="${UP_HOURS}h ${UP_MINUTES}min"
fi

# ------------------------------------------------------------
# Uso de CPU
# ------------------------------------------------------------

read -r _ u1 n1 s1 i1 w1 irq1 sirq1 steal1 _ < /proc/stat

TOTAL1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + steal1))
IDLE1=$((i1 + w1))

sleep 0.15

read -r _ u2 n2 s2 i2 w2 irq2 sirq2 steal2 _ < /proc/stat

TOTAL2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + steal2))
IDLE2=$((i2 + w2))

CPU="$(
    awk \
        -v total="$((TOTAL2 - TOTAL1))" \
        -v idle="$((IDLE2 - IDLE1))" \
        'BEGIN {
            if (total > 0) {
                printf "%.1f", (total-idle)*100/total
            } else {
                printf "0.0"
            }
        }'
)"

# ------------------------------------------------------------
# Memória, disco e carga
# ------------------------------------------------------------

RAM="$(
    free |
    awk '/^Mem:/ {
        if ($2 > 0) {
            printf "%.0f", $3*100/$2
        } else {
            printf "0"
        }
    }'
)"

DISK="$(
    df -P / |
    awk 'NR == 2 {
        gsub("%", "", $5)
        print $5
    }'
)"

LOAD="$(
    awk '{
        print $1", "$2", "$3
    }' /proc/loadavg
)"

# ------------------------------------------------------------
# Temperatura real do processador
# Prioriza x86_pkg_temp em vez dos sensores ACPI
# ------------------------------------------------------------

TEMP="N/D"

for TEMP_ZONE in /sys/class/thermal/thermal_zone*; do
    [ -r "$TEMP_ZONE/type" ] || continue
    [ -r "$TEMP_ZONE/temp" ] || continue

    SENSOR_TYPE="$(cat "$TEMP_ZONE/type")"

    if [ "$SENSOR_TYPE" = "x86_pkg_temp" ]; then
        TEMP_RAW="$(cat "$TEMP_ZONE/temp")"

        if [[ "$TEMP_RAW" =~ ^[0-9]+$ ]]; then
            TEMP="$(
                awk -v value="$TEMP_RAW" \
                    'BEGIN {
                        printf "%.0f°C", value/1000
                    }'
            )"
        fi

        break
    fi
done

# Alternativa usando lm-sensors
if [ "$TEMP" = "N/D" ] &&
   command -v sensors >/dev/null 2>&1; then

    TEMP="$(
        sensors 2>/dev/null |
        awk '/Package id 0:/ {
            gsub(/^\+/, "", $4)
            print $4
            exit
        }'
    )"
fi

# ------------------------------------------------------------
# Informações do Docker
# ------------------------------------------------------------

DOCKER_AVAILABLE=false
DOCKER_RUNNING=0
DOCKER_HEALTHY=0
DOCKER_UNHEALTHY=0

if command -v docker >/dev/null 2>&1 &&
   docker info >/dev/null 2>&1; then

    DOCKER_AVAILABLE=true

    DOCKER_RUNNING="$(
        docker ps -q 2>/dev/null |
        awk 'END {print NR}'
    )"

    DOCKER_HEALTHY="$(
        docker ps \
            --filter health=healthy \
            -q 2>/dev/null |
        awk 'END {print NR}'
    )"

    DOCKER_UNHEALTHY="$(
        docker ps \
            --filter health=unhealthy \
            -q 2>/dev/null |
        awk 'END {print NR}'
    )"
fi

# ------------------------------------------------------------
# Estado dos deployments no k3s (JobOps, Finance)
# Timeout curto para não travar o login se a API estiver lenta.
# ------------------------------------------------------------

K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
K3S_AVAILABLE=false
declare -A K3S_READY
K3S_PODS_RUNNING=0
K3S_PODS_TOTAL=0

if command -v kubectl >/dev/null 2>&1 &&
   [ -r "$K3S_KUBECONFIG" ]; then

    if KUBECONFIG="$K3S_KUBECONFIG" timeout 2 kubectl get --raw=/healthz \
        >/dev/null 2>&1; then

        K3S_AVAILABLE=true
    fi
fi

if [ "$K3S_AVAILABLE" = true ]; then
    while IFS='=' read -r deploy_key ready; do
        [ -n "$deploy_key" ] && K3S_READY["$deploy_key"]="${ready:-0}"
    done < <(
        KUBECONFIG="$K3S_KUBECONFIG" timeout 2 kubectl get deploy -A \
            -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.status.availableReplicas}{"\n"}{end}' \
            2>/dev/null
    )

    read -r K3S_PODS_RUNNING K3S_PODS_TOTAL < <(
        KUBECONFIG="$K3S_KUBECONFIG" timeout 2 kubectl get pods -A \
            --field-selector=status.phase!=Succeeded \
            --no-headers 2>/dev/null |
        awk '{
            total++
            if ($4 ~ /Running|Completed/) running++
        }
        END {
            print (running+0), (total+0)
        }'
    )
fi

k3s_deployment_ready() {
    local key="$1"
    local value="${K3S_READY[$key]:-0}"

    [ "${value:-0}" -ge 1 ] 2>/dev/null
}

# ------------------------------------------------------------
# Estado individual dos serviços
# ------------------------------------------------------------

container_is_running() {
    local container="$1"

    [ "$DOCKER_AVAILABLE" = true ] &&
    docker ps \
        --filter "name=^/${container}$" \
        --filter status=running \
        --format '{{.Names}}' 2>/dev/null |
    grep -Fxq "$container"
}

render_service_line() {
    local name="$1"
    local is_online="$2"
    local url="$3"
    local status
    local status_color
    local prefix
    local suffix
    local visible_length
    local padding

    if [ "$is_online" = true ]; then
        status="ONLINE "
        status_color="$GREEN"
    else
        status="OFFLINE"
        status_color="$RED"
    fi

    printf -v prefix ' %-13s [' "$name"
    printf -v suffix '] %s' "$url"

    visible_length=$((
        ${#prefix} +
        ${#status} +
        ${#suffix}
    ))

    padding=$((INNER_WIDTH - visible_length))

    [ "$padding" -lt 0 ] && padding=0

    printf "${CYAN}│${RESET}%s" "$prefix"
    printf "${status_color}%s${RESET}" "$status"
    printf '%s%*s' "$suffix" "$padding" ""
    printf "${CYAN}│${RESET}\n"
}

service_line() {
    local name="$1"
    local container="$2"
    local url="$3"

    if container_is_running "$container"; then
        render_service_line "$name" true "$url"
    else
        render_service_line "$name" false "$url"
    fi
}

service_line_k3s() {
    local name="$1"
    local deploy_key="$2"
    local url="$3"

    if [ "$K3S_AVAILABLE" = true ] && k3s_deployment_ready "$deploy_key"; then
        render_service_line "$name" true "$url"
    else
        render_service_line "$name" false "$url"
    fi
}

# ------------------------------------------------------------
# Exibição do painel
# ------------------------------------------------------------

echo

border_top
header_line
border_middle

line "Host     : ${HOST} - Lenovo ThinkCentre"
line "IP       : ${IP}"
line "Uptime   : ${UPTIME}"
line "CPU      : ${CPU}%     RAM: ${RAM}%     DISCO: ${DISK}%"
line "Carga    : ${LOAD}     TEMP: ${TEMP}"

border_middle

service_line \
    "OpenClaw" \
    "openclaw-lab" \
    "https://${IP}"

service_line \
    "n8n" \
    "n8n" \
    "https://${IP}:5678"

service_line \
    "Grafana" \
    "grafana" \
    "https://${IP}:3000"

service_line \
    "Prometheus" \
    "prometheus" \
    "https://${IP}:9090"

service_line \
    "Portainer" \
    "portainer" \
    "https://${IP}:9443"

border_middle

# JobOps e Finance rodam no k3s (não são containers Docker soltos),
# por isso o status vem do deployment, não do "docker ps".

service_line_k3s \
    "JobOps Web" \
    "jobops/web" \
    "http://${IP}:30808"

service_line_k3s \
    "JobOps API" \
    "jobops/api" \
    "http://${IP}:30800/docs"

service_line_k3s \
    "Finance Web" \
    "finance/finance-web" \
    "http://${IP}/"

border_middle

line \
    "Docker   : ${DOCKER_RUNNING} ativos | ${DOCKER_HEALTHY} saudáveis | ${DOCKER_UNHEALTHY} falhando"

if [ "$K3S_AVAILABLE" = true ]; then
    line \
        "k3s      : ${K3S_PODS_RUNNING}/${K3S_PODS_TOTAL} pods no ar"
else
    line \
        "k3s      : indisponível"
fi

line \
    "Internos : Caddy x4 | PostgreSQL | Redis | InfluxDB | Exporters"

line \
    "GitHub   : github.com/leonardodebs"

border_bottom

echo
