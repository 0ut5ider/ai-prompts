# Phase 1: Extract Shared Library from `install-project.sh`

**Risk:** High — touches working code with 103 existing tests
**Verification:** `bash test-install-project.sh` — all 103 tests pass unchanged

## Goal

Extract reusable functions from `install-project.sh` into `lib/` so both the project and global installers can share them without duplication.

## New Files

### `lib/adapters.sh`

Extracted from `install-project.sh` lines 7-147:

**Constants:**
```bash
ADAPTERS_DIR="${SCRIPT_DIR}/adapters"
NEUTRAL_CONFIG_DIR=".agent"
NEUTRAL_RULES_FILE="RULES.md"
NEUTRAL_SETTINGS_FILE="settings.yaml"
```

**Adapter state variables** (populated by `load_adapter()`):
```bash
ADAPTER_NAME=""
ADAPTER_LABEL=""
CONFIG_DIR=""
RULES_FILE=""
SETTINGS_FILE=""
SETTINGS_LOCATION=""
SUPPORTED_SUBDIRS=()
GLOBAL_CONFIG_DIR=""    # new in Phase 2
```

**Functions:**
- `check_dependencies()` — validates `jq` and `yq` are installed
- `discover_adapters()` — lists `*.sh` files in adapters/ directory
- `load_adapter(adapter_name)` — sources adapter file, validates contract (all required variables + `transform_settings` function)

### `lib/merge.sh`

Extracted from `install-project.sh` lines 238-490:

**Merge functions:**
- `merge_config_subdir(subdir_name, staging_dir, source_dir, sub_source_name)` — merges one config subdirectory (agents/, commands/, skills/, etc.) with collision handling
- `merge_root_md(staging_dir, source_file, sub_source_name)` — concatenates markdown files with source attribution headers; renames `RULES.md` → adapter-specific name
- `merge_root_structured(staging_dir, source_file, sub_source_name, format)` — deep-merges JSON/YAML files via `jq`/`yq`
- `merge_root_files(staging_dir, source_dir, sub_source_name)` — routes root files to appropriate merge function by extension

**Deploy functions:**
- `build_manifest(staging_dir)` — creates JSON array of all relative file paths in staging
- `transform_staging_settings(staging_dir)` — calls adapter's `transform_settings()`, deletes neutral `settings.yaml`, writes agent-specific output to correct location
- `deploy_staging(staging_dir, destination, layout)` — copies staged content to destination
  - `layout="project"` (default): deploys subdirs into `${destination}/${CONFIG_DIR}/`, root files to `${destination}/`
  - `layout="flat"`: deploys everything directly into `${destination}/`

**Backup/delete functions:**
- `backup_installed_files(destination, manifest_json)` — backs up files listed in manifest to `.agent-backups/<timestamp>/`
- `delete_installed_files(destination, manifest_json)` — surgically removes only files in manifest

## Changes to `install-project.sh`

Remove all extracted functions. Add at the top (after `SCRIPT_DIR`):
```bash
source "${SCRIPT_DIR}/lib/adapters.sh"
source "${SCRIPT_DIR}/lib/merge.sh"
```

Keep project-specific code:
- Registry functions (`registry_init`, `registry_find_entry`, `registry_add_entry`, `registry_update_entry`)
- Discovery functions (`discover_project_types`, `discover_sub_sources`)
- `do_install()` and `do_update()` orchestration
- Argument parsing and main entry point

## `deploy_staging` Layout Parameter

The existing `deploy_staging()` deploys into `${CONFIG_DIR}/` subdir (project behavior). Add a `layout` parameter:

```bash
deploy_staging() {
    local staging_dir="$1"
    local destination="$2"
    local layout="${3:-project}"   # "project" or "flat"

    if [[ "$layout" == "project" ]]; then
        # Existing behavior: copy CONFIG_DIR/ subdir, then root files
        cp -rL "${staging_dir}/${CONFIG_DIR}" "${destination}/"
        # ... root files ...
    elif [[ "$layout" == "flat" ]]; then
        # New: copy all staging contents directly to destination
        # Used by global installer where destination IS the config dir
        for item in "${staging_dir}"/*; do
            [[ -e "$item" ]] || continue
            local name
            name="$(basename "$item")"
            if [[ -d "$item" ]]; then
                cp -rL "$item" "${destination}/${name}"
            else
                cp -L "$item" "${destination}/${name}"
            fi
        done
    fi
    # Clean up empty directories
    find "$destination" -type d -empty -delete 2>/dev/null || true
}
```

For Phase 1, `install-project.sh` always calls `deploy_staging "$staging" "$dest"` (defaults to "project"). No behavioral change.

## Source Path Resolution

Both lib files need `SCRIPT_DIR` to locate adapters/. Since `SCRIPT_DIR` is set by the calling script, the lib files should NOT redefine it. They assume it's already set by the caller.

Similarly, `ADAPTERS_DIR` should be set by the lib based on `SCRIPT_DIR`:
```bash
# lib/adapters.sh
ADAPTERS_DIR="${SCRIPT_DIR}/adapters"
```

## Execution Order

1. Create `lib/` directory
2. Write `lib/adapters.sh` (extract from install-project.sh)
3. Write `lib/merge.sh` (extract from install-project.sh)
4. Edit `install-project.sh` to source lib/ and remove extracted functions
5. Run `test-install-project.sh` — all 103 tests must pass
6. If tests fail, debug and fix (the refactor should be purely structural)
