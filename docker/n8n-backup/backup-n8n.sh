#!/usr/bin/env bash
#
# backup-n8n.sh
# Backup do banco PostgreSQL do n8n, com compressão pigz, escrita atômica,
# verificação prévia de espaço em disco e retenção automática.
#
# Uso: bash backup-n8n.sh
# Agendamento: ver README.md (cron ou systemd timer)
# Autor: Leonardo

set -euo pipefail

# ============================================================
# Configuração (ajuste se necessário)
# ============================================================
CONTAINER="n8n-postgres"          # nome do container do Postgres
DB_USER="n8n"                     # usuário do banco
DB_NAME="n8n"                     # nome do banco
BACKUP_DIR="${HOME}/backups/n8n"  # onde guardar os dumps
RETENCAO_DIAS=7                   # quantos dias de backup manter
ESPACO_MINIMO_MB=500              # aborta se houver menos que isto livre
LOG_FILE="${BACKUP_DIR}/backup.log"

# ============================================================
# Funções de log
# ============================================================
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}
erro() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERRO] $1" | tee -a "$LOG_FILE" >&2
}

# ============================================================
# Preparação
# ============================================================
mkdir -p "$BACKUP_DIR"

DATA=$(date '+%Y%m%d_%H%M%S')
ARQUIVO_FINAL="${BACKUP_DIR}/n8n_${DATA}.sql.gz"
ARQUIVO_TMP="${ARQUIVO_FINAL}.tmp"   # escrita atômica: grava no .tmp e renomeia no fim

log "Iniciando backup do banco '${DB_NAME}'."

# ============================================================
# Pré-checagem 1: o container está rodando?
# ============================================================
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  erro "Container '${CONTAINER}' não está rodando. Backup abortado."
  exit 1
fi

# ============================================================
# Pré-checagem 2: há espaço em disco suficiente?
# ============================================================
ESPACO_LIVRE_MB=$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')
if [ "$ESPACO_LIVRE_MB" -lt "$ESPACO_MINIMO_MB" ]; then
  erro "Espaço insuficiente: ${ESPACO_LIVRE_MB} MB livres, mínimo ${ESPACO_MINIMO_MB} MB. Backup abortado."
  exit 1
fi

# ============================================================
# Verifica se o pigz está disponível, senão usa gzip
# ============================================================
if command -v pigz >/dev/null 2>&1; then
  COMPRESSOR="pigz"
else
  COMPRESSOR="gzip"
  log "pigz não encontrado, usando gzip (mais lento). Instale pigz para compressão paralela."
fi

# ============================================================
# Dump com compressão e escrita atômica
# pipefail garante que uma falha no pg_dump derrube o pipe inteiro
# ============================================================
log "Gerando dump comprimido com ${COMPRESSOR}..."
if docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | "$COMPRESSOR" > "$ARQUIVO_TMP"; then
  # Só renomeia para o nome final se o dump terminou sem erro
  mv "$ARQUIVO_TMP" "$ARQUIVO_FINAL"
  TAMANHO=$(du -h "$ARQUIVO_FINAL" | cut -f1)
  log "Backup concluído: ${ARQUIVO_FINAL} (${TAMANHO})."
else
  erro "Falha ao gerar o dump. Removendo arquivo parcial."
  rm -f "$ARQUIVO_TMP"
  exit 1
fi

# ============================================================
# Retenção: apaga backups mais antigos que RETENCAO_DIAS
# ============================================================
log "Aplicando retenção de ${RETENCAO_DIAS} dias..."
REMOVIDOS=$(find "$BACKUP_DIR" -name 'n8n_*.sql.gz' -type f -mtime +"$RETENCAO_DIAS" -print -delete | wc -l)
log "Backups antigos removidos: ${REMOVIDOS}."

log "Rotina de backup finalizada com sucesso."
exit 0
