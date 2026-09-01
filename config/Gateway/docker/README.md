# Gateway (DSP)

Reverse proxy nginx — porta de entrada única da stack. Frontend, backend e os dois GeoServers
não publicam porta no host; todo o acesso HTTP externo passa por aqui.

## Imagem

- Base: `nginx:alpine`
- Context de build: `rer-dsp-core/config/Gateway` (`dockerfile: docker/Dockerfile`)
- Serviço no Compose: `dsp-gateway`
- Os templates são copiados para a imagem em `/etc/nginx/templates/` (`nginx/default.conf.template`)

O template é processado por `envsubst` na subida do container. Só as variáveis `DSP_*` são
substituídas (`NGINX_ENVSUBST_FILTER=^DSP_`), para não conflitar com variáveis do próprio nginx
como `$uri` e `$host`.

Depois de alterar um template, faça rebuild (`./start.sh` ou `docker compose up -d --build dsp-gateway`).

## Padrões

| Item | Valor |
| --- | --- |
| Porta no host | `8026` (`DSP_GATEWAY_HOST_PORT`) |
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
`/geoserver` internamente, cada um recebe um prefixo externo próprio e um `rewrite`. O
`PROXY_BASE_URL` de cada GeoServer garante que os links do GetCapabilities e da UI web saiam com
a URL pública correta.

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

Para limpar o cache: `docker compose --env-file .env down` e remova o volume `dsp_gateway_cache`.

## Notas

- Os upstreams são resolvidos em runtime pelo DNS do Docker (`resolver 127.0.0.11` + nome em
  variável). Assim o gateway sobe mesmo com algum serviço parado, respondendo `502` em vez de
  falhar no boot — necessário no modo demo do `./setup.sh`, que não sobe backend nem frontend.
- Não há terminação TLS aqui. Expor via HTTPS continua a cargo do adotante; este é o ponto
  natural para fazê-lo.
