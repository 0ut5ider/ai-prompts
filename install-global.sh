#!/usr/bin/env bash
# ABOUTME: Installs global AI agent configuration to the agent's config directory.
# ABOUTME: Supports multiple agents via adapter system, with manifest-based tracking.
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/adapters.sh"
source "${SCRIPT_DIR}/lib/merge.sh"

GLOBAL_SOURCE_DIR="${SCRIPT_DIR}/global"
DRY_RUN=false
CUSTOM_TARGET=false
AGENT_FLAG=""
UPDATE_MODE=false
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"

# Counters
INSTALLED=0
SKIPPED=0
BACKED_UP=0

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install global AI agent configuration files.

Options:
  --agent NAME   Install for a specific agent (e.g., opencode, claude-code)
  --target DIR   Install to DIR instead of the agent's default location
  --update       Update existing global installations using manifests
  --dry-run      Print what would be done without making changes
  --help         Show this help message

Source directory: ${GLOBAL_SOURCE_DIR}
Adapters:        ${ADAPTERS_DIR}
EOF
    exit 0
}

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                echo "Error: --agent requires a name argument"
                exit 1
            fi
            AGENT_FLAG="$2"; shift 2 ;;
        --target)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                echo "Error: --target requires a directory argument"
                exit 1
            fi
            CUSTOM_TARGET="$2"; shift 2 ;;
        --update)  UPDATE_MODE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help)    usage ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$(basename "$0") --help' for usage."
            exit 1
            ;;
    esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()       { echo "[INFO]    $*"; }
warn()       { echo "[WARNING] $*"; }
error()      { echo "[ERROR]   $*" >&2; }
conflict()   { echo "[CONFLICT] $*"; }
skip()       { echo "[SKIP]    $*"; ((SKIPPED++)) || true; }
backup_msg() { echo "[BACKUP]  $*"; ((BACKED_UP++)) || true; }

# ─── Manifest helpers ────────────────────────────────────────────────────────
write_manifest() {
    local destination="$1"
    local adapter_name="$2"
    local manifest_json="$3"
    local installed_at="$4"
    local updated_at="$5"
    local manifest_file="${destination}/.agent-manifest.json"

    if $DRY_RUN; then
        info "(dry-run) Would write manifest to ${manifest_file}"
        return 0
    fi

    jq -n \
        --arg adapter "$adapter_name" \
        --arg installed "$installed_at" \
        --arg updated "$updated_at" \
        --argjson manifest "$manifest_json" \
        '{
            adapter: $adapter,
            installed_at: $installed,
            updated_at: $updated,
            manifest: $manifest
        }' > "$manifest_file"
}

read_manifest_field() {
    local manifest_file="$1"
    local field="$2"
    jq -r ".${field}" "$manifest_file"
}

