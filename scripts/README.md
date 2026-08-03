# Scripts do core

## Orquestração local

| Script | Papel |
|--------|--------|
| [`../setup.sh`](../setup.sh) | Bancos + migração de dados + populate GeoServer (uma vez / sob demanda) |
| [`../start.sh`](../start.sh) | Sobe GeoServer + backend + frontend (dia a dia; **não** migra) |
| [`common.sh`](common.sh) | Helpers compartilhados (source pelos dois scripts) |

```bash
./setup.sh          # prepara dados (volumes Docker); pergunta real vs demo
./start.sh          # sobe a aplicação
./setup.sh --quickstart       # seed Brasil de demonstração (sem JDBC)
./setup.sh --skip-migration   # só DBs + layers GeoServer, sem ETL e sem seed
```

Demo: [docs/quickstart.md](../docs/quickstart.md). Seed SQL: [`config/db/seed/quickstart/`](../config/db/seed/quickstart/).

## GeoServer

- Compose: `dsp-geoserver-exhibition`
- Docs: [docs/geoserver-exhibition.md](../docs/geoserver-exhibition.md)
- Populate: `./setup.sh` (publica layers via `/opt/populate_geoserver.sh`)

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```

Default WMS: http://localhost:22668/geoserver/dsp/wms
