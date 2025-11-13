#!/usr/bin/env bash
# ~/.local/share/dotfiles/symlink/linker.sh
# Config-driven symlink manager with remove & dry-run support

set -euo pipefail

# === DEFAULT CONFIG ===
CONFIG_FILE="${CONFIG_FILE:-/home/eshan/.local/share/dotfiles/symlink/links.conf}"
DRY_RUN=false
REMOVE=false

# === FUNCTIONS ===

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --config <file>   Use a specific config file (default: $CONFIG_FILE)
  --remove          Remove all symlinks defined in config
  --dry-run         Show what would happen without making changes
  -h, --help        Show this help message
EOF
  exit 0
}

log() {
  local emoji="$1"
  shift
  echo "$emoji $*"
}

expand_path() {
  local path="$1"
  echo "${path/#\~/$HOME}"
}

create_symlink() {
  local src="$1"
  local dest="$2"

  src="$(expand_path "$src")"
  dest="$(expand_path "$dest")"

  # Remove trailing slash to avoid mv errors
  local dest_no_slash="${dest%/}"

  if $DRY_RUN; then
    echo "🧩 [DRY-RUN] Would link: $dest_no_slash → $src"
    return
  fi

  # Backup if it exists and is not a symlink
  if [ -e "$dest_no_slash" ] && [ ! -L "$dest_no_slash" ]; then
    local backup="${dest_no_slash}.bak"
    echo "🟡 Backing up existing: $dest_no_slash → $backup"
    mv "$dest_no_slash" "$backup"
  fi

  # Remove old symlink if it exists
  if [ -L "$dest_no_slash" ]; then
    rm -f "$dest_no_slash"
  fi

  mkdir -p "$(dirname "$dest_no_slash")"
  ln -s "$src" "$dest_no_slash"

  # Show output
  echo "--------------------------------------------------"
  echo "✅ Created symlink:"
  echo "   Source:      $src"
  echo "   Destination: $dest_no_slash"
  echo "--------------------------------------------------"
}

remove_symlink() {
  local src="$1"
  local dest="$2"

  dest="$(expand_path "$dest")"

  if [ -L "$dest" ]; then
    if $DRY_RUN; then
      log "🧩" "[DRY-RUN] Would remove symlink: $dest"
    else
      rm "$dest"
      log "🗑️" "Removed symlink: $dest"
    fi
  else
    log "⚠️" "Skipping: $dest (not a symlink)"
  fi
}

# === ARGUMENT PARSING ===
while [[ $# -gt 0 ]]; do
  case "$1" in
  --config)
    CONFIG_FILE="$2"
    shift 2
    ;;
  --remove)
    REMOVE=true
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  -h | --help) usage ;;
  *)
    log "⚠️" "Unknown option: $1"
    usage
    ;;
  esac
done

# === MAIN ===
if [ ! -f "$CONFIG_FILE" ]; then
  log "❌" "Config file not found: $CONFIG_FILE"
  exit 1
fi

log "🔗" "Using config file: $CONFIG_FILE"
echo "---------------------------------------------"

while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  src="${line%%:*}"
  dest="${line##*:}"

  if [ -z "$src" ] || [ -z "$dest" ]; then
    log "⚠️" "Invalid line in config: $line"
    continue
  fi

  if $REMOVE; then
    remove_symlink "$src" "$dest"
  else
    create_symlink "$src" "$dest"
  fi
done <"$CONFIG_FILE"

echo "🎉 Done!"
log "🎉" "Done!"
