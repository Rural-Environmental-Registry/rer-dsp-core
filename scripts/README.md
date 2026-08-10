# Scripts do core

## Orquestração local

| Script | Papel |
|--------|--------|
| [`../setup.sh`](../setup.sh) | Bancos + migração de dados ou seed + populate GeoServer (menu interativo) |
| [`../start.sh`](../start.sh) | Sobe GeoServer + backend + frontend; em modo `continuous`, mantém stack migration |
| [`../config.sh`](../config.sh) | Wizard de configuração do adotante (menu: reaplicar, editar ou recomeçar) |
| [`common.sh`](common.sh) | Helpers compartilhados (source pelos scripts) |

```bash
./config.sh   # wizard do adotante (fluxo real)
./setup.sh    # menu: demo / real+ETL / real sem migração / status
./start.sh    # sobe a aplicação
```

`setup.sh` always runs interactively (no CLI flags). Options:

1. **Demonstration** — built-in Brazil seed; no JDBC; no migration job DB.
2. **Real + ETL** — requires `./config.sh`; submenu **once** (pontual) ou **continuous** (serviço com re-sync periódico).
3. **Real without migration** — requires `./config.sh`; empty app DBs + GeoServer only.
4. **Stack status / cleanup** — URLs and optional `docker compose --env-file .env --profile migration down -v --rmi all`.

Modo ETL (`.env`):

- **once** (`DSP_MIGRATION_EXECUTION_MODE=once`) — migração inicial no setup; job some ao terminar; `./start.sh` não sobe migration.
- **continuous** — carga inicial + containers ativos; entrypoint re-sincroniza a cada `DSP_MIGRATION_SYNC_INTERVAL` (default `1h`). Detalhe: [migration-config.md](../docs/migration-config.md).

`config.sh` fills `config/adopter/adopter-config.yaml`. When the file already
exists, choose **1** to reapply, **2** to edit via wizard (current values shown
in brackets), or **3** to start over from the template. It generates
`installation-config.json`, `mapLayersConfig.json`, and
`Job-Data-Migration/application/application.yaml`.
`setup.sh` Step 4 reapplies the adopter config quietly (`--quiet`); the migration
preview (Step 7) resolves the JDBC `source` datasource from `.env` instead of
showing `${DSP_SOURCE_*}` placeholders from `application.yaml`.
`setup.sh` and `start.sh` do not create active files from `.example`. Do not edit
the generated contract keys directly.

In demonstration mode, `start.sh` does not require `adopter-config.yaml` and
uses SRID 4674 temporarily without changing values persisted in `.env`.

Demo: [docs/quickstart.md](../docs/quickstart.md). Seed SQL: [`config/db/seed/quickstart/`](../config/db/seed/quickstart/).

## Stack status

Option **4** in `./setup.sh` and the end of `./start.sh` show each Compose
service as `STOPPED`, `RUNNING`, `HEALTHY`, `UNHEALTHY`, or `STARTING` from Docker state
and healthchecks. HTTP endpoints are listed but not probed.
`dsp-job-migration-db` appears in URLs only when that container is running.

## GeoServer

- Compose: `dsp-geoserver-exhibition`
- Docs: [docs/geoserver-exhibition.md](../docs/geoserver-exhibition.md)
- Populate: `./setup.sh` (publica layers via `/opt/populate_geoserver.sh`)

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```

Default WMS: http://localhost:22668/geoserver/dsp/wms
