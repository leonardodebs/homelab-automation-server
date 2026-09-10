<div align="center">

# 📈 monitoring

**Observabilidade do servidor com Prometheus, Grafana e exporters**

[![Prometheus](https://img.shields.io/badge/Prometheus-metrics-E6522C?logo=prometheus)](https://prometheus.io)
[![Grafana](https://img.shields.io/badge/Grafana-dashboards-F46800?logo=grafana)](https://grafana.com)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docker.com)

</div>

---

## 📋 Sobre

Stack de observabilidade no padrão da indústria, montado para monitorar o servidor de automação. Segue o modelo pull do Prometheus: os exporters expõem métricas, o Prometheus busca e armazena, o Grafana visualiza.

Cobre quatro camadas:

- Servidor: CPU, memória, disco, rede, load (via node_exporter)
- Containers Docker: CPU e memória por container (via cAdvisor)
- PostgreSQL: conexões, transações, disponibilidade (via postgres_exporter)
- Rede: tráfego, protocolos, alertas e anomalias, vindos do **ntopng** (rodando em outro host do homelab, `192.168.15.2`) que escreve no InfluxDB deste servidor

O Grafana já vem com os datasources e os dashboards provisionados, prontos no primeiro acesso.

## 🏗️ Arquitetura

```
   node_exporter ─┐
   cAdvisor ───────┤──▶  Prometheus ──┐        ┌─ Caddy :9090 ─┐
   postgres_exporter ┘   (:9090 int.) │        │  (tls internal)│
                                      ├─ Grafana ─ Caddy :3000 ─┼─▶ navegador
   ntopng (192.168.15.2) ──▶ InfluxDB ┘  (:3000 int.)           │   (https)
                             (:8086, recebe via rede, http)
```

O Prometheus faz scrape dos exporters a cada 15 segundos e guarda 15 dias de histórico. O InfluxDB só recebe (não faz scrape): o ntopng do outro servidor escreve direto nele pela rede. O Grafana lê os dois e desenha os painéis.

Grafana e Prometheus ficam só na rede interna do Docker; um Caddy dedicado (`monitoring-caddy`, `tls internal`) termina o HTTPS nas portas 3000 e 9090. O InfluxDB continua em http porque quem fala com ele é o ntopng (máquina-a-máquina), não o navegador.

## 🛠️ Componentes

| Serviço | Imagem | Porta | Função |
|---------|--------|-------|--------|
| Prometheus | prom/prometheus | 9090 | Coleta e armazena métricas dos exporters |
| Grafana | grafana/grafana | 3000 | Dashboards e visualização |
| InfluxDB | influxdb:1.8 | 8086 | Recebe as métricas de rede que o ntopng (`192.168.15.2`) escreve |
| node_exporter | prom/node-exporter | interna | Métricas do servidor |
| cAdvisor | gcr.io/cadvisor/cadvisor | interna | Métricas dos containers |
| postgres_exporter | prometheuscommunity/postgres-exporter | interna | Métricas do PostgreSQL |

O `monitoring-caddy` publica 3000 (Grafana) e 9090 (Prometheus) em https; o InfluxDB (8086) fica em http porque só o ntopng fala com ele. Os exporters ficam na rede interna, acessíveis apenas pelo Prometheus.

## 🚀 Instalação

Pré-requisito: o n8n-stack precisa estar rodando (o postgres_exporter conecta na rede dele).

```bash
cd monitoring
bash setup-monitoring.sh
```

O script detecta a rede do Docker, lê a senha do Postgres do `.env` do n8n-stack, gera as credenciais do Grafana, libera as portas no firewall e sobe tudo. Ao final, mostra o usuário e a senha do Grafana (guarde no KeePass).

## 📊 Acesso

| Serviço | URL | Login |
|---------|-----|-------|
| Grafana | https://192.168.15.3:3000 | admin e a senha gerada |
| Prometheus | https://192.168.15.3:9090 | sem login |
| InfluxDB | http://192.168.15.3:8086 | admin (ver `.env`) |

É https com CA local do Caddy (`monitoring-caddy`). O navegador avisa até você importar essa CA como raiz confiável — mesmo procedimento do Portainer/n8n (ver `docker/portainer/README.md`). Para importar as três CAs de uma vez, junte os `root.crt` num arquivo só:

```bash
for c in portainer-caddy n8n-caddy monitoring-caddy; do
  docker exec $c cat /data/caddy/pki/authorities/local/root.crt
done > homelab-cas.crt
# copie homelab-cas.crt para a máquina cliente e importe como raiz confiável
```

No Grafana, dois dashboards deste repositório já aparecem na lista (além de outros de projetos separados no mesmo host, como o "Dell Overview" do par `homelab-infrastructure-server`):

- **Homelab Lenovo Overview** — resumo executivo, CPU, memória (com swap), carga, rede, temperatura dos sensores, disco (uso e I/O), containers (CPU/memória/rede) e PostgreSQL. Layout espelhado no "Dell Overview" do repositório par, com variáveis de filtro (`$interface`, `$disk`, `$container`) pra não depender de scroll pra achar um container ou disco específico.
- **Rede (ntopng)** — tráfego, protocolos L7, top talkers por host e um painel de segurança/anomalias (alertas ativos, score da rede, hosts anômalos). Os nomes dos hosts vêm de um mapeamento manual dentro do dashboard (IP → nome), a partir das concessões fixas do DHCP — se um IP mudar, o nome fica desatualizado até alguém corrigir o mapeamento no JSON.

No Prometheus, a página Status > Targets mostra os exporters e se estão sendo coletados (todos devem estar "UP").

## 📥 Dashboards extras da comunidade

Além do dashboard provisionado, dá para importar dashboards prontos da comunidade pela interface do Grafana (menu Dashboards > New > Import, cola o ID e seleciona o datasource Prometheus):

| ID | Dashboard |
|----|-----------|
| 1860 | Node Exporter Full (servidor, muito completo) |
| 19792 | Docker via cAdvisor |
| 9628 | PostgreSQL Database |

## 🔒 Segurança

- As credenciais ficam no `.env`, que está no `.gitignore` e nunca vai para o Git. Apenas o `.env.example` é versionado.
- Grafana e Prometheus atrás do `monitoring-caddy` com `tls internal` (CA local). Ainda assim, acesso só na rede local — o certificado é de CA local, não pública, e o Prometheus não tem autenticação.

## 🔧 Operação

```bash
# Status dos serviços
docker compose ps

# Logs de um serviço
docker compose logs -f prometheus

# Recarregar a config do Prometheus após editar prometheus.yml
docker compose restart prometheus

# Parar tudo
docker compose down
```

## 📁 Estrutura

```
monitoring/
├── docker-compose.yml
├── Caddyfile                       # monitoring-caddy: https em 3000 e 9090
├── setup-monitoring.sh
├── .env.example
├── .gitignore
├── prometheus/
│   └── prometheus.yml              # Jobs de scrape
└── grafana/
    └── provisioning/
        ├── datasources/
        │   ├── prometheus.yml       # Datasource automático
        │   └── influxdb.yml         # Datasource do InfluxDB (dados do ntopng)
        └── dashboards/
            ├── dashboards.yml       # Provider de dashboards
            ├── lenovo-overview.json # Servidor, disco, temperatura, containers, PostgreSQL
            └── network-overview.json # Rede e segurança (ntopng)
```

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
