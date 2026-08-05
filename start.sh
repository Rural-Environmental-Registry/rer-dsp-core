#!/usr/bin/env bash
# Usage: ./start.sh   (migrate data first with ./setup.sh)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

DSP_ORCHESTRATION_SCRIPT="start.sh"
TOTAL_STEPS=8

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common.sh"

step_header 1 "Prerequisites (Docker)"
require_not_root
require_docker

step_header 2 "Environment (.env)"
ensure_dotenv
reject_legacy_migration_env

step_header 3 "Repository paths (backend / frontend)"

BACKEND_PATH="${DSP_BACKEND_PATH:-../rer-dsp-backend}"
FRONTEND_PATH="${DSP_FRONTEND_PATH:-../rer-dsp-frontend}"

info "Resolving repository paths..."
BACKEND_ABS="$(resolve_path "$BACKEND_PATH")"
FRONTEND_ABS="$(resolve_path "$FRONTEND_PATH")"

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

step_header 4 "Installation config (UI labels, screens, KPIs)"

INSTALLATION_CONFIG_EXAMPLE="$ROOT_DIR/config/installation/installation-config.json.example"
INSTALLATION_CONFIG="$ROOT_DIR/config/installation/installation-config.json"

ensure_adopter_json_config \
  "Installation config" \
  "$INSTALLATION_CONFIG_EXAMPLE" \
  "$INSTALLATION_CONFIG" \
  "hierarchy labels, screen titles, KPI cards, area unit, date formats"

print_installation_preview "$INSTALLATION_CONFIG"

step_header 5 "Map layers config (WMS / GeoServer)"

ensure_map_layers_config

if is_quickstart_configured; then
  info "Quickstart configuration detected."
  use_quickstart_layer_srids
fi

step_header 6 "Confirmation"

if is_continuous_migration_mode; then
  info "Continuous migration mode — ./start.sh will keep the migration stack running."
  info "Re-syncs are triggered externally (not scheduled by this repo)."
else
  info "This script starts the application stack only (no data migration)."
fi
info "To migrate/populate data, run ./setup.sh first (uses Docker volumes)."

if ! prompt_yes_no "Do you want to continue?"; then
  info "Startup cancelled."
  exit 0
fi

step_header 7 "Databases"

start_databases_and_wait "false"
ensure_migration_service_if_continuous
if is_continuous_migration_mode; then
  info "Migration service stack is active (continuous mode)."
else
  info "Migration is not run by ./start.sh. Use ./setup.sh when you need to (re)migrate."
fi

step_header 8 "GeoServer Exhibition + application containers"

MIGRATION_CONFIG="$ROOT_DIR/config/Job-Data-Migration/application/application.yaml"
start_geoserver_exhibition "up" "$MIGRATION_CONFIG"

info "Building and starting application containers..."
docker compose --env-file .env up -d --build dsp-backend dsp-frontend
ok "Backend and frontend are running"

print_stack_summary
print_stack_urls with-status
print_stack_usage_hints
