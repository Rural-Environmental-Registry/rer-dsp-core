#!/usr/bin/env python3
"""Generate operational files from the adopter configuration."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import shutil
import sys
from pathlib import Path
from typing import Any

# URLs consumidas pelo browser, portanto passam pelo gateway (DSP_PUBLIC_BASE_URL no .env).
PUBLIC_BASE_URL = os.environ.get("DSP_PUBLIC_BASE_URL", "http://localhost:8026").rstrip("/")
FIXED_WMS_BASE_URL = f"{PUBLIC_BASE_URL}/geoserver-exhibition/dsp/wms"
# Downloads use GeoServer Download (separate from map Exhibition WMS).
FIXED_WFS_BASE_URL = f"{PUBLIC_BASE_URL}/geoserver-download/dsp/wfs"
HEX_COLOR = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")
LAYER_NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
DESTINATION_SCHEMA = "dsp"
FIXED_GROUP_KEYS = {
    "territorial_division": "dt",
    "areas_of_interest": "ird",
}
FIXED_LAYER_IDS = {
    "dsp:territory-level-1",
    "dsp:territory-level-2",
    "dsp:territory-level-3",
    "dsp:area-of-interest",
}

try:
    import yaml
except ImportError:
    print("Error: the Python 'yaml' module is required. Install PyYAML.", file=sys.stderr)
    raise SystemExit(1)


class AdopterConfigDumper(yaml.SafeDumper):
    """Write multiline SQL values as readable YAML folded blocks."""


def represent_multiline_string(dumper: yaml.SafeDumper, value: str) -> yaml.nodes.ScalarNode:
    style = ">" if "\n" in value else None
    return dumper.represent_scalar("tag:yaml.org,2002:str", value, style=style)


AdopterConfigDumper.add_representer(str, represent_multiline_string)


def dump_yaml(data: Any) -> str:
    return yaml.dump(
        data,
        Dumper=AdopterConfigDumper,
        allow_unicode=True,
        sort_keys=False,
    )


def read_dotenv_value(env_file: Path, key: str, default: str = "") -> str:
    if not env_file.is_file():
        return default
    for line in env_file.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" in stripped:
            env_key, _, value = stripped.partition("=")
            if env_key == key:
                return value
    return default


def get(data: dict[str, Any], *keys: str, default: Any = None) -> Any:
    value: Any = data
    for key in keys:
        if not isinstance(value, dict):
            return default
        value = value.get(key, default)
    return value


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Fill missing keys from base without overwriting override values."""
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if (
            key in merged
            and isinstance(merged[key], dict)
            and isinstance(value, dict)
        ):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def ask(label: str, default: Any = "") -> Any:
    suffix = f" [{default}]" if default not in ("", None) else ""
    print(f"{label}{suffix}:")
    answer = input("  > ").strip()
    return default if answer == "" else answer


def ask_bool(label: str, default: bool) -> bool:
    value = str(ask(f"{label} (y/n)", "y" if default else "n")).lower()
    return value in {"y", "yes"}


def ask_field(label: str, default: Any, description: str, used_in: str) -> Any:
    print(f"\n  {label}")
    print(f"  What: {description}")
    print(f"  Used in: {used_in}")
    return ask("  Value", default)


def ask_int_field(
    label: str,
    default: Any,
    description: str,
    used_in: str,
    *,
    minimum: int | None = None,
    maximum: int | None = None,
) -> int:
    while True:
        print(f"\n  {label}")
        print(f"  What: {description}")
        print(f"  Used in: {used_in}")
        raw = ask("  Value", default)
        try:
            value = int(raw)
        except (TypeError, ValueError):
            print("\n  Enter a whole number.")
            continue
        if minimum is not None and value < minimum:
            print(f"\n  Enter a value greater than or equal to {minimum}.")
            continue
        if maximum is not None and value > maximum:
            print(f"\n  Enter a value less than or equal to {maximum}.")
            continue
        return value


def ask_float_field(
    label: str,
    default: Any,
    description: str,
    used_in: str,
    *,
    minimum: float | None = None,
    maximum: float | None = None,
) -> float:
    while True:
        print(f"\n  {label}")
        print(f"  What: {description}")
        print(f"  Used in: {used_in}")
        raw = ask("  Value", default)
        try:
            value = float(raw)
        except (TypeError, ValueError):
            print("\n  Enter a numeric value.")
            continue
        if not (value == value and abs(value) != float("inf")):
            print("\n  Enter a finite numeric value.")
            continue
        if minimum is not None and value < minimum:
            print(f"\n  Enter a value greater than or equal to {minimum}.")
            continue
        if maximum is not None and value > maximum:
            print(f"\n  Enter a value less than or equal to {maximum}.")
            continue
        return value


def ask_color_field(
    label: str,
    default: Any,
    description: str,
    used_in: str,
    *,
    allow_transparent: bool = False,
) -> str:
    while True:
        print(f"\n  {label}")
        print(f"  What: {description}")
        print(f"  Used in: {used_in}")
        raw = str(ask("  Value", default)).strip()
        if allow_transparent and raw == "transparent":
            return raw
        if HEX_COLOR.fullmatch(raw):
            return raw
        if allow_transparent:
            print("\n  Enter a #RGB or #RRGGBB value, or 'transparent'.")
        else:
            print("\n  Enter a #RGB or #RRGGBB value.")


def ask_bool_field(label: str, default: bool, description: str, used_in: str) -> bool:
    print(f"\n  {label}")
    print(f"  What: {description}")
    print(f"  Used in: {used_in}")
    return ask_bool("  Value", default)


def etl_field_help(field: str) -> str:
    descriptions = {
        "source_table": (
            "Source table name (schema.table) for this wizard. "
            "SQL subqueries are also supported, but only by editing "
            "./config/adopter/adopter-config.yaml (advanced mode), then running "
            "./config.sh — do not type SQL here."
        ),
        "primary_key": "Unique source column used to identify each record.",
        "parent_key": "Source column linking this record to its parent territory.",
        "name_column": "Source column containing the display name.",
        "geometry_column": "Source column containing the geometry.",
        "created_at_column": "Source column containing the registration date.",
        "updated_at_column": (
            "Source column with the last modification timestamp. "
            "Used as the watermark for incremental sync."
        ),
        "label_column": (
            "Source column with the feature display name. "
            "Copied to the destination as 'label'."
        ),
        "territory_level_3_column": "Source column linking an area to territorial level 3.",
        "area_column": "Source column containing the area measurement.",
        "persist_columns": (
            "Other source columns to copy besides the required ones. "
            "The destination keeps the same names."
        ),
        "theme_1_column": (
            "Source column for theme 1 (dsp-db only). The destination keeps this name — "
            "use theme_1 as the column or subquery alias to feed the KPI card."
        ),
        "theme_2_column": (
            "Source column for theme 2 (dsp-db only). The destination keeps this name — "
            "use theme_2 as the column or subquery alias to feed the KPI card."
        ),
        "theme_3_column": (
            "Source column for theme 3 (dsp-db only). The destination keeps this name — "
            "use theme_3 as the column or subquery alias to feed the KPI card."
        ),
        "theme_4_column": (
            "Source column for theme 4 (dsp-db only). The destination keeps this name — "
            "use theme_4 as the column or subquery alias to feed the KPI card."
        ),
    }
    return descriptions.get(field, "Source value used by the ETL mapping.")


def parse_column_list(raw: Any, prefix: str) -> list[str]:
    """Parse optional extra columns from a list or a comma-separated string."""
    if raw is None or raw == "" or raw == []:
        return []
    if isinstance(raw, str):
        parts = [item.strip() for item in raw.split(",") if item.strip()]
    elif isinstance(raw, list):
        parts = []
        for item in raw:
            if not isinstance(item, str) or not item.strip():
                raise ValueError(f"{prefix} must not contain blank entries.")
            parts.append(item.strip())
    else:
        raise ValueError(f"{prefix} must be a list of column names or a comma-separated string.")
    seen: set[str] = set()
    unique: list[str] = []
    for column in parts:
        if "<" in column:
            raise ValueError(f"{prefix} still contains a placeholder ('{column}').")
        if column in seen:
            raise ValueError(f"{prefix}: duplicate column '{column}'.")
        seen.add(column)
        unique.append(column)
    return unique


