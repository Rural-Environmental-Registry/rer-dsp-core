# RER DSP — Core

**Projeto**: Rural Environmental Registry — Data Sharing Platform  
**Componente**: Core (orquestração e configuração da instalação)  
**Tipo**: Digital Public Good (DPG)  
**Licença**: GPL-3.0

---

## Visão geral

O `rer-dsp-core` é o **hub de instalação** da stack DSP (mesmo papel do `core` do RER):

- Exemplos de configuração do adotante (hierarquia, telas, KPIs)
- Docker Compose para subir backend + frontend localmente
- Documentação dos repositórios e do contrato de instalação

O código das aplicações fica nos repositórios irmãos (`rer-dsp-backend`, `rer-dsp-frontend`, jobs). Este repo **não** é uma biblioteca Java de domínio.

## Layout esperado

```text
DSP/
├── rer-dsp-core/          ← este repositório
├── rer-dsp-backend/
├── rer-dsp-frontend/
├── rer-dsp-job-data-migration/
└── rer-dsp-job-geo-file-generation/
```

Veja [docs/submodules.md](docs/submodules.md).

## Início rápido

Pré-requisitos: Docker 24+ com Compose v2.

```bash
cd rer-dsp-core
cp .env.example .env
chmod +x ./start.sh
./start.sh
```

| Serviço | URL padrão |
| --- | --- |
| Frontend | http://localhost:8081/dsp/ |
| Backend API | http://localhost:8080/dsp-backend |
| Config da instalação | http://localhost:8080/dsp-backend/config/installation |

Parar:

```bash
docker compose down
```

## Configuração

| Caminho | Função |
| --- | --- |
| [`.env.example`](.env.example) | Portas, paths, CORS, URL da API no frontend |
| [`config/installation/installation-config.json.example`](config/installation/installation-config.json.example) | Hierarquia, telas, KPIs (contrato da API) |
| [`config/Backend/application/application.yml.example`](config/Backend/application/application.yml.example) | Overrides Spring do backend (futuro) |
| [`config/Frontend/environment/env.json.example`](config/Frontend/environment/env.json.example) | Exemplo de `urlBackend` em runtime |
| [`config/Job-Data-Migration/application/application.yaml.example`](config/Job-Data-Migration/application/application.yaml.example) | Exemplo de mapeamento level1/2/3 do batch |

Detalhes do contrato: [docs/installation-config.md](docs/installation-config.md).

Hoje o `GET /config/installation` ainda vem de um **mock no backend**. O JSON de exemplo neste repo é o formato que adotante e API devem manter alinhados.

## Fora desta primeira versão

- GeoServer
- Postgres/PostGIS no Compose (aguarda schema DSP)
- Containers dos jobs no Compose
- Proxy reverso / gateway

## Licença

[GNU General Public License v3.0](LICENSE)
