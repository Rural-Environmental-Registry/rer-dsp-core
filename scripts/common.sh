BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DSP_ORCHESTRATION_SCRIPT="${DSP_ORCHESTRATION_SCRIPT:-script}"
TOTAL_STEPS="${TOTAL_STEPS:-0}"

declare -gA STACK_SERVICE_STATUSES=()
STACK_REQUIRED_SERVICES=(
  dsp-db
  dsp-geoserver-exhibition-db
  dsp-geoserver-exhibition
  dsp-backend
  dsp-frontend
)

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

prompt_yes_no() {
  local prompt="$1"
  local answer=""

  while true; do
    read -r -p "${prompt} [y/n] " answer || return 1
    case "$answer" in
      y|Y)
        return 0
        ;;
      n|N)
        return 1
        ;;
      *)
        warn "Invalid response. Please enter y or n."
        ;;
    esac
  done
}

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
    error "${label} file not found:"
    echo "        $active"
    error "Run ./config.sh to generate the active file (${edit_hint}) and try './${DSP_ORCHESTRATION_SCRIPT}' again."
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

# Ensures config/map/mapLayersConfig.json exists, is valid JSON, was edited
# from the template, and keeps the required WMS layer ids/colors. Shared by
# setup.sh and start.sh so the validation stays identical in both.
ensure_map_layers_config() {
  local example="$ROOT_DIR/config/map/mapLayersConfig.json.example"
  local active="$ROOT_DIR/config/map/mapLayersConfig.json"

  ensure_adopter_json_config \
    "Map layers config" \
    "$example" \
    "$active" \
    "baseUrl / display names / style.color and style.fillColor (keep the four WMS layer ids unchanged)"

  print_map_layers_preview "$active"
  validate_map_layers_wms_ids "$active"
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

# Resolve ${VAR_NAME} using a variable already exported in the shell (.env).
resolve_env_placeholder() {
  local raw="$1"
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    if [ -n "${!var_name:-}" ]; then
      printf '%s' "${!var_name}"
      return
    fi
    printf '%s (unset)' "$raw"
    return
  fi
  printf '%s' "$raw"
}

print_migration_preview() {
  local cfg="$1"
  local will_run="${2:-false}"
  local run_label="disabled"
  if [ "$will_run" = "true" ]; then
    run_label="enabled"
  fi

  local batch_url source_url target_url
  local batch_user source_user target_user
  batch_url="$(yaml_scalar "$cfg" "batch" "url")"
  batch_user="$(yaml_scalar "$cfg" "batch" "username")"
  source_url="$(yaml_scalar "$cfg" "source" "url")"
  source_user="$(yaml_scalar "$cfg" "source" "username")"
  source_url="$(resolve_env_placeholder "$source_url")"
  source_user="$(resolve_env_placeholder "$source_user")"
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
  echo "  Job execution: ${run_label} (will run via ./setup.sh)"
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

# pg_isready answers while /docker-entrypoint-initdb.d scripts are still running,
# so wait for a schema created by the init SQL before touching the tables.
wait_for_db_schema() {
  local service="$1"
  local user="$2"
  local db="$3"
  local schema="$4"
  local i
  for i in $(seq 1 90); do
    if docker compose --env-file .env exec -T "$service" \
        psql -U "$user" -d "$db" -tAc \
        "SELECT 1 FROM information_schema.schemata WHERE schema_name = '${schema}'" \
        2>/dev/null | grep -q '^1$'; then
      return 0
    fi
    sleep 1
  done
  return 1
}

validate_positive_integer() {
  local label="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    error "${label}: srid must be a positive integer (got '${value:-<missing>}')"
    exit 1
  fi
}

export_layer_srids_from_migration_config() {
  local srid_l1 srid_l2 srid_l3 srid_aoi

  srid_l1="${LAYER_SRS_TERRITORY_LEVEL_1:-4674}"
  srid_l2="${LAYER_SRS_TERRITORY_LEVEL_2:-4674}"
  srid_l3="${LAYER_SRS_TERRITORY_LEVEL_3:-4674}"
  srid_aoi="${LAYER_SRS_AREA_OF_INTEREST:-4674}"

  srid_l1="${srid_l1#EPSG:}"
  srid_l2="${srid_l2#EPSG:}"
  srid_l3="${srid_l3#EPSG:}"
  srid_aoi="${srid_aoi#EPSG:}"

  validate_positive_integer "LAYER_SRS_TERRITORY_LEVEL_1" "$srid_l1"
  validate_positive_integer "LAYER_SRS_TERRITORY_LEVEL_2" "$srid_l2"
  validate_positive_integer "LAYER_SRS_TERRITORY_LEVEL_3" "$srid_l3"
  validate_positive_integer "LAYER_SRS_AREA_OF_INTEREST" "$srid_aoi"

  export LAYER_SRS_TERRITORY_LEVEL_1="EPSG:${srid_l1}"
  export LAYER_SRS_TERRITORY_LEVEL_2="EPSG:${srid_l2}"
  export LAYER_SRS_TERRITORY_LEVEL_3="EPSG:${srid_l3}"
  export LAYER_SRS_AREA_OF_INTEREST="EPSG:${srid_aoi}"

  ok "Layer SRS from .env: L1=${LAYER_SRS_TERRITORY_LEVEL_1} L2=${LAYER_SRS_TERRITORY_LEVEL_2} L3=${LAYER_SRS_TERRITORY_LEVEL_3} AOI=${LAYER_SRS_AREA_OF_INTEREST}"
}

require_not_root() {
  if [ "$(id -u)" -eq 0 ]; then
    error "Do not run as root/sudo. Use: ./${DSP_ORCHESTRATION_SCRIPT}"
    exit 1
  fi
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    error "Docker is required."
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    error "Docker Compose v2 is required (docker compose)."
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running. Start Docker and run './${DSP_ORCHESTRATION_SCRIPT}' again."
    exit 1
  fi

  ok "Docker and Docker Compose OK"
}

# Reject legacy env vars that used to control migration on/off.
# Decision is interactive in ./setup.sh only (call after ensure_dotenv).
reject_legacy_migration_env() {
  if [ -n "${DSP_RUN_MIGRATION+x}" ]; then
    error "DSP_RUN_MIGRATION is no longer supported."
    error "Remove it from .env and choose option 2 or 3 in ./setup.sh."
    exit 1
  fi
  if [ -n "${DSP_SKIP_MIGRATION+x}" ]; then
    error "DSP_SKIP_MIGRATION is no longer supported. Remove it from .env and choose option 3 in ./setup.sh if you do not want to migrate."
    exit 1
  fi
}

ensure_dotenv() {
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
}

set_env_var() {
  local key="$1"
  local value="$2"
  local env_file="${ROOT_DIR:-.}/.env"

  if [ ! -f "$env_file" ]; then
    error ".env not found — run ensure_dotenv first."
    exit 1
  fi

  if grep -q "^${key}=" "$env_file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
  else
    printf '\n%s=%s\n' "$key" "$value" >>"$env_file"
  fi

  set -a
  # shellcheck disable=SC1091
  source "$env_file"
  set +a
}

get_migration_execution_mode() {
  echo "${DSP_MIGRATION_EXECUTION_MODE:-once}"
}

is_continuous_migration_mode() {
  [ "$(get_migration_execution_mode)" = "continuous" ]
}

run_migration_job_once() {
  docker compose --env-file .env --profile migration run --rm --build \
    -e DSP_MIGRATION_EXECUTION_MODE=once \
    dsp-job-migration
}

start_migration_service_stack() {
  info "Starting migration service stack (profile=migration)..."
  docker compose --env-file .env --profile migration up -d dsp-job-migration-db dsp-job-migration
  docker update --restart unless-stopped dsp-job-migration >/dev/null 2>&1 || true

  info "Waiting for dsp-job-migration-db..."
  if ! wait_for_db dsp-job-migration-db "${DSP_JOB_MIGRATION_DB_USER:-dsp_job}" "${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}"; then
    error "dsp-job-migration-db did not become ready in time."
    exit 1
  fi
  ok "Migration service stack ready"
}

ensure_migration_service_if_continuous() {
  if ! is_continuous_migration_mode; then
    return 0
  fi
  start_migration_service_stack
}

print_migration_resync_hints() {
  if ! is_continuous_migration_mode; then
    return 0
  fi
  echo ""
  echo "Migration execution mode: continuous (external scheduling)"
  echo "Re-sync from source (one-shot run):"
  echo "  docker compose --env-file .env --profile migration run --rm -e DSP_MIGRATION_EXECUTION_MODE=once dsp-job-migration"
  echo "Or inside the running job container:"
  echo "  docker compose --env-file .env --profile migration exec dsp-job-migration java \$JAVA_OPTS -jar /app/app.jar"
}

ensure_adopter_config() {
  local example="$ROOT_DIR/config/adopter/adopter-config.yaml.example"
  local active="$ROOT_DIR/config/adopter/adopter-config.yaml"
  local apply_script="$ROOT_DIR/scripts/apply_adopter_config.py"

  if [ ! -f "$example" ]; then
    error "Adopter configuration template not found: $example"
    exit 1
  fi
  if [ ! -f "$active" ]; then
    error "Adopter configuration not found: $active"
    error "Run ./config.sh to fill in the allowed fields and try again."
    exit 1
  fi
  if cmp -s "$active" "$example"; then
    error "The adopter configuration is still identical to the template."
    error "Run ./config.sh to fill in the allowed fields."
    exit 1
  fi
  if ! python3 "$apply_script" --root "$ROOT_DIR" --config "$active" --quiet; then
    error "Could not generate the DSP configuration files."
    error "Fix $active or run ./config.sh again."
    exit 1
  fi
  # Applying the configuration may update .env; reload it before continuing.
  ensure_dotenv
  ok "Adopter configuration applied safely"
}

start_databases_and_wait() {
  local include_migration_db="${1:-false}"

  if [ "$include_migration_db" = "true" ]; then
    info "Starting databases (dsp-db, dsp-geoserver-exhibition-db, dsp-job-migration-db)..."
    docker compose --env-file .env --profile migration up -d \
      dsp-db dsp-geoserver-exhibition-db dsp-job-migration-db
  else
    info "Starting databases (dsp-db, dsp-geoserver-exhibition-db)..."
    docker compose --env-file .env up -d dsp-db dsp-geoserver-exhibition-db
  fi
  ok "Database containers started"

  info "Waiting for databases to become healthy..."
  if ! wait_for_db dsp-db "${DSP_DB_USER:-dsp}" "${DSP_DB_NAME:-dsp-db}"; then
    error "dsp-db did not become ready in time."
    exit 1
  fi
  if ! wait_for_db_schema dsp-db "${DSP_DB_USER:-dsp}" "${DSP_DB_NAME:-dsp-db}" dsp; then
    error "dsp-db init SQL did not create schema 'dsp' in time."
    docker compose --env-file .env logs --tail 40 dsp-db || true
    exit 1
  fi
  ok "dsp-db ready"

  if ! wait_for_db dsp-geoserver-exhibition-db "${DSP_GEOSERVER_EXHIBITION_DB_USER:-dsp_geo}" "${DSP_GEOSERVER_EXHIBITION_DB_NAME:-dsp-geoserver-exhibition-db}"; then
    error "dsp-geoserver-exhibition-db did not become ready in time."
    exit 1
  fi
  if ! wait_for_db_schema dsp-geoserver-exhibition-db "${DSP_GEOSERVER_EXHIBITION_DB_USER:-dsp_geo}" "${DSP_GEOSERVER_EXHIBITION_DB_NAME:-dsp-geoserver-exhibition-db}" dsp; then
    error "dsp-geoserver-exhibition-db init SQL did not create schema 'dsp' in time."
    docker compose --env-file .env logs --tail 40 dsp-geoserver-exhibition-db || true
    exit 1
  fi
  ok "dsp-geoserver-exhibition-db ready"

  if [ "$include_migration_db" = "true" ]; then
    if ! wait_for_db dsp-job-migration-db "${DSP_JOB_MIGRATION_DB_USER:-dsp_job}" "${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}"; then
      error "dsp-job-migration-db did not become ready in time."
      exit 1
    fi
    ok "dsp-job-migration-db ready"
  fi
  ok "Databases are ready"
}

# Runtime stack status helpers (container state / Docker healthcheck — no HTTP probes).

is_stack_optional_service() {
  [ "$1" = "dsp-job-migration-db" ]
}

get_stack_runtime_services() {
  local svc
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    [ "$svc" = "dsp-job-migration" ] && continue
    printf '%s\n' "$svc"
  done < <(docker compose --env-file .env --profile migration config --services 2>/dev/null || true)
}

compose_status_label() {
  local state="$1"
  local health="$2"

  if [ "$state" != "running" ]; then
    echo "STOPPED"
    return
  fi
  case "$health" in
    healthy) echo "HEALTHY" ;;
    unhealthy) echo "UNHEALTHY" ;;
    starting) echo "STARTING" ;;
    *) echo "RUNNING" ;;
  esac
}

