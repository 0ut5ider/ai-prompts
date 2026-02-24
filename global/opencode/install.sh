#!/usr/bin/env bash
# ABOUTME: Installs OpenCode configuration files to ~/.config/opencode/
# ABOUTME: Backs up existing config to .backups/<timestamp>/ before overwriting
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/opencode"
DRY_RUN=false
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"
BACKUP_DIR="${TARGET_DIR}/.backups/${TIMESTAMP}"

# Counters
INSTALLED=0
SKIPPED=0
BACKED_UP=0

# ─── Subdirectories to sync ──────────────────────────────────────────────────
SUBDIRS=("agents" "commands" "prompts" "skills")

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install OpenCode configuration files to ~/.config/opencode/

Options:
  --dry-run     Print what would be done without making changes
  --help        Show this help message

Source directory: ${SCRIPT_DIR}
Target directory: ${TARGET_DIR}
EOF
    exit 0
}

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true;   shift ;;
        --help)    usage ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$(basename "$0") --help' for usage."
            exit 1
            ;;
    esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo "[INFO]  $*"; }
skip()  { echo "[SKIP]  $*"; ((SKIPPED++)) || true; }
backup_msg() { echo "[BACKUP] $*"; ((BACKED_UP++)) || true; }

# Create a directory (respects --dry-run)
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        if $DRY_RUN; then
            info "(dry-run) Would create directory: $dir"
        else
            mkdir -p "$dir"
            info "Created directory: $dir"
        fi
    fi
}

# Back up a file or directory if it already exists at the target path.
# Preserves relative path from TARGET_DIR inside BACKUP_DIR.
# Returns 0 if a backup was made (or would be made), 1 otherwise.
backup_if_exists() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local rel_path="${target#"${TARGET_DIR}"/}"
        local bak="${BACKUP_DIR}/${rel_path}"
        local bak_parent
        bak_parent="$(dirname "$bak")"

        if $DRY_RUN; then
            backup_msg "(dry-run) Would back up $target -> $bak"
        else
            ensure_dir "$bak_parent"
            mv "$target" "$bak"
            backup_msg "Backed up $target -> $bak"
        fi
        return 0
    fi
    return 1
}

# Install a single file by copying it to the destination.
install_file() {
    local src="$1"
    local dest="$2"

    backup_if_exists "$dest" || true

    if $DRY_RUN; then
        info "(dry-run) Would copy $src -> $dest"
    else
        cp "$src" "$dest"
        info "Copied $src -> $dest"
    fi
    ((INSTALLED++)) || true
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo "============================================"
echo " OpenCode Config Installer"
echo "============================================"
echo "Source:    $SCRIPT_DIR"
echo "Target:    $TARGET_DIR"
echo "Dry run:   $DRY_RUN"
echo "--------------------------------------------"

# Create target directory
ensure_dir "$TARGET_DIR"

# ─── Install subdirectories (full replace) ────────────────────────────────────
for subdir in "${SUBDIRS[@]}"; do
    src_dir="${SCRIPT_DIR}/${subdir}"
    dest_dir="${TARGET_DIR}/${subdir}"

    if [[ ! -d "$src_dir" ]]; then
        skip "Source directory not found: $src_dir"
        continue
    fi

    # Back up existing target subdir, then replace entirely
    backup_if_exists "$dest_dir" || true

    if $DRY_RUN; then
        info "(dry-run) Would copy directory $src_dir -> $dest_dir"
    else
        cp -r "$src_dir" "$dest_dir"
        info "Copied directory $src_dir -> $dest_dir"
    fi
    ((INSTALLED++)) || true
done

# ─── AGENTS.md ────────────────────────────────────────────────────────────────
echo "--------------------------------------------"
install_file "${SCRIPT_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"

# ─── opencode.json ────────────────────────────────────────────────────────────
OPENCODE_TARGET="${TARGET_DIR}/opencode.json"
OPENCODE_EXAMPLE="${SCRIPT_DIR}/opencode_example.json"

if [[ ! -f "$OPENCODE_EXAMPLE" ]]; then
    echo "[ERROR] Example config not found: $OPENCODE_EXAMPLE"
    exit 1
fi

install_file "$OPENCODE_EXAMPLE" "$OPENCODE_TARGET"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo "============================================"
echo " Summary"
echo "============================================"
echo "  Installed:  $INSTALLED"
echo "  Skipped:    $SKIPPED"
echo "  Backed up:  $BACKED_UP"
echo "============================================"
