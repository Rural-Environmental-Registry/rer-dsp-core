# GeoServer Download (DSP)

Docker image for WFS export used by the DSP backend downloads (`downloadThemesConfig.json` / `DSP_GEOSERVER_WFS_BASE_URL`).

Shares the same PostGIS database as GeoServer Exhibition (`dsp-geoserver-db`). Layers are published from the same `mapLayersConfig.json` so download `typeName`s stay aligned with the map.

## Image

- Base: `docker.osgeo.org/geoserver:3.0.0`
- Build context: this directory (`config/GeoserverDownload/docker`)
- Compose service: `dsp-geoserver-download`

## Defaults

| Item | Value |
| --- | --- |
| Host port | `22669` (`DSP_GEOSERVER_DOWNLOAD_HOST_PORT`) |
| UI | http://localhost:22669/geoserver/web/ |
| WFS | http://localhost:22669/geoserver/dsp/wfs |
| Admin | `admin` / `geoserver` (same vars as Exhibition) |

## Published layers

Same FeatureTypes as Exhibition (from `mapLayersConfig.json`). Populate does **not** create tables — it only publishes layers for tables already in `dsp-geoserver-db`.

## Manual populate

```bash
docker compose up -d --build dsp-geoserver-download
docker compose exec dsp-geoserver-download /opt/populate_geoserver.sh
```