load_stack_service_statuses() {
  local refresh="${1:-false}"
  local line svc state health label runtime_svc

  if [ "$refresh" != "true" ] && [ "${#STACK_SERVICE_STATUSES[@]}" -gt 0 ]; then
    return
  fi

  STACK_SERVICE_STATUSES=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    svc="${line%%|*}"
    line="${line#*|}"
    state="${line%%|*}"
    health="${line#*|}"
    label="$(compose_status_label "$state" "$health")"
    STACK_SERVICE_STATUSES["$svc"]="$label"
  done < <(docker compose --env-file .env ps -a --format '{{.Service}}|{{.State}}|{{.Health}}' 2>/dev/null || true)

  while IFS= read -r runtime_svc; do
    [ -z "$runtime_svc" ] && continue
    if [ -z "${STACK_SERVICE_STATUSES[$runtime_svc]+x}" ]; then
      STACK_SERVICE_STATUSES["$runtime_svc"]="STOPPED"
    fi
  done < <(get_stack_runtime_services)
}

stack_service_status() {
  echo "${STACK_SERVICE_STATUSES[$1]:-STOPPED}"
}

is_stack_service_up() {
  [ "$(stack_service_status "$1")" != "STOPPED" ]
}

print_stack_service_status() {
  local svc status note

  load_stack_service_statuses true
  echo ""
  info "Checking this project's Docker containers..."
  echo ""
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    status="$(stack_service_status "$svc")"
    note=""
    if is_stack_optional_service "$svc"; then
      note="  (optional — setup/migration)"
    fi
    printf '  [%s] %s%s\n' "$status" "$svc" "$note"
  done < <(get_stack_runtime_services)
  echo ""
}

