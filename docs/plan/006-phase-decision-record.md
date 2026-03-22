# Phase 6: Decision Record

**Risk:** None — documentation only

## Goal

Document the architectural decisions made for the multi-agent global installer, following the same format as `docs/decisions/001-multi-agent-installer.md`.

## File

Create `docs/decisions/002-multi-agent-global-installer.md` covering:

1. **Context** — Why the global installer needs multi-agent support
2. **Decision** — Keep separate scripts with shared `lib/` library
3. **Alternatives considered:**
   - Consolidate into single script with --global/--project modes (rejected: different orchestration flows)
   - Keep fully separate with duplicated code (rejected: violates DRY for ~250 lines)
   - Shared library with separate scripts (chosen)
4. **Key design decisions:**
   - Flat deployment for global (destination IS the config dir)
   - Per-destination manifest instead of centralized registry
   - Credential templates as agent-specific files outside neutral format
   - `prompts/` handled via SUPPORTED_SUBDIRS (no special cases)
   - `GLOBAL_CONFIG_DIR` in adapter contract
5. **Known limitations / future work:**
   - No multi-source merge for global (single source only)
   - No `--dry-run` for project installer yet
   - Credential template convention is simple filename matching (not in adapter contract)
6. **Files changed** — summary of all new, modified, restructured files
