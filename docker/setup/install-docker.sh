#!/usr/bin/env bash
#
# install-docker.sh
# Instala o Docker Engine e o plugin do Compose a partir do repositório
# oficial da Docker no Ubuntu 24.04, configura o uso sem sudo e valida.
#
# Uso: bash install-docker.sh   (rodar como usuário normal, NÃO com sudo)
# Autor: Leonardo
# Alvo: Ubuntu Server 24.04 (ThinkCentre M900)

set -euo pipefail

# Cores para as mensagens de progresso
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
SEM_COR='\033[0m'

log()  { echo -e "${VERDE}[OK]${SEM_COR} $1"; }
info() { echo -e "${AMARELO}[..]${SEM_COR} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${SEM_COR} $1"; }

# Descobre o usuário alvo (funciona rodando direto ou via sudo)
USUARIO_ALVO="${SUDO_USER:-$(whoami)}"

# Bloqueia execução como root direto, pois o usermod precisa do usuário real
if [ "$USUARIO_ALVO" = "root" ]; then
  erro "Rode este script como seu usuário normal (leonardo), não como root."
  exit 1
fi

echo "==============================================="
echo " Instalação do Docker Engine + Compose"
echo " Usuário alvo para acesso sem sudo: $USUARIO_ALVO"
echo "==============================================="

# Se o Docker já estiver instalado, apenas informa e segue para a validação
if command -v docker >/dev/null 2>&1; then
  info "Docker já está instalado. Pulando a instalação e indo para a validação."
else
  # Passo 1: dependências e chave GPG oficial da Docker
  info "Instalando dependências e a chave oficial da Docker..."
  sudo apt update
  sudo apt install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  log "Chave GPG da Docker instalada."

  # Passo 2: adiciona o repositório oficial da Docker
  info "Configurando o repositório oficial da Docker..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  log "Repositório configurado."

  # Passo 3: instala o Docker Engine, CLI, containerd e o plugin do Compose
  info "Instalando o Docker Engine e o plugin do Compose..."
  sudo apt update
  sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
  log "Docker Engine e Compose instalados."
fi

# Passo 4: adiciona o usuário ao grupo docker (uso sem sudo)
if id -nG "$USUARIO_ALVO" | grep -qw docker; then
  log "Usuário $USUARIO_ALVO já está no grupo docker."
else
  info "Adicionando $USUARIO_ALVO ao grupo docker..."
  sudo usermod -aG docker "$USUARIO_ALVO"
  log "Usuário adicionado ao grupo docker."
fi

# Passo 5: garante que o serviço sobe no boot e está ativo agora
info "Habilitando e iniciando o serviço do Docker..."
sudo systemctl enable --now docker >/dev/null 2>&1
log "Serviço do Docker ativo e habilitado no boot."

# Passo 6: validação (usa sudo pois o grupo novo só vale após novo login)
echo "==============================================="
info "Validando a instalação..."
echo "Versão do Docker:  $(docker --version)"
echo "Versão do Compose: $(docker compose version)"
info "Rodando o container de teste hello-world..."
if sudo docker run --rm hello-world >/dev/null 2>&1; then
  log "Container de teste rodou com sucesso."
else
  erro "O container de teste falhou. Verifique a conexão e o serviço do Docker."
  exit 1
fi

echo "==============================================="
log "Docker instalado e funcionando."
echo ""
echo -e "${AMARELO}IMPORTANTE:${SEM_COR} o acesso ao Docker sem sudo só passa a valer"
echo "em uma nova sessão. Faça logout e login de novo no SSH, ou rode:"
echo ""
echo "    newgrp docker"
echo ""
echo "Depois teste sem sudo com: docker run --rm hello-world"
echo "==============================================="
