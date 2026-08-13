#!/usr/bin/env bash
# Configure the adopter without exposing internal DSP file keys.
# Generates installation-config.json, mapLayersConfig.json,
# downloadThemesConfig.json and application.yaml via apply_adopter_config.py.
# Usage: ./config.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
CONFIG_FILE="$ROOT_DIR/config/adopter/adopter-config.yaml"
EXAMPLE_FILE="$ROOT_DIR/config/adopter/adopter-config.yaml.example"
APPLY="$ROOT_DIR/scripts/apply_adopter_config.py"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common.sh"

if [ "$#" -gt 0 ]; then
  error "Run ./config.sh with no arguments."
  exit 1
fi

if [ ! -f "$EXAMPLE_FILE" ]; then
  error "Template not found: $EXAMPLE_FILE"
  exit 1
fi

ensure_dotenv
ensure_dsp_repositories --backend --frontend --job

if [ -f "$CONFIG_FILE" ]; then
  echo ""
  echo "An existing configuration was found:"
  echo "  $CONFIG_FILE"
  echo ""
  echo "What do you want to do?"
  echo "  1) Reapply the existing configuration (no wizard)"
  echo "  2) Edit the existing configuration (wizard with current values)"
  echo "  3) Start over from the template (discards current file)"
  echo ""
  choice=""
  read -r -p "Choice [1/2/3]: " choice || true
  case "$choice" in
    1)
      python3 "$APPLY" --root "$ROOT_DIR" --config "$CONFIG_FILE"
      exit 0
      ;;
    2)
      python3 "$APPLY" --root "$ROOT_DIR" --config "$CONFIG_FILE" --wizard --edit
      exit 0
      ;;
    3)
      rm -f "$CONFIG_FILE"
      ;;
    *)
      error "Invalid choice: '${choice}' — use 1 (reapply), 2 (edit), or 3 (start over)."
      exit 1
      ;;
  esac
fi

python3 "$APPLY" --root "$ROOT_DIR" --config "$CONFIG_FILE" --wizard
