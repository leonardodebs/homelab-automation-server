# Changelog

Todas as mudanças notáveis deste servidor serão documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).

---

## [1.0.0] - 2026-08-14

Primeira versão. Servidor montado do zero, de uma instalação limpa do Ubuntu até um ambiente completo de automação e observabilidade.

### Adicionado

- Base do sistema: IP fixo no cabo (192.168.100.3), kernel atualizado, disco expandido para 232 GB
- Script de hardening (`harden-server.sh`): timezone, unattended-upgrades, UFW, fail2ban, SSH
- Script de instalação do Docker Engine e Compose (`install-docker.sh`)
- Stack n8n com PostgreSQL como banco (`n8n-stack/`)
- Portainer para gerência visual dos containers (`portainer/`)
- Backup diário do PostgreSQL com pigz, escrita atômica e retenção de 7 dias (`n8n-backup/`)
- Instalador do backup com systemd timer (`install-n8n-backup.sh`)
- Stack de observabilidade Prometheus e Grafana com três exporters (`monitoring/`)
- Dashboard "Homelab Overview" provisionado como código, cobrindo servidor, containers e PostgreSQL
- Documentação do servidor e registro de decisões (`docs/`)

### Segurança

- Login root direto via SSH desabilitado
- fail2ban protegendo o SSH contra força bruta
- Placa Wi-Fi Intel desabilitada (blacklist do iwlwifi) por crash de firmware
- Segredos mantidos fora do Git, apenas arquivos `.env.example` versionados

### Removido

- Netdata: avaliado como opção de monitoramento, substituído pelo stack Prometheus e Grafana
