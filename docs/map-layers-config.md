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

## First run (`./start.sh`)

1. If `mapLayersConfig.json` is missing, `start.sh` copies it from `.example` and exits.
2. If the active file is still identical to `.example`, startup is **blocked** until you edit it (e.g. `baseUrl`, display names, or colors).
3. `start.sh` **validates** that these four WMS layer ids are present (do not rename them):
   - `dsp:territory-level-1`
   - `dsp:territory-level-2`
   - `dsp:territory-level-3`
   - `dsp:area-of-interest`
4. `start.sh` also validates `style.color` / `style.fillColor` on those four layers and **prints each layer with its colors** before confirmation.
5. After edits, re-run `./start.sh`. GeoServer Exhibition publishes the FeatureTypes and syncs SLD colors from this same file.

## Shape

| Field | Meaning |
| --- | --- |
| `groups` | Layer groups shown in the map UI |
| `groups[].name` | Display name of the group |
| `groups[].key` | Stable group identifier |
| `groups[].layers` | WMS layers in the group |
| `layers[].baseUrl` | GeoServer WMS base URL (default local: `http://localhost:22668/geoserver/dsp/wms`) |
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

1. Run `./start.sh` once to generate the active file from `.example` (or copy manually).
2. Edit `baseUrl` if needed; keep the four `layers` ids unchanged.
3. Customize `style.color` / `style.fillColor` as needed (hex or `transparent` for fill).
4. Align display `name` values with installation hierarchy labels when possible.
5. Re-run `./start.sh` so GeoServer Exhibition regenerates SLDs from the active file.
6. Restart backend after edits (config is cached at startup).

## Related APIs

- `GET /map/getBaseMaps` — basemap tiles (classpath config by default)
- `GET /config/installation` — hierarchy labels used alongside map layers
