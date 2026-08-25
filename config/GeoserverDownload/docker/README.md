# GeoServer Download (DSP)

Docker image for WFS export used by the DSP backend downloads (`downloadThemesConfig.json` / `DSP_GEOSERVER_WFS_BASE_URL`).

Shares the same PostGIS database as GeoServer Exhibition (`dsp-geoserver-db`). Layers are published from the same `mapLayersConfig.json` so download `typeName`s stay aligned with the map.

## Image

- Base: `docker.osgeo.org/geoserver:3.0.0`
- Build context: this directory (`config/GeoserverDownload/docker`)
- Compose service: `dsp-geoserver-download`

## Defaults

Não publica porta no host: o acesso externo passa pelo gateway (`config/Gateway/docker`). O backend
continua chamando o WFS direto pela rede Docker, via `DSP_GEOSERVER_WFS_BASE_URL`.

| Item | Value |
| --- | --- |
| Prefixo no gateway | `/geoserver-download` |
| UI | http://localhost:8026/geoserver-download/web/ |
| WFS | http://localhost:8026/geoserver-download/dsp/wfs |
| Admin | `admin` / `geoserver` (same vars as Exhibition) |

Como o prefixo externo difere do interno (`/geoserver`), o `PROXY_BASE_URL` é obrigatório aqui —
sem ele os links gerados pelo GeoServer apontariam para o path errado.

## Published layers

Same FeatureTypes as Exhibition (from `mapLayersConfig.json`). Populate does **not** create tables — it only publishes layers for tables already in `dsp-geoserver-db`.

## Manual populate

```bash
docker compose up -d --build dsp-geoserver-download
docker compose exec dsp-geoserver-download /opt/populate_geoserver.sh
```
