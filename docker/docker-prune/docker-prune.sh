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
