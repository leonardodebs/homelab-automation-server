# Portainer

Interface web para gerenciar os containers Docker do servidor: ver logs, uso de recurso, console e status de cada serviço.

## Subir

```bash
cd portainer
docker compose up -d
```

## Acesso

```
https://192.168.15.3:9443
```

Atenção: é https, com certificado self-signed (o navegador vai avisar, aceite). No primeiro acesso, crie o usuário admin (senha de 12 caracteres ou mais). A tela de criação expira em alguns minutos, então faça logo após subir. Se expirar, reinicie o container e recarregue:

```bash
docker restart portainer
```

Depois de logado, clique em "Get Started" para conectar ao Docker local.

## Firewall

A porta 9443 precisa estar liberada no UFW:

```bash
sudo ufw allow 9443/tcp comment 'portainer'
```
