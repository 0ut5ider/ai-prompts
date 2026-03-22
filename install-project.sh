#!/usr/bin/env bash
# ABOUTME: Installs project configurations (agents, commands, skills) from this repo into a target project.
# ABOUTME: Supports multiple AI agents (OpenCode, Claude Code, etc.) via adapter system.
# ABOUTME: Supports install (with merge from multiple sub-sources) and update (with backup and clean push).
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="${SCRIPT_DIR}/projects"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
REGISTRY_FILE="${PROJECTS_DIR}/.install-registry-${HOSTNAME_SHORT}.json"
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"

# Neutral source directory name (inside sub-sources)
NEUTRAL_CONFIG_DIR=".agent"
# Neutral rules file name (at sub-source root)
NEUTRAL_RULES_FILE="RULES.md"
# Neutral settings file name (at sub-source root)
NEUTRAL_SETTINGS_FILE="settings.yaml"

# Default adapter for legacy registry entries (before multi-adapter support)
DEFAULT_ADAPTER="opencode"

# ─── Adapter state (populated by load_adapter) ──────────────────────────────
ADAPTER_NAME=""
ADAPTER_LABEL=""
CONFIG_DIR=""
RULES_FILE=""
SETTINGS_FILE=""
SETTINGS_LOCATION=""  # "root" or "config_dir"
SUPPORTED_SUBDIRS=()

# ─── Dependency check ─────────────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    for cmd in jq yq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[ERROR] Missing required dependencies: ${missing[*]}"
        echo "Install them and try again."
        exit 1
    fi
}

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install or update AI agent project configurations.

Modes:
  (default)     Interactive install — pick a project type, agent, and destination
  --update      Update all previously installed destinations from source

Options:
  --help        Show this help message

Source directory: ${PROJECTS_DIR}
Adapters:        ${ADAPTERS_DIR}
Registry file:   ${REGISTRY_FILE}
EOF
    exit 0
}

# ─── Parse arguments ─────────────────────────────────────────────────────────
MODE="install"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --update) MODE="update"; shift ;;
        --help)   usage ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$(basename "$0") --help' for usage."
            exit 1
            ;;
    esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo "[INFO]    $*"; }
warn()    { echo "[WARN]    $*"; }
error()   { echo "[ERROR]   $*" >&2; }
conflict(){ echo "[CONFLICT] $*"; }

