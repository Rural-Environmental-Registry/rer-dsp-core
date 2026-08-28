# Job data-migration — Docker

The image is built from the sibling repository Dockerfile:

`../rer-dsp-job-data-migration/Dockerfile` (path configurable via `DSP_JOB_MIGRATION_PATH`).

The `dsp-job-migration` service uses Compose profile `migration`. Batch metadata lives in `dsp-db` schema `data_migration`.

## Entrypoint

[`entrypoint.sh`](entrypoint.sh) is mounted as `/migration-entrypoint.sh`:

| `DSP_MIGRATION_EXECUTION_MODE` | Behaviour |
| --- | --- |
| `once` (default) | Runs `java -jar /app/app.jar` and exits — used by `compose run --rm` and setup option 2 |
| `continuous` | If `DSP_MIGRATION_SCHEDULED_AT` is set (option 3), waits, runs one first load, publishes both GeoServers, then `supercronic` on `DSP_MIGRATION_CRON`. Option 2 continuous has no wait (first load and populate already ran in setup). |
| `scheduled-once` | Waits until `DSP_MIGRATION_SCHEDULED_AT`, runs once, publishes both GeoServers, exits (setup option 3 + once) |

| Variable | Notes |
| --- | --- |
| `DSP_MIGRATION_CRON` | 5-field cron (e.g. `0 22 * * *`). `continuous` only. |
| `DSP_MIGRATION_SCHEDULED_AT` | `YYYY-MM-DD HH:MM:SS`. Required for `scheduled-once`; optional first load for `continuous` (option 3). |
| `DSP_MIGRATION_TZ` | IANA timezone for wall clock. Read from `.env` (see `.env.example`). |

The JAR stays one-shot. Overlap: `flock` in the supercronic wrapper. A failed JAR does not stop the continuous container.

Option 3: [`publish_geoservers.sh`](publish_geoservers.sh) runs the same `populate_geoserver.sh` used by `./setup.sh`, against Exhibition and Download on the Docker network, after the first successful scheduled load.

## Commands

**One-time now** (`once`):

```bash
docker compose --env-file .env --profile migration run --rm --build \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration
```

**Scheduled service** (`continuous` or `scheduled-once`):

```bash
docker compose --env-file .env --profile migration up -d dsp-job-migration
```

Optional extra one-shot on top of the schedule:

```bash
docker compose --env-file .env --profile migration run --rm \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration
```

Compose mounts `../application/application.yaml`.
