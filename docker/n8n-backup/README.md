<div align="center">

# 💾 n8n-backup

**Backup automático do PostgreSQL do n8n, com pigz, escrita atômica e retenção**

[![Bash](https://img.shields.io/badge/Bash-script-4EAA25?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql)](https://postgresql.org)

</div>

---

## 📋 Sobre

Script de backup do banco PostgreSQL que dá suporte ao n8n. Gera um dump comprimido por dia, mantém os últimos 7 dias e apaga os mais antigos automaticamente. Escrito para rodar via cron ou systemd timer em um host Ubuntu.

Boas práticas aplicadas:

- Compressão com pigz (paralela, usa todos os núcleos), com fallback para gzip
- Escrita atômica: o dump é gravado em um arquivo temporário e só renomeado para o nome final se terminar sem erro, evitando backups corrompidos de 0 byte
- pipefail: uma falha no pg_dump derruba o pipe inteiro, em vez de gerar um arquivo comprimido vazio
- Verificação prévia de espaço em disco antes de começar
- Verificação de que o container do banco está rodando
- Retenção automática por número de dias
- Log com data e hora de cada execução

## 🚀 Instalação

### 1. Instalar o pigz no host

```bash
sudo apt update && sudo apt install -y pigz
```

### 2. Colocar o script no servidor

```bash
mkdir -p ~/n8n-backup
# copie o backup-n8n.sh para ~/n8n-backup/
chmod +x ~/n8n-backup/backup-n8n.sh
```

### 3. Testar manualmente antes de agendar

```bash
bash ~/n8n-backup/backup-n8n.sh
ls -lh ~/backups/n8n/
```

Deve aparecer um arquivo `n8n_AAAAMMDD_HHMMSS.sql.gz` e um `backup.log`.

## ⏰ Agendamento

Escolha uma das duas formas. O cron é mais simples, o systemd timer é mais observável.

### Opção A: cron (simples)

```bash
crontab -e
```

Adicione a linha abaixo para rodar todo dia às 02h00:

```
0 2 * * * /usr/bin/bash /home/leonardo/n8n-backup/backup-n8n.sh >> /home/leonardo/backups/n8n/cron.log 2>&1
```

### Opção B: systemd timer (recomendado, com logs no journald)

Crie o service em `/etc/systemd/system/n8n-backup.service`:

```ini
[Unit]
Description=Backup do PostgreSQL do n8n
After=docker.service

[Service]
Type=oneshot
User=leonardo
ExecStart=/usr/bin/bash /home/leonardo/n8n-backup/backup-n8n.sh
```

Crie o timer em `/etc/systemd/system/n8n-backup.timer`:

```ini
[Unit]
Description=Executa o backup do n8n diariamente

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Ative:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now n8n-backup.timer
systemctl list-timers n8n-backup.timer
```

O `Persistent=true` garante que, se o servidor estiver desligado na hora agendada, o backup roda assim que ele liga.

## ♻️ Restauração

Para restaurar um backup em um banco vazio:

```bash
# descomprime e injeta no banco
gunzip -c ~/backups/n8n/n8n_AAAAMMDD_HHMMSS.sql.gz | \
  docker exec -i n8n-postgres psql -U n8n -d n8n
```

## ⚙️ Configuração

Variáveis no topo do `backup-n8n.sh`:

| Variável | Padrão | Descrição |
|---------|--------|-----------|
| CONTAINER | n8n-postgres | Nome do container do Postgres |
| DB_USER | n8n | Usuário do banco |
| DB_NAME | n8n | Nome do banco |
| BACKUP_DIR | ~/backups/n8n | Onde guardar os dumps |
| RETENCAO_DIAS | 7 | Dias de backup a manter |
| ESPACO_MINIMO_MB | 500 | Aborta se houver menos espaço livre |

## ⚠️ Avisos

- Os dumps ficam em `~/backups/n8n` por padrão, fora deste repositório. Não versione os arquivos `.sql.gz`.
- Para proteção real contra falha de disco, copie os backups para outro local (outro disco, NAS, ou nuvem). Um backup no mesmo disco do banco não protege contra perda do disco.

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
