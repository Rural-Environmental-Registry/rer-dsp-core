# Job data-migration — Docker

The image is built from the sibling repository Dockerfile:

`../rer-dsp-job-data-migration/Dockerfile` (path configurable via `DSP_JOB_MIGRATION_PATH`).

Both `dsp-job-migration` and `dsp-job-migration-db` use Compose profile `migration`.
They start when `./setup.sh` chooses option **2** (real adopter + ETL).

## Entrypoint

[`entrypoint.sh`](entrypoint.sh) is mounted as `/migration-entrypoint.sh`:

| `DSP_MIGRATION_EXECUTION_MODE` | Behaviour |
| --- | --- |
| `once` (default) | Runs `java -jar /app/app.jar` and exits — used by `compose run --rm` |
| `continuous` | Keeps the container idle (`sleep infinity`) for external scheduling |

## Setup commands

**One-time initial migration** (`once` — default):

```bash
docker compose --env-file .env --profile migration up -d dsp-job-migration-db
docker compose --env-file .env --profile migration run --rm --build \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration
```

**Continuous service** (`continuous` — after initial migration):

```bash
docker compose --env-file .env --profile migration up -d dsp-job-migration-db dsp-job-migration
```

## Re-sync (external scheduling team)

```bash
docker compose --env-file .env --profile migration run --rm \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration
```

Or inside the idle container:

```bash
docker compose --env-file .env --profile migration exec dsp-job-migration \
  java $JAVA_OPTS -jar /app/app.jar
```

Compose mounts `../application/application.yaml`. Configure JDBC connections and
ETL mapping in that active file (generic template: `application.yaml.example`).
Guide: [docs/migration-config.md](../../../docs/migration-config.md).
