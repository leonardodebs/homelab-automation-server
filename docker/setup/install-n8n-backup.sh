#!/usr/bin/env bash
#
# install-n8n-backup.sh
# Instala e agenda o backup diário do PostgreSQL do n8n.
# Faz tudo: instala o pigz, grava o script de backup, roda um teste
# e configura o systemd timer para rodar todo dia às 02h00.
#
# Uso: bash install-n8n-backup.sh   (rodar como usuário normal, NÃO com sudo)
# Autor: Leonardo

set -euo pipefail

# Cores
VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; SEM_COR='\033[0m'
log()  { echo -e "${VERDE}[OK]${SEM_COR} $1"; }
info() { echo -e "${AMARELO}[..]${SEM_COR} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${SEM_COR} $1"; }

# Usuário alvo (funciona rodando direto ou via sudo)
USUARIO_ALVO="${SUDO_USER:-$(whoami)}"
if [ "$USUARIO_ALVO" = "root" ]; then
  erro "Rode como seu usuário normal (leonardo), não como root."
  exit 1
fi
HOME_DIR=$(getent passwd "$USUARIO_ALVO" | cut -d: -f6)
DIR_BACKUP="${HOME_DIR}/n8n-backup"
SCRIPT_BACKUP="${DIR_BACKUP}/backup-n8n.sh"

echo "==============================================="
echo " Instalação do backup automático do n8n"
echo " Usuário: $USUARIO_ALVO"
echo " Diretório: $DIR_BACKUP"
echo "==============================================="

# ============================================================
# Passo 1: instalar o pigz (compressão paralela)
# ============================================================
if command -v pigz >/dev/null 2>&1; then
  log "pigz já está instalado."
else
  info "Instalando o pigz..."
  sudo apt update
  sudo apt install -y pigz
  log "pigz instalado."
fi

# ============================================================
# Passo 2: gravar o script de backup
# ============================================================
info "Gravando o script de backup em ${SCRIPT_BACKUP}..."
mkdir -p "$DIR_BACKUP"
cat > "$SCRIPT_BACKUP" <<'SCRIPT_EOF'
#!/usr/bin/env bash
#
# backup-n8n.sh
# Backup do banco PostgreSQL do n8n, com compressão pigz, escrita atômica,
# verificação prévia de espaço em disco e retenção automática.

set -euo pipefail

# Configuração
CONTAINER="n8n-postgres"
DB_USER="n8n"
DB_NAME="n8n"
BACKUP_DIR="${HOME}/backups/n8n"
RETENCAO_DIAS=7
ESPACO_MINIMO_MB=500
LOG_FILE="${BACKUP_DIR}/backup.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"; }
erro() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERRO] $1" | tee -a "$LOG_FILE" >&2; }

mkdir -p "$BACKUP_DIR"
DATA=$(date '+%Y%m%d_%H%M%S')
ARQUIVO_FINAL="${BACKUP_DIR}/n8n_${DATA}.sql.gz"
ARQUIVO_TMP="${ARQUIVO_FINAL}.tmp"

log "Iniciando backup do banco '${DB_NAME}'."

# Pré-checagem: container rodando
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  erro "Container '${CONTAINER}' não está rodando. Backup abortado."
  exit 1
fi

# Pré-checagem: espaço em disco
ESPACO_LIVRE_MB=$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')
if [ "$ESPACO_LIVRE_MB" -lt "$ESPACO_MINIMO_MB" ]; then
  erro "Espaço insuficiente: ${ESPACO_LIVRE_MB} MB livres, mínimo ${ESPACO_MINIMO_MB} MB. Abortado."
  exit 1
fi

# Compressor
if command -v pigz >/dev/null 2>&1; then
  COMPRESSOR="pigz"
else
  COMPRESSOR="gzip"
  log "pigz não encontrado, usando gzip."
fi

# Dump com escrita atômica
log "Gerando dump comprimido com ${COMPRESSOR}..."
if docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | "$COMPRESSOR" > "$ARQUIVO_TMP"; then
  mv "$ARQUIVO_TMP" "$ARQUIVO_FINAL"
  TAMANHO=$(du -h "$ARQUIVO_FINAL" | cut -f1)
  log "Backup concluído: ${ARQUIVO_FINAL} (${TAMANHO})."
else
  erro "Falha ao gerar o dump. Removendo arquivo parcial."
  rm -f "$ARQUIVO_TMP"
  exit 1
fi

# Retenção
log "Aplicando retenção de ${RETENCAO_DIAS} dias..."
REMOVIDOS=$(find "$BACKUP_DIR" -name 'n8n_*.sql.gz' -type f -mtime +"$RETENCAO_DIAS" -print -delete | wc -l)
log "Backups antigos removidos: ${REMOVIDOS}."
log "Rotina de backup finalizada com sucesso."
exit 0
SCRIPT_EOF
chmod +x "$SCRIPT_BACKUP"
log "Script de backup gravado."

# ============================================================
# Passo 3: rodar um backup de teste
# ============================================================
info "Rodando um backup de teste..."
if bash "$SCRIPT_BACKUP"; then
  log "Backup de teste concluído. Arquivos em ${HOME_DIR}/backups/n8n/"
else
  erro "O backup de teste falhou. Verifique se o container n8n-postgres está rodando."
  exit 1
fi

# ============================================================
# Passo 4: configurar o systemd service e timer
# ============================================================
info "Configurando o systemd service e timer..."

sudo tee /etc/systemd/system/n8n-backup.service > /dev/null <<EOF
[Unit]
Description=Backup do PostgreSQL do n8n
After=docker.service

[Service]
Type=oneshot
User=${USUARIO_ALVO}
ExecStart=/usr/bin/bash ${SCRIPT_BACKUP}
EOF

sudo tee /etc/systemd/system/n8n-backup.timer > /dev/null <<'EOF'
[Unit]
Description=Executa o backup do n8n diariamente

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now n8n-backup.timer
log "Timer ativado."

# ============================================================
# Resumo
# ============================================================
echo "==============================================="
log "Backup do n8n instalado e agendado."
echo ""
info "Próxima execução agendada:"
systemctl list-timers n8n-backup.timer --no-pager || true
echo ""
echo "Comandos úteis:"
echo "  Rodar backup agora:   sudo systemctl start n8n-backup.service"
echo "  Ver logs:             journalctl -u n8n-backup.service"
echo "  Listar backups:       ls -lh ${HOME_DIR}/backups/n8n/"
echo "==============================================="
