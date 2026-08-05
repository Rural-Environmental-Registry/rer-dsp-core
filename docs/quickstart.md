# Quickstart (demonstration data)

Use this when you want to see the DSP UI and map **without** a JDBC source or ETL mapping.

## How to run

```bash
./setup.sh
# Choose: 1) Demonstration (built-in Brazil seed, no JDBC)
./start.sh
```

Option **4** in `./setup.sh` shows whether this project's stack is on, prints the same
URLs/hints as `./start.sh`, then lets you remove only this project's
containers/volumes/images (`docker compose --env-file .env --profile migration down -v --rmi all`) or exit.

In demo mode, `./start.sh` does not require
`config/adopter/adopter-config.yaml`. This file is only used in the real
adopter flow (options 2 and 3).

## What it does

1. Starts `dsp-db` and `dsp-geoserver-exhibition-db` (not the migration job DB).
2. Loads static SQL from [`config/db/seed/quickstart/`](../config/db/seed/quickstart/).
3. Publishes GeoServer layers (SRID **4674**), independent of the SRIDs in
   `.env` used by a real adopter.
4. Ensures UI configs: Country / Region / State labels from
   `installation-config.quickstart.json.example` and map layer names from
   `mapLayersConfig.quickstart.json.example`.

Does **not** build the `dsp-job-migration` image or start `dsp-job-migration-db`.

## Dataset (demo only)

| Level | Content |
| --- | --- |
| L1 | Brazil (`BR`) |
| L2 | 5 regions |
| L3 | 27 states |
| AOI | 54 synthetic `DEMO-*` squares (2 per state; 12 overlapping pairs) |

Geometries are heavily simplified, but topologically consistent: neighbouring states touch without gaps or overlaps, and each region is the union of its states. AOIs are synthetic squares around centroids — **not** real property boundaries. See the seed [README](../config/db/seed/quickstart/README.md).

## Real adopter setup

1. Run `./config.sh` to configure the source and generate
   [`application.yaml`](../config/Job-Data-Migration/application/application.yaml).
2. Run `./setup.sh` and choose **2** (migrate from JDBC) or **3** (empty DBs,
   UI/GeoServer only).

See [migration-config.md](migration-config.md).
