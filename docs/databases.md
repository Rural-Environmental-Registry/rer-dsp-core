# Bancos de dados do DSP (core)

Contrato de nomes usado pelo `rer-dsp-core` na instalação local (alinhado ao backend).

## Bancos (Compose)

| Serviço Compose | Database | Papel |
| --- | --- | --- |
| `dsp-db` | `dsp-db` | Base operacional — negócio + `boundary_box` + `centroid_coordinates` (**sem** `geometry` completa) |
| `dsp-geoserver-exhibition-db` | `dsp-geoserver-exhibition-db` | Geometria completa `dsp.*` — **somente** GeoServer Exhibition |
| `dsp-job-migration-db` | `dsp-job-migration-db` | Metadados Spring Batch (`BATCH_*`) |

O banco **source** fica fora do core — configure `spring.datasource.source` em `config/Job-Data-Migration/application/application.yaml`. Para teste local: `DSP/schema_2.sql`.

## Schema `dsp` — dsp-db (operacional)

| Tabela | Colunas principais |
| --- | --- |
| `dsp.territory_level_1` | `id`, `name`, `boundary_box`, `centroid_coordinates` |
| `dsp.territory_level_2` | `id`, `name`, `parent_id` → level_1, `boundary_box`, `centroid_coordinates` |
| `dsp.territory_level_3` | `id`, `name`, `parent_id` → level_2, `boundary_box`, `centroid_coordinates` |
| `dsp.area_of_interest` | `id`, datas, `territory_level_3_id`, `area`, `theme_1`…`theme_4`, `boundary_box`, `centroid_coordinates` |

KPI measures: `area` + `theme_1`…`theme_4` (números). Labels dos temas vêm do `installation-config` (`THEME_1`…).  
Colunas geo operacionais: `boundary_box` (Polygon) e `centroid_coordinates` (Point). **Sem** polígono completo (fica no exhibition-db).

## Schema `dsp` — exhibition-db

Mesmas tabelas lógicas, **com** coluna `geometry` completa (**sem** `boundary_box` / `centroid_coordinates`):

| Tabela | Colunas geo |
| --- | --- |
| `dsp.territory_level_1` … `dsp.area_of_interest` | `geometry` |

## SRID

O SRID **não** é fixado no DDL (sem typmod, ex.: `geometry(MultiPolygon, 4674)`). Use `geometry` genérico nos scripts init.

Cada job informa `srid` no YAML (`config/Job-Data-Migration/application/application.yaml`). O writer aplica o SRID na persistência; valide com `ST_SRID(...)` conforme o YAML.

## Scripts

**dsp-db:**

- `config/db/dsp-db/00_extensions.sql`
- `config/db/dsp-db/01_admin_units.sql`
- `config/db/dsp-db/02_area_of_interest.sql`

**exhibition-db:**

- `config/db/dsp-geoserver-exhibition-db/00_extensions.sql`
- `config/db/dsp-geoserver-exhibition-db/01_admin_units.sql`
- `config/db/dsp-geoserver-exhibition-db/02_area_of_interest.sql`

**batch:**

- `config/db/dsp-job-migration-db/01_spring_batch_schema.sql`

O backend usa `spring.jpa.hibernate.ddl-auto=none` — o DDL fica só no init SQL do core.

**Importante:** scripts em `/docker-entrypoint-initdb.d` rodam só na **primeira** criação do volume. Após mudar o DDL:

```bash
docker compose down -v
./setup.sh    # remigra / repovoa
./start.sh    # sobe as apps
```

## Migração

O `./setup.sh` sobe os DBs, executa `dsp-job-migration` (dual-write em `dsp-db` + `exhibition-db`) e publica layers no GeoServer. Os dados ficam nos volumes Docker.

O `./start.sh` **não** remigra — só sobe a stack (DBs já existentes + GeoServer + FE/BE).

YAML: `config/Job-Data-Migration/application/application.yaml` — inclui `spring.datasource.target`, `spring.datasource.geo-target` e `srid` por job.

Como preencher o template ETL: [migration-config.md](migration-config.md).

Contrato transversal: [rer-dsp-docs — Bancos de dados](https://github.com/Rural-Environmental-Registry/rer-dsp-docs/blob/main/docs/architecture/databases.md).
