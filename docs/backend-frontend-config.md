# Configuração de Backend e Frontend

Backend e frontend **não** têm arquivo de config próprio no `core` — toda a
configuração vem de variáveis de ambiente/build args do `docker-compose.yml`,
resolvidas a partir do `.env` (ver [`.env.example`](../.env.example)).

## Backend (`dsp-backend`)

Definido em `docker-compose.yml`, serviço `dsp-backend`.

| Variável (env do container) | Origem no `.env` | Papel |
| --- | --- | --- |
| `SERVER_SERVLET_CONTEXT_PATH` | `DSP_BACKEND_CONTEXT_PATH` | Context path da API |
| `DSP_CORS_ALLOWED_ORIGINS` | `DSP_CORS_ALLOWED_ORIGINS` | Origens permitidas (CORS) |
| `DSP_INSTALLATION_CONFIG_FILE` | `DSP_INSTALLATION_CONFIG_FILE` | Path do `installation-config.json` montado |
| `DSP_MAP_LAYERS_FILE` | `DSP_MAP_LAYERS_FILE` | Path do `mapLayersConfig.json` montado |
| `SPRING_DATASOURCE_URL/USERNAME/PASSWORD` | `DSP_DB_*` | Conexão com `dsp-db` |
| `SPRING_JPA_HIBERNATE_DDL_AUTO` | fixo (`none`) | DDL fica só no init SQL (ver [databases.md](databases.md)) |

Volumes montados (somente leitura):

- `config/installation/installation-config.json` → `/config/installation-config.json`
- `config/map/mapLayersConfig.json` → `/config/mapLayersConfig.json`

Templates desses dois arquivos: [`config/installation/installation-config.json.example`](../config/installation/installation-config.json.example)
e [`config/map/mapLayersConfig.json.example`](../config/map/mapLayersConfig.json.example).

## Frontend (`dsp-frontend`)

Definido em `docker-compose.yml`, serviço `dsp-frontend`. Configuração via
**build args** (não env de runtime — o Vite embute os valores no build):

| Build arg | Origem no `.env` | Papel |
| --- | --- | --- |
| `APP_VERSION` | `APP_VERSION` | Versão exibida na UI |
| `VITE_BASE_URL` | `VITE_BASE_URL` | Base path da aplicação |
| `VITE_DSP_API_URL` | `VITE_DSP_API_URL` | URL do backend consumida pelo frontend |

## Rodando fora do Docker (IDE local)

Para rodar backend/frontend fora do compose, replique manualmente os valores
acima como variáveis de ambiente (backend, Spring Boot) ou variáveis `VITE_*`
(frontend). Não existe mais um arquivo `.example` de referência no `config/`
para isso — os arquivos `config/Backend/application/application.yml.example`
e `config/Frontend/environment/env.json.example` foram removidos por não
serem consumidos pela stack Docker e confundirem quem os editava esperando
efeito real (ver `issues/09-remover-configs-backend-frontend-inativas.md`).
Use esta página como referência dos valores equivalentes.