print_stack_summary() {
  local svc status
  local required_total=0
  local required_up=0
  local has_caveat=false
  local any_up=false

  load_stack_service_statuses

  for svc in "${STACK_REQUIRED_SERVICES[@]}"; do
    required_total=$((required_total + 1))
    status="$(stack_service_status "$svc")"
    if is_stack_service_up "$svc"; then
      required_up=$((required_up + 1))
      any_up=true
      case "$status" in
        UNHEALTHY|STARTING) has_caveat=true ;;
      esac
    fi
  done

  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    if is_stack_service_up "$svc"; then
      any_up=true
    fi
  done < <(get_stack_runtime_services)

  if [ "$any_up" = false ]; then
    warn "Stack is off — no project containers are running."
  elif [ "$required_up" -lt "$required_total" ]; then
    warn "Partial stack — ${required_up} of ${required_total} required services running."
  elif [ "$has_caveat" = true ]; then
    warn "Stack is running with health caveats (UNHEALTHY or STARTING containers)."
  else
    ok "Stack ready — all required services are running."
  fi
  info "Container state only — HTTP endpoints are not probed."
}

print_stack_url_line() {
  local label="$1"
  local status="$2"
  local url="$3"

  if [ -n "$status" ]; then
    printf '%-22s [%s] %s\n' "${label}:" "$status" "$url"
  else
    printf '%-22s %s\n' "${label}:" "$url"
  fi
}