def ask_optional_column_list(label: str, default: Any, description: str, used_in: str) -> list[str]:
    if isinstance(default, list):
        default_display = ", ".join(default)
    else:
        default_display = str(default or "")
    while True:
        print(f"\n  {label}")
        print(f"  What: {description}")
        print(f"  Used in: {used_in}")
        print("  How: type column names separated by commas.")
        print("  Example: owner, status, year")
        print("  Skip: press Enter if there are no extra columns.")
        raw = ask("  Columns", default_display)
        text = str(raw or "").strip()
        if text and "," not in text and any(char.isspace() for char in text):
            print(
                "\n  Separate names with commas, not only spaces. "
                "Example: owner, status, year"
            )
            continue
        try:
            return parse_column_list(text, label)
        except ValueError as exc:
            print(f"\n  {exc}")


def require_non_blank_column(value: Any, prefix: str) -> str:
    if not isinstance(value, str) or not value.strip() or "<" in value:
        raise ValueError(f"{prefix} is required (source column name, no placeholder).")
    return value.strip()


def resolve_optional_layer_field(entry: dict[str, Any], field: str, prefix: str) -> str | None:
    value = entry.get(field)
    if value is None or value == "":
        return None
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{prefix}.{field} must be a non-empty string.")
    if "<" in value:
        raise ValueError(f"{prefix}.{field} still contains a placeholder.")
    return value.strip()


def require_layer_field(entry: dict[str, Any], field: str, prefix: str) -> str:
    value = resolve_optional_layer_field(entry, field, prefix)
    if value is None:
        raise ValueError(f"{prefix}.{field} is required.")
    return value


def normalize_adopter_layer_field_aliases(values: dict[str, Any]) -> bool:
    """Rewrite legacy layer keys onto the current adopter-config names."""
    changed = False
    raw_layers = get(values, "etl", "layers", default=[]) or []
    for entry in raw_layers:
        if not isinstance(entry, dict):
            continue
        if not entry.get("parent_key"):
            legacy = entry.get("area_of_interest_id_column")
            if isinstance(legacy, str) and legacy.strip():
                entry["parent_key"] = legacy.strip()
                changed = True
        if "area_of_interest_id_column" in entry and entry.get("parent_key"):
            entry.pop("area_of_interest_id_column", None)
            changed = True
    return changed


def reset_disabled_themes(
    config: dict[str, Any],
    template: dict[str, Any],
    theme_count: int,
) -> bool:
    """Restore template defaults for themes above theme_count and clear ETL columns."""
    changed = False
    kpis = config["installation"]["kpis"]
    template_kpis = template["installation"]["kpis"]
    for index in range(1, 5):
        code = f"theme_{index}"
        if index > theme_count:
            restored = copy.deepcopy(template_kpis[code])
            restored["enabled"] = False
            if kpis.get(code) != restored:
                changed = True
            kpis[code] = restored
        elif not kpis.get(code, {}).get("enabled", True):
            kpis[code]["enabled"] = True
            changed = True

    aoi = config["etl"]["area_of_interest"]
    for index in range(1, 5):
        key = f"theme_{index}_column"
        if index > theme_count and aoi.get(key) is not None:
            aoi[key] = None
            changed = True
    return changed


def enabled_kpi_codes(theme_count: int) -> tuple[str, ...]:
    return ("area_of_interest",) + tuple(f"theme_{index}" for index in range(1, theme_count + 1))


MAP_VIEW_MODES = ("territorial_bbox", "manual", "planet")
PLANET_CENTER_LAT = 0.0
PLANET_CENTER_LNG = 0.0
PLANET_ZOOM = 0


def is_source_table_placeholder(source_table: str) -> bool:
    normalized = source_table.strip()
    return not normalized or "<source_" in normalized or normalized == "source_schema.source_table"


def is_territory_level_etl_configured(values: dict[str, Any], level: str) -> bool:
    jobs = get(values, "etl", "jobs", default={}) or {}
    if jobs.get(level) is False:
        return False
    source_table = str(get(values, "etl", level, "source_table", default=""))
    return not is_source_table_placeholder(source_table)


def is_level1_source_configured(values: dict[str, Any]) -> bool:
    return is_territory_level_etl_configured(values, "level1")


def is_territorial_bbox_viable(values: dict[str, Any]) -> bool:
    """True when at least one territorial level can feed GET /territory/boundary-box."""
    return any(
        is_territory_level_etl_configured(values, level)
        for level in ("level1", "level2", "level3")
    )


TERRITORIAL_BBOX_PLANET_REASON = (
    "Territorial geometry cannot be resolved from the ETL configuration "
    "(no enabled level1/level2/level3 source table)."
)


def coerce_map_initial_view_to_planet(values: dict[str, Any]) -> bool:
    """Switch territorial_bbox to planet when the frontend would fall back to the globe."""
    initial_view = get(values, "map", "initial_view", default={}) or {}
    if initial_view.get("mode") != "territorial_bbox":
        return False
    if is_territorial_bbox_viable(values):
        return False

    map_config = values.setdefault("map", {})
    initial_view = map_config.setdefault("initial_view", {})
    initial_view["mode"] = "planet"
    initial_view["latitude"] = None
    initial_view["longitude"] = None
    initial_view["zoom"] = None

    print()
    print("  Map initial view: adjusted automatically.")
    print(f"  {TERRITORIAL_BBOX_PLANET_REASON}")
    print("  Changed map.initial_view.mode from 'territorial_bbox' to 'planet'.")
    return True


def _initial_view_coordinate_fields(initial_view: dict[str, Any]) -> dict[str, Any]:
    return {
        name: initial_view.get(name)
        for name in ("latitude", "longitude", "zoom")
    }


def _has_any_coordinate_field(fields: dict[str, Any]) -> bool:
    return any(
        value is not None and not (isinstance(value, str) and not value.strip())
        for value in fields.values()
    )


def _build_initial_view_json(
    mode: str,
    *,
    latitude: float | None = None,
    longitude: float | None = None,
    zoom: int | None = None,
) -> dict[str, Any]:
    return {
        "initialView": {
            "mode": mode,
            "latitude": latitude,
            "longitude": longitude,
            "zoom": zoom,
        }
    }


def validate_map_initial_view(values: dict[str, Any]) -> dict[str, Any]:
    """Validate map.initial_view and return the installation map block."""
    initial_view = get(values, "map", "initial_view", default={}) or {}
    mode = initial_view.get("mode")
    if not isinstance(mode, str) or mode not in MAP_VIEW_MODES:
        raise ValueError(
            "map.initial_view.mode is required and must be one of: "
            + ", ".join(MAP_VIEW_MODES)
            + "."
        )

    coordinate_fields = _initial_view_coordinate_fields(initial_view)
    has_coordinates = _has_any_coordinate_field(coordinate_fields)

    if mode in ("territorial_bbox", "planet"):
        if has_coordinates:
            raise ValueError(
                f"map.initial_view.latitude, longitude, and zoom must be null when "
                f"mode is '{mode}'."
            )
        return _build_initial_view_json(mode)

    latitude = coordinate_fields["latitude"]
    longitude = coordinate_fields["longitude"]
    zoom = coordinate_fields["zoom"]
    if not has_coordinates or any(
        value is None or (isinstance(value, str) and not value.strip())
        for value in coordinate_fields.values()
    ):
        raise ValueError(
            "map.initial_view requires latitude, longitude, and zoom when mode is 'manual'."
        )

    try:
        lat = float(latitude)
        lng = float(longitude)
        zoom_value = int(zoom)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            "map.initial_view latitude and longitude must be numbers; zoom must be an integer."
        ) from exc

    if not (-90 <= lat <= 90):
        raise ValueError("map.initial_view.latitude must be between -90 and 90.")
    if not (-180 <= lng <= 180):
        raise ValueError("map.initial_view.longitude must be between -180 and 180.")
    if not (0 <= zoom_value <= 16):
        raise ValueError("map.initial_view.zoom must be an integer between 0 and 16.")

    return _build_initial_view_json(
        "manual",
        latitude=lat,
        longitude=lng,
        zoom=zoom_value,
    )


