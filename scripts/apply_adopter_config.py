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

FIXED_WMS_BASE_URL = "http://localhost:22668/geoserver/dsp/wms"
HEX_COLOR = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")

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


def get(data: dict[str, Any], *keys: str, default: Any = None) -> Any:
    value: Any = data
    for key in keys:
        if not isinstance(value, dict):
            return default
        value = value.get(key, default)
    return value


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
            "./config.sh --apply — do not type SQL here."
        ),
        "primary_key": "Unique source column used to identify each record.",
        "parent_key": "Source column linking this record to its parent territory.",
        "name_column": "Source column containing the display name.",
        "geometry_column": "Source column containing the geometry.",
        "created_at_column": "Source column containing the registration date.",
        "updated_at_column": "Source column containing the last modification date.",
        "territory_level_3_column": "Source column linking an area to territorial level 3.",
        "area_column": "Source column containing the area measurement.",
        "theme_1_column": "Source column containing theme 1 values.",
        "theme_2_column": "Source column containing theme 2 values.",
        "theme_3_column": "Source column containing theme 3 values.",
        "theme_4_column": "Source column containing theme 4 values.",
    }
    return descriptions.get(field, "Source value used by the ETL mapping.")


def wizard(example: Path, active: Path) -> bool:
    config = yaml.safe_load(example.read_text(encoding="utf-8"))
    print("Guided adopter configuration")
    print("Each stage explains the field and where its value is used.")
    print("Values between brackets are default/example values.")
    print("Press Enter to accept the displayed default/example value.")
    print("\n" + "=" * 72)
    print("Setup mode")
    print("=" * 72)
    print("  1) Real adopter setup with source data migration")
    print("  2) Quickstart demonstration without source data")
    setup_mode = input("Choose setup mode: ").strip() or "1"
    if setup_mode == "2":
        print("\nQuickstart selected.")
        print("No migration fields are required.")
        print("Run: ./setup.sh --quickstart")
        print("Then run: ./start.sh")
        return False
    if setup_mode != "1":
        raise ValueError("Choose 1 for real setup or 2 for quickstart.")

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
        env["layer_srs"][key] = int(ask_field(
            label, env["layer_srs"][key],
            "Coordinate reference system identifier of the source geometry.",
            "ETL geometry conversion and GeoServer layers",
        ))

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
    theme_count = int(ask_field(
        "Number of theme KPIs (0-4)", 4,
        "Number of optional theme measurements available in the source data.",
        "generated KPI cards and ETL theme mappings",
    ))
    if theme_count < 0 or theme_count > 4:
        raise ValueError("The number of theme KPIs must be between 0 and 4.")
    config["installation"]["kpis"]["theme_count"] = theme_count
    for code in ("area_of_interest", "theme_1", "theme_2", "theme_3", "theme_4"):
        card = config["installation"]["kpis"][code]
        if code != "area_of_interest":
            theme_number = int(code.split("_")[1])
            card["enabled"] = theme_number <= theme_count
            if not card["enabled"]:
                continue
        card["label"] = ask_field(
            f"KPI label for {code}", card["label"],
            "Human-readable name shown on the KPI card.", "the application dashboard",
        )
        card["unit_of_measurement"] = ask_field(
            f"KPI unit for {code}", card["unit_of_measurement"],
            "Unit displayed beside the KPI value.", "the application dashboard",
        )

    print("\n" + "=" * 72)
    print("Stage 3/5 — Map layers")
    print("=" * 72)
    for layer_name, layer in config["map"]["layers"].items():
        layer["name"] = ask_field(
            f"Layer name for {layer_name}", layer["name"],
            "Name shown to users in the map layer list.", "the map layer selector",
        )
        print(f"\n  WMS URL for {layer_name}")
        print("  What: Fixed GeoServer WMS endpoint serving this layer.")
        print("  Used in: the map client and GeoServer requests")
        print(f"  Value: {FIXED_WMS_BASE_URL}")
        layer["active_default"] = ask_bool_field(
            f"Enable {layer_name} by default", layer["active_default"],
            "Whether the layer starts enabled when the map opens.",
            "the initial map state",
        )
        layer["color"] = ask_field(
            f"Stroke color for {layer_name}", layer["color"],
            "Line color used to draw the layer boundary.",
            "the map and generated GeoServer style",
        )
        layer["fill_color"] = ask_field(
            f"Fill color for {layer_name}", layer["fill_color"],
            "Fill color used inside the layer; use transparent when needed.",
            "the map and generated GeoServer style",
        )

    print("\n" + "=" * 72)
    print("Stage 4/5 — Source tables and columns")
    print("=" * 72)
    for name, fields in (
        ("level1", ("source_table", "primary_key", "name_column", "geometry_column")),
        (
            "level2",
            ("source_table", "primary_key", "parent_key", "name_column", "geometry_column"),
        ),
        (
            "level3",
            ("source_table", "primary_key", "parent_key", "name_column", "geometry_column"),
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
        "DSP_BACKEND_PATH": get(values, "environment", "backend_path"),
        "DSP_FRONTEND_PATH": get(values, "environment", "frontend_path"),
        "DSP_JOB_MIGRATION_PATH": get(values, "environment", "job_migration_path"),
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
    section["source-table"] = values["source_table"]
    section["primary-key"] = values["primary_key"]
    section["geometry-column"] = values["geometry_column"]
    section["where-clause"] = values["where_clause"]
    if values.get("parent_key"):
        section["partition-column"] = values["parent_key"]
    for key in ("source_pk", "source_name", "source_geom", "source_parent_pk"):
        section["comparison-columns"] = [
            values.get("name_column", values.get("primary_key"))
            if item == "<source_name>"
            else values.get("parent_key", values.get("primary_key"))
            if item == "<source_parent_pk>"
            else item
            for item in section.get("comparison-columns", [])
            if not item.startswith("<") or item in {"<source_name>", "<source_parent_pk>"}
        ]
    replacements = {
        "<source_pk>": values["primary_key"],
        "<source_name>": values.get("name_column"),
        "<source_geom>": values["geometry_column"],
        "<source_parent_pk>": values.get("parent_key"),
    }
    section["persist-columns"] = [
        replacements.get(item, item) if replacements.get(item, item) else item
        for item in section.get("persist-columns", [])
    ]
    mapping = section.get("column-mapping", {})
    for placeholder, source in replacements.items():
        if placeholder in mapping:
            mapping[source] = mapping.pop(placeholder)


def apply_config(root: Path, active: Path) -> None:
    values = yaml.safe_load(active.read_text(encoding="utf-8"))
    theme_count = get(values, "installation", "kpis", "theme_count", default=4)
    if not isinstance(theme_count, int) or theme_count < 0 or theme_count > 4:
        raise ValueError("theme_count must be an integer between 0 and 4.")
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
            ("accent_color", "accentColor"),
        ):
            if source in override:
                card[target] = override[source]
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
        group["name"] = get(values, "map", "group_names", group_key, default=group["name"])
    map_file = root / "config/map/mapLayersConfig.json"
    map_file.write_text(json.dumps(layers, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

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
            "primary-key": aoi_values["primary_key"],
            "geometry-column": aoi_values["geometry_column"],
            "where-clause": aoi_values["where_clause"],
        }
    )
    aoi["persist-columns"] = [
        aoi_values["primary_key"] if item == "<source_pk>" else item
        for item in aoi["persist-columns"]
    ]
    aoi_mapping = aoi.get("column-mapping", {})
    for placeholder, source, target in (
        ("<source_pk>", aoi_values["primary_key"], "id"),
        ("<source_geom>", aoi_values["geometry_column"], "geometry"),
    ):
        if placeholder in aoi_mapping:
            aoi_mapping[source] = aoi_mapping.pop(placeholder)
    for key, source in (
        ("<source_created_at>", "created_at_column"),
        ("<source_updated_at>", "updated_at_column"),
        ("<source_territory_level_3_fk>", "territory_level_3_column"),
        ("<source_area>", "area_column"),
    ):
        for list_name in ("comparison-columns", "persist-columns"):
            aoi[list_name] = [aoi_values.get(source) if item == key else item for item in aoi[list_name]]
        if key in aoi.get("column-mapping", {}):
            aoi["column-mapping"][aoi_values[source]] = aoi["column-mapping"].pop(key)
    aoi["business-only-persist-columns"] = []
    for index in range(1, 5):
        key = f"<source_theme_{index}>"
        if index > theme_count:
            aoi["column-mapping"].pop(key, None)
            continue
        source = aoi_values[f"theme_{index}_column"]
        aoi["business-only-persist-columns"].append(source)
        if key in aoi["column-mapping"]:
            aoi["column-mapping"][source] = aoi["column-mapping"].pop(key)
    jobs = etl.get("jobs", {})
    job_names = {
        "level1": "admin-unit-level-1-geoserver-job",
        "level2": "admin-unit-level-2-geoserver-job",
        "level3": "admin-unit-level-3-geoserver-job",
        "area_of_interest": "area-of-interest-geoserver-job",
    }
    for name, target in job_names.items():
        migration["execution-jobs"][target] = bool(jobs.get(name, True))
    output = root / "config/Job-Data-Migration/application/application.yaml"
    output.write_text(dump_yaml(migration), encoding="utf-8")
    replace_env(root / ".env", values)
    print("Configuration files generated successfully.")
    print("\nNext steps:")
    print(f"  1. Review: {active}")
    print(
        "  2. For SQL subqueries, keep source_table in a YAML folded block (>-)"
    )
    print("  3. Run ./setup.sh to migrate data and publish GeoServer layers.")
    print("  4. Run ./start.sh to start the application.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--wizard", action="store_true")
    args = parser.parse_args()
    example = args.root / "config/adopter/adopter-config.yaml.example"
    active = args.config or args.root / "config/adopter/adopter-config.yaml"
    if args.wizard and not wizard(example, active):
        return
    if not active.exists():
        print(f"Error: file not found: {active}", file=sys.stderr)
        print("Run ./config.sh to start the guided configuration.", file=sys.stderr)
        raise SystemExit(1)
    try:
        apply_config(args.root, active)
    except (KeyError, TypeError, ValueError) as error:
        print(f"Adopter configuration error: {error}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
