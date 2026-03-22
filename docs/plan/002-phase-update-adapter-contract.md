# Phase 2: Update Adapter Contract

**Risk:** Low
**Verification:** `bash test-install-project.sh` — all tests pass with updated adapters

## Goal

Extend the adapter contract with fields needed for global installation.

## Changes

### `adapters/opencode.sh`

Add after existing fields:
```bash
# Where global configuration lives for this agent
GLOBAL_CONFIG_DIR="${HOME}/.config/opencode"
```

Update SUPPORTED_SUBDIRS to include `prompts` (needed for global install — the global source has a `prompts/` directory):
```bash
SUPPORTED_SUBDIRS=("agents" "commands" "prompts" "skills")
```

Adding `prompts` is safe for project installs — if a project source has no `prompts/` directory in `.agent/`, the merge function simply skips it (no-op).

### `adapters/claude-code.sh`

Add after existing fields:
```bash
# Where global configuration lives for this agent
GLOBAL_CONFIG_DIR="${HOME}/.claude"
```

No change to SUPPORTED_SUBDIRS — Claude Code doesn't use `prompts/`.

### `lib/adapters.sh`

Update `load_adapter()` validation to check the new required field:
```bash
# Add to the validation block:
if [[ -z "${GLOBAL_CONFIG_DIR:-}" ]]; then
    echo "Error: adapter '${adapter_name}' does not set GLOBAL_CONFIG_DIR"
    exit 1
fi
```

Also add `GLOBAL_CONFIG_DIR=""` to the state variable reset block at the top of `load_adapter()`.

## Impact on Project Installer

None. The project installer doesn't use `GLOBAL_CONFIG_DIR` — it's only read by the global installer. The field is validated at adapter load time for contract completeness, but unused by project install flows.

## Impact on Existing Tests

The `test-install-project.sh` adapter validation tests will continue to pass because:
- The adapters now define `GLOBAL_CONFIG_DIR` (satisfies the new validation)
- Adding `prompts` to OpenCode's SUPPORTED_SUBDIRS doesn't affect project installs (no prompts/ in test fixtures)
