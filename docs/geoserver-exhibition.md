# GeoServer Exhibition

WMS service for the DSP map UI. Built and started by `./start.sh` as Compose service `dsp-geoserver-exhibition`.

## Endpoints (local defaults)

| Item | URL |
| --- | --- |
| UI | http://localhost:22668/geoserver/web/ |
| WMS | http://localhost:22668/geoserver/dsp/wms |
| Admin | `admin` / `geoserver` (`DSP_GEOSERVER_ADMIN_*`) |

Port: `DSP_GEOSERVER_HOST_PORT` (default **22668**).

## Database

GeoServer Exhibition reads **only** `dsp-geoserver-exhibition-db` — not `dsp-db`.

| Env var (populate) | Value |
| --- | --- |
| `DB_HOST` | `dsp-geoserver-exhibition-db` |
| `DB_PORT` | `5432` |
| `DB_NAME` | `dsp-geoserver-exhibition-db` (default) |
| `DB_SCHEMA` | `dsp` |

Tables and data come from init SQL (`config/db/dsp-geoserver-exhibition-db/`) and the migration job dual-write (`spring.datasource.geo-target`).

## SRS por layer

Native SRS of each layer follows the job YAML `srid` for that table — **not** hardcoded in populate or DDL. Example: CAR jobs use `srid: 4674`; other installations may use `4326`.

When validating, check `ST_SRID(geometry)` in exhibition-db against the YAML `srid` of the corresponding job block.

## Build

- Dockerfile: [`config/GeoserverExhibition/docker/Dockerfile`](../config/GeoserverExhibition/docker/Dockerfile)
- Base image: `docker.osgeo.org/geoserver:3.0.0`
- Populate: `/opt/populate_geoserver.sh` (workspace `dsp`, PostGIS datastore → `dsp-geoserver-exhibition-db`)
- Map config mount: `config/map/mapLayersConfig.json` → `/config/mapLayersConfig.json`

GeoServer does **not** create database tables. Tables come from [`config/db/dsp-geoserver-exhibition-db/`](../config/db/dsp-geoserver-exhibition-db/); data from the migration job.

## Layer name contract (three sides)

| PostGIS table | Populate / WMS | Job `layer-name` |
| --- | --- | --- |
| `dsp.territory_level_1` | `dsp:territory-level-1` | `territory-level-1` |
| `dsp.territory_level_2` | `dsp:territory-level-2` | `territory-level-2` |
| `dsp.territory_level_3` | `dsp:territory-level-3` | `territory-level-3` |
| `dsp.area_of_interest` | `dsp:area-of-interest` | `area-of-interest` |

- **Populate** publishes fixed FeatureTypes and syncs SLD colors from the mounted `mapLayersConfig.json`.
- **`mapLayersConfig.json`** must keep those four `layers` ids and valid `style.color` / `style.fillColor` — validated by `./start.sh`.
- **Job `layer-name`** identifies the published layer for future GeoServer cache invalidation (`GeoCacheUpdateListener`).

Style names created by populate:

- `dsp_territory_level_1`
- `dsp_territory_level_2`
- `dsp_territory_level_3`
- `dsp_area_of_interest`

Re-running populate updates existing styles when colors change in the active JSON.

See also [map-layers-config.md](map-layers-config.md) · [databases.md](databases.md).

## Manual commands

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```
