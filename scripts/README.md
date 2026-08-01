# Scripts do core

## Orquestração local

| Script | Papel |
|--------|--------|
| [`../setup.sh`](../setup.sh) | Bancos + migração de dados + populate GeoServer (uma vez / sob demanda) |
| [`../start.sh`](../start.sh) | Sobe GeoServer + backend + frontend (dia a dia; **não** migra) |
| [`common.sh`](common.sh) | Helpers compartilhados (source pelos dois scripts) |

```bash
./setup.sh          # prepara dados (volumes Docker)
./start.sh          # sobe a aplicação
./setup.sh --skip-migration   # só DBs + layers GeoServer, sem ETL
```

## GeoServer

- Compose: `dsp-geoserver-exhibition`
- Docs: [docs/geoserver-exhibition.md](../docs/geoserver-exhibition.md)
- Populate: `./setup.sh` (publica layers via `/opt/populate_geoserver.sh`)

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```

Default WMS: http://localhost:22668/geoserver/dsp/wms