# Tear down compose services, including the migration profile (job DB + migration job).
compose_down_project() {
  docker compose --env-file .env --profile migration down "$@"
}

# Status of this project's compose services + URLs; optional project cleanup; then exit.
show_stack_status_menu() {
  print_stack_service_status
  print_stack_summary
  print_stack_urls with-status
  print_stack_usage_hints

  echo ""
  echo "What do you want to do?"
  echo "  1) Remove this project's containers, volumes and images"
  echo "  2) Exit"
  local action=""
  read -r -p "Choice [1/2]: " action || true
  case "$action" in
    1)
      echo ""
      warn "This deletes ONLY this project's Docker resources (compose down -v --rmi all, migration profile included)."
      warn "Database data in project volumes will be lost."
      local confirm=""
      read -r -p "Type YES to confirm cleanup: " confirm || true
      if [ "$confirm" != "YES" ]; then
        info "Cleanup cancelled."
        exit 0
      fi
      info "Removing project containers, volumes and images..."
      compose_down_project -v --rmi all
      ok "Project Docker resources removed."
      exit 0
      ;;
    2|"")
      info "Exiting."
      exit 0
      ;;
    *)
      error "Invalid choice: '${action}' — use 1 (cleanup) or 2 (exit)."
      exit 1
      ;;
  esac
}

