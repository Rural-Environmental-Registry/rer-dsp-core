# Job data-migration — Docker

The image is built from the sibling repository Dockerfile:

`../rer-dsp-job-data-migration/Dockerfile` (path configurable via `DSP_JOB_MIGRATION_PATH`).

Both `dsp-job-migration` and `dsp-job-migration-db` use Compose profile `migration`.

## Entrypoint

[`entrypoint.sh`](entrypoint.sh) is mounted as `/migration-entrypoint.sh`:

| `DSP_MIGRATION_EXECUTION_MODE` | Behaviour |
| --- | --- |
| `once` (default) | Runs `java -jar /app/app.jar` and exits — used by `compose run --rm` and setup option 2 |
| `continuous` | If `DSP_MIGRATION_SCHEDULED_AT` is set (option 3), waits, runs one first load, then `supercronic` on `DSP_MIGRATION_CRON`. Option 2 continuous has no wait (first load already ran in setup). |
| `scheduled-once` | Waits until `DSP_MIGRATION_SCHEDULED_AT`, runs once, exits (setup option 3 + once) |

| Variable | Notes |
| --- | --- |
| `DSP_MIGRATION_CRON` | 5-field cron (e.g. `0 22 * * *`). `continuous` only. |
| `DSP_MIGRATION_SCHEDULED_AT` | `YYYY-MM-DD HH:MM:SS`. Required for `scheduled-once`; optional first load for `continuous` (option 3). |
| `DSP_MIGRATION_TZ` | IANA timezone for wall clock. Default `UTC`. |

The JAR stays one-shot. Overlap: `flock` in the supercronic wrapper. A failed JAR does not stop the continuous container.

## Commands

**One-time now** (`once`):

```bash
docker compose --env-file .env --profile migration up -d dsp-job-migration-db
docker compose --env-file .env --profile migration run --rm --build \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration
```

**Scheduled service** (`continuous` or `scheduled-once`):

```bash
docker compose --env-file .env --profile migration up -d dsp-job-migration-db dsp-job-migration
```

Optional extra one-shot on top of the schedule:

```bash
docker compose --env-file .env --profile migration run --rm \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration
```

Compose mounts `../application/application.yaml`.
