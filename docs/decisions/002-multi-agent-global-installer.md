# Decision 002: Multi-Agent Global Installer Architecture

**Date:** 2026-03-22
**Status:** Implemented
**Branch:** `feature/multi-agent-global-installer`

## Context

The project installer was rewritten with multi-agent adapter support (decision 001). The global installer (`install-global.sh`) remained hardcoded to OpenCode, deploying to `~/.config/opencode/` with no adapter system, no neutral source format, and no update tracking.

## Decision: Keep Separate Scripts with Shared Library

Extract ~250 lines of shared adapter/merge/deploy functions into `lib/adapters.sh` and `lib/merge.sh`. Both `install-project.sh` and `install-global.sh` source the shared library. Each script owns its own orchestration flow.

## Alternatives Considered

### Option A: Shared library + separate scripts (chosen)
Shared utility code, independent orchestration. Adding a new installer = one new script that sources `lib/`.

### Option B: Consolidate into single script with --global/--project modes
Rejected because the orchestration flows are fundamentally different (interactive multi-source merge with registry vs. non-interactive single-source with fixed destination). A combined script would be harder to understand and test.

### Option C: Keep fully separate with duplicated code
Rejected because ~250 lines of adapter loading, merge logic, and deploy functions would be duplicated. Every bug fix would need to be applied twice.

## Key Design Decisions

### Flat deployment for global installs
The global config directory IS the destination. No `CONFIG_DIR` nesting (unlike project installs where `.opencode/` lives inside the project root).

### `GLOBAL_CONFIG_DIR` in adapter contract
Each adapter declares where its global config lives (OpenCode: `~/.config/opencode`, Claude Code: `~/.claude`). Keeps agent-specific knowledge in the adapter, not hardcoded in the installer.

### Per-destination manifest (`.agent-manifest.json`)
Lightweight alternative to the project installer's centralized registry. Each global config dir tracks its own state. Enables surgical updates without a registry file.

### Credential templates outside neutral format
Provider/API key config is inherently agent-specific. Stored as `credentials/${ADAPTER_NAME}_example.json`. Deployed only if no settings file exists (preserves existing API keys).

### `prompts/` via SUPPORTED_SUBDIRS
OpenCode supports `prompts/`, Claude Code doesn't. Handled by the existing adapter mechanism rather than special-case code.

### Neutral global source format
`global/` uses the same `.agent/` + `RULES.md` + `settings.yaml` format as project sources. Single source of truth; adapters handle the transformation.

## Known Limitations / Future Work

1. **No multi-source merge for global** — single source only, unlike project installer's sub-source merge.
2. **No `--dry-run` for project installer yet** — easy to add via shared lib.
3. **Credential template uses filename convention** — `${ADAPTER_NAME}_example.json`, not an adapter contract field.
4. **Test helpers duplicated between test suites** — could extract to `lib/test-helpers.sh`.

## Files Changed

- `lib/adapters.sh` — new (extracted from install-project.sh)
- `lib/merge.sh` — new (extracted from install-project.sh)
- `install-project.sh` — refactored to source lib/
- `install-global.sh` — rewritten with adapter support
- `adapters/opencode.sh` — added GLOBAL_CONFIG_DIR, prompts to SUPPORTED_SUBDIRS
- `adapters/claude-code.sh` — added GLOBAL_CONFIG_DIR
- `global/` — restructured from opencode-specific to neutral format
- `test-install-global.sh` — rewritten for multi-agent testing
