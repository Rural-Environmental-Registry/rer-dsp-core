# RER DSP — Core

**Project**: Rural Environmental Registry — Data Sharing Platform  
**Component**: Core (installation orchestration & configuration)  
**Type**: Digital Public Good (DPG)  
**License**: GPL-3.0

---

## Overview

`rer-dsp-core` is the **installation hub** for the DSP stack (same role as RER `core`):

- Example adopter configuration (hierarchy, screens, KPIs)
- Init SQL and Docker Compose for databases `dsp-db` and `dsp-job-migration-db`
- Optional migration job (`DSP_RUN_MIGRATION=true`)
- Docker Compose to run backend + frontend locally

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
chmod +x ./start.sh
./start.sh
```

With migration from the adopter external database:

```bash
# Adjust DSP_SOURCE_* and config/Job-Data-Migration/application/application.yaml
DSP_RUN_MIGRATION=true ./start.sh
```

| Service | Default URL / port |
| --- | --- |
| Frontend | http://localhost:8081/dsp/ |
| Backend API | http://localhost:8080/dsp-backend |
| Installation config | http://localhost:8080/dsp-backend/config/installation |
| DSP DB (`dsp-db`) | localhost:5433 |
| Job migration DB (`dsp-job-migration-db`) | localhost:5434 |

Verify tables:

```bash
docker compose exec dsp-db psql -U dsp -d dsp-db -c '\dt dsp.*'
docker compose exec dsp-job-migration-db psql -U dsp_job -d dsp-job-migration-db -c '\dt BATCH*'
```

Stop / recreate databases:

```bash
docker compose down
docker compose down -v   # re-runs init SQL
```

## Configuration

| Path | Purpose |
| --- | --- |
| [`.env.example`](.env.example) | Ports, DBs, source JDBC, `DSP_RUN_MIGRATION` |
| [`config/db/dsp-db/`](config/db/dsp-db/) | PostGIS init SQL + `dsp.level1/2/3` |
| [`config/db/dsp-job-migration-db/`](config/db/dsp-job-migration-db/) | `BATCH_*` init SQL |
| [`config/Job-Data-Migration/application/application.yaml`](config/Job-Data-Migration/application/application.yaml) | Job ETL mapping |
| [`config/installation/installation-config.json`](config/installation/installation-config.json) | Hierarchy, screens, KPIs (mounted into backend) |

## Not in the core yet

- GeoServer
- Reverse proxy / gateway

## License

[GNU General Public License v3.0](LICENSE)
