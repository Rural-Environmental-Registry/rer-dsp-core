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
| `screens.downloads` | 3 levels + theme + section titles |
| `kpis` | Up to 5 cards; `primaryCode` = **`AREA_OF_INTEREST`**; optional `THEME_1`…`THEME_4` |
| `areaOfInterest` | Unit of area (`areaUnit` / `areaUnitLabel`) |
| `formats` | `date` / `dateTime` patterns for the UI |

### Localizable texts (`adopter-config.yaml`)

Configure these under `installation.screens` in
[`config/adopter/adopter-config.yaml.example`](../config/adopter/adopter-config.yaml.example).
The wizard asks for them in Stage 2. Omit a block to keep the English defaults from
`installation-config.json.example`.

| Adopter key | JSON target | UI use |
| --- | --- | --- |
| `home_title` | `screens.home.title` | Home screen heading |
| `downloads_title` | `screens.downloads.title` | Downloads screen heading |
| `identifier.label` | `screens.home.identifier.label` | Registration ID field label |
| `identifier.placeholder` | `screens.home.identifier.placeholder` | Registration ID placeholder |
| `detail.section_title` | `screens.home.detail.sectionTitle` | Detail panel heading |
| `detail.area_of_interest_section_title` | `screens.home.detail.areaOfInterestSectionTitle` | Area of interest data heading |
| `detail.registration_date_label` | `screens.home.detail.registrationDateLabel` | Registration date |
| `detail.alteration_date_label` | `screens.home.detail.alterationDateLabel` | Alteration date |
| `detail.latitude_label` | `screens.home.detail.latitudeLabel` | Latitude |
| `detail.longitude_label` | `screens.home.detail.longitudeLabel` | Longitude |
| `detail.area_label` | `screens.home.detail.areaLabel` | Area |
| `detail.features_download_label` | `screens.home.detail.featuresDownloadLabel` | Features download action |
| `downloads.theme.label` | `screens.downloads.theme.label` | Theme filter label |
| `downloads.theme.placeholder` | `screens.downloads.theme.placeholder` | Theme filter placeholder |
| `downloads.level1_section_title` | `screens.downloads.level1SectionTitle` | Downloads level 1 intro |
| `downloads.level2_section_title` | `screens.downloads.level2SectionTitle` | Downloads level 2 intro |
| `downloads.filter_by_title` | `screens.downloads.filterByTitle` | Downloads filter prefix |

Protected contract keys (do not change via adopter config): `hierarchyKeys`,
`identifier.key`, `theme.key`, `primaryCode`, KPI `code` values.

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
2. Configure hierarchy, KPI labels, screen texts, formats, and area through the wizard or `adopter-config.yaml`.
3. Keep `AREA_OF_INTEREST` as `primaryCode` unless the product contract changes.
4. Map theme source columns through the migration configuration — see [migration-config.md](migration-config.md).
5. Restart the backend after configuration changes (the config is cached at startup).
