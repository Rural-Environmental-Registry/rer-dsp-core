# Bancos de dados do DSP (core)

Contrato de nomes usado pelo `rer-dsp-core` na instalação local (alinhado ao backend).

## Bancos

| Serviço Compose | Database | Papel |
| --- | --- | --- |
| `dsp-db` | `dsp-db` | Base operacional PostGIS (API) |
| `dsp-job-migration-db` | `dsp-job-migration-db` | Metadados Spring Batch (`BATCH_*`) |

O banco **source** fica fora do core — configure `spring.datasource.source` em `config/Job-Data-Migration/application/application.yaml`. Para teste local: `DSP/schema_2.sql`.

## Schema `dsp` (destino)

| Tabela | Colunas |
| --- | --- |
| `dsp.territory_level_1` | `id`, `name`, `geometry` (MultiPolygon **4674**) |
| `dsp.territory_level_2` | `id`, `name`, `parent_id` → level_1, `geometry` |
| `dsp.territory_level_3` | `id`, `name`, `parent_id` → level_2, `geometry` |
| `dsp.area_of_interest` | `id`, `registration_date`, `alteration_date`, `territory_level_3_id`, `area`, `geometry` |

SRID **4674** (SIRGAS 2000) — alinhado ao job CAR (`srid: 4674` no YAML). Se o DDL antigo estava em 4326, use `docker compose down -v` para recriar.

Scripts:

- `config/db/dsp-db/00_extensions.sql`
- `config/db/dsp-db/01_admin_units.sql`
- `config/db/dsp-db/02_area_of_interest.sql`
- `config/db/dsp-job-migration-db/01_spring_batch_schema.sql`

O backend usa `spring.jpa.hibernate.ddl-auto=none` — o DDL fica só no init SQL do core.

**Importante:** scripts em `/docker-entrypoint-initdb.d` rodam só na **primeira** criação do volume. Após mudar o DDL:

```bash
docker compose down -v
./start.sh
```

## Migração

Com `DSP_RUN_MIGRATION=true`, o `start.sh` sobe os DBs, executa `dsp-job-migration` e sobe FE/BE.

YAML: `config/Job-Data-Migration/application/application.yaml`