# Interactive data-prep menu for ./setup.sh.
# Sets globals: SETUP_MODE (demo|real), WILL_MIGRATE, INCLUDE_MIGRATION_DB.
# Not a command substitution on purpose: error output must reach the terminal.
prompt_setup_data_mode() {
  echo ""
  echo "This step prepares geographic data in the local DSP databases and publishes GeoServer layers."
  echo "Pick the option that matches your goal:"
  echo ""
  echo "  1) Demonstration (built-in Brazil seed, no JDBC)"
  echo "     Loads demo map data from built-in SQL — no source database or migration job."
  echo "     Use when exploring the UI, evaluating the stack, or when you do not have adopter data yet."
  echo ""
  echo "  2) Real adopter — migrate from JDBC source (ETL)"
  echo "     Requires ./config.sh first, then runs ETL from your JDBC source into dsp-db and the GeoServer DB."
  echo "     Use for a production-like setup when your source database is ready to import."
  echo ""
  echo "  3) Real adopter — no migration (empty DBs, UI/GeoServer config only)"
  echo "     Applies adopter configuration (labels, map layers, SRIDs) but keeps databases empty."
  echo "     Use when setting up the stack before data is available, or when you will migrate later with option 2."
  echo ""
  echo "  4) Stack status / cleanup / exit"
  echo "     Shows container status and service URLs; optionally removes this project's Docker resources, then exits."
  echo "     Use to inspect the stack or reset containers/volumes without loading or migrating data."
  echo ""
  echo "How do you want to prepare data?"
  local choice=""
  read -r -p "Choice [1/2/3/4]: " choice || true
  case "$choice" in
    1)
      SETUP_MODE="demo"
      WILL_MIGRATE=false
      INCLUDE_MIGRATION_DB=false
      ;;
    2)
      SETUP_MODE="real"
      WILL_MIGRATE=true
      INCLUDE_MIGRATION_DB=true
      prompt_migration_execution_mode
      ;;
    3)
      SETUP_MODE="real"
      WILL_MIGRATE=false
      INCLUDE_MIGRATION_DB=false
      ;;
    4)
      show_stack_status_menu
      ;;
    *)
      error "Invalid choice: '${choice}' — use 1 (demonstration), 2 (real + ETL), 3 (real without migration) or 4 (status)."
      error "Run './${DSP_ORCHESTRATION_SCRIPT}' again."
      exit 1
      ;;
  esac
}

# Sets global MIGRATION_EXECUTION_MODE (once|continuous) after option 2 in ./setup.sh.
prompt_migration_execution_mode() {
  echo ""
  echo "How should the migration job run after setup?"
  echo ""
  echo "  1) One-time initial migration (recommended for first import)"
  echo "     Runs the job once during setup; container is removed when finished."
  echo ""
  echo "  2) Continuous service (external scheduling)"
  echo "     Runs the initial migration, then keeps the migration stack available"
  echo "     in Docker for your operations team to trigger re-syncs."
  echo ""
  local choice=""
  read -r -p "Choice [1/2]: " choice || true
  case "$choice" in
    1|"")
      MIGRATION_EXECUTION_MODE="once"
      ;;
    2)
      MIGRATION_EXECUTION_MODE="continuous"
      ;;
    *)
      error "Invalid choice: '${choice}' — use 1 (one-time) or 2 (continuous service)."
      error "Run './${DSP_ORCHESTRATION_SCRIPT}' again."
      exit 1
      ;;
  esac
}

