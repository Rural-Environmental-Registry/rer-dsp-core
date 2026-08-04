#!/usr/bin/env bash
# Configure the adopter without exposing internal DSP file keys.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$ROOT_DIR/config/adopter/adopter-config.yaml"
EXAMPLE_FILE="$ROOT_DIR/config/adopter/adopter-config.yaml.example"
APPLY="$ROOT_DIR/scripts/apply_adopter_config.py"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage: ./config.sh [--apply | --help]

  no option  Start the guided adopter configuration wizard.
  --apply    Apply the existing config/adopter/adopter-config.yaml file.
EOF
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --apply)
    if [ ! -f "$CONFIG_FILE" ]; then
      echo "Configuration file not found: $CONFIG_FILE" >&2
      echo "Run ./config.sh without options to start the wizard." >&2
      exit 1
    fi
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ ! -f "$EXAMPLE_FILE" ]; then
  echo "Template not found: $EXAMPLE_FILE" >&2
  exit 1
fi

if [ "${1:-}" != "--apply" ]; then
  if [ -f "$CONFIG_FILE" ]; then
    if ! prompt_yes_no "Use the existing configuration and reapply it?"; then
      rm -f "$CONFIG_FILE"
    fi
  fi
  python3 "$APPLY" --root "$ROOT_DIR" --config "$CONFIG_FILE" --wizard
else
  python3 "$APPLY" --root "$ROOT_DIR" --config "$CONFIG_FILE"
fi