def ask_map_initial_view(config: dict[str, Any]) -> None:
    """Configure the home map initial view mode."""
    map_config = config.setdefault("map", {})
    initial_view = map_config.setdefault(
        "initial_view",
        {
            "mode": "territorial_bbox",
            "latitude": None,
            "longitude": None,
            "zoom": None,
        },
    )

    print("\n  Initial map view")
    print("  What: Controls how the home map opens and returns to its default view")
    print("        (Center map tool and Clear search on the home page).")
    print("  Used in: the home page map")
    print()
    print("  Choose one mode:")
    print("    1. territorial_bbox — automatic framing from migrated L1/L2/L3 geometries")
    print("    2. manual — fixed latitude, longitude, and zoom")
    print("    3. planet — always show the whole world (zoomed out)")
    print()
    print("  If territorial_bbox is selected but no territorial level (L1/L2/L3) is")
    print("  configured in the ETL, the mode will be set to 'planet' automatically")
    print("  when configuration is applied (same view the frontend would use as fallback).")

    current_mode = initial_view.get("mode", "territorial_bbox")
    if current_mode not in MAP_VIEW_MODES:
        current_mode = "territorial_bbox"

    while True:
        print(f"\n  Current mode: {current_mode}")
        choice = ask("  Mode (1=territorial_bbox, 2=manual, 3=planet)", {
            "territorial_bbox": "1",
            "manual": "2",
            "planet": "3",
        }.get(current_mode, "1"))
        if choice == "1":
            selected_mode = "territorial_bbox"
            break
        if choice == "2":
            selected_mode = "manual"
            break
        if choice == "3":
            selected_mode = "planet"
            break
        print("\n  Enter 1, 2, or 3.")

    initial_view["mode"] = selected_mode

    if selected_mode == "territorial_bbox":
        initial_view["latitude"] = None
        initial_view["longitude"] = None
        initial_view["zoom"] = None
        if not is_territorial_bbox_viable(config):
            print()
            print("  Note: no territorial level (L1/L2/L3) is configured in the ETL yet.")
            print("  If that remains true after the wizard, map.initial_view.mode will be")
            print("  changed to 'planet' automatically when configuration is applied.")
        return

    if selected_mode == "planet":
        initial_view["latitude"] = None
        initial_view["longitude"] = None
        initial_view["zoom"] = None
        return

    initial_view["latitude"] = ask_float_field(
        "Initial center latitude",
        initial_view.get("latitude", -14.2),
        "Decimal degrees between -90 and 90. Example: -14.2 for central Brazil.",
        "the map center on load and when resetting the view",
        minimum=-90,
        maximum=90,
    )
    initial_view["longitude"] = ask_float_field(
        "Initial center longitude",
        initial_view.get("longitude", -51.9),
        "Decimal degrees between -180 and 180. Example: -51.9 for central Brazil.",
        "the map center on load and when resetting the view",
        minimum=-180,
        maximum=180,
    )
    initial_view["zoom"] = ask_int_field(
        "Initial zoom level",
        initial_view.get("zoom", 10),
        "Whole number from 0 (world) to 16 (closest). Higher values zoom in more.",
        "the map framing on load and when resetting the view",
        minimum=0,
        maximum=16,
    )


def ask_kpi_accent_colors(config: dict[str, Any], theme_count: int) -> None:
    print("\n  KPI card colors")
    print("  What: Highlight color shown on each KPI card in the dashboard.")
    print("  Used in: the application dashboard")
    kpis = config["installation"]["kpis"]
    for code in enabled_kpi_codes(theme_count):
        card = kpis[code]
        card["accent_color"] = ask_color_field(
            f"Accent color for {code}", card["accent_color"],
            "Highlight color for the KPI card.",
            "the application dashboard",
        )


def sync_map_layer_names(config: dict[str, Any]) -> bool:
    """Keep territorial layer display names aligned with hierarchy and AOI KPI labels."""
    changed = False
    hierarchy = config["installation"]["hierarchy"]
    layers = config["map"]["layers"]
    for level in ("level1", "level2", "level3"):
        label = hierarchy[level]["label"]
        if layers[level].get("name") != label:
            layers[level]["name"] = label
            changed = True
    aoi_name = config["installation"]["kpis"]["area_of_interest"]["label"]
    if layers["area_of_interest"].get("name") != aoi_name:
        layers["area_of_interest"]["name"] = aoi_name
        changed = True
    return changed


def table_name_from_source(source_table: str) -> str:
    """Return the unqualified table name (schema discarded), matching the job contract."""
    qualified = str(source_table).strip()
    if "." not in qualified:
        raise ValueError(
            f"etl.layers source_table must be schema.table (got {source_table!r})."
        )
    return qualified.rsplit(".", 1)[-1].strip()


def source_schema_from_table(source_table: str) -> str:
    """Return the schema part of schema.table."""
    qualified = str(source_table).strip()
    if "." not in qualified:
        raise ValueError(
            f"etl.layers source_table must be schema.table (got {source_table!r})."
        )
    return qualified.rsplit(".", 1)[0].strip()


def validate_layer_name(layer_name: str, prefix: str = "layer_name") -> str:
    """Ensure layer_name is a valid technical WMS id (lowercase, no spaces/accents)."""
    value = layer_name.strip()
    if not LAYER_NAME_PATTERN.fullmatch(value):
        raise ValueError(
            f"{prefix} must match ^[a-z0-9][a-z0-9_-]*$ "
            f"(lowercase letters, digits, hyphens, underscores; got {layer_name!r}). "
            "Use display_name for the human-readable label."
        )
    return value


def validate_source_table_schema(source_table: str, prefix: str) -> None:
    """Reject dsp.* — that schema is reserved for the migration destination."""
    schema = source_schema_from_table(source_table).lower()
    if schema == DESTINATION_SCHEMA:
        table = table_name_from_source(source_table)
        raise ValueError(
            f"{prefix}.source_table must use the origin schema, not '{DESTINATION_SCHEMA}'. "
            f"The job migrates schema.table → {DESTINATION_SCHEMA}.{table}. "
            f"Example: public.{table}"
        )


def resolve_layer_name(entry: dict[str, Any]) -> str:
    explicit = entry.get("layer_name")
    if isinstance(explicit, str) and explicit.strip():
        return explicit.strip()
    return table_name_from_source(entry["source_table"])


def normalize_epsg(srid: Any) -> str:
    if isinstance(srid, int):
        return f"EPSG:{srid}"
    if isinstance(srid, str):
        value = srid.strip()
        if value.upper().startswith("EPSG:"):
            return f"EPSG:{value.split(':', 1)[1].strip()}"
        if value.isdigit():
            return f"EPSG:{value}"
    raise ValueError(f"Invalid srid value: {srid!r} (expected integer or EPSG:n).")


def resolve_layer_parent_key(entry: dict[str, Any]) -> str | None:
    """Return the AOI parent_key for a generic layer (legacy: area_of_interest_id_column)."""
    for key in ("parent_key", "area_of_interest_id_column"):
        value = entry.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def validate_extra_layers(values: dict[str, Any]) -> list[dict[str, Any]]:
    """Validate and normalize etl.layers entries. Returns enabled layers only."""
    raw_layers = get(values, "etl", "layers", default=[])
    if raw_layers is None:
        return []
    if not isinstance(raw_layers, list):
        raise ValueError("etl.layers must be a list.")

    seen_tables: set[str] = set()
    seen_wms: set[str] = set(FIXED_LAYER_IDS)
    enabled: list[dict[str, Any]] = []

    for index, entry in enumerate(raw_layers):
        prefix = f"etl.layers[{index}]"
        if not isinstance(entry, dict):
            raise ValueError(f"{prefix} must be a mapping.")
        if entry.get("enabled", True) is False:
            continue

        source_table = entry.get("source_table")
        if not isinstance(source_table, str) or not source_table.strip():
            raise ValueError(f"{prefix}.source_table is required.")
        if "<" in source_table:
            raise ValueError(f"{prefix}.source_table still contains a placeholder.")
        validate_source_table_schema(source_table.strip(), prefix)

        aoi_column = resolve_layer_parent_key(entry)
        if not aoi_column:
            raise ValueError(f"{prefix}.parent_key is required.")

        table = table_name_from_source(source_table)
        if table in seen_tables:
            raise ValueError(
                f"{prefix}: duplicate target table dsp.{table} "
                "(two source tables must not share the same table name)."
            )
        seen_tables.add(table)

        layer_name = validate_layer_name(resolve_layer_name(entry), f"{prefix}.layer_name")
        wms_id = f"dsp:{layer_name}"
        if wms_id in seen_wms:
            raise ValueError(f"{prefix}: WMS id {wms_id} collides with another layer.")
        seen_wms.add(wms_id)

        if "srid" not in entry or entry.get("srid") in (None, ""):
            raise ValueError(f"{prefix}.srid is required.")
        srs = normalize_epsg(entry["srid"])

        display_name = entry.get("display_name") or layer_name
        if not isinstance(display_name, str) or not display_name.strip():
            raise ValueError(f"{prefix}.display_name must be a non-empty string.")

        group_key = entry.get("group_key") or "extra_layers"
        if not isinstance(group_key, str) or not group_key.strip():
            raise ValueError(f"{prefix}.group_key must be a non-empty string.")
        group_key = group_key.strip()

        color = entry.get("color", "#2563EB")
        fill_color = entry.get("fill_color", "transparent")
        if not isinstance(color, str) or not HEX_COLOR.fullmatch(color):
            raise ValueError(f"{prefix}.color must be a #RGB or #RRGGBB value.")
        if not isinstance(fill_color, str) or (
            fill_color != "transparent" and not HEX_COLOR.fullmatch(fill_color)
        ):
            raise ValueError(
                f"{prefix}.fill_color must be 'transparent' or a #RGB/#RRGGBB value."
            )

        normalized = {
            "source_table": source_table.strip(),
            "area_of_interest_id_column": aoi_column.strip(),
            "primary_key": require_layer_field(entry, "primary_key", prefix),
            "updated_at_column": require_layer_field(entry, "updated_at_column", prefix),
            "label_column": require_layer_field(entry, "label_column", prefix),
            "geometry_column": require_layer_field(entry, "geometry_column", prefix),
            "layer_name": layer_name,
            "table": table,
            "wms_id": wms_id,
            "srs": srs,
            "srid": int(srs.split(":", 1)[1]),
            "display_name": display_name.strip(),
            "group_key": group_key,
            "active_default": bool(entry.get("active_default", False)),
            "color": color,
            "fill_color": fill_color,
            "where_clause": str(entry.get("where_clause") or "1=1"),
            "enabled": True,
        }
        extras = parse_column_list(entry.get("persist_columns"), f"{prefix}.persist_columns")
        canonical = {
            normalized["primary_key"],
            aoi_column.strip(),
            normalized["updated_at_column"],
            normalized["label_column"],
            normalized["geometry_column"],
        }
        for column in extras:
            if column in canonical:
                raise ValueError(
                    f"{prefix}.persist_columns entry '{column}' duplicates a required column mapping."
                )
        if extras:
            normalized["persist_columns"] = extras
        enabled.append(normalized)
    return enabled


