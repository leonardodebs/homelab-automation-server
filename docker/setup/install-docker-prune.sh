#!/usr/bin/env bash
#
# install-docker-prune.sh
# Instala e agenda a limpeza periódica do Docker (imagens e cache de build
# sem uso). Grava o script, roda um teste e configura um systemd timer
# semanal (domingo 04h00).
#
# Uso: bash install-docker-prune.sh   (rodar como usuário normal, NÃO com sudo)
# Autor: Leonardo

set -euo pipefail

VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; SEM_COR='\033[0m'
log()  { echo -e "${VERDE}[OK]${SEM_COR} $1"; }
info() { echo -e "${AMARELO}[..]${SEM_COR} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${SEM_COR} $1"; }

USUARIO_ALVO="${SUDO_USER:-$(whoami)}"
if [ "$USUARIO_ALVO" = "root" ]; then
  erro "Rode como seu usuário normal (leonardo), não como root."
  exit 1
fi
HOME_DIR=$(getent passwd "$USUARIO_ALVO" | cut -d: -f6)
DIR_PRUNE="${HOME_DIR}/docker-prune"
SCRIPT_PRUNE="${DIR_PRUNE}/docker-prune.sh"

if ! id -nG "$USUARIO_ALVO" | tr ' ' '\n' | grep -qx docker; then
  erro "O usuário ${USUARIO_ALVO} não está no grupo docker. Rode install-docker.sh primeiro."
  exit 1
fi

echo "==============================================="
echo " Instalação da limpeza automática do Docker"
echo " Usuário: $USUARIO_ALVO"
echo " Diretório: $DIR_PRUNE"
echo "==============================================="

# ============================================================
# Passo 1: gravar o script de limpeza
# ============================================================
info "Gravando o script em ${SCRIPT_PRUNE}..."
mkdir -p "$DIR_PRUNE"
cat > "$SCRIPT_PRUNE" <<'SCRIPT_EOF'
#!/usr/bin/env bash
#
# docker-prune.sh
# Limpeza periódica do Docker: remove imagens sem uso e cache de build
# antigos, para o disco não encher com sobras de build do CI.
#
# O que NÃO é tocado:
#   - Contêineres (rodando ou parados) e suas imagens
#   - Qualquer imagem ou camada de cache criada nos últimos RETENCAO_DIAS
#   - Volumes (nomeados ou anônimos) — ver README
#   - A registry interna localhost:5000 (k3s) — ver README
#
# Uso: bash docker-prune.sh
# Roda como usuário normal (precisa estar no grupo docker).

set -euo pipefail

RETENCAO_DIAS="${RETENCAO_DIAS:-7}"
HORAS=$(( RETENCAO_DIAS * 24 ))

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [docker-prune] $1"; }

if ! docker info >/dev/null 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [docker-prune] ERRO: sem acesso ao Docker daemon." >&2
  exit 1
fi

log "Uso de disco antes:"
docker system df

log "Removendo imagens sem uso com mais de ${RETENCAO_DIAS} dias..."
docker image prune -af --filter "until=${HORAS}h"

log "Removendo cache de build com mais de ${RETENCAO_DIAS} dias..."
docker builder prune -f --filter "until=${HORAS}h"

log "Uso de disco depois:"
docker system df

log "Concluído."
SCRIPT_EOF
chmod +x "$SCRIPT_PRUNE"
log "Script gravado."

# ============================================================
# Passo 2: rodar uma vez como teste
# ============================================================
info "Rodando uma limpeza de teste..."
if bash "$SCRIPT_PRUNE"; then
  log "Limpeza de teste concluída."
else
  erro "A limpeza de teste falhou. Verifique o acesso ao Docker."
  exit 1
fi

# ============================================================
# Passo 3: configurar o systemd service e timer
# ============================================================
info "Configurando o systemd service e timer..."

sudo tee /etc/systemd/system/docker-prune.service > /dev/null <<EOF
[Unit]
Description=Limpeza periódica do Docker (imagens e cache de build sem uso)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=${USUARIO_ALVO}
ExecStart=/usr/bin/bash ${SCRIPT_PRUNE}
EOF

sudo tee /etc/systemd/system/docker-prune.timer > /dev/null <<'EOF'
[Unit]
Description=Executa a limpeza do Docker semanalmente

[Timer]
OnCalendar=Sun *-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now docker-prune.timer
log "Timer ativado."

# ============================================================
# Resumo
# ============================================================
echo "==============================================="
log "Limpeza do Docker instalada e agendada."
echo ""
info "Próxima execução agendada:"
systemctl list-timers docker-prune.timer --no-pager || true
echo ""
echo "Comandos úteis:"
echo "  Rodar agora:   sudo systemctl start docker-prune.service"
echo "  Ver logs:      journalctl -u docker-prune.service"
echo "  Retenção:      edite RETENCAO_DIAS no topo de ${SCRIPT_PRUNE}"
echo "==============================================="
