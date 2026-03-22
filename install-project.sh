#!/usr/bin/env bash
# ABOUTME: Installs OpenCode project configurations (agents, commands, skills) from this repo into a target project.
# ABOUTME: Supports install (with merge from multiple sub-sources) and update (with backup and clean push).
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="${SCRIPT_DIR}/projects"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
REGISTRY_FILE="${PROJECTS_DIR}/.install-registry-${HOSTNAME_SHORT}.json"
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"

# Directories inside .opencode/ that get merged
OPENCODE_SUBDIRS=("agents" "commands" "skills")

# ─── Dependency check ─────────────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    for cmd in jq; do
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

Install or update OpenCode project configurations.

Modes:
  (default)     Interactive install — pick a project type and destination
  --update      Update all previously installed destinations from source

Options:
  --help        Show this help message

Source directory: ${PROJECTS_DIR}
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
    local sources_json="$3"
    local manifest_json="$4"

    local tmp
    tmp="$(mktemp)"
    jq --arg proj "$project" \
       --arg dest "$destination" \
       --arg ts "$TIMESTAMP" \
       --argjson sources "$sources_json" \
       --argjson manifest "$manifest_json" \
       '.installs += [{
            project: $proj,
            destination: $dest,
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
    echo "${types[@]}"
}

discover_sub_sources() {
    local project_dir="$1"
    local sources=()
    for dir in "$project_dir"/*/; do
        [[ -d "$dir" ]] || continue
        sources+=("$(basename "$dir")")
    done
    # Sort alphabetically for deterministic ordering
    IFS=$'\n' sources=($(sort <<<"${sources[*]}")); unset IFS
    echo "${sources[@]}"
}

# ─── Merge functions ─────────────────────────────────────────────────────────

# Merge .opencode/ subdirectory contents (agents/, commands/, skills/)
# Strategy: copy all files. On name collision, last source wins with warning.
# Skills are entire directories — last source wins on directory name collision.
merge_opencode_subdir() {
    local subdir_name="$1"
    local staging_dir="$2"
    local source_dir="$3"
    local sub_source_name="$4"

    local src="${source_dir}/.opencode/${subdir_name}"
    local dest="${staging_dir}/.opencode/${subdir_name}"

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
        # agents/ and commands/ — copy individual files
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

# Merge root-level .md files by concatenation with source headers
merge_root_md() {
    local staging_dir="$1"
    local source_file="$2"
    local sub_source_name="$3"
    local filename
    filename="$(basename "$source_file")"
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

# Deep-merge root-level JSON files using jq
merge_root_json() {
    local staging_dir="$1"
    local source_file="$2"
    local sub_source_name="$3"
    local filename
    filename="$(basename "$source_file")"
    local dest="${staging_dir}/${filename}"

    # Validate source JSON
    if ! jq empty "$source_file" 2>/dev/null; then
        error "Invalid JSON in '${source_file}' from '${sub_source_name}' — skipping"
        return 1
    fi

    if [[ -f "$dest" ]]; then
        # Deep merge: existing * new (new wins on conflicts)
        local tmp
        tmp="$(mktemp)"
        jq -s '.[0] * .[1]' "$dest" "$source_file" > "$tmp"
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

        if [[ "$filename" == *.json ]]; then
            merge_root_json "$staging_dir" "$file" "$sub_source_name" || true
        elif [[ "$extension" == "md" ]]; then
            merge_root_md "$staging_dir" "$file" "$sub_source_name"
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
    local manifest=()

    while IFS= read -r -d '' file; do
        local rel="${file#"${staging_dir}"/}"
        manifest+=("\"${rel}\"")
    done < <(find "$staging_dir" -type f -print0 | sort -z)

    local json="["
    local first=true
    for entry in "${manifest[@]}"; do
        if $first; then
            json+="${entry}"
            first=false
        else
            json+=",${entry}"
        fi
    done
    json+="]"
    echo "$json"
}

# ─── Deploy from staging to destination ───────────────────────────────────────
deploy_staging() {
    local staging_dir="$1"
    local destination="$2"

    # Copy .opencode/ contents
    if [[ -d "${staging_dir}/.opencode" ]]; then
        mkdir -p "${destination}/.opencode"
        cp -rL "${staging_dir}/.opencode/." "${destination}/.opencode/"
    fi

    # Copy root-level files
    for file in "${staging_dir}"/*; do
        [[ -f "$file" ]] || continue
        cp -L "$file" "${destination}/$(basename "$file")"
    done

    # Clean up empty directories left behind from staging or prior deletes
    if [[ -d "${destination}/.opencode" ]]; then
        find "${destination}/.opencode" -type d -empty -delete 2>/dev/null || true
    fi
}

# ─── Backup existing installed files ─────────────────────────────────────────
backup_installed_files() {
    local destination="$1"
    local manifest_json="$2"
    local backup_dir="${destination}/.opencode-backups/${TIMESTAMP}"

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
    echo " OpenCode Project Installer"
    echo "============================================"

    # Discover project types
    local types_str
    types_str="$(discover_project_types)"
    if [[ -z "$types_str" ]]; then
        error "No project types found in ${PROJECTS_DIR}"
        exit 1
    fi

    read -ra project_types <<< "$types_str"

    # Present menu
    echo ""
    echo "Available project types:"
    echo "--------------------------------------------"
    local i=1
    for pt in "${project_types[@]}"; do
        echo "  ${i}) ${pt}"
        ((i++)) || true
    done
    echo ""

    # Get user selection
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
    mkdir -p "${destination}/.opencode"
    info "Destination: ${destination}"

    # Discover sub-sources
    local sources_str
    sources_str="$(discover_sub_sources "$project_dir")"
    read -ra sub_sources <<< "$sources_str"

    echo ""
    echo "Sub-sources (processed in order):"
    for ss in "${sub_sources[@]}"; do
        echo "  - ${ss}"
    done
    echo "--------------------------------------------"

    # Create staging directory
    local staging_dir
    staging_dir="$(mktemp -d)"
    mkdir -p "${staging_dir}/.opencode"
    trap "rm -rf '${staging_dir}'" EXIT

    # Merge from each sub-source
    for sub_source in "${sub_sources[@]}"; do
        local source_path="${project_dir}/${sub_source}"
        echo ""
        info "Processing sub-source: ${sub_source}"

        # Merge .opencode/ subdirectories
        for subdir in "${OPENCODE_SUBDIRS[@]}"; do
            merge_opencode_subdir "$subdir" "$staging_dir" "$source_path" "$sub_source"
        done

        # Merge root-level files
        merge_root_files "$staging_dir" "$source_path" "$sub_source"
    done

    # Build manifest
    local manifest_json
    manifest_json="$(build_manifest "$staging_dir")"

    # Build sources JSON array
    local sources_json
    sources_json="$(printf '%s\n' "${sub_sources[@]}" | jq -R . | jq -s .)"

    # Deploy to destination
    echo ""
    echo "--------------------------------------------"
    info "Deploying to ${destination}"
    deploy_staging "$staging_dir" "$destination"

    # Record in registry
    registry_add_entry "$project_type" "$destination" "$sources_json" "$manifest_json"
    info "Recorded install in registry"

    # Summary
    local file_count
    file_count="$(echo "$manifest_json" | jq '. | length')"
    echo ""
    echo "============================================"
    echo " Install Complete"
    echo "============================================"
    echo "  Project type:  ${project_type}"
    echo "  Destination:   ${destination}"
    echo "  Sub-sources:   ${sub_sources[*]}"
    echo "  Files:         ${file_count}"
    echo "============================================"
}

# ─── Main: Update mode ───────────────────────────────────────────────────────
do_update() {
    echo "============================================"
    echo " OpenCode Project Updater"
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

        local project destination old_manifest
        project="$(echo "$entry" | jq -r '.project')"
        destination="$(echo "$entry" | jq -r '.destination')"
        old_manifest="$(echo "$entry" | jq -c '.manifest')"

        echo ""
        info "Updating: ${destination} (project: ${project})"

        # Validate destination exists
        if [[ ! -d "$destination" ]]; then
            error "Destination '${destination}' does not exist. Skipping."
            echo "  The destination directory may have been moved or deleted."
            echo "  Remove this entry from the registry if it's no longer needed."
            ((failed++)) || true
            continue
        fi

        if [[ ! -d "${destination}/.opencode" ]]; then
            error "Destination '${destination}' has no .opencode/ directory. Skipping."
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
        mkdir -p "${staging_dir}/.opencode"

        local sources_str
        sources_str="$(discover_sub_sources "$project_dir")"
        read -ra sub_sources <<< "$sources_str"

        local merge_failed=false
        for sub_source in "${sub_sources[@]}"; do
            local source_path="${project_dir}/${sub_source}"
            info "  Merging sub-source: ${sub_source}"

            for subdir in "${OPENCODE_SUBDIRS[@]}"; do
                merge_opencode_subdir "$subdir" "$staging_dir" "$source_path" "$sub_source" || {
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
            error "  ${destination}/.opencode-backups/${TIMESTAMP}/"
            rm -rf "$staging_dir"
            ((failed++)) || true
            continue
        fi

        # Step 3: Build new manifest (before staging is removed)
        local new_manifest
        new_manifest="$(build_manifest "$staging_dir")"

        # Step 4: Delete old installed files (surgical)
        delete_installed_files "$destination" "$old_manifest"

        # Step 5: Deploy new files
        deploy_staging "$staging_dir" "$destination"
        rm -rf "$staging_dir"

        # Step 6: Update registry
        registry_update_entry "$destination" "$new_manifest"

        local file_count
        file_count="$(echo "$new_manifest" | jq '. | length')"
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
