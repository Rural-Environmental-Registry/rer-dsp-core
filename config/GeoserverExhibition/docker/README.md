# GeoServer Exhibition (DSP)

Docker image for map WMS/WFS navigation used by the DSP UI (`mapLayersConfig.json`).

Downloads (CSV/WFS export) use a separate GeoServer — see `config/GeoserverDownload/docker`.

## Image

- Base: `docker.osgeo.org/geoserver:3.0.0`
- Build context: this directory (`config/GeoserverExhibition/docker`)
- Compose service: `dsp-geoserver-exhibition`

## Defaults

Não publica porta no host: o acesso externo passa pelo gateway (`config/Gateway/docker`).

| Item | Value |
| --- | --- |
| Prefixo no gateway | `/geoserver-exhibition` |
| UI | http://localhost:8026/geoserver-exhibition/web/ |
| WMS | http://localhost:8026/geoserver-exhibition/dsp/wms |
| Admin | `admin` / `geoserver` |

Como o prefixo externo difere do interno (`/geoserver`), o `PROXY_BASE_URL` — derivado de
`DSP_PUBLIC_BASE_URL` — é obrigatório: sem ele os links do GetCapabilities e da UI web apontariam
para o path errado.

## Published layers (fixed)

| PostGIS table | WMS layer | Job `layer-name` |
| --- | --- | --- |
| `dsp.territory_level_1` | `dsp:territory-level-1` | `territory-level-1` |
| `dsp.territory_level_2` | `dsp:territory-level-2` | `territory-level-2` |
| `dsp.territory_level_3` | `dsp:territory-level-3` | `territory-level-3` |
| `dsp.area_of_interest` | `dsp:area-of-interest` | `area-of-interest` |

`populate_geoserver.sh` does **not** create tables. It only publishes FeatureTypes for tables created by `config/db/dsp-db` init SQL (data from the migration job).

`mapLayersConfig.json` must keep these four `layers` ids — `./start.sh` validates them.

Layer colors come from the mounted `config/map/mapLayersConfig.json` (`style.color` / `style.fillColor`). Populate creates/updates one SLD per layer (`dsp_territory_level_*`, `dsp_area_of_interest`).

## Manual populate

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```
