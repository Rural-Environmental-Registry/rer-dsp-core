# Scripts — GeoServer (deprecated)

The temporary scripts in this folder are **deprecated**.

Use the stack service instead:

- Compose: `dsp-geoserver-exhibition`
- Docs: [docs/geoserver-exhibition.md](../docs/geoserver-exhibition.md)
- Start: `./start.sh` (step 9 builds, waits, and runs `/opt/populate_geoserver.sh`)

```bash
docker compose up -d --build dsp-geoserver-exhibition
docker compose exec dsp-geoserver-exhibition /opt/populate_geoserver.sh
```

Default WMS: http://localhost:22668/geoserver/dsp/wms

The scripts `tmp-start-geoserver.sh` and `tmp-populate-geoserver.sh` remain only as historical reference and may be removed later.