def build_extra_map_layer(entry: dict[str, Any], group_json_key: str) -> dict[str, Any]:
    layer_name = entry["layer_name"]
    stable_key = f"{group_json_key}_{layer_name}".replace("-", "_")
    active = bool(entry["active_default"])
    return {
        "baseUrl": FIXED_WMS_BASE_URL,
        "layers": entry["wms_id"],
        "format": "image/png",
        "transparent": True,
        "name": entry["display_name"],
        "activeDefault": active,
        "active": active,
        "key": stable_key,
        "nativeName": entry["table"],
        "srs": entry["srs"],
        "toggle": {"active": "On", "inactive": "Off"},
        "style": {
            "color": entry["color"],
            "fillColor": entry["fill_color"],
        },
    }


def layer_name_to_code(layer_name: str) -> str:
    return layer_name.replace("-", "_")


def build_download_themes_config(
    values: dict[str, Any],
    extra_layers: list[dict[str, Any]],
) -> dict[str, Any]:
    layer_values = get(values, "map", "layers", default={})
    aoi_override = layer_values.get("area_of_interest", {})
    aoi_name = aoi_override.get("name", "Area of interest")

    themes: list[dict[str, Any]] = [
        {
            "code": "area_of_interest",
            "name": aoi_name,
            "typeName": "dsp:area-of-interest",
            "formats": ["csv"],
            "enabled": True,
            "territoryFilter": {
                "strategy": "direct",
                "level3Field": "territory_level_3_id",
            },
        }
    ]

    for entry in extra_layers:
        layer_name = entry["layer_name"]
        themes.append(
            {
                "code": layer_name_to_code(layer_name),
                "name": entry["display_name"],
                "typeName": entry["wms_id"],
                "formats": ["csv"],
                "enabled": True,
                "territoryFilter": {
                    "strategy": "aoi_linked",
                    "aoiLinkField": "area_of_interest_id",
                },
            }
        )

    return {
        "wfsBaseUrl": FIXED_WFS_BASE_URL,
        "themes": themes,
    }


def append_extra_layers_to_map(
    layers_doc: dict[str, Any],
    values: dict[str, Any],
    extra_layers: list[dict[str, Any]],
) -> None:
    """Append generic layers into mapLayersConfig groups (creates groups as needed)."""
    if not extra_layers:
        return

    group_names = get(values, "map", "group_names", default={}) or {}
    groups_by_key: dict[str, dict[str, Any]] = {
        group["key"]: group for group in layers_doc.get("groups", [])
    }

    for entry in extra_layers:
        adopter_group_key = entry["group_key"]
        json_key = FIXED_GROUP_KEYS.get(adopter_group_key, adopter_group_key)
        group = groups_by_key.get(json_key)
        if group is None:
            display = group_names.get(adopter_group_key, adopter_group_key.replace("_", " ").title())
            group = {
                "name": display,
                "key": json_key,
                "toggle": {"active": "On", "inactive": "Off"},
                "layers": [],
            }
            layers_doc.setdefault("groups", []).append(group)
            groups_by_key[json_key] = group
        elif adopter_group_key in group_names:
            group["name"] = group_names[adopter_group_key]
        group.setdefault("layers", []).append(build_extra_map_layer(entry, json_key))


