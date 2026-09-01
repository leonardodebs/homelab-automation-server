# Portainer

Interface web para gerenciar os containers Docker do servidor: ver logs, uso de recurso, console e status de cada serviço.

## Arquitetura

O Portainer fica só na rede interna do Docker (sem porta publicada). Quem serve HTTPS na porta 9443 é um Caddy dedicado, na frente, com `tls internal`: Caddy mantém sua própria CA local (gerada e guardada no volume `caddy_data`) e assina um certificado para `192.168.15.3` com ela. O aviso de "conexão não seguro" do navegador some depois que essa CA é importada uma vez como raiz confiável (veja abaixo).

```
navegador → https://192.168.15.3:9443 (Caddy, tls internal) → portainer:9000 (http, rede interna)
```

## Subir

```bash
cd portainer
docker compose up -d
```

No primeiro acesso, crie o usuário admin (senha de 12 caracteres ou mais). A tela de criação expira em alguns minutos, então faça logo após subir. Se expirar, reinicie o container e recarregue:

```bash
docker restart portainer
```

Depois de logado, clique em "Get Started" para conectar ao Docker local.

## Acesso

```
https://192.168.15.3:9443
```

## Confiar na CA local (elimina o aviso do navegador)

Isso só precisa ser feito uma vez por dispositivo/navegador que for acessar o servidor.

1. Extrair o certificado raiz do container Caddy:

   ```bash
   docker cp portainer-caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt
   ```

2. Copiar `caddy-root.crt` para a máquina cliente (ex: `scp leonardo@192.168.15.3:~/portainer/caddy-root.crt .`).

3. Importar como raiz confiável:
   - **Windows (Chrome/Edge, usam o repositório do Windows):**
     ```powershell
     Import-Certificate -FilePath .\caddy-root.crt -CertStoreLocation Cert:\LocalMachine\Root
     ```
     (requer PowerShell como administrador; alternativa gráfica: clique duplo no `.crt` → Instalar Certificado → Máquina Local → Colocar todos os certificados na loja "Autoridades de Certificação Raiz Confiáveis")
   - **Firefox (tem repositório próprio):** `about:preferences#privacy` → Certificados → Ver Certificados → Autoridades → Importar → marcar "confiar para identificar sites".
   - **macOS:** Keychain Access → arrastar o `.crt` para "System" → definir como "Always Trust" para SSL.
   - **Linux:** copiar para `/usr/local/share/ca-certificates/`, rodar `sudo update-ca-certificates`.

Depois disso, `https://192.168.15.3:9443` carrega sem aviso, com o cadeado normal.

> Se o servidor for reconstruído do zero e o volume `caddy_data` recriado, a CA muda e o passo acima precisa ser refeito.

## Firewall

A porta 9443 precisa estar liberada no UFW (agora é o Caddy que escuta nela, não mais o Portainer diretamente):

```bash
sudo ufw allow 9443/tcp comment 'portainer (via caddy)'
```