# ─── Adapter functions ────────────────────────────────────────────────────────
discover_adapters() {
    local adapters=()
    for file in "${ADAPTERS_DIR}"/*.sh; do
        [[ -f "$file" ]] || continue
        local name
        name="$(basename "$file" .sh)"
        adapters+=("$name")
    done
    printf '%s\n' "${adapters[@]}"
}

load_adapter() {
    local adapter_name="$1"
    local adapter_file="${ADAPTERS_DIR}/${adapter_name}.sh"

    if [[ ! -f "$adapter_file" ]]; then
        error "Adapter '${adapter_name}' not found at '${adapter_file}'"
        exit 1
    fi

    # Reset state from any previously loaded adapter
    ADAPTER_NAME=""
    ADAPTER_LABEL=""
    CONFIG_DIR=""
    RULES_FILE=""
    SETTINGS_FILE=""
    SETTINGS_LOCATION=""
    SUPPORTED_SUBDIRS=()
    unset -f transform_settings 2>/dev/null || true

    # shellcheck source=/dev/null
    source "$adapter_file"

    # Validate adapter contract
    local missing_fields=()
    [[ -z "$ADAPTER_NAME" ]]  && missing_fields+=("ADAPTER_NAME")
    [[ -z "$ADAPTER_LABEL" ]] && missing_fields+=("ADAPTER_LABEL")
    [[ -z "$CONFIG_DIR" ]]    && missing_fields+=("CONFIG_DIR")
    [[ -z "$RULES_FILE" ]]    && missing_fields+=("RULES_FILE")
    [[ -z "$SETTINGS_FILE" ]] && missing_fields+=("SETTINGS_FILE")
    [[ -z "$SETTINGS_LOCATION" ]] && missing_fields+=("SETTINGS_LOCATION")
    [[ ${#SUPPORTED_SUBDIRS[@]} -eq 0 ]] && missing_fields+=("SUPPORTED_SUBDIRS")

    if ! declare -f transform_settings &>/dev/null; then
        missing_fields+=("transform_settings()")
    fi

    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        error "Adapter '${adapter_name}' is missing required fields: ${missing_fields[*]}"
        exit 1
    fi

    if [[ "$SETTINGS_LOCATION" != "root" && "$SETTINGS_LOCATION" != "config_dir" ]]; then
        error "Adapter '${adapter_name}' has invalid SETTINGS_LOCATION='${SETTINGS_LOCATION}' (must be 'root' or 'config_dir')"
        exit 1
    fi
}

# ─── Registry functions ──────────────────────────────────────────────────────
registry_init() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo '{"installs":[]}' | jq '.' > "$REGISTRY_FILE"
    fi
}

registry_find_entry() {
    local destination="$1"
    jq -r --arg dest "$destination" \
        '.installs[] | select(.destination == $dest)' \
        "$REGISTRY_FILE"
}

registry_add_entry() {
    local project="$1"
    local destination="$2"
    local adapter="$3"
    local sources_json="$4"
    local manifest_json="$5"

    local tmp
    tmp="$(mktemp)"
    jq --arg proj "$project" \
       --arg dest "$destination" \
       --arg adap "$adapter" \
       --arg ts "$TIMESTAMP" \
       --argjson sources "$sources_json" \
       --argjson manifest "$manifest_json" \
       '.installs += [{
            project: $proj,
            destination: $dest,
            adapter: $adap,
            sources: $sources,
            installed_at: $ts,
            updated_at: $ts,
            manifest: $manifest
        }]' "$REGISTRY_FILE" > "$tmp"
    mv "$tmp" "$REGISTRY_FILE"
}

registry_update_entry() {
    local destination="$1"
    local manifest_json="$2"

    local tmp
    tmp="$(mktemp)"
    jq --arg dest "$destination" \
       --arg ts "$TIMESTAMP" \
       --argjson manifest "$manifest_json" \
       '(.installs[] | select(.destination == $dest)) |= (
            .updated_at = $ts |
            .manifest = $manifest
        )' "$REGISTRY_FILE" > "$tmp"
    mv "$tmp" "$REGISTRY_FILE"
}

# ─── Project discovery ────────────────────────────────────────────────────────
discover_project_types() {
    local types=()
    for dir in "${PROJECTS_DIR}"/*/; do
        [[ -d "$dir" ]] || continue
        local name
        name="$(basename "$dir")"

        # Skip empty project types (no sub-sources with content)
        local has_content=false
        for subdir in "$dir"*/; do
            if [[ -d "$subdir" ]]; then
                has_content=true
                break
            fi
        done
        if $has_content; then
            types+=("$name")
        fi
    done
    printf '%s\n' "${types[@]}"
}

