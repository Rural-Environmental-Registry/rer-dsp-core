# GeoServer Exhibition

WMS service for the DSP map UI. Compose service `dsp-geoserver-exhibition`: layers are published by `./setup.sh`; the container is started by `./setup.sh` and `./start.sh`.

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

Tables and data come from init SQL (`config/db/dsp-geoserver-exhibition-db/`) for the four fixed layers, and from the migration job (`spring.datasource.geo-target`). Generic layers are created by the job (DDL via introspection) — no init SQL entry is required.

## SRS per layer

- Fixed layers (L1–L3, AOI): native SRS from `.env` `LAYER_SRS_*` (set by `./config.sh`).
- Extra layers: `layers[].srs` in `mapLayersConfig.json` (generated from `etl.layers[].srid`).

When validating, check geometry SRID in exhibition-db against the configured SRS.

## Build

- Dockerfile: [`config/GeoserverExhibition/docker/Dockerfile`](../config/GeoserverExhibition/docker/Dockerfile)
- Base image: `docker.osgeo.org/geoserver:3.0.0`
- Compose build uses `network: host` so `apt-get` can resolve Ubuntu mirrors (BuildKit bridge DNS sometimes fails locally).
- Populate: `/opt/populate_geoserver.sh` (workspace `dsp`, PostGIS datastore → `dsp-geoserver-exhibition-db`)
- Map config mount: `config/map/mapLayersConfig.json` → `/config/mapLayersConfig.json`
- Image includes `jq` and `postgresql-client` (geometry type introspection for SLD)

Manual build if needed:

```bash
docker build --network=host -t dsp-geoserver-exhibition:local ./config/GeoserverExhibition/docker
```

GeoServer does **not** create database tables. Fixed tables come from [`config/db/dsp-geoserver-exhibition-db/`](../config/db/dsp-geoserver-exhibition-db/); generic tables and all data come from the migration job. **Always migrate before populate.**

## Layer name contract

### Fixed layers

| PostGIS table | Populate / WMS | Job `layer-name` |
| --- | --- | --- |
| `dsp.territory_level_1` | `dsp:territory-level-1` | `territory-level-1` |
| `dsp.territory_level_2` | `dsp:territory-level-2` | `territory-level-2` |
| `dsp.territory_level_3` | `dsp:territory-level-3` | `territory-level-3` |
| `dsp.area_of_interest` | `dsp:area-of-interest` | `area-of-interest` |

### Generic layers

| PostGIS table | Populate / WMS | Job `layer-name` |
| --- | --- | --- |
| `dsp.<table>` | `dsp:<layer_name>` | `<layer_name>` (default = table name) |

- **Populate** iterates **all** entries in the mounted `mapLayersConfig.json` (not a hardcoded list of four).
- For each layer it syncs SLD (point / line / polygon from `geometry_columns`) and publishes the FeatureType when missing.
- Extra layers require `nativeName` (PostGIS table) and `srs` in the JSON.
- The four fixed WMS ids remain mandatory and are validated by `./setup.sh` / `./start.sh`.
- Style name: `dsp_<layer_name_with_underscores>` (e.g. `dsp_territory_level_1`, `dsp_<layer_name>`).

Re-running populate updates existing styles when colors change in the active JSON.

See also [map-layers-config.md](map-layers-config.md) · [databases.md](databases.md) · [migration-config.md](migration-config.md).

## Manual commands

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```
