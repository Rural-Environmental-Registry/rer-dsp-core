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
- `./setup.sh` — migração de dados + populate (uma vez; dados nos volumes Docker)
- `./start.sh` — sobe backend + frontend + GeoServer (dia a dia; **não** remigra)

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
chmod +x ./setup.sh ./start.sh
```

Edite (os scripts criam a partir dos `.example` e **interrompem** se ainda forem idênticos ao template):

- `config/installation/installation-config.json` — labels da UI, telas, KPIs
- `config/map/mapLayersConfig.json` — camadas WMS do GeoServer
- `config/Job-Data-Migration/application/application.yaml` — JDBC + mapeamento ETL (para migrar)

```bash
./setup.sh    # bancos + migração + publish GeoServer (dados ficam nos volumes)
./start.sh    # sobe a aplicação (não remigra)
```

UI sem dados do CAR: `./setup.sh --skip-migration` e depois `./start.sh`.

Ajuste só no frontend: `docker compose up -d --build dsp-frontend` (não use `down -v`).

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
docker compose down              # para containers; mantém volumes (dados)
docker compose down -v           # apaga volumes — depois rode ./setup.sh de novo
```

## Configuração

| Caminho | Função |
| --- | --- |
| [`.env.example`](.env.example) | Portas, DBs, `DSP_SKIP_MIGRATION` |
| [`setup.sh`](setup.sh) / [`start.sh`](start.sh) | Setup (dados) vs start (apps) — ver [scripts/README.md](scripts/README.md) |
| [`config/db/dsp-db/`](config/db/dsp-db/) | Init SQL PostGIS + `dsp.territory_level_*` + `dsp.area_of_interest` |
| [`config/db/dsp-job-migration-db/`](config/db/dsp-job-migration-db/) | Init SQL `BATCH_*` |
| [`config/Job-Data-Migration/application/application.yaml`](config/Job-Data-Migration/application/application.yaml) | Conexões JDBC + mapeamento ETL do job |
| [`config/installation/installation-config.json.example`](config/installation/installation-config.json.example) | Template: hierarquia, telas, KPIs |
| [`config/map/mapLayersConfig.json.example`](config/map/mapLayersConfig.json.example) | Template: camadas WMS / GeoServer |
| [`config/GeoserverExhibition/docker/`](config/GeoserverExhibition/docker/) | Imagem GeoServer Exhibition + script de populate |

Veja também [docs/installation-config.md](docs/installation-config.md), [docs/map-layers-config.md](docs/map-layers-config.md) e [docs/geoserver-exhibition.md](docs/geoserver-exhibition.md).

## Ainda fora do core

- Proxy reverso / gateway

## Licença

[GNU General Public License v3.0](LICENSE)
