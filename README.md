# RER DSP — Core

**Project**: Rural Environmental Registry — Data Sharing Platform  
**Component**: Core (installation orchestration & configuration)  
**Type**: Digital Public Good (DPG)  
**License**: GPL-3.0

---

## Overview

`rer-dsp-core` is the **installation hub** for the DSP stack (same role as RER `core`):

- Example adopter configuration (hierarchy, screens, KPIs)
- Docker Compose to run backend + frontend locally
- Docs for repositories and the installation contract

Application code lives in sibling repositories (`rer-dsp-backend`, `rer-dsp-frontend`, jobs). This repo does **not** hold domain Java libraries.

## Expected layout

```text
DSP/
├── rer-dsp-core/          ← this repository
├── rer-dsp-backend/
├── rer-dsp-frontend/
├── rer-dsp-job-data-migration/
└── rer-dsp-job-geo-file-generation/
```

See [docs/submodules.md](docs/submodules.md).

## Quick start

Prerequisites: Docker 24+ with Compose v2.

```bash
cd rer-dsp-core
cp .env.example .env
chmod +x ./start.sh
./start.sh
```

| Service | Default URL |
| --- | --- |
| Frontend | http://localhost:8081/dsp/ |
| Backend API | http://localhost:8080/dsp-backend |
| Installation config | http://localhost:8080/dsp-backend/config/installation |

Stop:

```bash
docker compose down
```

## Configuration

| Path | Purpose |
| --- | --- |
| [`.env.example`](.env.example) | Ports, paths, CORS, frontend API URL |
| [`config/installation/installation-config.json.example`](config/installation/installation-config.json.example) | Hierarchy, screens, KPIs (API contract) |
| [`config/Backend/application/application.yml.example`](config/Backend/application/application.yml.example) | Backend Spring overrides (future) |
| [`config/Frontend/environment/env.json.example`](config/Frontend/environment/env.json.example) | Runtime `urlBackend` example |
| [`config/Job-Data-Migration/application/application.yaml.example`](config/Job-Data-Migration/application/application.yaml.example) | Batch level1/2/3 mapping example |

Contract details: [docs/installation-config.md](docs/installation-config.md).

Today `GET /config/installation` is still served from a **backend mock**. The JSON example here is the shape adopters and the API must keep aligned.

## Not in this first version

- GeoServer
- Postgres/PostGIS service in Compose (pending DSP target schema)
- Job containers in Compose
- Reverse proxy / gateway

## License

[GNU General Public License v3.0](LICENSE)
