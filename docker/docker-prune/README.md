<div align="center">

# 🧹 docker-prune

**Limpeza automática do Docker: imagens e cache de build sem uso**

[![Bash](https://img.shields.io/badge/Bash-script-4EAA25?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/systemd-timer-30D475)](https://www.freedesktop.org/wiki/Software/systemd/)

</div>

---

## 📋 Sobre

Este host também roda um k3s com um CI que builda e faz push das imagens do
jobops e do finance a cada commit. Cada build deixa uma cópia da imagem no
store do Docker e camadas no cache de build — que o k3s **não usa** (ele puxa
da registry interna `localhost:5000` via containerd). Em poucos dias isso vira
dezenas de GB de sobra.

O `docker-prune.sh` roda semanalmente e limpa só o que é seguro:

| Alvo | Ação |
|------|------|
| Imagens sem uso | Remove as que não estão em nenhum contêiner **e** têm mais de `RETENCAO_DIAS` |
| Cache de build | Remove camadas com mais de `RETENCAO_DIAS` |

O filtro `until` protege qualquer coisa recente — uma imagem que você acabou de
buildar pra debugar não some no meio da semana.

## 🚫 O que NÃO é tocado

- **Contêineres** (rodando ou parados) e as imagens que eles usam.
- **Volumes.** Pruning de volume é arriscado num host com k3s + compose (um
  volume entre `down` e `up`, um deploy em andamento). Se precisar, rode manual
  e com cuidado: `docker volume prune` (só anônimos) ou liste antes com
  `docker volume ls -f dangling=true`.
- **A registry interna `localhost:5000`.** É o que o k3s usa de verdade. Ela
  guarda o histórico de tags do jobops/finance (~1.3 GB) e serve de rollback.
  Podar exige deletar manifests pela API e rodar `registry garbage-collect`
  dentro do contêiner `k3s-registry` — feito à parte, quando fizer sentido.

## 🚀 Instalação

```bash
cd docker
bash setup/install-docker-prune.sh
```

Grava o script em `~/docker-prune/`, roda uma limpeza de teste e agenda o
systemd timer (domingo 04h00).

## ⏰ Agendamento

O timer roda `Sun *-*-* 04:00:00` com `Persistent=true` (se o host estiver
desligado no horário, roda assim que ligar).

```bash
systemctl list-timers docker-prune.timer
journalctl -u docker-prune.service        # logs, com o docker system df antes/depois
sudo systemctl start docker-prune.service # rodar agora
```

## ⚙️ Configuração

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `RETENCAO_DIAS` | 7 | Idade mínima para uma imagem/camada ser removida |

Editar no topo de `~/docker-prune/docker-prune.sh` no servidor (o timer relê o
arquivo a cada execução).

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
