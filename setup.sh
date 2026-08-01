#!/usr/bin/env bash
# Usage: ./setup.sh [--skip-migration]   then ./start.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

DSP_ORCHESTRATION_SCRIPT="setup.sh"
TOTAL_STEPS=8

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common.sh"

SKIP_MIGRATION=false
for arg in "$@"; do
  case "$arg" in
    --skip-migration)
      SKIP_MIGRATION=true
      ;;
    -h|--help)
      echo "Usage: ./setup.sh [--skip-migration]"
      echo ""
      echo "Prepares persistent data for the local DSP stack:"
      echo "  - starts databases"
      echo "  - runs the data-migration job (unless --skip-migration)"
      echo "  - starts GeoServer Exhibition and publishes layers"
      echo ""
      echo "Then run: ./start.sh"
      echo ""
      echo "Env:"
      echo "  DSP_SKIP_MIGRATION=true   same as --skip-migration"
      exit 0
      ;;
    *)
      error "Unknown argument: $arg (try --help)"
      exit 1
      ;;
  esac
done

step_header 1 "Prerequisites (Docker)"
require_not_root
require_docker

step_header 2 "Environment (.env)"
ensure_dotenv

SKIP_MIGRATION="$(should_skip_migration "$SKIP_MIGRATION")"

WILL_MIGRATE=true
if [ "$SKIP_MIGRATION" = "true" ]; then
  WILL_MIGRATE=false
fi

step_header 3 "Migration job repository path"

JOB_PATH="${DSP_JOB_MIGRATION_PATH:-../rer-dsp-job-data-migration}"
JOB_ABS="$(resolve_path "$JOB_PATH")"

if [ "$WILL_MIGRATE" = "true" ]; then
  if [ ! -f "$JOB_ABS/Dockerfile" ]; then
    error "Migration job not found at: $JOB_ABS"
    error "Clone rer-dsp-job-data-migration or set DSP_JOB_MIGRATION_PATH in .env"
    exit 1
  fi
  ok "Migration job found: $JOB_ABS"
else
  info "Migration skipped — job repository check not required."
fi

step_header 4 "Map layers config (WMS / GeoServer)"

ensure_map_layers_config

step_header 5 "Migration config (JDBC + ETL)"

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
  error "Edit the generated file (JDBC connections and ETL mapping) and run './setup.sh' again."
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

print_migration_preview "$MIGRATION_CONFIG" "$WILL_MIGRATE"

step_header 6 "Confirmation"

if [ "$WILL_MIGRATE" = "true" ] && [ "$MIGRATION_CONFIG_READY" = "false" ]; then
  error "Migration will run, but application.yaml is still a copy of the template."
  error "Edit $MIGRATION_CONFIG and run './setup.sh' again."
  error "Or use: ./setup.sh --skip-migration"
  exit 1
fi

confirmation=""
read -r -p "Do you want to continue with this setup? [y/N] " confirmation || true
if [[ ! "$confirmation" =~ ^([yY]|[yY][eE][sS])$ ]]; then
  info "Setup cancelled."
  exit 0
fi

step_header 7 "Databases (+ migration)"

start_databases_and_wait

if [ "$WILL_MIGRATE" = "true" ]; then
  info "Running data migration (profile=migration)..."
  docker compose --env-file .env --profile migration run --rm --build dsp-job-migration
  ok "Migration finished"
else
  info "Data migration skipped (--skip-migration / DSP_SKIP_MIGRATION=true)."
fi

step_header 8 "GeoServer Exhibition (publish layers)"

start_geoserver_exhibition "populate" "$MIGRATION_CONFIG"

ok "Setup finished — data is ready on Docker volumes."
echo ""
echo "Next: start the application stacks with:"
echo "  ./start.sh"
echo ""
echo "Day-to-day: prefer ./start.sh (does not re-run migration)."
echo "Rebuild only frontend: docker compose up -d --build dsp-frontend"
echo "Reset DBs (lose data): docker compose down -v && ./setup.sh"
echo ""
