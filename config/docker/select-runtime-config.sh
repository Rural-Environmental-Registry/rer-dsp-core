#!/bin/sh
# Picks the active operational file, or the versioned .example if it is missing.
# Usage:
#   select-runtime-config.sh pick <src_dir> <name> <dest_file>
#   select-runtime-config.sh about <src_dir> <dest_dir>
set -eu

die() {
  echo "select-runtime-config: $*" >&2
  exit 1
}

pick() {
  p_src="$1"
  p_name="$2"
  p_dest="$3"
  mkdir -p "$(dirname "$p_dest")"
  if [ -f "$p_src/$p_name" ]; then
    cp "$p_src/$p_name" "$p_dest"
  elif [ -f "$p_src/$p_name.example" ]; then
    cp "$p_src/$p_name.example" "$p_dest"
  else
    die "missing $p_name and $p_name.example in $p_src"
  fi
}

sync_about() {
  a_src="$1"
  a_dest="$2"
  mkdir -p "$a_dest"
  pick "$a_src" "about-config.json" "$a_dest/about-config.json"

  for f in "$a_src"/*.md; do
    [ -f "$f" ] || continue
    case "$f" in
      *.example) continue ;;
    esac
    cp "$f" "$a_dest/"
  done

  for f in "$a_src"/*.md.example; do
    [ -f "$f" ] || continue
    case "$f" in
      *.quickstart.md.example) continue ;;
    esac
    base=$(basename "$f" .example)
    if [ ! -f "$a_dest/$base" ]; then
      cp "$f" "$a_dest/$base"
    fi
  done
}

cmd="${1:-}"
case "$cmd" in
  pick)
    [ "$#" -eq 4 ] || die "usage: pick <src_dir> <name> <dest_file>"
    pick "$2" "$3" "$4"
    ;;
  about)
    [ "$#" -eq 3 ] || die "usage: about <src_dir> <dest_dir>"
    sync_about "$2" "$3"
    ;;
  *)
    die "usage: pick <src_dir> <name> <dest_file> | about <src_dir> <dest_dir>"
    ;;
esac
