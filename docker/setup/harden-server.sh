#!/usr/bin/env bash
#
# harden-server.sh
# Aplica a base de segurança do servidor: timezone, atualizações automáticas,
# firewall UFW, fail2ban e hardening do SSH.
# Idempotente: pode rodar mais de uma vez sem quebrar.
#
# Uso: bash harden-server.sh   (rodar como usuário normal, NÃO com sudo)
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

echo "==============================================="
echo " Hardening do servidor"
echo "==============================================="

# ============================================================
# 1: Timezone
# ============================================================
info "Ajustando o timezone para America/Sao_Paulo..."
sudo timedatectl set-timezone America/Sao_Paulo
log "Timezone: $(timedatectl show -p Timezone --value)"

# ============================================================
# 2: Atualizações de segurança automáticas
# ============================================================
info "Instalando e ativando o unattended-upgrades..."
sudo apt update
sudo apt install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
log "Atualizações automáticas de segurança ativadas."

# ============================================================
# 3: Firewall UFW
# Libera SSH primeiro para não perder a conexão ao ativar
# ============================================================
info "Configurando o firewall UFW..."
sudo ufw allow OpenSSH
sudo ufw allow 5678/tcp comment 'n8n web'
sudo ufw allow 9443/tcp comment 'portainer'
sudo ufw --force enable
log "Firewall ativo. Portas liberadas: SSH, 5678 (n8n), 9443 (portainer)."

# ============================================================
# 4: fail2ban
# ============================================================
info "Instalando e configurando o fail2ban..."
sudo apt install -y fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[sshd]
enabled = true
bantime = 1h
findtime = 10m
maxretry = 5
EOF
sudo systemctl restart fail2ban
sleep 3
log "fail2ban ativo, protegendo o SSH."

# ============================================================
# 5: Hardening do SSH
# Desliga login root direto, mantém login por senha do usuário
# ============================================================
info "Aplicando hardening do SSH..."
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<'EOF'
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
EOF
if sudo sshd -t; then
  sudo systemctl restart ssh
  log "SSH endurecido: login root direto desabilitado."
else
  erro "Configuração do SSH inválida. Nada foi aplicado ao serviço."
  exit 1
fi

echo "==============================================="
log "Hardening concluído."
echo ""
echo "Verificação rápida:"
echo "  sudo ufw status verbose"
echo "  sudo fail2ban-client status sshd"
echo "  timedatectl"
echo "==============================================="
