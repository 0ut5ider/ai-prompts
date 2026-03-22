# Phase 5: Rewrite `test-install-global.sh`

**Risk:** Low — tests are additive
**Verification:** All test groups pass

## Goal

Rewrite the global test suite to cover multi-agent behavior, manifest tracking, update mode, and credential handling.

## Test Fixture

Create a temporary global source in the test's temp directory (similar to how `test-install-project.sh` creates a `zzz-testbed` project):

```
${TEST_DIR}/source/global/
  RULES.md               # Neutral rules content
  settings.yaml          # MCP config
  .agent/
    agents/
      test-agent-alpha.md
      test-agent-bravo.md
    commands/
      test-cmd.md
    prompts/
      test-prompt.md
    skills/
      test-skill/
        SKILL.md
  credentials/
    opencode_example.json   # Credential template
```

The test overrides `SCRIPT_DIR` and `SOURCE_DIR` to point at the fixture.

## Test Groups

### Group 1: CLI Arguments (~6 tests)

- `--help` prints usage and exits 0
- `--agent opencode` selects OpenCode adapter
- `--agent claude-code` selects Claude Code adapter
- `--agent nonexistent` exits with error
- `--update` with no existing installations exits cleanly
- Unknown flag exits with error

### Group 2: Clean Install — OpenCode (~12 tests)

- Creates destination directory at `--target`
- Deploys `AGENTS.md` (renamed from RULES.md) — not `RULES.md`
- Deploys `opencode.json` settings (transformed from settings.yaml)
- Deploys agents/ directory with both agent files
- Deploys commands/ directory
- Deploys prompts/ directory (OpenCode supports prompts)
- Deploys skills/ directory with skill contents
- File content matches expected transformations
- Settings file contains MCP config in OpenCode format (`mcp:` key, `$schema` added)
- Credential template deployed as opencode.json (when no existing config)
- `.agent-manifest.json` created at destination
- Manifest lists all deployed files

### Group 3: Clean Install — Claude Code (~10 tests)

- Deploys `CLAUDE.md` (renamed from RULES.md)
- Deploys `settings.json` (transformed from settings.yaml)
- Settings file contains MCP config in Claude Code format (`mcpServers:` key)
- Does NOT deploy prompts/ directory (Claude Code doesn't support prompts)
- Deploys agents/, commands/, skills/
- No credential template deployed (no claude-code_example.json exists)
- `.agent-manifest.json` created with correct adapter name
- Flat layout: no `.claude/` nesting inside destination

### Group 4: Re-install / Collision Handling (~8 tests)

- Existing files backed up to `.backups/<timestamp>/`
- Backup preserves directory structure
- New content overwrites old content
- Credential file preserved if it already exists (not overwritten)
- Credential file deployed if it does NOT exist
- User-added custom files NOT deleted (not in manifest)
- `.agent-manifest.json` updated with new timestamp
- Backup count reported in summary

### Group 5: Dry-Run Mode (~6 tests)

- No files created at destination
- No backup directory created
- Output contains "(dry-run)" prefixes
- Summary shows what would be installed
- Exit code 0

### Group 6: Manifest Tracking (~6 tests)

- `.agent-manifest.json` contains correct adapter name
- `.agent-manifest.json` contains installed_at timestamp
- `.agent-manifest.json` manifest array matches deployed files
- Manifest does NOT include `.agent-manifest.json` itself
- Manifest does NOT include `.backups/` entries
- Manifest does NOT include credential files that were skipped

### Group 7: Update Mode (~10 tests)

- Discovers existing installation via manifest
- Backs up old files before update
- Surgically deletes old manifest files
- Deploys new content
- New files from source appear at destination
- Removed files from source disappear from destination
- Removed files preserved in backup
- User-added custom files survive update
- `.agent-manifest.json` updated with new manifest and updated_at
- Multiple agents can be updated in one run

### Group 8: Edge Cases (~6 tests)

- Missing source directory handled gracefully
- Empty subdirectories cleaned up
- Symlinks in source followed correctly
- Paths with spaces work correctly
- Missing adapter in manifest handled with error message
- Destination directory auto-created if missing

### Group 9: Idempotency (~3 tests)

- Running install twice produces same result
- Second run creates backup of first run's files
- File content identical after idempotent install

## Test Helper Reuse

The test helpers (`pass`, `fail`, `assert_eq`, `assert_contains`, `assert_not_contains`) from the current test suite should be reused. Consider extracting them to `lib/test-helpers.sh` if they're identical to the project test helpers. Otherwise, keep them inline (lower priority optimization).

## Approximate Test Count

~67 tests across 9 groups (current suite has 109, but many were for OpenCode-specific behaviors that simplify with the adapter system).
