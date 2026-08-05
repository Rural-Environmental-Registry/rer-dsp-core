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

1. Run `./config.sh` to fill in the guided adopter configuration.
2. The script generates `installation-config.json` from the protected template.
3. `start.sh` validates the generated file and starts the application. Migration remains in `./setup.sh`.

In advanced mode, edit only `config/adopter/adopter-config.yaml` (created from
`config/adopter/adopter-config.yaml.example`) and run `./config.sh` (choose
reapply or edit when prompted). Do not edit the `key`, `code`, or `primaryCode` keys
directly.

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

During `./config.sh`, the wizard first asks how many theme KPIs exist in the
source database (from zero to four). Unselected themes are omitted from both
the generated KPI configuration and the ETL mapping.

## Related APIs

- `GET /territory/options?level=&parentId=` — `dsp.territory_level_*`
- Totalizers / detail — `dsp.area_of_interest` measures + KPI labels from this JSON

## Adopter changes

1. Run `./config.sh` to generate the active installation configuration.
2. Configure hierarchy, KPI labels, formats, and area through the wizard or `adopter-config.yaml`.
3. Keep `AREA_OF_INTEREST` as `primaryCode` unless the product contract changes.
4. Map theme source columns through the migration configuration — see [migration-config.md](migration-config.md).
5. Restart the backend after configuration changes (the config is cached at startup).
