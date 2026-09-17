# Cursos

Portal local (só rede interna) pra assistir cursos próprios hospedados no servidor, com um player HTML por curso (estilo playlist, na ordem dos módulos).

## Arquitetura

```
navegador → https://192.168.15.3:8443 (Caddy, tls internal) → /CURSOS (arquivos estáticos, host)
```

O conteúdo em si (`/CURSOS`, vídeos + os `*-player.html` de cada curso) **não é versionado** — fica só no host, fora do Git, pelo tamanho. Só o Caddyfile, o compose e a página de catálogo (`catalog/index.html`) são código.

## Subir

```bash
cd cursos
docker compose up -d
```

Pré-requisito: `/CURSOS` já existir no host com o conteúdo sincronizado (ver seção Sincronização) e o catálogo copiado pra `/CURSOS/index.html`:

```bash
cp catalog/index.html /CURSOS/index.html
```

(Não dá pra montar o `index.html` como volume dentro de `/CURSOS` porque esse mount é `:ro` — o Docker não consegue criar o ponto de montagem do arquivo num diretório somente-leitura. Por isso o catálogo é copiado direto pro host em vez de bind-mount.)

## Acesso

```
https://192.168.15.3:8443
```

Certificado de CA local (Caddy `tls internal`) — importa a CA uma vez por dispositivo, mesmo processo do Portainer/n8n/monitoring (ver `docker/portainer/README.md`).

## Sincronização do conteúdo

Os vídeos vêm de `D:\DOWNLOADS\02 CURSOS` (Windows). Usa `rsync` (via WSL, pois não tem rsync nativo no Windows) pra copiar cada curso pra `/CURSOS/<categoria>/<curso>/` no servidor — retomável, então dá pra rodar de novo sem re-transferir o que já chegou.

## Os arquivos `*-player.html`

Cada curso vem com um player HTML próprio (não foi feito por nós — vem no pacote do curso), com os caminhos dos vídeos gravados como **absolutos** (`file:///D:/DOWNLOADS/...`). Antes de colocar um curso no ar:

1. Copiar a pasta do curso pra `/CURSOS/<categoria>/<curso>/`
2. Reescrever o `data-path`/caminho-base do player pra apontar pro caminho real atual (o nome da pasta/categoria já pode ter mudado desde que o player foi gerado — conferir sempre, não assumir)
3. Adicionar o link do curso em `catalog/index.html`

## Curadoria de conteúdo

Só cursos comprados de fato entram aqui. Vários itens da pasta local têm a marca d'água de um site de redistribuição não autorizada (`DownloadCursos.top.html` em cada pasta) — esses ficam de fora até ter comprovante de compra.

---

<div align="center">

Desenvolvido por **[Leonardo Debs](https://github.com/leonardodebs)**

</div>
