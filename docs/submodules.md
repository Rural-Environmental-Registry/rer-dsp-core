# DSP repositories

The `rer-dsp-core` repository orchestrates a local/demo installation. Application code lives in sibling repositories.

| Directory (sibling of `rer-dsp-core`) | Role |
| --- | --- |
| `rer-dsp-frontend` | Vue SPA |
| `rer-dsp-backend` | Spring Boot API |
| `rer-dsp-job-data-migration` | Spring Batch geo sync (ETL) |
| `rer-dsp-job-geo-file-generation` | Geospatial file generation job |

## Expected local layout

```text
DSP/
├── rer-dsp-core/                 ← this repo
├── rer-dsp-backend/
├── rer-dsp-frontend/
├── rer-dsp-job-data-migration/
└── rer-dsp-job-geo-file-generation/
```

Paths are configurable in `.env` (`DSP_BACKEND_PATH`, `DSP_FRONTEND_PATH`, `DSP_JOB_MIGRATION_PATH`).

Databases created by this core: see [databases.md](databases.md).

## Not included yet

- GeoServer
- Reverse proxy / gateway
