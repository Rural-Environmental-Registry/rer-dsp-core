# Job data-migration — Docker

The image is built from the sibling repository Dockerfile:

`../rer-dsp-job-data-migration/Dockerfile` (path configurable via `DSP_JOB_MIGRATION_PATH`).

Both `dsp-job-migration` and `dsp-job-migration-db` use Compose profile `migration`.
They start only when `./setup.sh` chooses option **2** (real adopter + ETL):

```bash
docker compose --env-file .env --profile migration up -d dsp-job-migration-db
docker compose --env-file .env --profile migration run --rm --build dsp-job-migration
```

Compose mounts `../application/application.yaml`. Configure JDBC connections and
ETL mapping in that active file (generic template: `application.yaml.example`).
Guide: [docs/migration-config.md](../../../docs/migration-config.md).
