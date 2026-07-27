# Installation configuration contract

Source of truth for adopter-facing installation settings used by the DSP UI/API.

## Endpoint

`GET /config/installation`

Values are loaded from the JSON file mounted by the core into the backend:

- Active (adopter-local, gitignored): `config/installation/installation-config.json`
- Template: [`config/installation/installation-config.json.example`](../config/installation/installation-config.json.example) (based on backend `installationConfig2.json`)

```text
DSP_INSTALLATION_CONFIG_FILE=file:/config/installation-config.json
```

The backend does **not** package this JSON in the jar.

## First run (`./start.sh`)

1. If `installation-config.json` is missing, `start.sh` copies it from `.example` and exits.
2. If the active file is still identical to `.example`, startup is **blocked** until you edit hierarchy labels, screens, KPIs, and formats.
3. After edits, restart the stack (re-run `./start.sh`).

## Shape

| Field | Meaning |
| --- | --- |
| `hierarchy` | Levels `level1`…`level3` (labels/placeholders) |
| `screens.home` | 2 levels (`level2`, `level3`) + identifier + `detail` |
| `screens.downloads` | 3 levels + theme |
| `kpis` | Up to 5 cards; `primaryCode` = **`AREA_OF_INTEREST`** |
| `areaOfInterest` | Unit of area (`areaUnit` / `areaUnitLabel`) |
| `formats` | `date` / `dateTime` patterns for the UI |

## Related APIs

- `GET /territory/options?level=&parentId=` — `dsp.territory_level_*`
- Totalizers / detail — `dsp.area_of_interest` + KPIs from this JSON

## Adopter changes

1. Run `./start.sh` once to generate the active file from `.example` (or copy manually).
2. Edit `installation-config.json` — rename hierarchy labels for your territory model.
3. Keep `AREA_OF_INTEREST` as `primaryCode` unless the product contract changes.
4. Adjust `formats` and `areaOfInterest` as needed.
5. Restart backend after edits (config is cached at startup).