# Ensure UI/map configs for demo without blocking on "edit the template".
ensure_quickstart_adopter_configs() {
  local install_example="$ROOT_DIR/config/installation/installation-config.quickstart.json.example"
  local install_generic="$ROOT_DIR/config/installation/installation-config.json.example"
  local install_active="$ROOT_DIR/config/installation/installation-config.json"
  local map_example="$ROOT_DIR/config/map/mapLayersConfig.quickstart.json.example"
  local map_generic="$ROOT_DIR/config/map/mapLayersConfig.json.example"
  local map_active="$ROOT_DIR/config/map/mapLayersConfig.json"

  if [ ! -f "$install_example" ]; then
    error "Quickstart installation template not found at: $install_example"
    exit 1
  fi

  if [ ! -f "$install_active" ] || { [ -f "$install_generic" ] && cmp -s "$install_active" "$install_generic"; }; then
    cp "$install_example" "$install_active"
    info "Installation config set from quickstart template:"
    echo "       $install_active"
  else
    ok "Installation config found: $install_active"
  fi

  if [ ! -f "$map_example" ]; then
    error "Quickstart map layers template not found at: $map_example"
    exit 1
  fi

  if [ ! -f "$map_active" ] || { [ -f "$map_generic" ] && cmp -s "$map_active" "$map_generic"; }; then
    cp "$map_example" "$map_active"
    info "Map layers config set from quickstart template: $map_active"
  else
    ok "Map layers config found: $map_active"
  fi

  if ! validate_json_file "$install_active"; then
    error "Installation config contains invalid JSON: $install_active"
    exit 1
  fi
  if ! validate_json_file "$map_active"; then
    error "Map layers config contains invalid JSON: $map_active"
    exit 1
  fi
  validate_map_layers_wms_ids "$map_active"
}

is_quickstart_configured() {
  local install_example="$ROOT_DIR/config/installation/installation-config.quickstart.json.example"
  local install_active="$ROOT_DIR/config/installation/installation-config.json"
  local map_example="$ROOT_DIR/config/map/mapLayersConfig.quickstart.json.example"
  local map_active="$ROOT_DIR/config/map/mapLayersConfig.json"
  local adopter_config="$ROOT_DIR/config/adopter/adopter-config.yaml"

  if [ ! -f "$adopter_config" ] &&
    [ -f "$install_active" ] &&
    [ -f "$map_active" ]; then
    return 0
  fi

  [ -f "$install_example" ] &&
    [ -f "$install_active" ] &&
    [ -f "$map_example" ] &&
    [ -f "$map_active" ] &&
    cmp -s "$install_active" "$install_example" &&
    cmp -s "$map_active" "$map_example"
}

use_quickstart_layer_srids() {
  local mismatch=false
  local value

  for value in \
    "${LAYER_SRS_TERRITORY_LEVEL_1:-4674}" \
    "${LAYER_SRS_TERRITORY_LEVEL_2:-4674}" \
    "${LAYER_SRS_TERRITORY_LEVEL_3:-4674}" \
    "${LAYER_SRS_AREA_OF_INTEREST:-4674}"
  do
    value="${value#EPSG:}"
    if [ "$value" != "4674" ]; then
      mismatch=true
      break
    fi
  done

  if [ "$mismatch" = "true" ]; then
    warn "Quickstart uses SRID 4674; .env LAYER_SRS_* values apply only in the real adopter flow."
  fi

  export LAYER_SRS_TERRITORY_LEVEL_1="EPSG:4674"
  export LAYER_SRS_TERRITORY_LEVEL_2="EPSG:4674"
  export LAYER_SRS_TERRITORY_LEVEL_3="EPSG:4674"
  export LAYER_SRS_AREA_OF_INTEREST="EPSG:4674"
  ok "Quickstart layer SRS: L1=EPSG:4674 L2=EPSG:4674 L3=EPSG:4674 AOI=EPSG:4674"
}

