# RER DSP — Core

**Projeto**: Rural Environmental Registry — Data Sharing Platform  
**Componente**: Core (orquestração e configuração da instalação)  
**Tipo**: Digital Public Good (DPG)  
**Licença**: GPL-3.0

---

## Visão geral

O `rer-dsp-core` é o **hub de instalação** da stack DSP (mesmo papel do `core` do RER):

- Exemplos de configuração do adotante (hierarquia, telas, KPIs, camadas do mapa)
- Init SQL e Docker Compose para bancos `dsp-db` e `dsp-job-migration-db`
- GeoServer Exhibition (WMS do mapa)
- Job de migração opcional (`DSP_RUN_MIGRATION=true`)
- Docker Compose para subir backend + frontend localmente

O código das aplicações fica nos repositórios irmãos. Este repo **não** é uma biblioteca Java de domínio.

## Layout esperado

```text
DSP/
├── rer-dsp-core/          ← este repositório
├── rer-dsp-backend/
├── rer-dsp-frontend/
├── rer-dsp-job-data-migration/
└── rer-dsp-job-geo-file-generation/
```

Veja [docs/submodules.md](docs/submodules.md) e [docs/databases.md](docs/databases.md).

## Início rápido

Pré-requisitos: Docker 24+ com Compose v2.

```bash
cd rer-dsp-core
cp .env.example .env
chmod +x ./start.sh
./start.sh
```

Na primeira execução, o `./start.sh` cria os arquivos de configuração a partir dos templates e **interrompe** até você editá-los:

- `config/installation/installation-config.json` — labels da UI, telas, KPIs
- `config/map/mapLayersConfig.json` — camadas WMS do GeoServer

Execute `./start.sh` novamente após editar os dois arquivos.

Com migração a partir do banco externo do adotante:

```bash
# Edite config/Job-Data-Migration/application/application.yaml (JDBC + mapeamento ETL)
DSP_RUN_MIGRATION=true ./start.sh
```

| Serviço | URL / porta padrão |
| --- | --- |
| Frontend | http://localhost:22667/dsp/ |
| Backend API | http://localhost:22666/dsp-backend |
| Config da instalação | http://localhost:22666/dsp-backend/config/installation |
| Camadas do mapa | http://localhost:22666/dsp-backend/map/getLayers |
| GeoServer Exhibition | http://localhost:22668/geoserver/web/ |
| GeoServer WMS | http://localhost:22668/geoserver/dsp/wms |
| DSP DB (`dsp-db`) | localhost:20654 |
| Job migration DB (`dsp-job-migration-db`) | localhost:20655 |

Conferir tabelas:

```bash
docker compose exec dsp-db psql -U dsp -d dsp-db -c '\dt dsp.*'
docker compose exec dsp-job-migration-db psql -U dsp_job -d dsp-job-migration-db -c '\dt BATCH*'
```

Parar / recriar bancos:

```bash
docker compose down
docker compose down -v   # reaplica init SQL
```

## Configuração

| Caminho | Função |
| --- | --- |
| [`.env.example`](.env.example) | Portas, DBs, `DSP_RUN_MIGRATION` |
| [`config/db/dsp-db/`](config/db/dsp-db/) | Init SQL PostGIS + `dsp.territory_level_*` + `dsp.area_of_interest` |
| [`config/db/dsp-job-migration-db/`](config/db/dsp-job-migration-db/) | Init SQL `BATCH_*` |
| [`config/Job-Data-Migration/application/application.yaml`](config/Job-Data-Migration/application/application.yaml) | Conexões JDBC + mapeamento ETL do job |
| [`config/installation/installation-config.json.example`](config/installation/installation-config.json.example) | Template: hierarquia, telas, KPIs (arquivo ativo criado pelo `start.sh`) |
| [`config/map/mapLayersConfig.json.example`](config/map/mapLayersConfig.json.example) | Template: camadas WMS / GeoServer (arquivo ativo criado pelo `start.sh`) |
| [`config/GeoserverExhibition/docker/`](config/GeoserverExhibition/docker/) | Imagem GeoServer Exhibition + script de populate |

Veja também [docs/installation-config.md](docs/installation-config.md), [docs/map-layers-config.md](docs/map-layers-config.md) e [docs/geoserver-exhibition.md](docs/geoserver-exhibition.md).

## Ainda fora do core

- Proxy reverso / gateway

## Licença

[GNU General Public License v3.0](LICENSE)