def build_batch_layers(extra_layers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    batch_layers: list[dict[str, Any]] = []
    for entry in extra_layers:
        item: dict[str, Any] = {
            "source-table": entry["source_table"],
            "primary-key": entry["primary_key"],
            "area-of-interest-id-column": entry["area_of_interest_id_column"],
            "updated-at-column": entry["updated_at_column"],
            "label-column": entry["label_column"],
            "geometry-column": entry["geometry_column"],
            "layer-name": entry["layer_name"],
            "srid": entry["srid"],
            "where-clause": entry["where_clause"],
            "enabled": True,
        }
        extras = entry.get("persist_columns") or []
        if extras:
            item["persist-columns"] = extras
        batch_layers.append(item)
    return batch_layers

def apply_screen_text_overrides(
    installation: dict[str, Any],
    screens_yaml: dict[str, Any],
) -> None:
    """Apply localized screen labels from adopter-config to installation-config."""
    home = installation["screens"]["home"]
    downloads = installation["screens"]["downloads"]

    identifier = screens_yaml.get("identifier")
    if isinstance(identifier, dict):
        target = home.get("identifier")
        if isinstance(target, dict):
            if "label" in identifier:
                target["label"] = identifier["label"]
            if "placeholder" in identifier:
                target["placeholder"] = identifier["placeholder"]

    detail = screens_yaml.get("detail")
    if isinstance(detail, dict):
        target = home.setdefault("detail", {})
        for yaml_key, json_key in (
            ("section_title", "sectionTitle"),
            ("area_of_interest_section_title", "areaOfInterestSectionTitle"),
            ("registration_date_label", "registrationDateLabel"),
            ("alteration_date_label", "alterationDateLabel"),
            ("latitude_label", "latitudeLabel"),
            ("longitude_label", "longitudeLabel"),
            ("area_label", "areaLabel"),
            ("features_download_label", "featuresDownloadLabel"),
        ):
            if yaml_key in detail:
                target[json_key] = detail[yaml_key]

    downloads_yaml = screens_yaml.get("downloads")
    if isinstance(downloads_yaml, dict):
        theme = downloads_yaml.get("theme")
        if isinstance(theme, dict):
            target = downloads.get("theme")
            if isinstance(target, dict):
                if "label" in theme:
                    target["label"] = theme["label"]
                if "placeholder" in theme:
                    target["placeholder"] = theme["placeholder"]
        for yaml_key, json_key in (
            ("level1_section_title", "level1SectionTitle"),
            ("level2_section_title", "level2SectionTitle"),
            ("filter_by_title", "filterByTitle"),
        ):
            if yaml_key in downloads_yaml:
                downloads[json_key] = downloads_yaml[yaml_key]


def ask_screen_text_fields(screens: dict[str, Any]) -> None:
    """Collect localized home and downloads screen labels in the wizard."""
    identifier = screens.setdefault("identifier", {})
    identifier["label"] = ask_field(
        "Home identifier label", identifier.get("label", "Identifier"),
        "Label for the registration ID search field on the home screen.",
        "the home screen search form",
    )
    identifier["placeholder"] = ask_field(
        "Home identifier placeholder", identifier.get("placeholder", "Enter the identifier"),
        "Placeholder shown inside the registration ID search field.",
        "the home screen search form",
    )

    print("\n  Home detail labels")
    print("  What: Text shown on the registration detail panel after a search.")
    print("  Used in: the home screen detail panel")
    detail = screens.setdefault("detail", {})
    detail_fields = (
        ("section_title", "Detail section title", "Search details"),
        ("area_of_interest_section_title","Detail area of interest section title","Area of interest data"),
        ("registration_date_label", "Registration date label", "Registration date"),
        ("alteration_date_label", "Alteration date label", "Alteration date"),
        ("latitude_label", "Latitude label", "Latitude"),
        ("longitude_label", "Longitude label", "Longitude"),
        ("area_label", "Area label", "Area"),
        ("features_download_label", "Features download label", "Download features"),
    )
    for key, label, default in detail_fields:
        detail[key] = ask_field(
            label, detail.get(key, default),
            f"Label for '{default}' on the registration detail panel.",
            "the home screen detail panel",
        )

    print("\n  Downloads screen labels")
    print("  What: Text shown on filters and section headers in the downloads screen.")
    print("  Used in: the downloads screen")
    downloads = screens.setdefault("downloads", {})
    theme = downloads.setdefault("theme", {})
    theme["label"] = ask_field(
        "Downloads theme label", theme.get("label", "Theme"),
        "Label for the theme filter on the downloads screen.",
        "the downloads screen",
    )
    theme["placeholder"] = ask_field(
        "Downloads theme placeholder", theme.get("placeholder", "All themes"),
        "Placeholder for the theme filter on the downloads screen.",
        "the downloads screen",
    )
    downloads["level1_section_title"] = ask_field(
        "Downloads level 1 section title",
        downloads.get(
            "level1_section_title",
            "Select the continent you want to access for Downloads",
        ),
        "Introductory text for territorial level 1 on the downloads screen.",
        "the downloads screen",
    )
    downloads["level2_section_title"] = ask_field(
        "Downloads level 2 section title",
        downloads.get("level2_section_title", "Options for the selected continent"),
        "Introductory text for territorial level 2 on the downloads screen.",
        "the downloads screen",
    )
    downloads["filter_by_title"] = ask_field(
        "Downloads filter-by title", downloads.get("filter_by_title", "Filter by:"),
        "Prefix shown before download filters.",
        "the downloads screen",
    )


def ask_generic_layer_entry(
    config: dict[str, Any],
    entry: dict[str, Any] | None,
) -> dict[str, Any]:
    """Ask every field of one generic layer (migration + map presentation)."""
    entry = copy.deepcopy(entry) if entry else {}

    while True:
        default_source = entry.get("source_table") or "public.my_layer"
        source_table = str(
            ask_field(
                "Source table", default_source,
                "Origin table (schema.table). Destination is always dsp.<table> — do not use schema 'dsp'.",
                "the migration job (reads from your source database)",
            )
        ).strip()
        if "." not in source_table or "<" in source_table:
            print("\n  Enter the origin table as schema.table (e.g. public.my_layer).")
            continue
        try:
            validate_source_table_schema(source_table, "etl.layers")
        except ValueError as exc:
            print(f"\n  {exc}")
            continue
        break
    entry["source_table"] = source_table

    while True:
        aoi_column = str(
            ask_field(
                "parent_key",
                resolve_layer_parent_key(entry) or "",
                etl_field_help("parent_key"),
                "the ETL job mapping for this entity",
            )
        ).strip()
        if aoi_column and "<" not in aoi_column:
            break
        print("\n  Enter the source column name.")
    entry["parent_key"] = aoi_column
    entry.pop("area_of_interest_id_column", None)

    for field in ("primary_key", "updated_at_column", "label_column", "geometry_column"):
        while True:
            value = str(
                ask_field(
                    field,
                    entry.get(field) or "",
                    etl_field_help(field),
                    "the ETL job mapping for this layer",
                )
            ).strip()
            if value and "<" not in value:
                entry[field] = value
                break
            print("\n  Enter the source column name.")

    entry["persist_columns"] = ask_optional_column_list(
        "Extra columns to migrate",
        entry.get("persist_columns") or [],
        etl_field_help("persist_columns"),
        "the ETL job mapping for this layer",
    )
    entry["where_clause"] = ask_field(
        "where-clause", entry.get("where_clause", "1=1"),
        "Optional SQL filter applied while reading this layer.",
        "the ETL source query",
    )

    default_layer_name = entry.get("layer_name") or source_table.rsplit(".", 1)[-1]
    while True:
        raw_name = str(
            ask_field(
                "Layer name", default_layer_name,
                "Technical WMS id (lowercase, digits, hyphens, underscores). Published as dsp:<name>.",
                "GeoServer and the map layer selector",
            )
        ).strip()
        try:
            entry["layer_name"] = validate_layer_name(raw_name, "layer_name")
            break
        except ValueError as exc:
            print(f"\n  {exc}")

    entry["srid"] = ask_int_field(
        "Layer SRID", entry.get("srid", 4674),
        "Coordinate reference system identifier of the source geometry.",
        "ETL geometry conversion and GeoServer layers",
        minimum=1,
    )

    entry["display_name"] = ask_field(
        "Display name", entry.get("display_name") or entry["layer_name"],
        "Human-readable label shown in the map panel (any language).",
        "the map layer selector",
    )

    group_names = config["map"]["group_names"]
    existing_keys = sorted(group_names)
    default_group_key = entry.get("group_key") or (existing_keys[0] if existing_keys else "thematic")
    keys_list = ", ".join(existing_keys) if existing_keys else "(none yet)"
    group_key_help = (
        "Stable group id. Enter an existing key to add this layer to that group, "
        "or type a new key to create a group (you will be asked for its display name next). "
        f"Existing keys: {keys_list}."
    )
    if existing_keys:
        print(
            f"\n  Example: reuse `{existing_keys[0]}` or create `environmental_layers`."
        )
    group_key = str(
        ask_field(
            "Map group key", default_group_key,
            group_key_help,
            "the map layer selector",
        )
    ).strip()
    entry["group_key"] = group_key
    if group_key not in group_names:
        group_names[group_key] = ask_field(
            f"Map group name — {group_key}", group_key.replace("_", " ").capitalize(),
            "Display title for the new group (only asked when the key is new).",
            "the map layer selector",
        )

    entry["active_default"] = ask_bool_field(
        "Enable this layer by default", bool(entry.get("active_default", False)),
        "Whether the layer starts enabled when the map opens.",
        "the initial map state",
    )
    entry["color"] = ask_color_field(
        "Stroke color", entry.get("color", "#2563EB"),
        "Line color used to draw the layer.",
        "the map and generated GeoServer style",
    )
    entry["fill_color"] = ask_color_field(
        "Fill color", entry.get("fill_color", "transparent"),
        "Fill color used inside the layer; use transparent when needed.",
        "the map and generated GeoServer style",
        allow_transparent=True,
    )
    entry["enabled"] = True
    return entry


def ask_generic_layers(config: dict[str, Any]) -> None:
    """Review, edit, and add generic layers under etl.layers."""
    etl = config["etl"]
    declared = list(etl.get("layers") or [])
    result: list[dict[str, Any]] = []

    print("\n  Generic layers")
    print("  What: extra source tables migrated to dsp.<table> and published as WMS layers.")
    print("  Used in: the migration job, GeoServer publishing, and the map layer selector")

    for item in declared:
        if not isinstance(item, dict):
            continue
        print(f"\n  Declared layer: {item.get('source_table', '<unset>')}")
        if not ask_bool("  Keep this layer", True):
            continue
        if ask_bool("  Edit this layer", False):
            item = ask_generic_layer_entry(config, item)
        result.append(item)

    add_next = not result
    while ask_bool("\n  Add a generic layer" if not result else "\n  Add another generic layer", add_next):
        result.append(ask_generic_layer_entry(config, None))
        add_next = False

    etl["layers"] = result


def ask_data_preparation_flow() -> bool:
    print("\nBefore configuring a JDBC source, choose the data preparation flow:")
    print("  1. Quickstart — demonstration data, no JDBC source or migration job")
    print("  2. Empty databases — real adopter setup without running the migration job")
    print("  3. Real adopter — configure a JDBC source and continue this wizard")

    while True:
        choice = ask("Choice", "3")
        if choice == "3":
            return True
        if choice == "1":
            if ask_bool("Use the Quickstart flow instead", True):
                print("\nRun ./setup.sh and choose option 1 (Demonstration).")
                print("This wizard will now exit without configuring a JDBC source.")
                return False
        elif choice == "2":
            if ask_bool("Use the empty-database flow instead", True):
                print("\nRun ./setup.sh and choose option 3 (Real adopter — no migration).")
                print("This wizard will now exit without configuring a JDBC source.")
                return False
        else:
            print("Invalid choice. Enter 1, 2, or 3.")


def wizard(example: Path, active: Path, *, edit: bool = False) -> bool:
    print()
    template = yaml.safe_load(example.read_text(encoding="utf-8"))
    if edit:
        if not active.is_file():
            print(f"Error: file not found: {active}", file=sys.stderr)
            raise SystemExit(1)
        saved = yaml.safe_load(active.read_text(encoding="utf-8"))
        config = deep_merge(template, saved)
        print("Edit adopter configuration")
        print("Each stage explains the field and where its value is used.")
        print("Values between brackets are the current saved values.")
        print("Press Enter to keep the displayed value.")
    else:
        config = copy.deepcopy(template)
        print("Guided adopter configuration")
        print("Each stage explains the field and where its value is used.")
        print("Values between brackets are default/example values.")
        print("Press Enter to accept the displayed default/example value.")
        if not ask_data_preparation_flow():
            return False

    print("\n" + "=" * 72)
    print("Stage 1/5 — Source database and spatial reference")
    print("=" * 72)
    env = config["environment"]
    env["source_jdbc_url"] = ask_field(
        "Source JDBC URL", env["source_jdbc_url"],
        "JDBC address of the database that contains the adopter data.",
        "the ETL migration job and .env",
    )
    env["source_db_user"] = ask_field(
        "Source database user", env["source_db_user"],
        "User used to read the source database.",
        "the ETL migration job and .env",
    )
    env["source_db_password"] = ask_field(
        "Source database password", env["source_db_password"],
        "Password used to read the source database.",
        "the ETL migration job and .env",
    )
    for key, label in (
        ("territory_level_1", "Territorial level 1 SRID"),
        ("territory_level_2", "Territorial level 2 SRID"),
        ("territory_level_3", "Territorial level 3 SRID"),
        ("area_of_interest", "Area of interest SRID"),
    ):
        env["layer_srs"][key] = ask_int_field(
            label, env["layer_srs"][key],
            "Coordinate reference system identifier of the source geometry.",
            "ETL geometry conversion and GeoServer layers",
            minimum=1,
        )

    print("\n" + "=" * 72)
    print("Stage 2/5 — Application text and KPI selection")
    print("=" * 72)
    for level in ("level1", "level2", "level3"):
        section = config["installation"]["hierarchy"][level]
        section["label"] = ask_field(
            f"Displayed name for {level}", section["label"],
            "Name shown to users for this hierarchy level.",
            "filters, downloads, and detail screens",
        )
        section["placeholder"] = ask_field(
            f"Selection text for {level}", section["placeholder"],
            "Text shown when the user has not selected this level.",
            "hierarchy filter controls",
        )
    screens = config["installation"]["screens"]
    screens["home_title"] = ask_field(
        "Home screen title", screens["home_title"],
        "Title displayed above the registration search screen.", "the home screen",
    )
    screens["downloads_title"] = ask_field(
        "Downloads screen title", screens["downloads_title"],
        "Title displayed above the public downloads screen.", "the downloads screen",
    )
    ask_screen_text_fields(screens)
    theme_count = ask_int_field(
        "Number of theme KPIs (0-4)", config["installation"]["kpis"]["theme_count"],
        "Number of optional theme measurements available in the source data. "
        "The Area of Interest (AOI) KPI is always present — this value only "
        "controls additional theme KPIs (use 0 when there are no theme columns).",
        "generated KPI cards and ETL theme mappings",
        minimum=0,
        maximum=4,
    )
    config["installation"]["kpis"]["theme_count"] = theme_count
    reset_disabled_themes(config, template, theme_count)
    for code in ("area_of_interest", "theme_1", "theme_2", "theme_3", "theme_4"):
        card = config["installation"]["kpis"][code]
        if code != "area_of_interest" and not card["enabled"]:
            continue
        card["label"] = ask_field(
            f"KPI label for {code}", card["label"],
            "Human-readable name shown on the KPI card.", "the application dashboard",
        )
        card["unit_of_measurement"] = ask_field(
            f"KPI unit for {code}", card["unit_of_measurement"],
            "Unit displayed beside the KPI value.", "the application dashboard",
        )
        if code == "area_of_interest":
            card["optional_label"] = ask_field(
                "KPI optional label for area_of_interest", card["optional_label"],
                "Secondary unit shown for the area sum (e.g. ha).",
                "the AREA_OF_INTEREST KPI card",
            )
    area = config["installation"]["area"]
    area["unit"] = ask_field(
        "Area unit code", area["unit"],
        "Short code for the area measurement (e.g. ha, m²).",
        "area labels and KPI subtotals",
    )
    area["unit_label"] = ask_field(
        "Area unit label", area["unit_label"],
        "Label shown beside area values in the UI.",
        "detail screens and downloads",
    )
    formats = config["installation"]["formats"]
    formats["date"] = ask_field(
        "Date format", formats["date"],
        "Pattern for dates without time (Java-style, e.g. dd/MM/yyyy).",
        "lists and detail screens",
    )
    formats["date_time"] = ask_field(
        "Date-time format", formats["date_time"],
        "Pattern for dates with time (e.g. dd/MM/yyyy HH:mm).",
        "detail screens",
    )

    print("\n" + "=" * 72)
    print("Stage 3/5 — KPI colors and map layers")
    print("=" * 72)
    ask_kpi_accent_colors(config, theme_count)
    ask_map_initial_view(config)
    group_names = config["map"]["group_names"]
    group_names["territorial_division"] = ask_field(
        "Map group name — territorial division", group_names["territorial_division"],
        "Title of the territorial hierarchy layer group in the map.",
        "the map layer selector",
    )
    group_names["areas_of_interest"] = ask_field(
        "Map group name — areas of interest", group_names["areas_of_interest"],
        "Title of the declared areas layer group in the map.",
        "the map layer selector",
    )
    sync_map_layer_names(config)
    for layer_name, layer in config["map"]["layers"].items():
        print(f"\n  Layer name for {layer_name}")
        print("  What: Same display name defined in the previous stage.")
        print("  Used in: the map layer selector")
        print(f"  Value: {layer['name']}")
        print(f"\n  WMS URL for {layer_name}")
        print("  What: Fixed GeoServer WMS endpoint serving this layer.")
        print("  Used in: the map client and GeoServer requests")
        print(f"  Value: {FIXED_WMS_BASE_URL}")
        layer["active_default"] = ask_bool_field(
            f"Enable {layer_name} by default", layer["active_default"],
            "Whether the layer starts enabled when the map opens.",
            "the initial map state",
        )
        layer["color"] = ask_color_field(
            f"Stroke color for {layer_name}", layer["color"],
            "Line color used to draw the layer boundary.",
            "the map and generated GeoServer style",
        )
        layer["fill_color"] = ask_color_field(
            f"Fill color for {layer_name}", layer["fill_color"],
            "Fill color used inside the layer; use transparent when needed.",
            "the map and generated GeoServer style",
            allow_transparent=True,
        )

    print("\n" + "=" * 72)
    print("Stage 4/5 — Source tables and columns")
    print("=" * 72)
    for name, fields in (
        ("level1", ("source_table", "primary_key", "name_column", "geometry_column", "updated_at_column")),
        (
            "level2",
            ("source_table", "primary_key", "parent_key", "name_column", "geometry_column", "updated_at_column"),
        ),
        (
            "level3",
            ("source_table", "primary_key", "parent_key", "name_column", "geometry_column", "updated_at_column"),
        ),
        (
            "area_of_interest",
            (
                "source_table",
                "primary_key",
                "geometry_column",
                "created_at_column",
                "updated_at_column",
                "territory_level_3_column",
                "area_column",
                "theme_1_column",
                "theme_2_column",
                "theme_3_column",
                "theme_4_column",
            ),
        ),
    ):
        print(f"\nEntity: {name}")
        for field in fields:
            section = config["etl"][name]
            if name == "area_of_interest" and field.startswith("theme_"):
                if int(field.split("_")[1]) > theme_count:
                    section[field] = None
                    continue
            section[field] = ask_field(
                field, section[field],
                etl_field_help(field),
                "the ETL job mapping for this entity",
            )
        if name == "area_of_interest":
            config["etl"][name]["persist_columns"] = ask_optional_column_list(
                "Extra columns to migrate",
                config["etl"][name].get("persist_columns") or [],
                etl_field_help("persist_columns"),
                "the ETL job mapping for this entity",
            )
        config["etl"][name]["where_clause"] = ask_field(
            "where-clause", config["etl"][name]["where_clause"],
            "Optional SQL filter applied while reading this entity.",
            "the ETL source query",
        )

    print("\n" + "=" * 72)
    print("Stage 5/5 — Migration jobs")
    print("=" * 72)
    for name in ("level1", "level2", "level3", "area_of_interest"):
        config["etl"]["jobs"][name] = ask_bool_field(
            f"Run {name} job", config["etl"]["jobs"][name],
            "Whether this entity should be loaded during migration.",
            "the ETL execution plan",
        )
    config["etl"]["jobs"]["layer_jobs"] = ask_bool_field(
        "Run generic layer jobs",
        bool(config["etl"]["jobs"].get("layer_jobs", False)),
        "Whether extra layers (etl.layers) should be migrated and published.",
        "the ETL execution plan",
    )
    if config["etl"]["jobs"]["layer_jobs"]:
        ask_generic_layers(config)
        if not config["etl"].get("layers"):
            print("\n  Note: no generic layer declared; the layer jobs have nothing to migrate.")
    else:
        declared = len(config["etl"].get("layers") or [])
        if declared:
            print(
                f"\n  Note: {declared} generic layer(s) stay declared in etl.layers "
                "but will not be migrated while layer jobs are disabled."
            )
    print(
        "\n  Note: enabled generic layers are also published as download themes "
        "in downloadThemesConfig.json."
    )

    active.parent.mkdir(parents=True, exist_ok=True)
    active.write_text(
        dump_yaml(config),
        encoding="utf-8",
    )
    print(f"\nConfiguration saved to {active}")
    return True


def replace_env(env_file: Path, values: dict[str, Any]) -> None:
    if not env_file.exists():
        example = env_file.with_name(".env.example")
        shutil.copyfile(example, env_file)
    lines = env_file.read_text(encoding="utf-8").splitlines()
    replacements = {
        "DSP_SOURCE_JDBC_URL": get(values, "environment", "source_jdbc_url"),
        "DSP_SOURCE_DB_USER": get(values, "environment", "source_db_user"),
        "DSP_SOURCE_DB_PASSWORD": get(values, "environment", "source_db_password"),
    }
    srs = get(values, "environment", "layer_srs", default={})
    for name, value in srs.items():
        replacements[f"LAYER_SRS_{name.upper()}"] = value
    result = []
    seen = set()
    for line in lines:
        key = line.split("=", 1)[0] if "=" in line and not line.lstrip().startswith("#") else ""
        if key in replacements:
            result.append(f"{key}={replacements[key]}")
            seen.add(key)
        else:
            result.append(line)
    for key, value in replacements.items():
        if key not in seen:
            result.append(f"{key}={value}")
    env_file.write_text("\n".join(result) + "\n", encoding="utf-8")


def set_source_mapping(section: dict[str, Any], values: dict[str, Any]) -> None:
    primary_key = require_non_blank_column(values.get("primary_key"), "primary-key")
    geometry_column = require_non_blank_column(values.get("geometry_column"), "geometry-column")
    updated_at_column = require_non_blank_column(
        values.get("updated_at_column"), "updated-at-column"
    )
    name_column = values.get("name_column")
    if isinstance(name_column, str):
        name_column = name_column.strip() or None
    else:
        name_column = None
    parent_key = values.get("parent_key")
    if isinstance(parent_key, str):
        parent_key = parent_key.strip() or None
    else:
        parent_key = None

    section["source-table"] = values["source_table"]
    section["primary-key"] = primary_key
    section["geometry-column"] = geometry_column
    section["updated-at-column"] = updated_at_column
    section["where-clause"] = values.get("where_clause") or "1=1"
    if parent_key:
        section["partition-column"] = parent_key
    else:
        section.pop("partition-column", None)

    persist = [primary_key]
    if name_column:
        persist.append(name_column)
    if parent_key:
        persist.append(parent_key)
    persist.append(updated_at_column)
    section["persist-columns"] = persist

    mapping = {
        primary_key: "id",
        geometry_column: "geom",
        updated_at_column: "updated_at",
    }
    if name_column:
        mapping[name_column] = "name"
    if parent_key:
        mapping[parent_key] = "parent_id"
    section["column-mapping"] = mapping
    section.pop("comparison-columns", None)
    section.pop("change-detection-strategy", None)


def validate_job_migration_path(root: Path) -> None:
    raw = read_dotenv_value(
        root / ".env",
        "DSP_JOB_MIGRATION_PATH",
        default="../rer-dsp-job-data-migration",
    )
    path = Path(str(raw))
    if not path.is_absolute():
        path = (root / path).resolve()
    else:
        path = path.resolve()
    dockerfile = path / "Dockerfile"
    if not dockerfile.is_file():
        raise ValueError(
            f"Migration job repository not found at: {path} "
            f"(expected Dockerfile). Clone rer-dsp-job-data-migration "
            f"or set DSP_JOB_MIGRATION_PATH in .env."
        )


def apply_config(root: Path, active: Path, *, quiet: bool = False) -> None:
    example = root / "config/adopter/adopter-config.yaml.example"
    template = yaml.safe_load(example.read_text(encoding="utf-8"))
    values = yaml.safe_load(active.read_text(encoding="utf-8"))
    validate_job_migration_path(root)
    theme_count = get(values, "installation", "kpis", "theme_count", default=4)
    if not isinstance(theme_count, int) or theme_count < 0 or theme_count > 4:
        raise ValueError("theme_count must be an integer between 0 and 4.")
    config_changed = reset_disabled_themes(values, template, theme_count)
    config_changed = sync_map_layer_names(values) or config_changed
    config_changed = normalize_adopter_layer_field_aliases(values) or config_changed
    if config_changed:
        active.write_text(dump_yaml(values), encoding="utf-8")
    source_values = []
    for entity in ("level1", "level2", "level3", "area_of_interest"):
        entity_values = get(values, "etl", entity, default={})
        source_values.extend(
            value
            for key, value in entity_values.items()
            if not (
                entity == "area_of_interest"
                and key.startswith("theme_")
                and int(key.split("_")[1].split("_")[0]) > theme_count
            )
        )
    invalid = [
        str(value)
        for value in source_values
        if isinstance(value, str) and ("<source_" in value or value == "source_schema.source_table")
    ]
    if invalid:
        raise ValueError(
            "The ETL configuration still contains placeholders. "
            "Fill in the source table and columns in the wizard or adopter-config.yaml."
        )
    for layer_name, layer in get(values, "map", "layers", default={}).items():
        color = layer.get("color")
        fill_color = layer.get("fill_color")
        if not isinstance(color, str) or not HEX_COLOR.fullmatch(color):
            raise ValueError(
                f"map.layers.{layer_name}.color must be a #RGB or #RRGGBB value."
            )
        if not isinstance(fill_color, str) or (
            fill_color != "transparent" and not HEX_COLOR.fullmatch(fill_color)
        ):
            raise ValueError(
                f"map.layers.{layer_name}.fill_color must be 'transparent' or a #RGB/#RRGGBB value."
            )
    extra_layers = validate_extra_layers(values)
    if coerce_map_initial_view_to_planet(values):
        active.write_text(dump_yaml(values), encoding="utf-8")
    map_initial_view = validate_map_initial_view(values)
    kpis = get(values, "installation", "kpis", default={})
    for code in enabled_kpi_codes(theme_count):
        accent_color = get(kpis, code, "accent_color")
        if not isinstance(accent_color, str) or not HEX_COLOR.fullmatch(accent_color):
            raise ValueError(
                f"installation.kpis.{code}.accent_color must be a #RGB or #RRGGBB value."
            )
    if any(
        "\n" in str(get(values, "etl", entity, "source_table", default=""))
        for entity in ("level1", "level2", "level3", "area_of_interest")
    ):
        active.write_text(dump_yaml(values), encoding="utf-8")
    installation = json.loads(
        (root / "config/installation/installation-config.json.example").read_text(
            encoding="utf-8"
        )
    )
    hierarchy = get(values, "installation", "hierarchy", default={})
    for item in installation["hierarchy"]:
        override = hierarchy.get(item["key"], {})
        item["label"] = override.get("label", item["label"])
        item["placeholder"] = override.get("placeholder", item["placeholder"])
    screens = get(values, "installation", "screens", default={})
    installation["screens"]["home"]["title"] = screens.get(
        "home_title", installation["screens"]["home"]["title"]
    )
    installation["screens"]["downloads"]["title"] = screens.get(
        "downloads_title", installation["screens"]["downloads"]["title"]
    )
    apply_screen_text_overrides(installation, screens)
    cards = get(values, "installation", "kpis", default={})
    configured_cards = []
    for card in installation["kpis"]["cards"]:
        override = cards.get(card["code"].lower(), {})
        if card["code"].startswith("THEME_"):
            theme_number = int(card["code"].split("_")[1])
            if theme_number > theme_count:
                continue
        if override.get("enabled") is False:
            continue
        for source, target in (
            ("label", "label"),
            ("unit_of_measurement", "unitOfMeasurement"),
            ("optional_label", "optionalLabel"),
        ):
            if source in override:
                card[target] = override[source]
        accent_color = override.get("accent_color")
        if isinstance(accent_color, str) and HEX_COLOR.fullmatch(accent_color):
            card["accentColor"] = accent_color
        configured_cards.append(card)
    installation["kpis"]["cards"] = configured_cards
    area = get(values, "installation", "area", default={})
    installation["areaOfInterest"]["areaUnit"] = area.get(
        "unit", installation["areaOfInterest"]["areaUnit"]
    )
    installation["areaOfInterest"]["areaUnitLabel"] = area.get(
        "unit_label", installation["areaOfInterest"]["areaUnitLabel"]
    )
    formats = get(values, "installation", "formats", default={})
    installation["formats"]["date"] = formats.get("date", installation["formats"]["date"])
    installation["formats"]["dateTime"] = formats.get(
        "date_time", installation["formats"]["dateTime"]
    )
    installation["map"] = map_initial_view
    install_file = root / "config/installation/installation-config.json"
    install_file.write_text(
        json.dumps(installation, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    layers = json.loads(
        (root / "config/map/mapLayersConfig.json.example").read_text(encoding="utf-8")
    )
    layer_values = get(values, "map", "layers", default={})
    layer_names = {
        "territory-level-1": "level1",
        "territory-level-2": "level2",
        "territory-level-3": "level3",
        "area-of-interest": "area_of_interest",
    }
    for group in layers["groups"]:
        for layer in group["layers"]:
            identifier = layer["layers"].split(":")[-1]
            override = layer_values.get(layer_names[identifier], {})
            for source, target in (
                ("name", "name"),
                ("active_default", "activeDefault"),
            ):
                if source in override:
                    layer[target] = override[source]
            layer.setdefault("style", {})["color"] = override.get(
                "color", layer["style"]["color"]
            )
            layer["style"]["fillColor"] = override.get(
                "fill_color", layer["style"]["fillColor"]
            )
        group_key = "territorial_division" if group["key"] == "dt" else "areas_of_interest"
        if group["key"] in ("dt", "ird"):
            group["name"] = get(values, "map", "group_names", group_key, default=group["name"])
    append_extra_layers_to_map(layers, values, extra_layers)
    map_file = root / "config/map/mapLayersConfig.json"
    map_file.write_text(json.dumps(layers, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    download_themes = build_download_themes_config(values, extra_layers)
    download_dir = root / "config/downloads"
    download_dir.mkdir(parents=True, exist_ok=True)
    download_file = root / "config/downloads/downloadThemesConfig.json"
    download_file.write_text(
        json.dumps(download_themes, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    migration_example = root / "config/Job-Data-Migration/application/application.yaml.example"
    migration = yaml.safe_load(migration_example.read_text(encoding="utf-8"))
    etl = get(values, "etl", default={})
    for name in ("level1", "level2", "level3"):
        set_source_mapping(migration["batch"]["admin-unit"][name.replace("level", "level-")], etl[name])
    aoi = migration["batch"]["area-of-interest"]
    aoi_values = etl["area_of_interest"]
    aoi.update(
        {
            "source-table": aoi_values["source_table"],
            "primary-key": require_non_blank_column(
                aoi_values.get("primary_key"), "etl.area_of_interest.primary_key"
            ),
            "creation-date-column": require_non_blank_column(
                aoi_values.get("created_at_column"),
                "etl.area_of_interest.created_at_column",
            ),
            "updated-at-column": require_non_blank_column(
                aoi_values.get("updated_at_column"),
                "etl.area_of_interest.updated_at_column",
            ),
            "commune-id-column": require_non_blank_column(
                aoi_values.get("territory_level_3_column"),
                "etl.area_of_interest.territory_level_3_column",
            ),
            "total-area-column": require_non_blank_column(
                aoi_values.get("area_column"), "etl.area_of_interest.area_column"
            ),
            "geometry-column": require_non_blank_column(
                aoi_values.get("geometry_column"),
                "etl.area_of_interest.geometry_column",
            ),
            "where-clause": aoi_values.get("where_clause") or "1=1",
        }
    )
    extras = parse_column_list(
        aoi_values.get("persist_columns"),
        "etl.area_of_interest.persist_columns",
    )
    canonical_source = {
        aoi["primary-key"],
        aoi["creation-date-column"],
        aoi["updated-at-column"],
        aoi["commune-id-column"],
        aoi["total-area-column"],
        aoi["geometry-column"],
    }
    for column in extras:
        if column in canonical_source:
            raise ValueError(
                "etl.area_of_interest.persist_columns entry "
                f"'{column}' duplicates a required column mapping."
            )
    aoi["persist-columns"] = extras
    aoi.pop("comparison-columns", None)
    aoi.pop("column-mapping", None)
    aoi.pop("change-detection-strategy", None)
    aoi["business-only-persist-columns"] = []
    for index in range(1, 5):
        if index > theme_count:
            continue
        source = aoi_values.get(f"theme_{index}_column")
        if not isinstance(source, str) or not source.strip() or source.strip().lower() == "null":
            raise ValueError(
                f"etl.area_of_interest.theme_{index}_column is required when "
                f"installation.kpis.theme_count is {theme_count}. "
                "Set the source column, or lower theme_count to 0 if you have no theme KPIs."
            )
        source = source.strip()
        if source in canonical_source or source in extras:
            raise ValueError(
                f"etl.area_of_interest.theme_{index}_column '{source}' duplicates "
                "a required or extra persist column."
            )
        if source in aoi["business-only-persist-columns"]:
            raise ValueError(
                f"etl.area_of_interest.theme_{index}_column '{source}' is duplicated."
            )
        aoi["business-only-persist-columns"].append(source)
    migration["batch"]["layers"] = build_batch_layers(extra_layers)
    jobs = etl.get("jobs", {})
    job_names = {
        "level1": "admin-unit-level-1-geoserver-job",
        "level2": "admin-unit-level-2-geoserver-job",
        "level3": "admin-unit-level-3-geoserver-job",
        "area_of_interest": "area-of-interest-geoserver-job",
    }
    for name, target in job_names.items():
        migration["execution-jobs"][target] = bool(jobs.get(name, True))
    layer_jobs_enabled = bool(jobs.get("layer_jobs", bool(extra_layers)))
    migration["execution-jobs"]["layer-jobs"] = layer_jobs_enabled
    output = root / "config/Job-Data-Migration/application/application.yaml"
    output.write_text(dump_yaml(migration), encoding="utf-8")
    replace_env(root / ".env", values)
    if not quiet:
        print("Configuration files generated successfully.")
        if extra_layers:
            print(f"  Generic layers: {len(extra_layers)} (layer-jobs={layer_jobs_enabled})")
        print(f"  Download themes: {len(download_themes.get('themes', []))}")
        print("\nNext steps:")
        print(f"  1. Review: {active}")
        print(
            "  2. For SQL subqueries, keep source_table in a YAML folded block (>-)"
        )
        print("  3. Run ./setup.sh and choose option 2 (migrate) or 3 (no migration).")
        print("  4. Run ./start.sh to start the application.")

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--wizard", action="store_true")
    parser.add_argument(
        "--edit",
        action="store_true",
        help="Edit an existing configuration (use with --wizard).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress success message and next steps (used by setup.sh).",
    )
    args = parser.parse_args()
    example = args.root / "config/adopter/adopter-config.yaml.example"
    active = args.config or args.root / "config/adopter/adopter-config.yaml"
    if args.edit and not args.wizard:
        print("Error: --edit requires --wizard.", file=sys.stderr)
        raise SystemExit(1)
    if args.wizard:
        try:
            if not wizard(example, active, edit=args.edit):
                return
        except ValueError as error:
            print(f"\nConfiguration error: {error}", file=sys.stderr)
            raise SystemExit(1)
    if not active.exists():
        print(f"Error: file not found: {active}", file=sys.stderr)
        print("Run ./config.sh to start the guided configuration.", file=sys.stderr)
        raise SystemExit(1)
    try:
        apply_config(args.root, active, quiet=args.quiet)
    except (KeyError, TypeError, ValueError) as error:
        print(f"Adopter configuration error: {error}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
