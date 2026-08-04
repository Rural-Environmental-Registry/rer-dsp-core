# Quickstart (demonstration data)

Use this when you want to see the DSP UI and map **without** a JDBC source or ETL mapping.

## How to run

```bash
./setup.sh
# Choose: 2) Demonstration only
./start.sh
```

Option **3** in `./setup.sh` (or `./setup.sh --status`) shows whether this project's stack is on, prints the same URLs/hints as `./start.sh`, then lets you remove only this project's containers/volumes/images (`docker compose down -v --rmi all`) or exit.

Non-interactive:

```bash
./setup.sh --quickstart
./start.sh
```

In demo mode, `./start.sh` does not require
`config/adopter/adopter-config.yaml`. This file is only used in the flow
real of the adopter.

## What it does

1. Starts `dsp-db` and `dsp-geoserver-exhibition-db` (not the migration job DB).
2. Loads static SQL from [`config/db/seed/quickstart/`](../config/db/seed/quickstart/).
3. Publishes GeoServer layers (SRID **4674**), independent of the SRIDs in
   `.env` used by a real adopter.
4. Ensures UI configs: Country / Region / State labels from
   `installation-config.quickstart.json.example` and map layer names from
   `mapLayersConfig.quickstart.json.example`.

## Dataset (demo only)

| Level | Content |
| --- | --- |
| L1 | Brazil (`BR`) |
| L2 | 5 regions |
| L3 | 27 states |
| AOI | 54 synthetic `DEMO-*` squares (2 per state; 12 overlapping pairs) |

Geometries are heavily simplified, but topologically consistent: neighbouring states touch without gaps or overlaps, and each region is the union of its states. AOIs are synthetic squares around centroids — **not** real property boundaries. See the seed [README](../config/db/seed/quickstart/README.md).

## Real adopter setup

Choose option **1** in `./setup.sh` (or run without choosing demo) after
running `./config.sh` to configure the source and generate
[`application.yaml`](../config/Job-Data-Migration/application/application.yaml).
See [migration-config.md](migration-config.md).

`./setup.sh --skip-migration` still means empty DBs (no seed) + GeoServer only.
