#!/usr/bin/env bash
# =============================================================================
# RER DSP — start local stack (databases + optional migration + apps)
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

TOTAL_STEPS=10

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

step_header() {
  local step="$1"
  local title="$2"
  echo ""
  echo "============================================================================="
  echo "Step ${step}/${TOTAL_STEPS} — ${title}"
  echo "============================================================================="
}

resolve_path() {
  local path="$1"
  local resolved
  if [[ "$path" = /* ]]; then
    resolved="$path"
  else
    resolved="$ROOT_DIR/$path"
  fi
  realpath -m "$resolved"
}

validate_json_file() {
  local file="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$file" >/dev/null
    return $?
  fi
  if command -v jq >/dev/null 2>&1; then
    jq empty "$file" >/dev/null
    return $?
  fi
  warn "Neither python3 nor jq found — skipping JSON syntax validation for: $file"
  return 0
}

# Ensures an adopter JSON config exists, is valid, and differs from the template.
# Hard block: startup cannot continue while the active file is still the template copy.
ensure_adopter_json_config() {
  local label="$1"
  local example="$2"
  local active="$3"
  local edit_hint="$4"

  if [ ! -f "$example" ]; then
    error "${label} template not found at: $example"
    exit 1
  fi

  if [ ! -f "$active" ]; then
    cp "$example" "$active"
    error "${label} file not found:"
    echo "        $active"
    info "Created from template: $example"
    error "Edit the file (${edit_hint}) and run './start.sh' again."
    exit 1
  fi

  if ! validate_json_file "$active"; then
    error "${label} file contains invalid JSON:"
    echo "        $active"
    exit 1
  fi

  if cmp -s "$active" "$example"; then
    error "${label} file is still identical to the template."
    echo "        $active"
    error "Edit the file (${edit_hint}) before continuing."
    exit 1
  fi

  ok "${label} configured: $active"
}

print_installation_preview() {
  local cfg="$1"
  info "Installation configuration preview:"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  File: $cfg"
    return
  fi
  python3 - "$cfg" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

print("  Hierarchy:")
for level in data.get("hierarchy", []):
    print(f"    {level.get('key', '?')}: {level.get('label', '?')}")

screens = data.get("screens", {})
home = screens.get("home", {})
downloads = screens.get("downloads", {})
print(f"  Home screen: {home.get('title', '<missing>')}")
print(f"  Downloads screen: {downloads.get('title', '<missing>')}")

kpis = data.get("kpis", {})
cards = kpis.get("cards", [])
print(f"  KPI cards: {len(cards)} (primary: {kpis.get('primaryCode', '<missing>')})")

aoi = data.get("areaOfInterest", {})
print(f"  Area unit: {aoi.get('areaUnitLabel', '<missing>')}")
PY
}

print_map_layers_preview() {
  local cfg="$1"
  info "Map layers configuration preview:"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  File: $cfg"
    return
  fi
  python3 - "$cfg" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

for group in data.get("groups", []):
    print(f"  Group: {group.get('name', '?')} ({group.get('key', '?')})")
    for layer in group.get("layers", []):
        style = layer.get("style") or {}
        color = style.get("color", "<missing>")
        fill = style.get("fillColor", "<missing>")
        print(f"    - {layer.get('name', '?')} [{layer.get('layers', '<missing>')}]")
        print(f"      baseUrl: {layer.get('baseUrl', '<missing>')}")
        print(f"      color: {color} | fillColor: {fill}")
PY
}

# Validates fixed WMS layer ids and style colors used by GeoServer Exhibition populate.
validate_map_layers_wms_ids() {
  local cfg="$1"
  if ! command -v python3 >/dev/null 2>&1; then
    error "python3 is required to validate mapLayersConfig WMS layer ids and colors."
    exit 1
  fi
  if ! python3 - "$cfg" <<'PY'
import json
import re
import sys

REQUIRED = {
    "dsp:territory-level-1",
    "dsp:territory-level-2",
    "dsp:territory-level-3",
    "dsp:area-of-interest",
}
HEX = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

by_id = {}
for group in data.get("groups", []):
    for layer in group.get("layers", []):
        lid = layer.get("layers")
        if isinstance(lid, str) and lid:
            by_id[lid] = layer

missing = sorted(REQUIRED - set(by_id))
errors = []
if missing:
    print("EXPECTED (required WMS layer ids):")
    for item in sorted(REQUIRED):
        print(f"  - {item}")
    print("FOUND in mapLayersConfig.json:")
    for item in sorted(by_id) or ["(none)"]:
        print(f"  - {item}")
    print("MISSING:")
    for item in missing:
        print(f"  - {item}")
    sys.exit(1)

for lid in sorted(REQUIRED):
    style = (by_id[lid].get("style") or {})
    color = style.get("color")
    fill = style.get("fillColor")
    if not isinstance(color, str) or not color.strip():
        errors.append(f"{lid}: style.color is missing")
    elif not HEX.match(color):
        errors.append(f"{lid}: style.color must be #RGB or #RRGGBB (got {color!r})")
    if not isinstance(fill, str) or not fill.strip():
        errors.append(f"{lid}: style.fillColor is missing")
    elif fill != "transparent" and not HEX.match(fill):
        errors.append(
            f"{lid}: style.fillColor must be 'transparent' or #RGB/#RRGGBB (got {fill!r})"
        )

if errors:
    print("INVALID layer style colors:")
    for item in errors:
        print(f"  - {item}")
    sys.exit(1)
sys.exit(0)
PY
  then
    error "mapLayersConfig.json must keep the four WMS layer ids and valid style colors."
    error "Ids must match GeoServer Exhibition populate and job layer-name."
    error "style.color: #RGB or #RRGGBB; style.fillColor: transparent or #RGB/#RRGGBB."
    exit 1
  fi
  ok "WMS layer ids and style colors match Exhibition contract"
}

wait_for_geoserver() {
  local url="$1"
  local user="$2"
  local password="$3"
  local i
  for i in $(seq 1 60); do
    if command -v curl >/dev/null 2>&1; then
      if curl -sf -u "${user}:${password}" \
          "${url}/rest/about/version.json" >/dev/null 2>&1; then
        return 0
      fi
    elif docker compose --env-file .env exec -T dsp-geoserver-exhibition \
        curl -sf -u "${user}:${password}" \
        "http://localhost:8080/geoserver/rest/about/version.json" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# Lê um valor escalar simples do YAML sob um bloco (ex.: spring.datasource.batch.url).
yaml_scalar() {
  local file="$1"
  local section="$2"
  local key="$3"
  awk -v section="$section" -v key="$key" '
    function leading_spaces(s) {
      match(s, /^[ ]*/)
      return RLENGTH
    }
    BEGIN { in_section = 0; section_indent = -1 }
    {
      indent = leading_spaces($0)
      line = $0
      sub(/^[ ]+/, "", line)
    }
    line ~ ("^" section ":") {
      in_section = 1
      section_indent = indent
      next
    }
    in_section && line != "" && line !~ /^#/ && indent <= section_indent {
      in_section = 0
    }
    in_section && line ~ ("^" key ":") {
      sub(/^[^:]+:[ ]*/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      print line
      exit
    }
  ' "$file"
}

