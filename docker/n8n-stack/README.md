<div align="center">

# 🔄 n8n-stack

**Ambiente de automação com n8n e PostgreSQL em Docker Compose, para homelab em rede local**

[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docker.com)
[![n8n](https://img.shields.io/badge/n8n-automation-EA4B71?logo=n8n)](https://n8n.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql)](https://postgresql.org)

</div>

---

## 📋 Sobre o Projeto

Stack de automação para rodar o n8n com persistência em PostgreSQL, empacotada em Docker Compose para subir com um comando. Foi montada para um homelab em um Lenovo ThinkCentre M900 com Ubuntu Server, com acesso restrito à rede local.

O n8n é uma plataforma de automação de fluxos de trabalho (workflows), semelhante ao Zapier ou Make, mas self-hosted. Por padrão o n8n guarda os dados em SQLite. Aqui ele usa PostgreSQL como banco, o que dá mais robustez e permite backup e restauração no mesmo padrão de qualquer base Postgres.

Projeto de infraestrutura pessoal, voltado a estudo e uso próprio, não a produção com múltiplos usuários.

## 🏗️ Arquitetura

```
                Rede local 192.168.100.0/24
                          │
                          ▼
              ┌───────────────────────┐
              │  Host: Ubuntu Server  │
              │   (ThinkCentre M900)  │
              │                       │
              │   ┌───────────────┐   │
   :5678 ─────┼──▶│   n8n         │   │
   (browser)  │   │  (workflows)  │   │
              │   └───────┬───────┘   │
              │           │ rede      │
              │           │ interna   │
              │           ▼           │
              │   ┌───────────────┐   │
              │   │  PostgreSQL 16│   │
              │   │  (dados n8n)  │   │
              │   └───────────────┘   │
              │                       │
              │  Volumes persistentes │
              └───────────────────────┘
```

**Componentes principais:**

| Componente | Tecnologia | Responsabilidade |
|-----------|-----------|-----------------|
| n8n | n8n (imagem oficial) | Motor de automação, interface web na porta 5678 |
| Banco | PostgreSQL 16 Alpine | Persistência dos workflows e credenciais do n8n |
| Rede | Docker bridge (n8n-net) | Comunicação interna entre n8n e Postgres |
| Volumes | Docker named volumes | Dados do Postgres e do n8n sobrevivem a reinícios |

Somente a porta 5678 (n8n) é exposta ao host. O PostgreSQL fica acessível apenas na rede interna do Compose, não exposto à rede local, por segurança.

## 🛠️ Stack Técnica

| Categoria | Tecnologia | Versão |
|-----------|-----------|--------|
| Orquestração | Docker Compose | v2 (plugin) |
| Automação | n8n | latest |
| Banco de dados | PostgreSQL | 16-alpine |
| Host | Ubuntu Server | 24.04 LTS |

## 🚀 Como Usar

### Pré-requisitos

```bash
# Docker Engine e o plugin do Compose instalados
docker --version
docker compose version
```

### Instalação e Configuração

```bash
# 1. Clonar ou copiar este diretório para o servidor
cd n8n-stack

# 2. Criar o arquivo de segredos a partir do modelo
cp .env.example .env

# 3. Editar o .env e definir senhas fortes
#    Gere valores com:
#      openssl rand -base64 24   (senha do Postgres)
#      openssl rand -hex 24      (chave de criptografia do n8n)
nano .env

# 4. Subir o stack em segundo plano
docker compose up -d

# 5. Acompanhar os logs na primeira subida (opcional)
docker compose logs -f
```

### Acesso

Abra no navegador de qualquer máquina da rede local:

```
http://192.168.100.3:5678
```

No primeiro acesso, o n8n pede para criar a conta de dono (owner). Esse é o login de administrador do seu n8n. A partir daí você cria os workflows.

### Variáveis de Ambiente

| Variável | Descrição | Obrigatório |
|---------|-----------|-------------|
| POSTGRES_USER | Usuário do banco PostgreSQL | Sim |
| POSTGRES_PASSWORD | Senha do banco (use valor forte) | Sim |
| POSTGRES_DB | Nome do banco de dados | Sim |
| N8N_HOST | IP do servidor na rede local | Sim |
| N8N_ENCRYPTION_KEY | Chave que criptografa as credenciais dos workflows | Sim |

## 📁 Estrutura do Projeto

```
n8n-stack/
├── docker-compose.yml   # Definição dos serviços n8n e postgres
├── .env.example         # Modelo de configuração (versionado)
├── .env                 # Segredos reais (NÃO versionado)
├── .gitignore           # Garante que o .env fique fora do Git
└── README.md            # Este arquivo
```

## 🔧 Operação

```bash
# Ver status dos containers
docker compose ps

# Parar o stack (mantém os dados)
docker compose down

# Parar e apagar os dados (cuidado, remove os volumes)
docker compose down -v

# Atualizar as imagens para a versão mais recente
docker compose pull && docker compose up -d
```

### Backup do banco

```bash
# Gera um dump do banco do n8n
docker exec n8n-postgres pg_dump -U n8n n8n > backup_n8n_$(date +%Y%m%d).sql
```

## ⚠️ Avisos de Segurança

- O arquivo `.env` contém senhas e a chave de criptografia. Ele está no `.gitignore` e nunca deve ser enviado ao Git.
- Guarde a `N8N_ENCRYPTION_KEY` em local seguro (KeePass). Sem ela, as credenciais salvas nos workflows ficam ilegíveis após uma restauração.
- Esta configuração usa http e cookie não seguro por rodar apenas na rede local. Não exponha a porta 5678 à internet sem colocar HTTPS e autenticação na frente.

## 🔄 Roadmap

- [ ] Adicionar Portainer para gestão visual dos containers
- [ ] Rotina de backup automático do Postgres com pigz
- [ ] Migrar para VM ou LXC quando o host virar Proxmox

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
