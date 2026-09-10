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

## Por que Caddy com `tls internal` na frente do Portainer, n8n, Grafana e Prometheus

Esses serviços serviam HTTP(S) sem certificado confiável (Portainer com autoassinado próprio, disparando "conexão não é particular"; n8n, Grafana e Prometheus em http puro). Como o servidor só é acessado pela rede local (sem domínio público apontando pra ele), não dá pra usar um certificado Let's Encrypt normal (desafio HTTP-01 exige a porta 80 acessível pela internet). A alternativa foi colocar um Caddy dedicado na frente de cada stack, usando `tls internal`: cada Caddy mantém sua própria CA local e assina o certificado do IP com ela. Basta importar essa CA como raiz confiável uma vez em cada dispositivo cliente para o aviso sumir de vez, sem depender de infraestrutura externa.

Cada stack tem seu próprio Caddy e sua própria CA (`portainer-caddy`, `n8n-caddy`, `monitoring-caddy` — este último cobre Grafana e Prometheus num só container, portas 3000 e 9090) — mantém os `docker compose up -d` independentes um do outro, como já eram, ao custo de importar três CAs em vez de uma. Dá pra juntar os três `root.crt` num arquivo só e importar de uma vez. Mesmo padrão que já era usado em outro projeto no mesmo host (openclaw-lab), mas com CAs próprias deste repositório, para manter tudo reconstruível a partir só daqui.

O InfluxDB (porta 8086) fica de fora: quem escreve nele é o ntopng rodando no Dell (`192.168.15.2`), comunicação máquina-a-máquina. Botar TLS na frente exigiria configurar o exporter do ntopng pra falar https e confiar na CA — complexidade sem ganho, já que nenhum navegador acessa o InfluxDB direto.

Prometheus recebe `--web.external-url=https://192.168.15.3:9090/` e o Grafana `GF_SERVER_ROOT_URL=https://192.168.15.3:3000/` para gerarem links e redirects coerentes com o TLS que o Caddy termina na frente.

## Rede

IP fixo 192.168.15.3 na interface cabeada (eno1). A placa Wi-Fi Intel foi desabilitada via blacklist do iwlwifi, pois travava com crash de firmware (NMI_INTERRUPT_LMAC_FATAL) e não faz sentido em um servidor fixo com cabo.
