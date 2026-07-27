# GeoServer Exhibition (DSP)

Docker image for the map WMS used by the DSP UI (`mapLayersConfig.json`).

## Image

- Base: `docker.osgeo.org/geoserver:3.0.0`
- Build context: this directory (`config/GeoserverExhibition/docker`)
- Compose service: `dsp-geoserver-exhibition`

## Defaults

| Item | Value |
| --- | --- |
| Host port | `22668` (`DSP_GEOSERVER_HOST_PORT`) |
| UI | http://localhost:22668/geoserver/web/ |
| WMS | http://localhost:22668/geoserver/dsp/wms |
| Admin | `admin` / `geoserver` |

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
