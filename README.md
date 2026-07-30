# RER DSP — Core

**Project**: Rural Environmental Registry — Data Sharing Platform  
**Component**: Core (installation orchestration & configuration)  
**Type**: Digital Public Good (DPG)  
**License**: GPL-3.0

---

## Overview

`rer-dsp-core` is the **installation hub** for the DSP stack (same role as RER `core`):

- Example adopter configuration (hierarchy, screens, KPIs, map layers)
- Init SQL and Docker Compose for databases `dsp-db` and `dsp-job-migration-db`
- GeoServer Exhibition (WMS for the map)
- `./setup.sh` — data migration + GeoServer populate (once; data on Docker volumes)
- `./start.sh` — starts backend + frontend + GeoServer (day-to-day; **no** remigration)

Application code lives in sibling repositories. This repo does **not** hold domain Java libraries.

## Expected layout

```text
DSP/
├── rer-dsp-core/          ← this repository
├── rer-dsp-backend/
├── rer-dsp-frontend/
├── rer-dsp-job-data-migration/
└── rer-dsp-job-geo-file-generation/
```

See [docs/submodules.md](docs/submodules.md) and [docs/databases.md](docs/databases.md).

## Quick start

Prerequisites: Docker 24+ with Compose v2.

```bash
cd rer-dsp-core
cp .env.example .env
chmod +x ./setup.sh ./start.sh
```

Edit (scripts create from `.example` and **stop** while files still match the template):

- `config/installation/installation-config.json` — UI labels, screens, KPIs
- `config/map/mapLayersConfig.json` — GeoServer WMS layers
- `config/Job-Data-Migration/application/application.yaml` — JDBC + ETL mapping (to migrate)

```bash
./setup.sh    # databases + migration + GeoServer publish (data stays on volumes)
./start.sh    # start the application (does not remigrate)
```

UI without CAR data: `./setup.sh --skip-migration` then `./start.sh`.

Frontend-only tweak: `docker compose up -d --build dsp-frontend` (do not use `down -v`).

| Service | Default URL / port |
| --- | --- |
| Frontend | http://localhost:22667/dsp/ |
| Backend API | http://localhost:22666/dsp-backend |
| Installation config | http://localhost:22666/dsp-backend/config/installation |
| Map layers | http://localhost:22666/dsp-backend/map/getLayers |
| GeoServer Exhibition | http://localhost:22668/geoserver/web/ |
| GeoServer WMS | http://localhost:22668/geoserver/dsp/wms |
| DSP DB (`dsp-db`) | localhost:20654 |
| Job migration DB (`dsp-job-migration-db`) | localhost:20655 |

Verify tables:

```bash
docker compose exec dsp-db psql -U dsp -d dsp-db -c '\dt dsp.*'
docker compose exec dsp-job-migration-db psql -U dsp_job -d dsp-job-migration-db -c '\dt BATCH*'
```

Stop / recreate databases:

```bash
docker compose down              # stop containers; keeps volumes (data)
docker compose down -v           # wipe volumes — then run ./setup.sh again
```

## Configuration

| Path | Purpose |
| --- | --- |
| [`.env.example`](.env.example) | Ports, DBs, `DSP_SKIP_MIGRATION` |
| [`setup.sh`](setup.sh) / [`start.sh`](start.sh) | Setup (data) vs start (apps) — see [scripts/README.md](scripts/README.md) |
| [`config/db/dsp-db/`](config/db/dsp-db/) | PostGIS init SQL + `dsp.territory_level_*` + `dsp.area_of_interest` |
| [`config/db/dsp-job-migration-db/`](config/db/dsp-job-migration-db/) | `BATCH_*` init SQL |
| [`config/Job-Data-Migration/application/application.yaml`](config/Job-Data-Migration/application/application.yaml) | JDBC connections + job ETL mapping |
| [`config/installation/installation-config.json.example`](config/installation/installation-config.json.example) | Template: hierarchy, screens, KPIs |
| [`config/map/mapLayersConfig.json.example`](config/map/mapLayersConfig.json.example) | Template: WMS layers / GeoServer |
| [`config/GeoserverExhibition/docker/`](config/GeoserverExhibition/docker/) | GeoServer Exhibition image + populate script |

See also [docs/installation-config.md](docs/installation-config.md), [docs/map-layers-config.md](docs/map-layers-config.md), and [docs/geoserver-exhibition.md](docs/geoserver-exhibition.md).

## Not in the core yet

- Reverse proxy / gateway

## License

[GNU General Public License v3.0](LICENSE)
