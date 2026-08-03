# Configuração da migração de dados (ETL)

Contrato do YAML usado pelo job `dsp-job-migration` para ler a origem do adotante e gravar em `dsp-db` + `dsp-geoserver-exhibition-db`.

## Arquivos

| Arquivo | Papel |
| --- | --- |
| [`config/Job-Data-Migration/application/application.yaml.example`](../config/Job-Data-Migration/application/application.yaml.example) | Template genérico (versionado) |
| `config/Job-Data-Migration/application/application.yaml` | Arquivo ativo (local, gitignored) |

O Docker Compose monta apenas o arquivo ativo em `/config/application.yaml` no container do job.

## Fluxo no primeiro uso

1. Rode `./setup.sh`. Se `application.yaml` não existir, o script copia o `.example` e interrompe.
2. Edite o arquivo ativo: substitua os placeholders `<...>` pelas tabelas/colunas da sua origem e ajuste `where-clause`, paralelismo e SRIDs se necessário.
3. Configure a origem no `.env` (`DSP_SOURCE_JDBC_URL`, `DSP_SOURCE_DB_USER`, `DSP_SOURCE_DB_PASSWORD`).
4. Rode `./setup.sh` de novo. Enquanto o ativo for idêntico ao template, a migração fica bloqueada (use `--skip-migration` se quiser só subir bancos/GeoServer, ou escolha demonstration / `--quickstart` para seed embutido — ver [quickstart.md](quickstart.md)).

## Datasources

| Prefixo YAML | Destino | Observação |
| --- | --- | --- |
| `spring.datasource.source` | Banco do adotante | Vem do `.env` / Compose |
| `spring.datasource.target` | `dsp-db` | Negócio + bbox/centroid |
| `spring.datasource.geo-target` | `dsp-geoserver-exhibition-db` | Geometria completa para o GeoServer |
| `spring.datasource.batch` | `dsp-job-migration-db` | Metadados Spring Batch |

## Contrato ETL (`batch`)

Quatro jobs fixos: `admin-unit.level-1`, `level-2`, `level-3` e `area-of-interest`.

### Campos por entidade

| Campo | Função |
| --- | --- |
| `source-table` | Tabela ou subquery SQL na origem |
| `target-table` | Tabela destino (`dsp.territory_level_*` ou `dsp.area_of_interest`) |
| `primary-key` | Coluna PK na origem |
| `partition-column` | Particionamento paralelo (L2/L3; em geral o parent) |
| `geometry-column` | Coluna geométrica na origem |
| `where-clause` | Filtro SQL adicional |
| `comparison-columns` | Colunas para detecção de mudança |
| `persist-columns` | Colunas gravadas em business + exhibition |
| `business-only-persist-columns` | Só `dsp-db` (ex.: medidas `theme_*`) |
| `column-mapping` | Mapa origem → coluna destino |
| `layer-name` | Nome da layer no GeoServer |
| `srid` | SRID aplicado na persistência |
| `change-detection-strategy` | Em geral `DEFAULT` |

### Destinos esperados no `column-mapping`

**Níveis territoriais (L1–L3):** `id`, `name`, `geometry`; em L2/L3 também `parent_id`.

**Área de interesse:** `id`, `registration_date`, `alteration_date`, `territory_level_3_id`, `area`, `geometry`; opcionalmente `theme_1`…`theme_4`.

KPIs da UI leem `theme_*` via [installation-config](installation-config.md) (`THEME_1`…`THEME_4`). Os rótulos ficam no JSON de instalação; o YAML só mapeia as colunas numéricas.

## Paralelismo e jobs

- `parallelization.jobs.*` — threads, chunk e page size por job.
- `execution-jobs.*` — liga/desliga cada job (`true`/`false`).

Ajuste conforme o volume da sua origem.

## Relacionados

- Bancos e schema destino: [databases.md](databases.md)
- Labels de hierarquia e KPIs: [installation-config.md](installation-config.md)
- Camadas WMS: [map-layers-config.md](map-layers-config.md)
- GeoServer Exhibition: [geoserver-exhibition.md](geoserver-exhibition.md)