# ─── Select adapter (interactive or via --agent flag) ────────────────────────
select_adapter() {
    if [[ -n "$AGENT_FLAG" ]]; then
        echo "$AGENT_FLAG"
        return 0
    fi

    # Discover adapters and present menu
    local available_adapters=()
    mapfile -t available_adapters < <(discover_adapters)
    if [[ ${#available_adapters[@]} -eq 0 ]]; then
        error "No adapters found in ${ADAPTERS_DIR}"
        exit 1
    fi

    echo ""
    echo "Available agents:"
    echo "--------------------------------------------"
    local i=1
    for adap in "${available_adapters[@]}"; do
        (
            source "${ADAPTERS_DIR}/${adap}.sh"
            echo "  ${i}) ${ADAPTER_LABEL} (${adap})"
        )
        ((i++)) || true
    done
    echo ""

    local selection
    while true; do
        read -rp "Select agent [1-${#available_adapters[@]}]: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#available_adapters[@]} )); then
            break
        fi
        echo "Invalid selection. Enter a number between 1 and ${#available_adapters[@]}."
    done

    echo "${available_adapters[$((selection - 1))]}"
}

# ─── Stage global content into a provided staging directory ──────────────────
# Merges .agent/ subdirs, root files, and transforms settings.
# Requires: adapter already loaded, staging_dir already created with CONFIG_DIR.
stage_global_content() {
    local staging_dir="$1"

    # Merge .agent/ subdirs into staging
    for subdir in "${SUPPORTED_SUBDIRS[@]}"; do
        merge_config_subdir "$subdir" "$staging_dir" "$GLOBAL_SOURCE_DIR" "global"
    done

    # Merge root files (RULES.md -> adapter name, settings.yaml deep merge)
    merge_root_files "$staging_dir" "$GLOBAL_SOURCE_DIR" "global"

    # Transform settings (settings.yaml -> adapter-specific format)
    transform_staging_settings "$staging_dir"
}

# ─── Handle credential template ─────────────────────────────────────────────
# Copies credential template to staging if no config file exists at destination.
# Returns 0 if credential was staged, 1 if skipped.
handle_credential_template() {
    local staging_dir="$1"
    local destination="$2"

    local cred_template="${GLOBAL_SOURCE_DIR}/credentials/${ADAPTER_NAME}_example.json"

    if [[ ! -f "$cred_template" ]]; then
        # No credential template for this adapter — silently skip
        return 1
    fi

    # Determine where the settings/config file lives at destination
    local settings_dest
    if [[ "$SETTINGS_LOCATION" == "root" ]]; then
        settings_dest="${destination}/${SETTINGS_FILE}"
    else
        settings_dest="${destination}/${CONFIG_DIR}/${SETTINGS_FILE}"
    fi

    if [[ -f "$settings_dest" ]]; then
        skip "Config file already exists at ${settings_dest} — preserving existing config"
        return 1
    fi

    # Place credential template as the settings file in staging.
    # For flat deploy with SETTINGS_LOCATION "root": file goes at staging root.
    # The credential template replaces any transform-generated settings (it provides
    # the full config including providers, API keys, etc.).
    local staged_settings
    if [[ "$SETTINGS_LOCATION" == "root" ]]; then
        staged_settings="${staging_dir}/${SETTINGS_FILE}"
    else
        staged_settings="${staging_dir}/${CONFIG_DIR}/${SETTINGS_FILE}"
    fi

    if $DRY_RUN; then
        info "(dry-run) Would copy credential template as ${SETTINGS_FILE}"
    else
        cp "$cred_template" "$staged_settings"
        info "Copied credential template as ${SETTINGS_FILE}"
    fi
    return 0
}

# ─── Main: Install mode ──────────────────────────────────────────────────────
do_install() {
    echo "============================================"
    echo " Global AI Agent Config Installer"
    echo "============================================"

    # Step 1: Select adapter
    local selected_adapter
    selected_adapter="$(select_adapter)"
    load_adapter "$selected_adapter"
    info "Selected agent: ${ADAPTER_LABEL} (${ADAPTER_NAME})"

    # Step 2: Resolve destination
    local destination
    if [[ "$CUSTOM_TARGET" != "false" ]]; then
        destination="$CUSTOM_TARGET"
    else
        destination="$GLOBAL_CONFIG_DIR"
    fi
    destination="${destination%/}"  # normalize
    info "Destination: ${destination}"

    # Step 3: Check for existing manifest — warn but allow re-install
    local manifest_file="${destination}/.agent-manifest.json"
    if [[ -f "$manifest_file" ]]; then
        local existing_adapter
        existing_adapter="$(read_manifest_field "$manifest_file" "adapter")"
        warn "Destination already has a global install (adapter: ${existing_adapter})"
        warn "Re-installing will overwrite the existing configuration."
    fi

    # Step 4: Create destination directory
    if $DRY_RUN; then
        info "(dry-run) Would create directory: ${destination}"
    else
        mkdir -p "$destination"
    fi

    echo "--------------------------------------------"

    # Step 5: Create staging directory with cleanup trap
    local staging_dir
    staging_dir="$(mktemp -d)"
    mkdir -p "${staging_dir}/${CONFIG_DIR}"
    trap "rm -rf '${staging_dir}'" EXIT

    # Step 6: Merge and transform
    stage_global_content "$staging_dir"

    # Step 7: Handle credential template
    handle_credential_template "$staging_dir" "$destination" || true

    # Step 7b: If destination settings file already exists, remove transform-generated
    # settings from staging so deploy_staging() won't overwrite user's config.
    # The credential template provides the FULL config (providers, API keys, MCP);
    # the transform only outputs partial MCP config. Preserve user's existing file.
    local settings_dest
    if [[ "$SETTINGS_LOCATION" == "root" ]]; then
        settings_dest="${destination}/${SETTINGS_FILE}"
    else
        settings_dest="${destination}/${CONFIG_DIR}/${SETTINGS_FILE}"
    fi
    if [[ -f "$settings_dest" ]]; then
        local staged_settings
        if [[ "$SETTINGS_LOCATION" == "root" ]]; then
            staged_settings="${staging_dir}/${SETTINGS_FILE}"
        else
            staged_settings="${staging_dir}/${CONFIG_DIR}/${SETTINGS_FILE}"
        fi
        if [[ -f "$staged_settings" ]]; then
            rm "$staged_settings"
            info "Removed transform-generated ${SETTINGS_FILE} from staging (preserving existing config)"
        fi
    fi

    # Step 8: Build manifest (after credential handling, so manifest reflects final files)
    # The manifest must reflect the flat layout at destination, so strip CONFIG_DIR/ prefix
    local manifest_json
    manifest_json="$(build_manifest "$staging_dir" | jq --arg cd "${CONFIG_DIR}/" '[.[] | if startswith($cd) then ltrimstr($cd) else . end]')"

    # Step 9: Deploy
    echo "--------------------------------------------"
    if $DRY_RUN; then
        info "(dry-run) Would deploy the following files:"
        echo "$manifest_json" | jq -r '.[]' | while IFS= read -r f; do
            info "  ${destination}/${f}"
        done
    else
        deploy_staging "$staging_dir" "$destination" "flat"
        info "Deployed files to ${destination}"
    fi

    # Step 10: Write manifest
    write_manifest "$destination" "$ADAPTER_NAME" "$manifest_json" "$TIMESTAMP" "$TIMESTAMP"

    # Count installed files
    INSTALLED="$(echo "$manifest_json" | jq 'length')"

    # Summary
    echo ""
    echo "============================================"
    echo " Install Complete"
    echo "============================================"
    echo "  Agent:       ${ADAPTER_LABEL}"
    echo "  Destination: ${destination}"
    echo "  Installed:   ${INSTALLED}"
    echo "  Skipped:     ${SKIPPED}"
    echo "  Backed up:   ${BACKED_UP}"
    echo "============================================"
}

# ─── Main: Update mode ───────────────────────────────────────────────────────
do_update() {
    echo "============================================"
    echo " Global AI Agent Config Updater"
    echo "============================================"

    # Step 1: Discover existing installations by scanning each adapter's GLOBAL_CONFIG_DIR
    local found_installs=()
    local available_adapters=()
    mapfile -t available_adapters < <(discover_adapters)

    for adap in "${available_adapters[@]}"; do
        # Load adapter in a subshell to get GLOBAL_CONFIG_DIR without polluting state
        local global_dir
        global_dir="$(
            source "${ADAPTERS_DIR}/${adap}.sh"
            echo "$GLOBAL_CONFIG_DIR"
        )"
        local mf="${global_dir}/.agent-manifest.json"
        if [[ -f "$mf" ]]; then
            found_installs+=("$mf")
        fi
    done

    if [[ ${#found_installs[@]} -eq 0 ]]; then
        info "No global installations found. Nothing to update."
        exit 0
    fi

    echo "Found ${#found_installs[@]} installation(s) to update."
    echo "--------------------------------------------"

    local updated=0
    local failed=0

    for manifest_file in "${found_installs[@]}"; do
        local destination
        destination="$(dirname "$manifest_file")"

        local adapter_name installed_at old_manifest
        adapter_name="$(read_manifest_field "$manifest_file" "adapter")"
        installed_at="$(read_manifest_field "$manifest_file" "installed_at")"
        old_manifest="$(read_manifest_field "$manifest_file" "manifest")"

        echo ""
        info "Updating: ${destination} (adapter: ${adapter_name})"

        # Load adapter
        if [[ ! -f "${ADAPTERS_DIR}/${adapter_name}.sh" ]]; then
            error "Adapter '${adapter_name}' not found. Skipping."
            ((failed++)) || true
            continue
        fi
        load_adapter "$adapter_name"

        # Validate destination exists
        if [[ ! -d "$destination" ]]; then
            error "Destination '${destination}' does not exist. Skipping."
            ((failed++)) || true
            continue
        fi

        # Step a: Backup existing installed files
        if $DRY_RUN; then
            info "(dry-run) Would back up installed files"
        else
            backup_installed_files "$destination" "$old_manifest"
        fi

        # Step b: Stage new content
        local staging_dir
        staging_dir="$(mktemp -d)"
        mkdir -p "${staging_dir}/${CONFIG_DIR}"

        stage_global_content "$staging_dir"

        # Step c: Handle credential template
        handle_credential_template "$staging_dir" "$destination" || true

        # Step c2: If destination settings file already exists, remove transform-generated
        # settings from staging so deploy_staging() won't overwrite user's config.
        # Also save the user's settings file so we can restore it after delete_installed_files.
        local settings_dest preserved_settings_file=""
        if [[ "$SETTINGS_LOCATION" == "root" ]]; then
            settings_dest="${destination}/${SETTINGS_FILE}"
        else
            settings_dest="${destination}/${CONFIG_DIR}/${SETTINGS_FILE}"
        fi
        if [[ -f "$settings_dest" ]]; then
            # Save user's settings to a temp file for restoration after delete
            preserved_settings_file="$(mktemp)"
            cp "$settings_dest" "$preserved_settings_file"
            # Remove transform-generated settings from staging
            local staged_settings
            if [[ "$SETTINGS_LOCATION" == "root" ]]; then
                staged_settings="${staging_dir}/${SETTINGS_FILE}"
            else
                staged_settings="${staging_dir}/${CONFIG_DIR}/${SETTINGS_FILE}"
            fi
            if [[ -f "$staged_settings" ]]; then
                rm "$staged_settings"
                info "Removed transform-generated ${SETTINGS_FILE} from staging (preserving existing config)"
            fi
        fi

        # Step d: Build new manifest (flat layout — strip CONFIG_DIR/ prefix)
        local new_manifest
        new_manifest="$(build_manifest "$staging_dir" | jq --arg cd "${CONFIG_DIR}/" '[.[] | if startswith($cd) then ltrimstr($cd) else . end]')"

        # Step e: Delete old installed files
        if $DRY_RUN; then
            info "(dry-run) Would delete previously installed files"
        else
            delete_installed_files "$destination" "$old_manifest"
        fi

        # Step f: Deploy new files
        if $DRY_RUN; then
            info "(dry-run) Would deploy updated files:"
            echo "$new_manifest" | jq -r '.[]' | while IFS= read -r f; do
                info "  ${destination}/${f}"
            done
        else
            deploy_staging "$staging_dir" "$destination" "flat"
        fi

        # Step f2: Restore preserved settings file if it was saved
        if [[ -n "$preserved_settings_file" && -f "$preserved_settings_file" ]]; then
            cp "$preserved_settings_file" "$settings_dest"
            rm "$preserved_settings_file"
            info "Restored preserved ${SETTINGS_FILE}"
        fi

        # Step g: Update manifest with new content and updated_at timestamp
        write_manifest "$destination" "$adapter_name" "$new_manifest" "$installed_at" "$TIMESTAMP"

        rm -rf "$staging_dir"

        local file_count
        file_count="$(echo "$new_manifest" | jq 'length')"
        info "Updated ${file_count} files at ${destination}"
        ((updated++)) || true
    done

    # Summary
    echo ""
    echo "============================================"
    echo " Update Complete"
    echo "============================================"
    echo "  Updated:  ${updated}"
    echo "  Failed:   ${failed}"
    echo "  Total:    ${#found_installs[@]}"
    echo "============================================"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
check_dependencies

if $UPDATE_MODE; then
    do_update
else
    do_install
fi
