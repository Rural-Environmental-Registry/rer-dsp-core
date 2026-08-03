# Job data-migration — Docker

A imagem é construída a partir do Dockerfile do repositório irmão:

`../rer-dsp-job-data-migration/Dockerfile` (path configurável via `DSP_JOB_MIGRATION_PATH`).

O Compose monta `../application/application.yaml`. Configure conexões JDBC e mapeamento ETL nesse arquivo ativo (template genérico: `application.yaml.example`). Guia: [docs/migration-config.md](../../../docs/migration-config.md).
