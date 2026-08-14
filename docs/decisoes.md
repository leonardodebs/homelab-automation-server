# Decisões de arquitetura

Registro das escolhas técnicas feitas na montagem deste servidor.

## Por que Docker puro e não Proxmox (nesta fase)

A máquina começou como Ubuntu Server com Docker para ter serviços no ar rapidamente, sem formatar. O plano é migrar para Proxmox depois. O que foi feito com Docker Compose migra sem retrabalho, os mesmos containers sobem dentro de uma VM ou LXC.

## Por que n8n com PostgreSQL e não SQLite

O n8n usa SQLite por padrão. Trocar para PostgreSQL dá mais robustez e permite backup e restauração no mesmo padrão de qualquer base Postgres, com pg_dump.

## Por que systemd timer e não cron no backup

O timer é mais observável: logs no journald, próximo disparo visível com systemctl list-timers, e Persistent=true garante execução se a máquina estiver desligada na hora agendada.

## Por que pigz no backup

Compressão paralela, usa todos os núcleos, mais rápido que o gzip de thread única. Mesma prática aplicada nos backups de produção dos clientes.

## Rede

IP fixo 192.168.100.3 na interface cabeada (eno1). A placa Wi-Fi Intel foi desabilitada via blacklist do iwlwifi, pois travava com crash de firmware (NMI_INTERRUPT_LMAC_FATAL) e não faz sentido em um servidor fixo com cabo.
