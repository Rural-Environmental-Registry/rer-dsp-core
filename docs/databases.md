# Bancos de dados do DSP (core)

Contrato de nomes usado pelo `rer-dsp-core` na instalação local.

## Bancos

| Serviço Compose | Database | Papel |
| --- | --- | --- |
| `dsp-db` | `dsp-db` | Base operacional PostGIS (dados consumidos pela API) |
| `dsp-job-migration-db` | `dsp-job-migration-db` | Metadados do Spring Batch (`BATCH_*`) do job de migração |

O banco **source** (origem da migração) fica fora do core — é o PostgreSQL externo do adotante (`DSP_SOURCE_JDBC_URL`).

## Schema e tabelas em `dsp-db`

Schema: `dsp`

| Tabela | Nível | Colunas |
| --- | --- | --- |
| `dsp.level1` | Level 1 | `id`, `label`, `geometry` |
| `dsp.level2` | Level 2 | `id`, `label`, `level1_id` → `level1`, `geometry` |
| `dsp.level3` | Level 3 | `id`, `label`, `level2_id` → `level2`, `geometry` |

Nomes alinhados ao contrato de instalação e às entidades JPA do backend (`TerritoryLevel*`).

O backend usa `spring.jpa.hibernate.ddl-auto=none` — o DDL fica só no init SQL do core.

## Schema em `dsp-job-migration-db`

Tabelas oficiais do Spring Batch 5 (`BATCH_JOB_*`, `BATCH_STEP_*` + sequences). Criadas por init SQL; o job usa `spring.batch.jdbc.initialize-schema: never`.

## Migração (`DSP_RUN_MIGRATION`)

Com `DSP_RUN_MIGRATION=true`, o `start.sh`:

1. Sobe `dsp-db` e `dsp-job-migration-db`
2. Executa o serviço one-shot `dsp-job-migration` (profile `migration`)
3. Sobe backend e frontend

Configuração do job: `config/Job-Data-Migration/application/application.yaml`  
Ajuste `source-table` / `column-mapping` ao schema do banco externo.

## Onde estão os scripts

- `config/db/dsp-db/` — extensão PostGIS + tabelas `dsp.level*`
- `config/db/dsp-job-migration-db/` — schema `BATCH_*`

Scripts em `/docker-entrypoint-initdb.d` rodam **somente** na primeira criação do volume Docker.
