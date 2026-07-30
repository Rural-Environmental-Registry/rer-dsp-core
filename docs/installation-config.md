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
3. After edits, re-run `./start.sh` (app stack). Data migration stays in `./setup.sh`.

## Shape

| Field | Meaning |
| --- | --- |
| `hierarchy` | Levels `level1`…`level3` (labels/placeholders) |
| `screens.home` | 2 levels (`level2`, `level3`) + identifier + `detail` |
| `screens.downloads` | 3 levels + theme |
| `kpis` | Up to 5 cards; `primaryCode` = **`AREA_OF_INTEREST`**; optional `THEME_1`…`THEME_4` |
| `areaOfInterest` | Unit of area (`areaUnit` / `areaUnitLabel`) |
| `formats` | `date` / `dateTime` patterns for the UI |

### KPI codes (stable) vs labels (local)

| Code | Data on `dsp.area_of_interest` | Card value |
| --- | --- | --- |
| `AREA_OF_INTEREST` | row count + `SUM(area)` | count; optional sub-item = area sum |
| `THEME_1` … `THEME_4` | `SUM(theme_1)` … `SUM(theme_4)` | area sum (unit from card) |

Rename only the `label` fields for your country (e.g. Theme 1 → “Legal reserve”).

## Related APIs

- `GET /territory/options?level=&parentId=` — `dsp.territory_level_*`
- Totalizers / detail — `dsp.area_of_interest` measures + KPI labels from this JSON

## Adopter changes

1. Run `./start.sh` once to generate the active file from `.example` (or copy manually).
2. Edit `installation-config.json` — rename hierarchy and KPI labels.
3. Keep `AREA_OF_INTEREST` as `primaryCode` unless the product contract changes.
4. Map theme source columns in the migration YAML (`business-only-persist-columns`) when you have theme measures.
5. Adjust `formats` and `areaOfInterest` as needed.
6. Restart backend after edits (config is cached at startup).
