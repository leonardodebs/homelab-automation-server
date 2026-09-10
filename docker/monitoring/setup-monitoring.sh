#!/usr/bin/env bash
#
# setup-monitoring.sh
# Configura e sobe o stack Prometheus + Grafana + exporters.
# Lê a senha do Postgres do .env do n8n-stack, detecta a rede do Docker,
# gera as credenciais do Grafana e libera as portas no firewall.
#
# Uso: bash setup-monitoring.sh   (rodar como usuário normal, NÃO com sudo)
# Autor: Leonardo

set -euo pipefail

VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; SEM_COR='\033[0m'
log()  { echo -e "${VERDE}[OK]${SEM_COR} $1"; }
info() { echo -e "${AMARELO}[..]${SEM_COR} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${SEM_COR} $1"; }

USUARIO_ALVO="${SUDO_USER:-$(whoami)}"
if [ "$USUARIO_ALVO" = "root" ]; then
  erro "Rode como seu usuário normal, não como root."
  exit 1
fi

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR_SCRIPT"

echo "==============================================="
echo " Setup do monitoramento (Prometheus + Grafana)"
echo "==============================================="

# ============================================================
# 1: Detectar a rede do n8n-stack
# ============================================================
info "Detectando a rede do Docker onde o PostgreSQL está..."
N8N_NETWORK=$(docker network ls --format '{{.Name}}' | grep -i 'n8n' | grep -i 'net' | head -1 || true)
if [ -z "$N8N_NETWORK" ]; then
  erro "Não encontrei a rede do n8n. O n8n-stack está rodando?"
  exit 1
fi
log "Rede encontrada: ${N8N_NETWORK}"

# ============================================================
# 2: Ler a senha do Postgres do .env do n8n-stack
# ============================================================
info "Procurando a senha do Postgres..."
ENV_N8N=""
for caminho in "${HOME}/n8n-stack/.env" "../n8n-stack/.env" "${HOME}/homelab-automation-server/docker/n8n-stack/.env"; do
  if [ -f "$caminho" ]; then ENV_N8N="$caminho"; break; fi
done
if [ -n "$ENV_N8N" ]; then
  PG_PASS=$(grep -E '^POSTGRES_PASSWORD=' "$ENV_N8N" | cut -d= -f2-)
  log "Senha do Postgres lida de ${ENV_N8N}"
else
  info "Digite a senha do Postgres do n8n:"
  read -rs PG_PASS; echo ""
fi
if [ -z "$PG_PASS" ]; then erro "Senha do Postgres vazia. Abortado."; exit 1; fi

# ============================================================
# 3: Gerar credenciais do Grafana e o arquivo .env
# ============================================================
if [ -f .env ]; then
  info "Arquivo .env já existe, mantendo as credenciais atuais."
  # shellcheck disable=SC1091
  source .env
  GRAF_USER="${GRAFANA_USER:-admin}"
  GRAF_PASS="${GRAFANA_PASSWORD}"
else
  info "Gerando credenciais do Grafana..."
  GRAF_USER="admin"
  GRAF_PASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
fi

cat > .env <<EOF
# Rede do n8n-stack (detectada automaticamente)
N8N_NETWORK=${N8N_NETWORK}

# Senha do Postgres (para o postgres-exporter)
POSTGRES_PASSWORD=${PG_PASS}

# Credenciais de acesso ao Grafana
GRAFANA_USER=${GRAF_USER}
GRAFANA_PASSWORD=${GRAF_PASS}
EOF
log "Arquivo .env gravado."

# ============================================================
# 4: Liberar as portas no firewall
# ============================================================
info "Liberando as portas 3000 (Grafana) e 9090 (Prometheus)..."
sudo ufw allow 3000/tcp comment 'grafana (via monitoring-caddy)' >/dev/null 2>&1 || true
sudo ufw allow 9090/tcp comment 'prometheus (via monitoring-caddy)' >/dev/null 2>&1 || true
log "Portas liberadas."

# ============================================================
# 5: Subir o stack
# ============================================================
info "Subindo o stack (pode levar um ou dois minutos na primeira vez)..."
docker compose up -d
log "Stack no ar."

echo "==============================================="
log "Monitoramento instalado."
echo ""
echo "Grafana:     https://192.168.15.3:3000   (Caddy tls internal)"
echo "  usuário:   ${GRAF_USER}"
echo "  senha:     ${GRAF_PASS}"
echo ""
echo "Prometheus:  https://192.168.15.3:9090   (Caddy tls internal)"
echo ""
echo "Importe a CA do monitoring-caddy uma vez para o navegador parar de avisar:"
echo "  docker exec monitoring-caddy cat /data/caddy/pki/authorities/local/root.crt"
echo ""
echo "Os dashboards 'Homelab Lenovo Overview' e 'Rede (ntopng)' já vêm provisionados no Grafana."
echo "Guarde a senha do Grafana no KeePass."
echo "==============================================="
