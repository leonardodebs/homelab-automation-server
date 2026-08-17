# Documentação do servidor

Registro técnico do que foi construído no servidor de automação (Lenovo ThinkCentre M900). Documenta o estado atual da máquina, os serviços em execução e as decisões tomadas. Serve de referência para operação e para reconstrução.

## Visão geral

Servidor Ubuntu 24.04 rodando serviços de automação e observabilidade em Docker, na rede local. Montado do zero, com toda a configuração versionada neste repositório. A máquina está preparada para migrar para Proxmox em uma fase futura.

## Estado da máquina

| Item | Valor |
|------|-------|
| Hostname | vmlab |
| IP fixo | 192.168.100.3 (eno1, cabo) |
| Sistema | Ubuntu Server 24.04 LTS |
| Kernel | 6.8.0-137-generic |
| CPU | Intel Skylake 4 núcleos |
| RAM | 16 GB |
| Disco | SSD 232 GB (LVM expandido) |

## Serviços em execução

| Serviço | Porta | Função |
|---------|-------|--------|
| n8n | 5678 | Automação de workflows |
| PostgreSQL | interna | Banco de dados do n8n |
| Portainer | 9443 | Gerência visual dos containers |
| Grafana | 3000 | Dashboards de observabilidade |
| Prometheus | 9090 | Coleta e armazenamento de métricas |
| node_exporter | interna | Métricas do servidor |
| cAdvisor | interna | Métricas dos containers |
| postgres_exporter | interna | Métricas do PostgreSQL |

## O que foi feito

### Base do sistema

Instalação limpa do Ubuntu Server, com os primeiros ajustes de infraestrutura. A placa Wi-Fi Intel foi desabilitada via blacklist do `iwlwifi`, pois travava com crash de firmware (`NMI_INTERRUPT_LMAC_FATAL`) e não faz sentido em um servidor fixo com cabo. A rede migrou para a interface cabeada com IP fixo `192.168.100.3`. O kernel foi atualizado para o `6.8.0-137`, o disco foi expandido de 100 GB para os 232 GB completos do SSD (o instalador provisiona metade por padrão), e a verificação de firmware confirmou que nada faltava.

### Segurança

A base de hardening foi aplicada e está registrada como código no script `setup/harden-server.sh`. Cobre: timezone `America/Sao_Paulo`, atualizações automáticas de segurança via `unattended-upgrades`, firewall UFW liberando apenas as portas em uso, `fail2ban` protegendo o SSH contra força bruta, e hardening do SSH com login root direto desabilitado.

### Docker e serviços

Docker Engine e Compose instalados da fonte oficial. Os serviços foram organizados em projetos separados, cada um com seu Compose e README. O n8n usa PostgreSQL como banco (em vez do SQLite padrão), para robustez e backup no padrão Postgres. O Portainer dá visão web dos containers.

### Backup

Backup diário do PostgreSQL às 02h, via systemd timer, com compressão `pigz`, escrita atômica, verificação prévia de espaço em disco e retenção de 7 dias. Instalado pelo script `setup/install-n8n-backup.sh`.

### Observabilidade

O Netdata foi avaliado primeiro, mas a escolha final foi o stack padrão do mercado: Prometheus coletando, Grafana visualizando, e três exporters (node_exporter, cAdvisor, postgres_exporter). O Grafana já vem com datasource e um dashboard das três camadas provisionados como código. O stack foi validado com teste de carga usando `stress-ng`, confirmando a coleta sob estresse de CPU e memória.

## Portas liberadas no firewall

| Porta | Serviço |
|-------|---------|
| 22 | SSH |
| 3000 | Grafana |
| 5678 | n8n |
| 9090 | Prometheus |
| 9443 | Portainer |

## Reconstrução

A ordem completa para provisionar a máquina do zero está no README principal do repositório, seção "Reconstruir do zero". Em resumo: hardening, Docker, configurar segredos, subir os serviços, agendar o backup, subir o monitoramento.

## Próxima fase

A máquina será migrada para Proxmox, com estes serviços rodando em VM ou LXC. O runbook de instalação do Proxmox já existe. Quando a migração acontecer, será adicionada uma pasta `proxmox/` ao lado de `docker/`.
