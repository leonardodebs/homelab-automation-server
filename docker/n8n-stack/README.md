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
                Rede local 192.168.15.0/24
                          │
                          ▼
              ┌─────────────────────────────┐
              │    Host: Ubuntu Server      │
              │     (ThinkCentre M900)      │
              │                             │
              │   ┌─────────────────────┐   │
   :5678 ─────┼──▶│ Caddy (tls internal)│   │
   (browser)  │   └──────────┬──────────┘   │
              │              │ rede interna │
              │              ▼              │
              │   ┌───────────────┐         │
              │   │   n8n         │         │
              │   │  (workflows)  │         │
              │   └───────┬───────┘         │
              │           │ rede interna     │
              │           ▼                 │
              │   ┌───────────────┐         │
              │   │  PostgreSQL 16│         │
              │   │  (dados n8n)  │         │
              │   └───────────────┘         │
              │                             │
              │  Volumes persistentes       │
              └─────────────────────────────┘
```

**Componentes principais:**

| Componente | Tecnologia | Responsabilidade |
|-----------|-----------|-----------------|
| Caddy | Caddy 2 (`tls internal`) | Termina HTTPS na porta 5678 com CA local própria, repassa para o n8n em http na rede interna |
| n8n | n8n (imagem oficial) | Motor de automação, interface web (atrás do Caddy) |
| Banco | PostgreSQL 16 Alpine | Persistência dos workflows e credenciais do n8n |
| Rede | Docker bridge (n8n-net) | Comunicação interna entre Caddy, n8n e Postgres |
| Volumes | Docker named volumes | Dados do Postgres, do n8n e a CA do Caddy sobrevivem a reinícios |

Somente a porta 5678 (Caddy, à frente do n8n) é exposta ao host. O n8n em si não publica porta própria, e o PostgreSQL fica acessível apenas na rede interna do Compose — nenhum dos dois é exposto direto à rede local.

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
https://192.168.15.3:5678
```

É https com certificado emitido por uma CA local (Caddy `tls internal`) — o navegador vai avisar até você importar essa CA como raiz confiável (veja abaixo). No primeiro acesso, o n8n pede para criar a conta de dono (owner). Esse é o login de administrador do seu n8n. A partir daí você cria os workflows.

### Confiar na CA local (elimina o aviso do navegador)

Mesmo princípio usado no Portainer (CAs diferentes, então esse import é separado do dele):

```bash
# no servidor
docker cp n8n-caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root-n8n.crt
# copiar para a máquina cliente e importar como raiz confiável
```

- **Windows (admin):** `Import-Certificate -FilePath .\caddy-root-n8n.crt -CertStoreLocation Cert:\LocalMachine\Root`
- **Firefox:** `about:preferences#privacy` → Certificados → Ver Certificados → Autoridades → Importar.
- **macOS:** Keychain Access → arrastar para "System" → "Always Trust" para SSL.
- **Linux:** copiar para `/usr/local/share/ca-certificates/` e rodar `sudo update-ca-certificates`.

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
- Acesso via https (Caddy `tls internal` na frente do n8n) com cookie seguro. Mesmo assim, não exponha a porta 5678 à internet: o certificado é de uma CA local, não uma CA pública, e não há autenticação de rede na frente.

## 🔄 Roadmap

- [ ] Adicionar Portainer para gestão visual dos containers
- [ ] Rotina de backup automático do Postgres com pigz
- [ ] Migrar para VM ou LXC quando o host virar Proxmox

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
