# Setup

Scripts de provisionamento do servidor, na ordem em que devem rodar. Todos são idempotentes e devem ser executados como usuário normal (não root), pois chamam sudo internamente onde precisam.

## Ordem de execução

### 1. Hardening da base

```bash
bash harden-server.sh
```

Aplica: timezone, atualizações automáticas de segurança, firewall UFW (libera SSH, 5678 e 9443), fail2ban e hardening do SSH (desabilita login root direto).

### 2. Docker

```bash
bash install-docker.sh
```

Instala o Docker Engine e o plugin do Compose a partir do repositório oficial, e adiciona o usuário ao grupo docker. Depois, faça logout e login para o grupo valer.

### 3. Backup do n8n

```bash
bash install-n8n-backup.sh
```

Instala o pigz, grava o script de backup, roda um teste e agenda o backup diário via systemd timer. Rode depois que o n8n-stack estiver no ar.

### 4. Limpeza automática do Docker

```bash
bash install-docker-prune.sh
```

Grava o script de limpeza, roda um teste e agenda um systemd timer semanal que remove imagens e cache de build sem uso com mais de 7 dias. Detalhes em [`../docker-prune/`](../docker-prune/).

## Depois do setup

Suba os serviços na ordem:

```bash
cd ../n8n-stack && docker compose up -d
cd ../portainer && docker compose up -d
```
