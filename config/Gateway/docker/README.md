# Gateway (DSP)

Reverse proxy nginx que é a porta de entrada única da stack. Frontend, backend e os dois GeoServers
não publicam mais porta no host — todo o acesso HTTP passa por aqui.

## Image

- Base: `nginx:alpine` (sem build próprio)
- Compose service: `dsp-gateway`
- Config: `config/Gateway/nginx/default.conf.template`, montada em `/etc/nginx/templates/`

O template é processado por `envsubst` na subida do container. Só as variáveis `DSP_*` são
substituídas (`NGINX_ENVSUBST_FILTER=^DSP_`), para não conflitar com variáveis do próprio nginx
como `$uri` e `$host`.

## Defaults

| Item | Value |
| --- | --- |
| Host port | `8026` (`DSP_GATEWAY_HOST_PORT`) |
| Base pública | `http://localhost:8026` (`DSP_PUBLIC_BASE_URL`) |
| Health | http://localhost:8026/gateway/health |

## Rotas

| Rota externa | Destino interno | Cache |
| --- | --- | --- |
| `/` | redireciona para `/dsp/` | — |
| `/dsp/` | `dsp-frontend:8080` | não |
| `/dsp-backend/` | `dsp-backend:8080` (mesmo path, sem rewrite) | não |
| `/geoserver-exhibition/<ws>/wms` e `/wfs` | `dsp-geoserver-exhibition:8080/geoserver/...` | sim |
| `/geoserver-exhibition/` (UI web, REST) | `dsp-geoserver-exhibition:8080/geoserver/` | não |
| `/geoserver-download/<ws>/wms` e `/wfs` | `dsp-geoserver-download:8080/geoserver/...` | sim |
| `/geoserver-download/` (UI web, REST) | `dsp-geoserver-download:8080/geoserver/` | não |
| `/gateway/health` | resposta local do nginx | — |

O prefixo do backend acompanha `DSP_BACKEND_CONTEXT_PATH`. Como os dois GeoServers respondem em
`/geoserver` internamente, cada um recebe um prefixo externo próprio e um `rewrite`; o
`PROXY_BASE_URL` de cada um garante que os links do GetCapabilities e da UI web saiam com a URL
pública correta.

## Cache

A zona de cache (`dsp_cache`, volume `dsp_gateway_cache`) já está declarada e aplicada nos endpoints
WMS/WFS, mas vem **desligada**: `DSP_GATEWAY_CACHE_BYPASS=1` no `.env`.

O cache cobre só os endpoints de serviço, que não têm sessão. A UI web e a API REST do GeoServer
ficam de fora, para não quebrar o login do admin. Como o GeoServer responde
`Cache-Control: max-age=0, must-revalidate` em toda requisição, o gateway ignora esse header nessas
rotas — sem isso nada seria armazenado.

Para ligar, deixe a variável vazia e recrie o container:

```bash
# .env
DSP_GATEWAY_CACHE_BYPASS=
DSP_GATEWAY_CACHE_TTL=10m

docker compose --env-file .env up -d --force-recreate dsp-gateway
```

O header `X-Cache-Status` (`HIT`, `MISS`, `BYPASS`) sai em toda resposta dos GeoServers e serve para
conferir o comportamento:

```bash
curl -sI "http://localhost:8026/geoserver-exhibition/dsp/wms?service=WMS&request=GetCapabilities" | grep -i x-cache
```

Para limpar o cache: `docker compose --env-file .env down` e remover o volume `dsp_gateway_cache`.

## Notas

- Os upstreams são resolvidos em runtime pelo DNS do Docker (`resolver 127.0.0.11` + nome em
  variável). Assim o gateway sobe mesmo com algum serviço parado, respondendo `502` em vez de
  falhar no boot — necessário no modo demo do `./setup.sh`, que não sobe backend e frontend.
- Não há terminação TLS aqui. Expor via HTTPS continua a cargo do adotante, e este é o ponto
  natural para fazê-lo.
