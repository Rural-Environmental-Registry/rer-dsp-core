# Backend Docker

A imagem é construída a partir do Dockerfile do repositório irmão:

`../rer-dsp-backend/Dockerfile` (path configurável via `DSP_BACKEND_PATH`).

O Compose monta:

- `config/installation/installation-config.json` → `/config/installation-config.json`
- `config/map/mapLayersConfig.json` → `/config/mapLayersConfig.json`
- Env `DSP_INSTALLATION_CONFIG_FILE=file:/config/installation-config.json`
- Env `DSP_MAP_LAYERS_FILE=file:/config/mapLayersConfig.json`
- Datasource apontando para o serviço `dsp-db`