apply_quickstart_seed() {
  local seed_dir="$ROOT_DIR/config/db/seed/quickstart"
  local dsp_user="${DSP_DB_USER:-dsp}"
  local dsp_db="${DSP_DB_NAME:-dsp-db}"
  local geo_user="${DSP_GEOSERVER_EXHIBITION_DB_USER:-dsp_geo}"
  local geo_db="${DSP_GEOSERVER_EXHIBITION_DB_NAME:-dsp-geoserver-exhibition-db}"

  for f in \
    "$seed_dir/01_territory_dsp.sql" \
    "$seed_dir/02_aoi_dsp.sql" \
    "$seed_dir/01_territory_exhibition.sql" \
    "$seed_dir/02_aoi_exhibition.sql"
  do
    if [ ! -f "$f" ]; then
      error "Quickstart seed file missing: $f"
      exit 1
    fi
  done

  info "Applying quickstart seed to dsp-db (demo data)..."
  docker compose --env-file .env exec -T dsp-db \
    psql -q -v ON_ERROR_STOP=1 -U "$dsp_user" -d "$dsp_db" \
    <"$seed_dir/01_territory_dsp.sql"
  docker compose --env-file .env exec -T dsp-db \
    psql -q -v ON_ERROR_STOP=1 -U "$dsp_user" -d "$dsp_db" \
    <"$seed_dir/02_aoi_dsp.sql"
  ok "dsp-db seeded"

  info "Applying quickstart seed to dsp-geoserver-exhibition-db..."
  docker compose --env-file .env exec -T dsp-geoserver-exhibition-db \
    psql -q -v ON_ERROR_STOP=1 -U "$geo_user" -d "$geo_db" \
    <"$seed_dir/01_territory_exhibition.sql"
  docker compose --env-file .env exec -T dsp-geoserver-exhibition-db \
    psql -q -v ON_ERROR_STOP=1 -U "$geo_user" -d "$geo_db" \
    <"$seed_dir/02_aoi_exhibition.sql"
  ok "exhibition-db seeded"

  warn "Demonstration data only — heavily simplified Brazil geometries, not production."
}

start_geoserver_exhibition() {
  local mode="${1:-up}"
  local migration_config="${2:-}"

  # LAYER_SRS_* come from .env (defaults 4674); migration YAML path is unused for SRS today.
  info "Resolving layer SRS from .env (LAYER_SRS_*)..."
  export_layer_srids_from_migration_config "$migration_config"
  if [ -z "$migration_config" ] || [ ! -f "$migration_config" ]; then
    info "No migration YAML — using LAYER_SRS_* defaults (demonstration / no migration)."
  fi

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

  if [ "$mode" = "populate" ]; then
    info "Publishing fixed DSP layers (workspace dsp)..."
    docker compose --env-file .env exec -T dsp-geoserver-exhibition /opt/populate_geoserver.sh
    ok "GeoServer layers published"
  fi
}

