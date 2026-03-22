# ABOUTME: Shared merge, staging, deploy, and manifest functions for installer scripts.
# ABOUTME: Sourced after lib/adapters.sh. Requires adapter state and NEUTRAL_* constants to be set.

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
# Layout parameter:
#   "project" (default) — deploys config dir as subdir, root files at destination root
#   "flat" — deploys everything directly to destination (for global installer use)
deploy_staging() {
    local staging_dir="$1"
    local destination="$2"
    local layout="${3:-project}"

    if [[ "$layout" == "project" ]]; then
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
    elif [[ "$layout" == "flat" ]]; then
        # Copy contents of config directory directly to destination
        if [[ -d "${staging_dir}/${CONFIG_DIR}" ]]; then
            cp -rL "${staging_dir}/${CONFIG_DIR}/." "${destination}/"
        fi

        # Copy root-level files directly to destination
        for file in "${staging_dir}"/*; do
            [[ -f "$file" ]] || continue
            cp -L "$file" "${destination}/$(basename "$file")"
        done

        # Clean up empty directories
        find "${destination}" -type d -empty -delete 2>/dev/null || true
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
