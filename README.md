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
chmod +x ./setup.sh ./start.sh ./config.sh
```

Configure the adopter without editing internal files:

```bash
./config.sh       # guided wizard; menu to reapply, edit, or start over
```

The wizard writes `config/adopter/adopter-config.yaml` and generates the
operational JSON/YAML files. The override file contains only editable fields;
contract keys such as WMS IDs, target tables, and KPI codes remain protected in
the core templates.

```bash
./setup.sh    # interactive menu: demo / real+ETL / real without migration / status
./start.sh    # start the application (does not remigrate)
```

`./setup.sh` always asks how to prepare data:

1. **Demonstration** — built-in Brazil seed (no JDBC; no migration job DB)
2. **Real adopter + ETL** — migrate from JDBC (`./config.sh` first)
3. **Real adopter without migration** — empty DBs + GeoServer only
4. **Stack status / cleanup**

Demo with map data: `./setup.sh` (option 1) then `./start.sh` — see [docs/quickstart.md](docs/quickstart.md).

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
docker compose --env-file .env --profile migration down              # stop containers; keeps volumes (data)
docker compose --env-file .env --profile migration down -v           # wipe volumes — then run ./setup.sh again
```

## Configuration

| Path | Purpose |
| --- | --- |
| [`.env.example`](.env.example) | Ports, DBs, repository paths |
| [`setup.sh`](setup.sh) / [`start.sh`](start.sh) | Setup (data) vs start (apps) — see [scripts/README.md](scripts/README.md) |
| [`config/db/dsp-db/`](config/db/dsp-db/) | PostGIS init SQL + `dsp.territory_level_*` + `dsp.area_of_interest` |
| [`config/db/dsp-job-migration-db/`](config/db/dsp-job-migration-db/) | `BATCH_*` init SQL |
| [`config/Job-Data-Migration/application/application.yaml`](config/Job-Data-Migration/application/application.yaml) | JDBC connections + job ETL mapping |
| [`config/installation/installation-config.json.example`](config/installation/installation-config.json.example) | Template: hierarchy, screens, KPIs |
| [`config/map/mapLayersConfig.json.example`](config/map/mapLayersConfig.json.example) | Template: WMS layers / GeoServer |
| [`config/GeoserverExhibition/docker/`](config/GeoserverExhibition/docker/) | GeoServer Exhibition image + populate script |

See also [docs/quickstart.md](docs/quickstart.md), [docs/migration-config.md](docs/migration-config.md), [docs/installation-config.md](docs/installation-config.md), [docs/map-layers-config.md](docs/map-layers-config.md), and [docs/geoserver-exhibition.md](docs/geoserver-exhibition.md).

## Not in the core yet

- Reverse proxy / gateway

## License

[GNU General Public License v3.0](LICENSE)
