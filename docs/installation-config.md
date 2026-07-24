# Installation configuration contract

Source of truth for adopter-facing installation settings used by the DSP UI/API.

## Endpoint

`GET /config/installation`

Values are loaded from the JSON file mounted by the core into the backend:

- Active file: [`config/installation/installation-config.json`](../config/installation/installation-config.json)
- Template: [`config/installation/installation-config.json.example`](../config/installation/installation-config.json.example)

Compose mounts the active file at `/config/installation-config.json` and sets:

```text
DSP_INSTALLATION_CONFIG_FILE=file:/config/installation-config.json
```

O backend **não** embute esse JSON no jar. A configuração fica só no core.

## Shape

| Field | Meaning |
| --- | --- |
| `hierarchy` | Generic territorial levels (`level1`…`level3`) with labels/placeholders |
| `screens.home` | Always **2** levels: `level2`, `level3` (+ optional identifier) |
| `screens.downloads` | Always **3** levels: `level1`, `level2`, `level3` (+ theme) |
| `kpis` | Up to **5** cards; `primaryCode` must be first (registered properties) |

## Related APIs

- `GET /territory/options?level=&parentId=` — options for each hierarchy level (tables `dsp.level1/2/3`)
- Totalizers feed KPI **values**; KPI **labels/units** come from `kpis.cards`

## Adopter changes

1. Edit `config/installation/installation-config.json` (or copy from `.example`).
2. Rename level labels (e.g. Country / Region / District).
3. Adjust KPI card labels and colors (keep `REGISTERED_AREA` as `primaryCode` unless the product contract changes).
4. Keep Home = 2 levels and Downloads = 3 levels.
5. Restart the backend (`docker compose up -d dsp-backend`) — the file is read at startup (cached).