yaml_source_table() {
  local file="$1"
  local section="$2"
  local line
  line="$(awk -v section="$section" '
    function leading_spaces(s) {
      match(s, /^[ ]*/)
      return RLENGTH
    }
    BEGIN { in_section = 0; section_indent = -1 }
    {
      indent = leading_spaces($0)
      line = $0
      sub(/^[ ]+/, "", line)
    }
    line ~ ("^" section ":") {
      in_section = 1
      section_indent = indent
      next
    }
    in_section && line != "" && line !~ /^#/ && indent <= section_indent {
      in_section = 0
    }
    in_section && line ~ /^source-table:/ {
      sub(/^[^:]+:[ ]*/, "", line)
      print line
      exit
    }
  ' "$file")"
  if [ -z "$line" ] || [[ "$line" == ">-" ]] || [[ "$line" == "|"* ]] || [[ "$line" == "("* ]]; then
    echo "SQL query defined in YAML"
  else
    echo "$line" | sed -e 's/^["'\'']//' -e 's/["'\'']$//'
  fi
}

yaml_target_table() {
  yaml_scalar "$1" "$2" "target-table"
}

job_enabled_label() {
  if [ "${1:-false}" = "true" ]; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

print_migration_preview() {
  local cfg="$1"
  local run_label="disabled"
  if [ "${DSP_RUN_MIGRATION:-false}" = "true" ]; then
    run_label="enabled"
  fi

  local batch_url source_url target_url
  local batch_user source_user target_user
  batch_url="$(yaml_scalar "$cfg" "batch" "url")"
  batch_user="$(yaml_scalar "$cfg" "batch" "username")"
  source_url="$(yaml_scalar "$cfg" "source" "url")"
  source_user="$(yaml_scalar "$cfg" "source" "username")"
  target_url="$(yaml_scalar "$cfg" "target" "url")"
  target_user="$(yaml_scalar "$cfg" "target" "username")"

  local l1_src l1_tgt l2_src l2_tgt l3_src l3_tgt aoi_src aoi_tgt
  l1_src="$(yaml_source_table "$cfg" "level-1")"
  l1_tgt="$(yaml_target_table "$cfg" "level-1")"
  l2_src="$(yaml_source_table "$cfg" "level-2")"
  l2_tgt="$(yaml_target_table "$cfg" "level-2")"
  l3_src="$(yaml_source_table "$cfg" "level-3")"
  l3_tgt="$(yaml_target_table "$cfg" "level-3")"
  aoi_src="$(yaml_source_table "$cfg" "area-of-interest")"
  aoi_tgt="$(yaml_target_table "$cfg" "area-of-interest")"

  local j1 j2 j3 j_aoi
  j1="$(yaml_scalar "$cfg" "execution-jobs" "admin-unit-level-1-geoserver-job")"
  j2="$(yaml_scalar "$cfg" "execution-jobs" "admin-unit-level-2-geoserver-job")"
  j3="$(yaml_scalar "$cfg" "execution-jobs" "admin-unit-level-3-geoserver-job")"
  j_aoi="$(yaml_scalar "$cfg" "execution-jobs" "area-of-interest-geoserver-job")"

  info "Migration configuration preview:"
  echo "  Job execution: ${run_label} (DSP_RUN_MIGRATION=${DSP_RUN_MIGRATION:-false})"
  echo "  Datasources:"
  echo "    batch:  ${batch_url:-<missing>} (user: ${batch_user:-<missing>})"
  echo "    source: ${source_url:-<missing>} (user: ${source_user:-<missing>})"
  echo "    target: ${target_url:-<missing>} (user: ${target_user:-<missing>})"
  echo "  ETL mappings:"
  echo "    level 1:          ${l1_src:-<missing>} -> ${l1_tgt:-<missing>}"
  echo "    level 2:          ${l2_src:-<missing>} -> ${l2_tgt:-<missing>}"
  echo "    level 3:          ${l3_src:-<missing>} -> ${l3_tgt:-<missing>}"
  echo "    area of interest: ${aoi_src:-<missing>} -> ${aoi_tgt:-<missing>}"
  echo "  Jobs:"
  echo "    level 1: $(job_enabled_label "$j1")"
  echo "    level 2: $(job_enabled_label "$j2")"
  echo "    level 3: $(job_enabled_label "$j3")"
  echo "    area of interest: $(job_enabled_label "$j_aoi")"
}

wait_for_db() {
  local service="$1"
  local user="$2"
  local db="$3"
  local i
  for i in $(seq 1 60); do
    if docker compose --env-file .env exec -T "$service" \
        pg_isready -U "$user" -d "$db" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# =============================================================================
# Step 1 — Prerequisites (Docker)
# =============================================================================
step_header 1 "Prerequisites (Docker)"

if [ "$(id -u)" -eq 0 ]; then
  error "Do not run as root/sudo. Use: ./start.sh"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  error "Docker is required."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  error "Docker Compose v2 is required (docker compose)."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  error "Docker daemon is not running. Start Docker and run './start.sh' again."
  exit 1
fi
ok "Docker and Docker Compose OK"

# =============================================================================
# Step 2 — Environment (.env)
# =============================================================================
step_header 2 "Environment (.env)"

if [ ! -f .env ]; then
  info "Creating .env from .env.example"
  cp .env.example .env
  ok ".env created — review values if needed"
else
  info "Using existing .env"
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

# =============================================================================
# Step 3 — Repository paths
# =============================================================================
step_header 3 "Repository paths (backend / frontend)"

BACKEND_PATH="${DSP_BACKEND_PATH:-../rer-dsp-backend}"
FRONTEND_PATH="${DSP_FRONTEND_PATH:-../rer-dsp-frontend}"
JOB_PATH="${DSP_JOB_MIGRATION_PATH:-../rer-dsp-job-data-migration}"

info "Resolving repository paths..."
BACKEND_ABS="$(resolve_path "$BACKEND_PATH")"
FRONTEND_ABS="$(resolve_path "$FRONTEND_PATH")"
JOB_ABS="$(resolve_path "$JOB_PATH")"

if [ ! -f "$BACKEND_ABS/Dockerfile" ]; then
  error "Backend not found at: $BACKEND_ABS"
  error "Clone rer-dsp-backend as a sibling or set DSP_BACKEND_PATH in .env"
  exit 1
fi
ok "Backend found: $BACKEND_ABS"

if [ ! -f "$FRONTEND_ABS/Dockerfile" ]; then
  error "Frontend not found at: $FRONTEND_ABS"
  error "Clone rer-dsp-frontend as a sibling or set DSP_FRONTEND_PATH in .env"
  exit 1
fi
ok "Frontend found: $FRONTEND_ABS"

# =============================================================================
# Step 4 — Installation config (UI labels, screens, KPIs)
# =============================================================================
step_header 4 "Installation config (UI labels, screens, KPIs)"

INSTALLATION_CONFIG_EXAMPLE="$ROOT_DIR/config/installation/installation-config.json.example"
INSTALLATION_CONFIG="$ROOT_DIR/config/installation/installation-config.json"

ensure_adopter_json_config \
  "Installation config" \
  "$INSTALLATION_CONFIG_EXAMPLE" \
  "$INSTALLATION_CONFIG" \
  "hierarchy labels, screen titles, KPI cards, area unit, date formats"

print_installation_preview "$INSTALLATION_CONFIG"

# =============================================================================
# Step 5 — Map layers config (WMS / GeoServer)
# =============================================================================
step_header 5 "Map layers config (WMS / GeoServer)"

MAP_LAYERS_CONFIG_EXAMPLE="$ROOT_DIR/config/map/mapLayersConfig.json.example"
MAP_LAYERS_CONFIG="$ROOT_DIR/config/map/mapLayersConfig.json"

ensure_adopter_json_config \
  "Map layers config" \
  "$MAP_LAYERS_CONFIG_EXAMPLE" \
  "$MAP_LAYERS_CONFIG" \
  "baseUrl / display names / style.color and style.fillColor (keep the four WMS layer ids unchanged)"

print_map_layers_preview "$MAP_LAYERS_CONFIG"
validate_map_layers_wms_ids "$MAP_LAYERS_CONFIG"

# =============================================================================
# Step 6 — Migration config (optional JDBC + ETL)
# =============================================================================
step_header 6 "Migration config (optional JDBC + ETL)"

MIGRATION_CONFIG_EXAMPLE="$ROOT_DIR/config/Job-Data-Migration/application/application.yaml.example"
MIGRATION_CONFIG="$ROOT_DIR/config/Job-Data-Migration/application/application.yaml"

if [ ! -f "$MIGRATION_CONFIG_EXAMPLE" ]; then
  error "Migration config template not found at: $MIGRATION_CONFIG_EXAMPLE"
  exit 1
fi

if [ ! -f "$MIGRATION_CONFIG" ]; then
  error "Migration configuration file not found:"
  echo "        $MIGRATION_CONFIG"
  cp "$MIGRATION_CONFIG_EXAMPLE" "$MIGRATION_CONFIG"
  info "Configuration file created from template:"
  echo "       $MIGRATION_CONFIG"
  error "Edit the generated file (JDBC connections and ETL mapping) and run './start.sh' again."
  exit 1
fi

MIGRATION_CONFIG_READY=true
if cmp -s "$MIGRATION_CONFIG" "$MIGRATION_CONFIG_EXAMPLE"; then
  warn "Migration config is still identical to the template:"
  echo "       $MIGRATION_CONFIG"
  warn "Edit this file (JDBC connections and ETL mapping) before migrating data."
  MIGRATION_CONFIG_READY=false
else
  ok "Migration config found: $MIGRATION_CONFIG"
fi

print_migration_preview "$MIGRATION_CONFIG"

# =============================================================================
# Step 7 — Confirmation
# =============================================================================
step_header 7 "Confirmation"

confirmation=""
read -r -p "Do you want to continue with this configuration? [y/N] " confirmation || true
if [[ ! "$confirmation" =~ ^([yY]|[yY][eE][sS])$ ]]; then
  info "Startup cancelled."
  exit 0
fi

# =============================================================================
# Step 8 — Databases (+ optional migration)
# =============================================================================
step_header 8 "Databases (+ optional migration)"

info "Starting databases (dsp-db, dsp-job-migration-db)..."
docker compose --env-file .env up -d dsp-db dsp-job-migration-db
ok "Database containers started"

info "Waiting for databases to become healthy..."
if ! wait_for_db dsp-db "${DSP_DB_USER:-dsp}" "${DSP_DB_NAME:-dsp-db}"; then
  error "dsp-db did not become ready in time."
  exit 1
fi
ok "dsp-db ready"

if ! wait_for_db dsp-job-migration-db "${DSP_JOB_MIGRATION_DB_USER:-dsp_job}" "${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}"; then
  error "dsp-job-migration-db did not become ready in time."
  exit 1
fi
ok "dsp-job-migration-db ready"
ok "Databases are ready"

if [ "${DSP_RUN_MIGRATION:-false}" = "true" ]; then
  if [ "$MIGRATION_CONFIG_READY" = "false" ]; then
    error "DSP_RUN_MIGRATION=true, but application.yaml is still a copy of the template."
    error "Edit $MIGRATION_CONFIG and run './start.sh' again."
    exit 1
  fi
  if [ ! -f "$JOB_ABS/Dockerfile" ]; then
    error "Migration job not found at: $JOB_ABS"
    error "Clone rer-dsp-job-data-migration or set DSP_JOB_MIGRATION_PATH in .env"
    exit 1
  fi
  ok "Migration job found: $JOB_ABS"
  info "Running data migration (profile=migration)..."
  docker compose --env-file .env --profile migration run --rm --build dsp-job-migration
  ok "Migration finished"
else
  if [ "$MIGRATION_CONFIG_READY" = "false" ]; then
    info "Data will not be migrated via job — configure application.yaml and use DSP_RUN_MIGRATION=true."
  else
    info "Data will not be migrated via job (DSP_RUN_MIGRATION=${DSP_RUN_MIGRATION:-false})."
  fi
fi

# =============================================================================
# Step 9 — GeoServer Exhibition (WMS)
# =============================================================================
step_header 9 "GeoServer Exhibition (WMS map layers)"

info "Building and starting GeoServer Exhibition..."
docker compose --env-file .env up -d --build dsp-geoserver-exhibition
ok "GeoServer Exhibition container started"

GEOSERVER_HOST_PORT="${DSP_GEOSERVER_HOST_PORT:-22668}"
GEOSERVER_PUBLIC_URL="http://${DSP_HTTP_HOST:-localhost}:${GEOSERVER_HOST_PORT}/geoserver"
GEOSERVER_ADMIN_USER="${DSP_GEOSERVER_ADMIN_USER:-admin}"
GEOSERVER_ADMIN_PASSWORD="${DSP_GEOSERVER_ADMIN_PASSWORD:-geoserver}"

info "Waiting for GeoServer REST API at ${GEOSERVER_PUBLIC_URL} ..."
if ! wait_for_geoserver "$GEOSERVER_PUBLIC_URL" "$GEOSERVER_ADMIN_USER" "$GEOSERVER_ADMIN_PASSWORD"; then
  error "GeoServer Exhibition did not become ready in time."
  docker compose --env-file .env logs --tail 80 dsp-geoserver-exhibition || true
  exit 1
fi
ok "GeoServer Exhibition is ready"

info "Publishing fixed DSP layers (workspace dsp)..."
docker compose --env-file .env exec -T dsp-geoserver-exhibition /opt/populate_geoserver.sh
ok "GeoServer layers published"

# =============================================================================
# Step 10 — Application containers
# =============================================================================
step_header 10 "Application containers (backend + frontend)"

info "Building and starting application containers..."
docker compose --env-file .env up -d --build dsp-backend dsp-frontend
ok "Backend and frontend are running"

ok "Stack is up"
echo ""
echo "Frontend:              http://${DSP_HTTP_HOST:-localhost}:${DSP_FRONTEND_HOST_PORT:-22667}${VITE_BASE_URL:-/dsp/}"
echo "Backend:               http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-22666}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}"
echo "Installation config:   http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-22666}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}/config/installation"
echo "Map layers:            http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-22666}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}/map/getLayers"
echo "GeoServer Exhibition:  ${GEOSERVER_PUBLIC_URL}/web/"
echo "GeoServer WMS:         ${GEOSERVER_PUBLIC_URL}/dsp/wms"
echo "DSP DB:                localhost:${DSP_DB_HOST_PORT:-20654}  db=${DSP_DB_NAME:-dsp-db}  user=${DSP_DB_USER:-dsp}"
echo "Job migration DB:      localhost:${DSP_JOB_MIGRATION_DB_HOST_PORT:-20655}  db=${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}  user=${DSP_JOB_MIGRATION_DB_USER:-dsp_job}"
echo ""
echo "Verify tables:"
echo "  docker compose exec dsp-db psql -U ${DSP_DB_USER:-dsp} -d ${DSP_DB_NAME:-dsp-db} -c '\\dt dsp.*'"
echo "  docker compose exec dsp-job-migration-db psql -U ${DSP_JOB_MIGRATION_DB_USER:-dsp_job} -d ${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db} -c '\\dt BATCH*'"
echo ""
echo "Run migration later:"
echo "  DSP_RUN_MIGRATION=true ./start.sh"
echo "  # or: docker compose --profile migration run --rm --build dsp-job-migration"
echo ""
echo "Logs:       docker compose logs -f"
echo "Stop:       docker compose down"
echo "Reset DBs:  docker compose down -v   # removes volumes (re-runs init SQL)"