print_stack_urls() {
  local show_status="${1:-}"
  local geoserver_url="${GEOSERVER_PUBLIC_URL:-http://${DSP_HTTP_HOST:-localhost}:${DSP_GEOSERVER_HOST_PORT:-22668}/geoserver}"
  local http_host="${DSP_HTTP_HOST:-localhost}"
  local frontend_url="http://${http_host}:${DSP_FRONTEND_HOST_PORT:-22667}${VITE_BASE_URL:-/dsp/}"
  local backend_url="http://${http_host}:${DSP_BACKEND_HOST_PORT:-22666}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}"
  local svc_status=""
  local migration_db_url="${http_host}:${DSP_JOB_MIGRATION_DB_HOST_PORT:-20655}  db=${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}  user=${DSP_JOB_MIGRATION_DB_USER:-dsp_job}"

  load_stack_service_statuses

  if [ "$show_status" = "with-status" ]; then
    echo ""
    svc_status="$(stack_service_status dsp-frontend)"
    print_stack_url_line "Frontend" "$svc_status" "$frontend_url"
    svc_status="$(stack_service_status dsp-backend)"
    print_stack_url_line "Backend" "$svc_status" "$backend_url"
    print_stack_url_line "Installation config" "$svc_status" "${backend_url}/config/installation"
    print_stack_url_line "Map layers" "$svc_status" "${backend_url}/map/getLayers"
    svc_status="$(stack_service_status dsp-geoserver-exhibition)"
    print_stack_url_line "GeoServer Exhibition" "$svc_status" "${geoserver_url}/web/"
    print_stack_url_line "GeoServer WMS" "$svc_status" "${geoserver_url}/dsp/wms"
    svc_status="$(stack_service_status dsp-db)"
    print_stack_url_line "DSP DB" "$svc_status" "${http_host}:${DSP_DB_HOST_PORT:-20654}  db=${DSP_DB_NAME:-dsp-db}  user=${DSP_DB_USER:-dsp}"
    svc_status="$(stack_service_status dsp-geoserver-exhibition-db)"
    print_stack_url_line "GeoServer Exhibition DB" "$svc_status" "${http_host}:${DSP_GEOSERVER_EXHIBITION_DB_HOST_PORT:-20656}  db=${DSP_GEOSERVER_EXHIBITION_DB_NAME:-dsp-geoserver-exhibition-db}  user=${DSP_GEOSERVER_EXHIBITION_DB_USER:-dsp_geo}"
    if is_stack_service_up dsp-job-migration-db; then
      svc_status="$(stack_service_status dsp-job-migration-db)"
      print_stack_url_line "Job migration DB" "$svc_status" "$migration_db_url"
    fi
    if is_continuous_migration_mode && is_stack_service_up dsp-job-migration; then
      svc_status="$(stack_service_status dsp-job-migration)"
      print_stack_url_line "Migration job (service)" "$svc_status" "mode=continuous (idle — trigger re-sync externally)"
    fi
    return
  fi

  echo ""
  echo "Frontend:              ${frontend_url}"
  echo "Backend:               ${backend_url}"
  echo "Installation config:   ${backend_url}/config/installation"
  echo "Map layers:            ${backend_url}/map/getLayers"
  echo "GeoServer Exhibition:  ${geoserver_url}/web/"
  echo "GeoServer WMS:         ${geoserver_url}/dsp/wms"
  echo "DSP DB:                ${http_host}:${DSP_DB_HOST_PORT:-20654}  db=${DSP_DB_NAME:-dsp-db}  user=${DSP_DB_USER:-dsp}"
  echo "GeoServer Exhibition DB: ${http_host}:${DSP_GEOSERVER_EXHIBITION_DB_HOST_PORT:-20656}  db=${DSP_GEOSERVER_EXHIBITION_DB_NAME:-dsp-geoserver-exhibition-db}  user=${DSP_GEOSERVER_EXHIBITION_DB_USER:-dsp_geo}"
  if is_stack_service_up dsp-job-migration-db; then
    echo "Job migration DB:      ${migration_db_url}"
  fi
  if is_continuous_migration_mode && is_stack_service_up dsp-job-migration; then
    echo "Migration job:         continuous service (idle — trigger re-sync externally)"
  fi
}

print_stack_usage_hints() {
  echo ""
  echo "Verify tables:"
  echo "  docker compose exec dsp-db psql -U ${DSP_DB_USER:-dsp} -d ${DSP_DB_NAME:-dsp-db} -c '\\dt dsp.*'"
  echo "  docker compose exec dsp-geoserver-exhibition-db psql -U ${DSP_GEOSERVER_EXHIBITION_DB_USER:-dsp_geo} -d ${DSP_GEOSERVER_EXHIBITION_DB_NAME:-dsp-geoserver-exhibition-db} -c '\\dt dsp.*'"
  echo ""
  echo "Migrate / (re)populate data:"
  echo "  ./setup.sh"
  print_migration_resync_hints
  echo ""
  echo "Rebuild frontend only: docker compose up -d --build dsp-frontend"
  echo "Logs:       docker compose logs -f"
  echo "Stop:       docker compose --env-file .env --profile migration down"
  echo "Reset DBs:  docker compose --env-file .env --profile migration down -v && ./setup.sh"
  echo ""
}
