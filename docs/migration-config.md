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

The guided configuration asks for the number of available theme KPIs before
asking for their source columns. Themes that are not selected are omitted from
`business-only-persist-columns` and `column-mapping`.

## Paralelismo e jobs

- `parallelization.jobs.*` — threads, chunk e page size por job.
- `execution-jobs.*` — liga/desliga cada job (`true`/`false`).

Ajuste conforme o volume da sua origem.

## Relacionados

- Bancos e schema destino: [databases.md](databases.md)
- Labels de hierarquia e KPIs: [installation-config.md](installation-config.md)
- Camadas WMS: [map-layers-config.md](map-layers-config.md)
- GeoServer Exhibition: [geoserver-exhibition.md](geoserver-exhibition.md)
