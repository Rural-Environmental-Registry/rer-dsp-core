# Installation configuration contract

Source of truth for adopter-facing installation settings used by the DSP UI/API.

## Endpoint (current)

`GET /config/installation`

Today values are served from a backend mock. This repository keeps the example file:

- [`config/installation/installation-config.json.example`](../config/installation/installation-config.json.example)

When the DSP database is ready, the same JSON shape should be loaded from persistence (or from this file mounted into the backend).

## Shape

| Field | Meaning |
| --- | --- |
| `hierarchy` | Generic territorial levels (`level1`…`level3`) with labels/placeholders |
| `screens.home` | Always **2** levels: `level2`, `level3` (+ optional identifier) |
| `screens.downloads` | Always **3** levels: `level1`, `level2`, `level3` (+ theme) |
| `kpis` | Up to **5** cards; `primaryCode` must be first (registered properties) |

## Related APIs

- `GET /territory/options?level=&parentId=` — options for each hierarchy level
- Totalizers feed KPI **values**; KPI **labels/units** come from `kpis.cards`

## Adopter changes

1. Copy `installation-config.json.example`.
2. Rename level labels (e.g. Country / Region / District).
3. Adjust KPI card labels and colors (keep `REGISTERED_AREA` as `primaryCode` unless the product contract changes).
4. Keep Home = 2 levels and Downloads = 3 levels.
