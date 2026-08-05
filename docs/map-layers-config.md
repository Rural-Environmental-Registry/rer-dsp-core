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
5. Run `./setup.sh` to publish the layers; use `./start.sh` day to day.

## Shape

| Field | Meaning |
| --- | --- |
| `groups` | Layer groups shown in the map UI |
| `groups[].name` | Display name of the group |
| `groups[].key` | Stable group identifier |
| `groups[].layers` | WMS layers in the group |
| `layers[].baseUrl` | Fixed GeoServer WMS base URL from the core template |
| `layers[].layers` | WMS `layers` parameter (workspace:layer) — **fixed ids**, validated by `start.sh` |
| `layers[].name` | Display name (free to edit) |
| `layers[].activeDefault` | Whether the layer is on by default |
| `layers[].style.color` | Stroke color used by GeoServer SLD (`#RGB` or `#RRGGBB`) |
| `layers[].style.fillColor` | Fill color (`transparent` or `#RGB` / `#RRGGBB`) |

Basemaps are still loaded from the backend classpath (`baseMapConfig.json`) unless overridden separately.

## Default colors (template)

| Layer | `color` | `fillColor` |
| --- | --- | --- |
| `dsp:territory-level-1` | `#000000` | `transparent` |
| `dsp:territory-level-2` | `#1a1a1a` | `transparent` |
| `dsp:territory-level-3` | `#333333` | `transparent` |
| `dsp:area-of-interest` | `#cccc00` | `#ffff00` |

Territory defaults are a black-to-gray scale (L1 → L3). Change them in the active `mapLayersConfig.json` before confirming `./start.sh`.

## Adopter changes

1. Run `./config.sh` to configure display names and colors.
2. WMS URLs remain fixed; keep the four `layers` IDs unchanged.
3. Run `./setup.sh` so GeoServer Exhibition regenerates SLDs from the generated file.
4. Restart the backend after edits (config is cached at startup).

## Related APIs

- `GET /map/getBaseMaps` — basemap tiles (classpath config by default)
- `GET /config/installation` — hierarchy labels used alongside map layers