discover_sub_sources() {
    local project_dir="$1"
    local sources=()
    while IFS= read -r -d '' dir; do
        sources+=("$(basename "$dir")")
    done < <(find "$project_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    printf '%s\n' "${sources[@]}"
}

# ─── Merge functions ─────────────────────────────────────────────────────────

# Merge .agent/ subdirectory contents (agents/, commands/, skills/, rules/)
# Strategy: copy all files. On name collision, last source wins with warning.
# Skills are entire directories — last source wins on directory name collision.
merge_config_subdir() {
    local subdir_name="$1"
    local staging_dir="$2"
    local source_dir="$3"
    local sub_source_name="$4"

    local src="${source_dir}/${NEUTRAL_CONFIG_DIR}/${subdir_name}"
    local dest="${staging_dir}/${CONFIG_DIR}/${subdir_name}"

    [[ -d "$src" ]] || return 0

    mkdir -p "$dest"

    if [[ "$subdir_name" == "skills" ]]; then
        # Skills are directories — copy whole skill folders
        for skill_dir in "$src"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name="$(basename "$skill_dir")"
            if [[ -d "${dest}/${skill_name}" ]]; then
                conflict "Skill '${skill_name}' exists from a previous source, overwriting with '${sub_source_name}'"
                rm -rf "${dest}/${skill_name}"
            fi
            cp -rL "$skill_dir" "${dest}/${skill_name}"
        done
    else
        # agents/, commands/, rules/ — copy individual files
        for file in "$src"/*; do
            [[ -e "$file" ]] || continue
            local filename
            filename="$(basename "$file")"
            if [[ -e "${dest}/${filename}" ]]; then
                conflict "File '${subdir_name}/${filename}' exists from a previous source, overwriting with '${sub_source_name}'"
            fi
            cp -L "$file" "${dest}/${filename}"
        done
    fi
}

# Merge root-level .md files by concatenation with source headers.
# Handles RULES.md → agent-specific rules file rename.
merge_root_md() {
    local staging_dir="$1"
    local source_file="$2"
    local sub_source_name="$3"
    local filename
    filename="$(basename "$source_file")"

    # Map neutral RULES.md to agent-specific name
    if [[ "$filename" == "$NEUTRAL_RULES_FILE" ]]; then
        filename="$RULES_FILE"
    fi

    local dest="${staging_dir}/${filename}"

    local header="<!-- ═══════════════════════════════════════════════════════════ -->
<!-- Source: ${sub_source_name} -->
<!-- ═══════════════════════════════════════════════════════════ -->"

    if [[ -f "$dest" ]]; then
        # Append with separator
        printf '\n\n%s\n\n' "$header" >> "$dest"
        cat "$source_file" >> "$dest"
        info "Appended '${filename}' content from '${sub_source_name}'"
    else
        # First source — write header + content
        printf '%s\n\n' "$header" > "$dest"
        cat "$source_file" >> "$dest"
        info "Created '${filename}' from '${sub_source_name}'"
    fi
}

# Deep-merge root-level structured files (JSON or YAML).
# Args: staging_dir source_file sub_source_name format
#   format: "json" or "yaml"
merge_root_structured() {
    local staging_dir="$1"
    local source_file="$2"
    local sub_source_name="$3"
    local format="$4"
    local filename
    filename="$(basename "$source_file")"
    local dest="${staging_dir}/${filename}"

    # Validate source file
    if [[ "$format" == "json" ]]; then
        if ! jq empty "$source_file" 2>/dev/null; then
            error "Invalid JSON in '${source_file}' from '${sub_source_name}' — skipping"
            return 1
        fi
    else
        if ! yq '.' "$source_file" &>/dev/null; then
            error "Invalid YAML in '${source_file}' from '${sub_source_name}' — skipping"
            return 1
        fi
    fi

    if [[ -f "$dest" ]]; then
        local tmp
        tmp="$(mktemp)"
        if [[ "$format" == "json" ]]; then
            jq -s '.[0] * .[1]' "$dest" "$source_file" > "$tmp"
        else
            yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$dest" "$source_file" > "$tmp"
        fi
        mv "$tmp" "$dest"
        info "Deep-merged '${filename}' with content from '${sub_source_name}'"
    else
        cp "$source_file" "$dest"
        info "Created '${filename}' from '${sub_source_name}'"
    fi
}

# Process all root-level files from a sub-source
merge_root_files() {
    local staging_dir="$1"
    local source_dir="$2"
    local sub_source_name="$3"

    for file in "$source_dir"/*; do
        [[ -f "$file" ]] || continue
        local filename
        filename="$(basename "$file")"

        # Skip hidden files and directories
        [[ "$filename" == .* ]] && continue

        local extension="${filename##*.}"

        if [[ "$filename" == "$NEUTRAL_SETTINGS_FILE" ]]; then
            merge_root_structured "$staging_dir" "$file" "$sub_source_name" "yaml" || true
        elif [[ "$filename" == *.json ]]; then
            merge_root_structured "$staging_dir" "$file" "$sub_source_name" "json" || true
        elif [[ "$extension" == "md" ]]; then
            merge_root_md "$staging_dir" "$file" "$sub_source_name"
        elif [[ "$extension" == "yaml" || "$extension" == "yml" ]]; then
            merge_root_structured "$staging_dir" "$file" "$sub_source_name" "yaml" || true
        else
            # Unknown file type — last source wins with warning
            if [[ -f "${staging_dir}/${filename}" ]]; then
                conflict "Root file '${filename}' exists from a previous source, overwriting with '${sub_source_name}'"
            fi
            cp -L "$file" "${staging_dir}/${filename}"
            info "Copied root file '${filename}' from '${sub_source_name}'"
        fi
    done
}

# ─── Build file manifest from staging directory ──────────────────────────────
build_manifest() {
    local staging_dir="$1"

    find "$staging_dir" -type f -print0 | sort -z | \
        while IFS= read -r -d '' file; do
            printf '%s\n' "${file#"${staging_dir}"/}"
        done | jq -Rs 'split("\n") | map(select(. != ""))'
}

# ─── Transform settings in staging ────────────────────────────────────────────
# Replaces neutral settings.yaml with the agent-specific settings file.
# Must be called before build_manifest() so the manifest reflects final filenames.
transform_staging_settings() {
    local staging_dir="$1"

    if [[ ! -f "${staging_dir}/${NEUTRAL_SETTINGS_FILE}" ]]; then
        return 0
    fi

    local transformed_settings
    transformed_settings="$(transform_settings "${staging_dir}/${NEUTRAL_SETTINGS_FILE}")"
    rm "${staging_dir}/${NEUTRAL_SETTINGS_FILE}"

    if [[ "$transformed_settings" != "{}" ]]; then
        if [[ "$SETTINGS_LOCATION" == "root" ]]; then
            echo "$transformed_settings" > "${staging_dir}/${SETTINGS_FILE}"
        else
            echo "$transformed_settings" > "${staging_dir}/${CONFIG_DIR}/${SETTINGS_FILE}"
        fi
    fi
}

# ─── Deploy from staging to destination ───────────────────────────────────────
# Copies staged files to the destination directory.
# Assumes settings have already been transformed via transform_staging_settings().
deploy_staging() {
    local staging_dir="$1"
    local destination="$2"

    # Copy config directory contents
    if [[ -d "${staging_dir}/${CONFIG_DIR}" ]]; then
        mkdir -p "${destination}/${CONFIG_DIR}"
        cp -rL "${staging_dir}/${CONFIG_DIR}/." "${destination}/${CONFIG_DIR}/"
    fi

    # Copy root-level files
    for file in "${staging_dir}"/*; do
        [[ -f "$file" ]] || continue
        cp -L "$file" "${destination}/$(basename "$file")"
    done

    # Clean up empty directories left behind from staging or prior deletes
    if [[ -d "${destination}/${CONFIG_DIR}" ]]; then
        find "${destination}/${CONFIG_DIR}" -type d -empty -delete 2>/dev/null || true
    fi
}

# ─── Backup existing installed files ─────────────────────────────────────────
backup_installed_files() {
    local destination="$1"
    local manifest_json="$2"
    local backup_dir="${destination}/.agent-backups/${TIMESTAMP}"

    info "Creating backup at: ${backup_dir}"
    mkdir -p "$backup_dir"

    # Read manifest entries and back up each file
    local count=0
    while IFS= read -r rel_path; do
        [[ -z "$rel_path" ]] && continue
        local src="${destination}/${rel_path}"
        if [[ -f "$src" ]]; then
            local dest_backup="${backup_dir}/${rel_path}"
            mkdir -p "$(dirname "$dest_backup")"
            cp -L "$src" "$dest_backup"
            ((count++)) || true
        fi
    done < <(echo "$manifest_json" | jq -r '.[]')

    info "Backed up ${count} files"
}

# Delete previously installed files (surgical, manifest-based)
delete_installed_files() {
    local destination="$1"
    local manifest_json="$2"

    local count=0
    while IFS= read -r rel_path; do
        [[ -z "$rel_path" ]] && continue
        local target="${destination}/${rel_path}"
        if [[ -f "$target" ]]; then
            rm "$target"
            ((count++)) || true
        fi
    done < <(echo "$manifest_json" | jq -r '.[]')

    info "Deleted ${count} previously installed files"
}

# ─── Main: Install mode ──────────────────────────────────────────────────────
do_install() {
    echo "============================================"
    echo " AI Agent Project Installer"
    echo "============================================"

    # Discover project types
    local project_types=()
    mapfile -t project_types < <(discover_project_types)
    if [[ ${#project_types[@]} -eq 0 ]]; then
        error "No project types found in ${PROJECTS_DIR}"
        exit 1
    fi

    # Present project type menu
    echo ""
    echo "Available project types:"
    echo "--------------------------------------------"
    local i=1
    for pt in "${project_types[@]}"; do
        echo "  ${i}) ${pt}"
        ((i++)) || true
    done
    echo ""

    # Get project type selection
    local selection
    while true; do
        read -rp "Select project type [1-${#project_types[@]}]: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#project_types[@]} )); then
            break
        fi
        echo "Invalid selection. Enter a number between 1 and ${#project_types[@]}."
    done

    local project_type="${project_types[$((selection - 1))]}"
    local project_dir="${PROJECTS_DIR}/${project_type}"
    info "Selected project type: ${project_type}"

    # Discover and present agent adapters
    local available_adapters=()
    mapfile -t available_adapters < <(discover_adapters)
    if [[ ${#available_adapters[@]} -eq 0 ]]; then
        error "No adapters found in ${ADAPTERS_DIR}"
        exit 1
    fi

    echo ""
    echo "Available agents:"
    echo "--------------------------------------------"
    i=1
    for adap in "${available_adapters[@]}"; do
        # Load adapter temporarily to get its label
        (
            source "${ADAPTERS_DIR}/${adap}.sh"
            echo "  ${i}) ${ADAPTER_LABEL} (${adap})"
        )
        ((i++)) || true
    done
    echo ""

    # Get agent selection
    while true; do
        read -rp "Select agent [1-${#available_adapters[@]}]: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#available_adapters[@]} )); then
            break
        fi
        echo "Invalid selection. Enter a number between 1 and ${#available_adapters[@]}."
    done

    local selected_adapter="${available_adapters[$((selection - 1))]}"
    load_adapter "$selected_adapter"
    info "Selected agent: ${ADAPTER_LABEL} (${ADAPTER_NAME})"

    # Get destination path
    echo ""
    local destination
    read -rp "Enter destination path (absolute): " destination

    # Normalize — remove trailing slash
    destination="${destination%/}"

    # Validate it's absolute
    if [[ "$destination" != /* ]]; then
        error "Destination must be an absolute path."
        exit 1
    fi

    # Check registry for existing install at this destination
    registry_init
    local existing
    existing="$(registry_find_entry "$destination")"
    if [[ -n "$existing" ]]; then
        local existing_project
        existing_project="$(echo "$existing" | jq -r '.project')"
        error "Destination '${destination}' already has a '${existing_project}' install."
        echo "Use '$(basename "$0") --update' to push changes."
        exit 1
    fi

    # Create destination structure
    mkdir -p "${destination}/${CONFIG_DIR}"
    info "Destination: ${destination}"

    # Discover sub-sources
    local sub_sources=()
    mapfile -t sub_sources < <(discover_sub_sources "$project_dir")

    echo ""
    echo "Sub-sources (processed in order):"
    for ss in "${sub_sources[@]}"; do
        echo "  - ${ss}"
    done
    echo "--------------------------------------------"

    # Create staging directory
    local staging_dir
    staging_dir="$(mktemp -d)"
    mkdir -p "${staging_dir}/${CONFIG_DIR}"
    trap "rm -rf '${staging_dir}'" EXIT

    # Merge from each sub-source
    for sub_source in "${sub_sources[@]}"; do
        local source_path="${project_dir}/${sub_source}"
        echo ""
        info "Processing sub-source: ${sub_source}"

        # Merge .agent/ subdirectories (only those supported by adapter)
        for subdir in "${SUPPORTED_SUBDIRS[@]}"; do
            merge_config_subdir "$subdir" "$staging_dir" "$source_path" "$sub_source"
        done

        # Merge root-level files
        merge_root_files "$staging_dir" "$source_path" "$sub_source"
    done

    # Transform settings and build manifest (order matters — manifest must reflect final filenames)
    transform_staging_settings "$staging_dir"

    local manifest_json
    manifest_json="$(build_manifest "$staging_dir")"

    # Build sources JSON array
    local sources_json
    sources_json="$(printf '%s\n' "${sub_sources[@]}" | jq -Rs 'split("\n") | map(select(. != ""))')"

    # Deploy to destination
    echo ""
    echo "--------------------------------------------"
    info "Deploying to ${destination}"
    deploy_staging "$staging_dir" "$destination"

    # Record in registry
    registry_add_entry "$project_type" "$destination" "$selected_adapter" "$sources_json" "$manifest_json"
    info "Recorded install in registry"

    # Summary
    echo ""
    echo "============================================"
    echo " Install Complete"
    echo "============================================"
    echo "  Project type:  ${project_type}"
    echo "  Agent:         ${ADAPTER_LABEL}"
    echo "  Destination:   ${destination}"
    echo "  Sub-sources:   ${sub_sources[*]}"
    echo "  Files:         $(echo "$manifest_json" | jq 'length')"
    echo "============================================"
}

# ─── Main: Update mode ───────────────────────────────────────────────────────
do_update() {
    echo "============================================"
    echo " AI Agent Project Updater"
    echo "============================================"

    registry_init

    # Read all entries
    local entry_count
    entry_count="$(jq '.installs | length' "$REGISTRY_FILE")"

    if [[ "$entry_count" -eq 0 ]]; then
        info "No installations found in registry. Nothing to update."
        exit 0
    fi

    echo "Found ${entry_count} installation(s) to update."
    echo "--------------------------------------------"

    local updated=0
    local failed=0

    for (( idx=0; idx < entry_count; idx++ )); do
        local entry
        entry="$(jq ".installs[${idx}]" "$REGISTRY_FILE")"

        local project destination adapter_name old_manifest
        IFS=$'\t' read -r project destination adapter_name old_manifest <<< \
            "$(echo "$entry" | jq -r --arg def "$DEFAULT_ADAPTER" '[.project, .destination, (.adapter // $def), (.manifest | @json)] | @tsv')"

        echo ""
        info "Updating: ${destination} (project: ${project}, agent: ${adapter_name})"

        # Load adapter for this install
        if [[ ! -f "${ADAPTERS_DIR}/${adapter_name}.sh" ]]; then
            error "Adapter '${adapter_name}' not found. Skipping."
            ((failed++)) || true
            continue
        fi
        load_adapter "$adapter_name"

        # Validate destination exists
        if [[ ! -d "$destination" ]]; then
            error "Destination '${destination}' does not exist. Skipping."
            echo "  The destination directory may have been moved or deleted."
            echo "  Remove this entry from the registry if it's no longer needed."
            ((failed++)) || true
            continue
        fi

        if [[ ! -d "${destination}/${CONFIG_DIR}" ]]; then
            error "Destination '${destination}' has no ${CONFIG_DIR}/ directory. Skipping."
            echo "  The installed configuration appears to be missing."
            echo "  Use a fresh install instead of update."
            ((failed++)) || true
            continue
        fi

        local project_dir="${PROJECTS_DIR}/${project}"
        if [[ ! -d "$project_dir" ]]; then
            error "Source project '${project}' no longer exists at '${project_dir}'. Skipping."
            ((failed++)) || true
            continue
        fi

        # Step 1: Backup existing installed files
        backup_installed_files "$destination" "$old_manifest"

        # Step 2: Stage new merged content
        local staging_dir
        staging_dir="$(mktemp -d)"
        mkdir -p "${staging_dir}/${CONFIG_DIR}"

        local sub_sources=()
        mapfile -t sub_sources < <(discover_sub_sources "$project_dir")

        local merge_failed=false
        for sub_source in "${sub_sources[@]}"; do
            local source_path="${project_dir}/${sub_source}"
            info "  Merging sub-source: ${sub_source}"

            for subdir in "${SUPPORTED_SUBDIRS[@]}"; do
                merge_config_subdir "$subdir" "$staging_dir" "$source_path" "$sub_source" || {
                    merge_failed=true
                    break 2
                }
            done

            merge_root_files "$staging_dir" "$source_path" "$sub_source" || {
                merge_failed=true
                break
            }
        done

        if $merge_failed; then
            error "Merge failed for '${destination}'. Files were NOT deleted. Backup is at:"
            error "  ${destination}/.agent-backups/${TIMESTAMP}/"
            rm -rf "$staging_dir"
            ((failed++)) || true
            continue
        fi

        # Step 3: Transform settings in staging
        transform_staging_settings "$staging_dir"

        # Step 4: Build new manifest (after transform)
        local new_manifest
        new_manifest="$(build_manifest "$staging_dir")"

        # Step 5: Delete old installed files (surgical)
        delete_installed_files "$destination" "$old_manifest"

        # Step 6: Deploy new files
        deploy_staging "$staging_dir" "$destination"
        rm -rf "$staging_dir"

        # Step 7: Update registry
        registry_update_entry "$destination" "$new_manifest"

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
    echo "  Total:    ${entry_count}"
    echo "============================================"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
check_dependencies

case "$MODE" in
    install) do_install ;;
    update)  do_update ;;
esac
