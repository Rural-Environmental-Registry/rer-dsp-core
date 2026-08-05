# Configuração da migração de dados (ETL)

Contrato do YAML usado pelo job `dsp-job-migration` para ler a origem do adotante e gravar em `dsp-db` + `dsp-geoserver-exhibition-db`.

## Arquivos

| Arquivo | Papel |
| --- | --- |
| [`config/Job-Data-Migration/application/application.yaml.example`](../config/Job-Data-Migration/application/application.yaml.example) | Template genérico (versionado) |
| `config/Job-Data-Migration/application/application.yaml` | Arquivo ativo (local, gitignored) |

O Docker Compose monta apenas o arquivo ativo em `/config/application.yaml` no container do job.

## Fluxo no primeiro uso

1. Run `./config.sh` and provide the source database, tables, and columns.
2. The wizard generates `application.yaml` with protected targets and layer names.
3. In advanced mode, fill in `config/adopter/adopter-config.yaml` and run `./config.sh`
   (choose reapply or edit when prompted).
4. Run `./setup.sh` and choose:
   - **2** — migrate from JDBC (builds/runs `dsp-job-migration`, starts
     `dsp-job-migration-db` via Compose profile `migration`)
   - **3** — real adopter without ETL (empty DBs + GeoServer only)
   - **1** — demonstration seed (no JDBC) — see [quickstart.md](quickstart.md)

Migration remains blocked while placeholders exist in `application.yaml`.

## Modos de execução

Escolhidos no `./setup.sh` (opção 2 → submenu). O valor fica em `.env` como `DSP_MIGRATION_EXECUTION_MODE`.

| Modo | Quando usar | Comportamento |
| --- | --- | --- |
| `once` | Primeira carga / import pontual | Job roda uma vez no setup (`compose run --rm`); container some ao terminar; `./start.sh` não sobe migration |
| `continuous` | Origem muda com frequência; agendamento externo | Setup faz carga inicial + deixa `dsp-job-migration-db` e `dsp-job-migration` ativos; `./start.sh` mantém a stack migration |

O modo `continuous` **não implementa agendamento** neste repositório — apenas mantém os containers prontos para outra equipe disparar re-syncs.

### Re-sync manual (modo `continuous`)

```bash
# Execução pontual (recomendado)
docker compose --env-file .env --profile migration run --rm \
  -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration

# Dentro do container em idle
docker compose --env-file .env --profile migration exec dsp-job-migration \
  java $JAVA_OPTS -jar /app/app.jar
```

Cada reexecução usa detecção de mudanças (`change-detection-strategy: DEFAULT`) — só registros alterados na origem são reprocessados.

**Limitação:** invalidação automática de cache GeoServer após re-sync ainda não está implementada no job; re-syncs frequentes podem exigir truncate manual do GWC até essa integração existir.

## Datasources

| Prefixo YAML | Destino | Observação |
| --- | --- | --- |
| `spring.datasource.source` | Banco do adotante | Vem do `.env` / Compose |
| `spring.datasource.target` | `dsp-db` | Negócio + bbox/centroid |
| `spring.datasource.geo-target` | `dsp-geoserver-exhibition-db` | Geometria completa para o GeoServer |
| `spring.datasource.batch` | `dsp-job-migration-db` | Metadados Spring Batch |

## ETL contract (`batch`)

Four fixed jobs: `admin-unit.level-1`, `level-2`, `level-3`, and `area-of-interest`, plus optional **generic layers** under `batch.layers`.

### Fixed entity fields

| Field | Role |
| --- | --- |
| `source-table` | Source table or SQL subquery |
| `target-table` | Target table (`dsp.territory_level_*` or `dsp.area_of_interest`) |
| `primary-key` | Source PK column |
| `partition-column` | Parallel partition key (L2/L3; usually parent) |
| `geometry-column` | Source geometry column |
| `where-clause` | Extra SQL filter |
| `comparison-columns` | Columns used for change detection |
| `persist-columns` | Columns written to business + exhibition |
| `business-only-persist-columns` | `dsp-db` only (e.g. `theme_*` measures) |
| `column-mapping` | Source → target column map |
| `layer-name` | GeoServer layer name (without workspace) |
| `srid` | SRID applied on persist |
| `change-detection-strategy` | Usually `DEFAULT` |

### Generic layers (`batch.layers`)

Generated from `etl.layers` in `adopter-config.yaml` by `./config.sh`. Each item migrates **only** to geo-target (`dsp.<table>`). WMS publishing is owned by core (`./setup.sh` → `populate_geoserver.sh`), not by the job.

| Field | Role |
| --- | --- |
| `source-table` | Source `schema.table` (required) |
| `area-of-interest-id-column` | Source column linking each feature to an AOI (required) |
| `layer-name` | WMS id without workspace; default = table name |
| `srid` | Source / target SRID |
| `where-clause` | Optional filter (default `1=1`) |
| `primary-key` / `geometry-column` | Optional overrides when introspection is ambiguous |
| `enabled` | Skip when `false` |

Enable with `execution-jobs.layer-jobs: true` (also `etl.jobs.layer_jobs` in adopter-config).

See [map-layers-config.md](map-layers-config.md) for presentation fields (`display_name`, colors, groups).

### Expected `column-mapping` targets (fixed jobs)

**Territory levels (L1–L3):** `id`, `name`, `geometry`; L2/L3 also `parent_id`.

**Area of interest:** `id`, `registration_date`, `alteration_date`, `territory_level_3_id`, `area`, `geometry`; optionally `theme_1`…`theme_4`.

UI KPIs read `theme_*` via [installation-config](installation-config.md) (`THEME_1`…`THEME_4`). Labels live in the installation JSON; the YAML only maps numeric columns.

The guided configuration asks for the number of available theme KPIs before
asking for their source columns. Themes that are not selected are omitted from
`business-only-persist-columns` and `column-mapping`.

## Parallelism and jobs

- `parallelization.jobs.*` — threads, chunk, and page size per job.
- `execution-jobs.*` — enable/disable each job (`true`/`false`), including `layer-jobs`.

Tune for your source volume.

## Related

- Target databases and schemas: [databases.md](databases.md)
- Hierarchy and KPI labels: [installation-config.md](installation-config.md)
- WMS layers: [map-layers-config.md](map-layers-config.md)
- GeoServer Exhibition: [geoserver-exhibition.md](geoserver-exhibition.md)
