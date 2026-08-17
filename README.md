<div align="center">

# 🖥️ homelab-automation-server

**Servidor de automação do homelab: Ubuntu, Docker e n8n em um Lenovo ThinkCentre M900**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docker.com)
[![n8n](https://img.shields.io/badge/n8n-automation-EA4B71?logo=n8n)](https://n8n.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql)](https://postgresql.org)

</div>

---

## 📋 Sobre

Registro de configuração e infraestrutura como código do meu servidor de automação, um Lenovo ThinkCentre M900 rodando Ubuntu Server. Toda a configuração fica versionada aqui, do hardening inicial aos serviços em Docker, para eu conseguir reconstruir a máquina do zero ou migrar para outra base (Proxmox) sem perder nada.

É um repositório pessoal, de registro e portfólio. Documenta decisões, comandos e a estrutura que roda na máquina.

Repositório par: [homelab-infrastructure-server](https://github.com/leonardodebs/homelab-infrastructure-server) (Dell Wyse 3290, AdGuard Home e Unbound).

## 🖥️ Hardware

| Item | Especificação |
|------|---------------|
| Máquina | Lenovo ThinkCentre M900 (10FLS44U00) |
| CPU | Intel Skylake 4 núcleos (CPU ID 506E3) |
| RAM | 16 GB |
| Disco | SSD 240 GB |
| Rede | Ethernet Intel (eno1), IP fixo 192.168.100.3 |
| SO | Ubuntu Server 24.04 LTS |

## 🏗️ Arquitetura

```
                    Rede local 192.168.100.0/24
                              │
                              ▼
   ┌───────────────────────────────────────────────────────────┐
   │  Lenovo ThinkCentre M900                                   │
   │  Ubuntu Server 24.04  (192.168.100.3)                      │
   │  Segurança: UFW, fail2ban, SSH hardening                   │
   │                                                           │
   │  Serviços:                                                │
   │  ┌─────────────┐   ┌──────────────────┐                    │
   │  │  Portainer  │   │  n8n (automação) │                    │
   │  │   :9443     │   │      :5678       │                    │
   │  └─────────────┘   └────────┬─────────┘                    │
   │                             ▼                              │
   │                    ┌──────────────────┐   Backup diário    │
   │                    │  PostgreSQL 16   │──▶ pigz, 7 dias,    │
   │                    │  (dados do n8n)  │   systemd timer     │
   │                    └────────┬─────────┘                    │
   │                             │ (exporters)                  │
   │  Observabilidade:           ▼                              │
   │  ┌────────────────────────────────────────┐               │
   │  │ node_exporter, cAdvisor, postgres_exp.  │               │
   │  └──────────────────┬─────────────────────┘               │
   │                     ▼                                      │
   │        ┌────────────────┐      ┌──────────────┐            │
   │        │  Prometheus    │─────▶│   Grafana    │            │
   │        │    :9090       │      │    :3000     │            │
   │        └────────────────┘      └──────────────┘            │
   └───────────────────────────────────────────────────────────┘
```

## 🛠️ Stack

| Camada | Tecnologia |
|--------|-----------|
| Sistema | Ubuntu Server 24.04 LTS |
| Runtime | Docker Engine, Docker Compose v2 |
| Automação | n8n (Community Edition) |
| Banco | PostgreSQL 16 |
| Gerência | Portainer CE |
| Observabilidade | Prometheus, Grafana, node_exporter, cAdvisor, postgres_exporter |
| Backup | Bash, pigz, systemd timer |
| Segurança | UFW, fail2ban, unattended-upgrades |

## 📁 Estrutura

```
homelab-automation-server/
├── CHANGELOG.md         # Histórico de mudanças
├── docker/
│   ├── setup/           # Scripts de provisionamento (rodar primeiro)
│   │   ├── harden-server.sh      # Segurança: UFW, fail2ban, SSH, timezone
│   │   ├── install-docker.sh     # Docker Engine e Compose
│   │   └── install-n8n-backup.sh # Backup do n8n com systemd timer
│   ├── n8n-stack/       # n8n + PostgreSQL (Compose)
│   ├── n8n-backup/      # Script de backup do banco
│   ├── portainer/       # Gerência visual dos containers
│   └── monitoring/      # Prometheus + Grafana + exporters
└── docs/                # Documentação do servidor e decisões
```

## 🚀 Reconstruir do zero

Ordem completa para provisionar a máquina em uma instalação limpa do Ubuntu Server:

```bash
# 1. Clonar o repositório
git clone https://github.com/leonardodebs/homelab-automation-server.git
cd homelab-automation-server/docker

# 2. Hardening da base (segurança)
bash setup/harden-server.sh

# 3. Docker
bash setup/install-docker.sh
# fazer logout e login para o grupo docker valer

# 4. Configurar segredos do n8n
cd n8n-stack
cp .env.example .env
nano .env   # definir senhas fortes

# 5. Subir os serviços
docker compose up -d
cd ../portainer && docker compose up -d

# 6. Agendar o backup diário
cd ../setup
bash install-n8n-backup.sh

# 7. Subir o monitoramento (Prometheus + Grafana)
cd ../monitoring
bash setup-monitoring.sh
```

## 🔒 Segurança

- Segredos (arquivo `.env`) nunca são versionados, apenas os `.env.example`. As senhas reais ficam só no servidor.
- Acesso aos serviços restrito à rede local. Nada exposto à internet sem HTTPS e autenticação na frente.
- SSH com login root direto desabilitado e fail2ban barrando força bruta.

## 🔄 Roadmap

- [x] Observabilidade com Prometheus e Grafana
- [ ] Copiar backups para armazenamento externo (S3 na conta AWS pessoal)
- [ ] Migrar a máquina para Proxmox, com este stack rodando em VM ou LXC
- [ ] Adicionar pasta `proxmox/` com a configuração da nova base

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
