# Map layers configuration contract

Source of truth for WMS layer groups served to the DSP map UI, including layer colors used by GeoServer Exhibition.

Local WMS is provided by **GeoServer Exhibition** (`dsp-geoserver-exhibition`). See [geoserver-exhibition.md](geoserver-exhibition.md).

## Endpoint

`GET /map/getLayers`

Values are loaded from the JSON file mounted by the core into the backend:

- Active (adopter-local, gitignored): `config/map/mapLayersConfig.json`
- Template: [`config/map/mapLayersConfig.json.example`](../config/map/mapLayersConfig.json.example)

```text
DSP_MAP_LAYERS_FILE=file:/config/mapLayersConfig.json
```

The backend does **not** require this JSON to be packaged in the jar when running via Docker Compose.

## First run (`./config.sh` / `./setup.sh` / `./start.sh`)

1. Run `./config.sh` and provide layer names and colors. WMS URLs are fixed by the core template.
2. The wizard generates `mapLayersConfig.json`; in advanced mode, edit
   `adopter-config.yaml` and run `./config.sh` (choose reapply or edit when prompted).
3. Both scripts **validate** that these four WMS IDs are present (do not rename them):
   - `dsp:territory-level-1`
   - `dsp:territory-level-2`
   - `dsp:territory-level-3`
   - `dsp:area-of-interest`
4. They also validate `style.color` / `style.fillColor` and display each layer before confirmation.
5. Optional **generic layers** are asked by the wizard (stage 5, after enabling layer jobs) and stored
   under `etl.layers`. They are appended to the JSON with `nativeName` and `srs`, and validated in
   addition to the four required IDs.
6. Run `./setup.sh` to publish all layers from the JSON; use `./start.sh` day to day.

## Shape

| Field | Meaning |
| --- | --- |
| `groups` | Layer groups shown in the map UI |
| `groups[].name` | Display name of the group |
| `groups[].key` | Stable group identifier |
| `groups[].layers` | WMS layers in the group |
| `layers[].baseUrl` | Fixed GeoServer WMS base URL from the core template |
| `layers[].layers` | WMS `layers` parameter (`workspace:layer`) |
| `layers[].name` | Display name (free to edit) |
| `layers[].activeDefault` | Whether the layer is on by default |
| `layers[].style.color` | Stroke color used by GeoServer SLD (`#RGB` or `#RRGGBB`) |
| `layers[].style.fillColor` | Fill color (`transparent` or `#RGB` / `#RRGGBB`) |
| `layers[].nativeName` | PostGIS table name in schema `dsp` (**required for extra layers**) |
| `layers[].srs` | Layer SRS, e.g. `EPSG:4674` (**required for extra layers**) |

The four fixed territorial / AOI layer ids must stay present. Additional groups and layers are allowed.

Basemaps are still loaded from the backend classpath (`baseMapConfig.json`) unless overridden separately.

## Generic layers (`etl.layers`)

Declare extra layers with `./config.sh` (answer yes to *Run generic layer jobs*, then add one entry per layer) or by editing [`adopter-config.yaml`](../config/adopter/adopter-config.yaml.example) directly. Each entry drives:

1. Migration job YAML (`batch.layers` + `execution-jobs.layer-jobs`)
2. Map UI entry in `mapLayersConfig.json`
3. GeoServer FeatureType + SLD via `./setup.sh` populate

```yaml
etl:
  layers:
    - source_table: <schema>.<table>   # origin schema (e.g. public) — never dsp
      area_of_interest_id_column: <aoi_fk_column>
      layer_name: <wms_id>           # technical id: ^[a-z0-9][a-z0-9_-]*$ → dsp:<wms_id>
      srid: 4674
      enabled: true
      display_name: <ui_label>       # human-readable map label (any language)
      group_key: <group_key>         # map.group_names key (or a new key)
      active_default: false
      color: "#2563EB"
      fill_color: transparent
  jobs:
    layer_jobs: true
```

### Naming rules

| Field | Role | Rules |
| --- | --- | --- |
| `source_table` | Origin PostGIS table | `schema.table` from the **source** database. Schema `dsp` is reserved for the migration destination (`dsp.<table>` on exhibition-db). |
| `layer_name` | Technical WMS id | Lowercase letters, digits, hyphens, underscores only (`area-seguranca-300m`). Published as `dsp:<layer_name>`. |
| `display_name` | Map panel label | Free text (accents, spaces, any language). Not used as WMS id. |

`map.group_names` accepts extra keys matching `group_key`. Adding another layer is a new list item — no application code changes.

## Default colors (template)

| Layer | `color` | `fillColor` |
| --- | --- | --- |
| `dsp:territory-level-1` | `#000000` | `transparent` |
| `dsp:territory-level-2` | `#1a1a1a` | `transparent` |
| `dsp:territory-level-3` | `#333333` | `transparent` |
| `dsp:area-of-interest` | `#cccc00` | `#ffff00` |

Territory defaults are a black-to-gray scale (L1 → L3). Change them in the active `mapLayersConfig.json` before confirming `./start.sh`.

## Adopter changes

1. Run `./config.sh` to configure display names, colors, and generic layers.
2. WMS base URL remains fixed; keep the four required `layers` IDs unchanged.
3. Run `./setup.sh` so GeoServer Exhibition publishes / regenerates SLDs from the generated file.
4. Restart the backend after edits (config is cached at startup).

## Related APIs

- `GET /map/getBaseMaps` — basemap tiles (classpath config by default)
- `GET /config/installation` — hierarchy labels used alongside map layers
