# Phase 4: Rewrite `install-global.sh` with Adapter Support

**Risk:** Medium — new code, but isolated from project installer
**Verification:** `bash test-install-global.sh` passes all test groups

## Goal

Rewrite the global installer to use the shared adapter system, neutral source format, and manifest-based tracking.

## New CLI Interface

```
Usage: install-global.sh [OPTIONS]

Install global AI agent configuration files.

Options:
  --agent NAME   Install for a specific agent (e.g., opencode, claude-code)
  --target DIR   Install to DIR instead of the agent's default location
  --update       Update an existing installation using its manifest
  --dry-run      Print what would be done without making changes
  --help         Show this help message
```

If `--agent` is omitted, the script presents an interactive menu of available adapters (same pattern as the project installer).

## Script Flow

```
1.  Source lib/adapters.sh and lib/merge.sh
2.  Parse arguments
3.  check_dependencies()

4.  If --update:
      → do_update()
    Else:
      → do_install()
```

### `do_install()` Flow

```
 1. Select adapter (--agent flag or interactive menu)
 2. load_adapter()
 3. Resolve destination: --target override OR GLOBAL_CONFIG_DIR from adapter
 4. Check for existing manifest at destination (warn if re-installing)
 5. Create destination directory

 6. Create staging directory (with trap for cleanup)
 7. Merge .agent/ subdirs into staging:
    - For each subdir in SUPPORTED_SUBDIRS:
      - merge_config_subdir(subdir, staging, global/.agent, "global")
    - Note: single source, so no multi-source merge loop
 8. Merge root files:
    - merge_root_files(staging, global/, "global")
    - This handles RULES.md → adapter-specific name
    - This handles settings.yaml → deep merge
 9. transform_staging_settings(staging)
    - Converts settings.yaml to agent-specific format
    - Places output at correct location per adapter

10. Handle credential template:
    - Look for global/credentials/${ADAPTER_NAME}_example.json
    - If found AND no settings file exists at destination:
      - Copy template to destination as the settings file
    - If settings file already exists: skip (preserve user's API keys)

11. build_manifest(staging)
12. deploy_staging(staging, destination, "flat")
    - Flat layout: subdirs go directly into destination
    - No CONFIG_DIR nesting (destination IS the config dir)
13. Write manifest to ${destination}/.agent-manifest.json
14. Print summary
```

### `do_update()` Flow

```
 1. Scan known global config locations by loading each adapter:
    - For each adapter: check if ${GLOBAL_CONFIG_DIR}/.agent-manifest.json exists
    - Collect list of installations to update
 2. For each installation:
    a. Load the adapter recorded in the manifest
    b. Validate destination still exists
    c. backup_installed_files(destination, old_manifest)
    d. Stage new content (same as install steps 6-9)
    e. build_manifest(staging)
    f. delete_installed_files(destination, old_manifest)
    g. deploy_staging(staging, destination, "flat")
    h. Update .agent-manifest.json with new manifest + timestamp
 3. Print summary (updated / failed count)
```

## Manifest File Format

Written to `${destination}/.agent-manifest.json`:

```json
{
  "adapter": "opencode",
  "installed_at": "2026-03-22T10-15-30",
  "updated_at": "2026-03-22T10-15-30",
  "manifest": [
    "AGENTS.md",
    "agents/testing.md",
    "agents/thinking-partener.md",
    "commands/chat-summary.md",
    "opencode.json",
    "prompts/augster-system.md",
    "skills/gog/SKILL.md"
  ]
}
```

The manifest does NOT include:
- `.agent-manifest.json` itself
- `.backups/` directory
- Credential files that were skipped (not deployed by us)

## Key Design Decisions

### Flat Deployment

For project installs, content deploys as:
```
project-root/
  .opencode/agents/...    ← CONFIG_DIR nesting
  AGENTS.md               ← root level
  opencode.json           ← root level
```

For global installs, the destination IS the config directory:
```
~/.config/opencode/
  agents/...              ← directly in destination
  AGENTS.md               ← directly in destination
  opencode.json           ← directly in destination
```

The `deploy_staging(staging, dest, "flat")` parameter handles this difference.

### No CONFIG_DIR in Staging

For global installs, the staging directory should NOT create a `${CONFIG_DIR}/` subdirectory inside staging. The merge functions place subdirs into `${staging_dir}/${CONFIG_DIR}/agents/...` for project layout. For flat layout, we need subdirs at `${staging_dir}/agents/...`.

**Approach:** Add a parameter to the merge functions, OR restructure staging after merge, OR have `deploy_staging("flat")` look inside `${CONFIG_DIR}/` when deploying flat. The simplest: `deploy_staging("flat")` copies from `${staging_dir}/${CONFIG_DIR}/*` and `${staging_dir}/root-files` to destination. This way the merge functions stay unchanged.

Actually, the cleanest approach: for global installs, set `CONFIG_DIR` to `.` or use a temporary name, then deploy_staging("flat") handles it. But this would break transform_staging_settings which uses CONFIG_DIR.

**Recommended approach:** Keep merge functions unchanged (they put subdirs in `${staging_dir}/${CONFIG_DIR}/`). In `deploy_staging("flat")`:
1. Copy contents of `${staging_dir}/${CONFIG_DIR}/*` to destination (flattening the nesting)
2. Copy root-level files from staging to destination
3. This matches the current project behavior but without the extra directory level

### Credential Template Convention

The installer looks for `global/credentials/${ADAPTER_NAME}_example.json`. If no template exists for an adapter, credential deployment is silently skipped. This means:
- OpenCode: finds `opencode_example.json`, deploys it as `opencode.json` if missing
- Claude Code: no template exists, skip (Claude manages its own credentials)

### --dry-run Support

All operations check `$DRY_RUN` before making changes. Output prefixed with `(dry-run)` when active. This is carried over from the current script.

## Functions Unique to Global Installer

These live in `install-global.sh`, not in the shared lib:

- `do_install()` — global install orchestration
- `do_update()` — global update orchestration
- `write_manifest()` — writes .agent-manifest.json
- `read_manifest()` — reads existing manifest
- `deploy_credentials()` — handles credential template deployment
- `discover_global_installations()` — finds existing global installs by scanning adapter GLOBAL_CONFIG_DIRs for manifests
