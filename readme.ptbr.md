# RER DSP — Core

**Projeto**: Rural Environmental Registry — Data Sharing Platform  
**Componente**: Core (orquestração e configuração da instalação)  
**Tipo**: Digital Public Good (DPG)  
**Licença**: GPL-3.0

---

## Visão geral

O `rer-dsp-core` é o **hub de instalação** da stack DSP (mesmo papel do `core` do RER):

- Exemplos de configuração do adotante (hierarquia, telas, KPIs)
- Init SQL e Docker Compose para bancos `dsp-db` e `dsp-job-migration-db`
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

Com migração a partir do banco externo do adotante:

```bash
# Ajuste DSP_SOURCE_* e o YAML em config/Job-Data-Migration/application/
DSP_RUN_MIGRATION=true ./start.sh
```

| Serviço | URL / porta padrão |
| --- | --- |
| Frontend | http://localhost:8081/dsp/ |
| Backend API | http://localhost:8080/dsp-backend |
| Config da instalação | http://localhost:8080/dsp-backend/config/installation |
| DSP DB (`dsp-db`) | localhost:5433 |
| Job migration DB (`dsp-job-migration-db`) | localhost:5434 |

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
| [`.env.example`](.env.example) | Portas, DBs, source JDBC, `DSP_RUN_MIGRATION` |
| [`config/db/dsp-db/`](config/db/dsp-db/) | Init SQL PostGIS + `dsp.level1/2/3` |
| [`config/db/dsp-job-migration-db/`](config/db/dsp-job-migration-db/) | Init SQL `BATCH_*` |
| [`config/Job-Data-Migration/application/application.yaml`](config/Job-Data-Migration/application/application.yaml) | Mapeamento ETL do job |
| [`config/installation/installation-config.json`](config/installation/installation-config.json) | Hierarquia, telas, KPIs (montado no backend) |

## Ainda fora do core

- GeoServer
- Proxy reverso / gateway

## Licença

[GNU General Public License v3.0](LICENSE)
