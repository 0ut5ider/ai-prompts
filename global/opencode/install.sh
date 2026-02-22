#!/usr/bin/env bash
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/opencode"
MODE="copy"
DRY_RUN=false
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"

# Counters
INSTALLED=0
SKIPPED=0
BACKED_UP=0

# ─── Subdirectories to sync ──────────────────────────────────────────────────
SUBDIRS=("agents" "commands" "prompts")

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install OpenCode configuration files to ~/.config/opencode/

Options:
  --copy        Copy files to target directory (default)
  --symlink     Create individual file symlinks instead of copying
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
        --copy)    MODE="copy";    shift ;;
        --symlink) MODE="symlink"; shift ;;
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

# Back up a file if it already exists at the target path.
# Returns 0 if a backup was made (or would be made), 1 otherwise.
backup_if_exists() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local bak="${target}.bak.${TIMESTAMP}"
        if $DRY_RUN; then
            backup_msg "(dry-run) Would back up $target -> $bak"
        else
            mv "$target" "$bak"
            backup_msg "Backed up $target -> $bak"
        fi
        return 0
    fi
    return 1
}

# Install a single file (copy or symlink).
install_file() {
    local src="$1"
    local dest="$2"

    backup_if_exists "$dest" || true

    if [[ "$MODE" == "symlink" ]]; then
        if $DRY_RUN; then
            info "(dry-run) Would symlink $dest -> $src"
        else
            ln -s "$src" "$dest"
            info "Symlinked $dest -> $src"
        fi
    else
        if $DRY_RUN; then
            info "(dry-run) Would copy $src -> $dest"
        else
            cp "$src" "$dest"
            info "Copied $src -> $dest"
        fi
    fi
    ((INSTALLED++)) || true
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo "============================================"
echo " OpenCode Config Installer"
echo "============================================"
echo "Mode:      $MODE"
echo "Source:    $SCRIPT_DIR"
echo "Target:    $TARGET_DIR"
echo "Dry run:   $DRY_RUN"
echo "--------------------------------------------"

# Create target directory structure
ensure_dir "$TARGET_DIR"
for subdir in "${SUBDIRS[@]}"; do
    ensure_dir "$TARGET_DIR/$subdir"
done

# ─── Install .md files from subdirectories ────────────────────────────────────
for subdir in "${SUBDIRS[@]}"; do
    src_dir="${SCRIPT_DIR}/${subdir}"
    dest_dir="${TARGET_DIR}/${subdir}"

    if [[ ! -d "$src_dir" ]]; then
        skip "Source directory not found: $src_dir"
        continue
    fi

    # Process each .md file
    for src_file in "$src_dir"/*.md; do
        # Handle the case where glob matches nothing
        [[ -e "$src_file" ]] || continue

        filename="$(basename "$src_file")"
        install_file "$src_file" "$dest_dir/$filename"
    done
done

# ─── AGENTS.md (first-run only) ──────────────────────────────────────────────
echo "--------------------------------------------"
AGENTS_TARGET="${TARGET_DIR}/AGENTS.md"
AGENTS_TEMPLATE="${SCRIPT_DIR}/AGENTS.md.template"

if [[ -e "$AGENTS_TARGET" ]]; then
    skip "AGENTS.md already exists at $AGENTS_TARGET — skipping generation"
else
    if [[ ! -f "$AGENTS_TEMPLATE" ]]; then
        echo "[ERROR] Template not found: $AGENTS_TEMPLATE"
        exit 1
    fi

    if $DRY_RUN; then
        info "(dry-run) Would prompt for name/email and generate $AGENTS_TARGET from template"
        ((INSTALLED++)) || true
    else
        # Prompt for user details
        read -rp "Enter your name (for git config): " user_name
        read -rp "Enter your email (for git config): " user_email

        if [[ -z "$user_name" || -z "$user_email" ]]; then
            echo "[ERROR] Name and email are required."
            exit 1
        fi

        # Substitute placeholders and write
        sed -e "s/YOUR_NAME/${user_name}/g" -e "s/YOUR_EMAIL/${user_email}/g" \
            "$AGENTS_TEMPLATE" > "$AGENTS_TARGET"
        info "Generated $AGENTS_TARGET (name=$user_name, email=$user_email)"
        ((INSTALLED++)) || true
    fi
fi

# ─── opencode.json (first-run only) ──────────────────────────────────────────
OPENCODE_TARGET="${TARGET_DIR}/opencode.json"
OPENCODE_EXAMPLE="${SCRIPT_DIR}/opencode_example.json"

if [[ -e "$OPENCODE_TARGET" ]]; then
    skip "opencode.json already exists at $OPENCODE_TARGET — skipping"
else
    if [[ ! -f "$OPENCODE_EXAMPLE" ]]; then
        echo "[ERROR] Example config not found: $OPENCODE_EXAMPLE"
        exit 1
    fi

    if $DRY_RUN; then
        info "(dry-run) Would copy $OPENCODE_EXAMPLE -> $OPENCODE_TARGET"
        ((INSTALLED++)) || true
    else
        cp "$OPENCODE_EXAMPLE" "$OPENCODE_TARGET"
        info "Copied $OPENCODE_EXAMPLE -> $OPENCODE_TARGET"
        echo ""
        echo "  >>> ACTION REQUIRED: Edit $OPENCODE_TARGET"
        echo "  >>> Fill in your API keys and replace <<IP>> with your server IP."
        echo ""
        ((INSTALLED++)) || true
    fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo "============================================"
echo " Summary"
echo "============================================"
echo "  Installed:  $INSTALLED"
echo "  Skipped:    $SKIPPED"
echo "  Backed up:  $BACKED_UP"
echo "============================================"
