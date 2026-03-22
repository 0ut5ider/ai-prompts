# Multi-Agent Global Installer — Plan Overview

**Date:** 2026-03-22
**Branch:** `feature/multi-agent-global-installer`
**Predecessor:** Decision 001 — Multi-Agent Project Installer

## Problem

The project installer (`install-project.sh`) now supports multiple AI agents via an adapter system. The global installer (`install-global.sh`) is still hardcoded to OpenCode — it deploys OpenCode-specific content to `~/.config/opencode/` with no adapter support, no neutral source format, and no update tracking.

## Architecture Decision: Keep Separate Scripts, Extract Shared Library

Both scripts share ~250 lines of adapter/merge/deploy logic, but differ in orchestration:

| Aspect | Global | Project |
|--------|--------|---------|
| Destination | Fixed per agent (`~/.config/opencode/`, `~/.claude/`) | User-specified per project |
| Source | Single directory (`global/`) | Multi-source merge (N sub-sources) |
| Interaction | Non-interactive (flags only) | Interactive menus |
| Tracking | Per-destination manifest file | Centralized registry |
| Credentials | Must preserve existing API keys | No credential concern |
| Dry-run | Yes | No |

**Decision:** Extract shared functions into `lib/adapters.sh` and `lib/merge.sh`. Both scripts source the library. Each script owns its own orchestration flow.

**Why not consolidate into one script:** The orchestration flows are different enough that a combined `--global`/`--project` mode would add complexity without reducing it. The shared code is in utility functions, not control flow.

## Phases

| # | Phase | Risk | Key Verification |
|---|-------|------|-----------------|
| 1 | [Extract shared library](001-phase-extract-shared-lib.md) | **High** — touches working code | 103 project tests pass |
| 2 | [Update adapter contract](002-phase-update-adapter-contract.md) | Low | Adapter validation tests pass |
| 3 | [Convert global source to neutral format](003-phase-convert-global-source.md) | Medium — content move | File checksums match |
| 4 | [Rewrite global installer](004-phase-rewrite-global-installer.md) | Medium — new code | New test suite passes |
| 5 | [Rewrite global test suite](005-phase-rewrite-test-suite.md) | Low | All test groups pass |
| 6 | [Decision record](006-phase-decision-record.md) | None | Documentation only |

## Critical Files

| File | Action |
|------|--------|
| `lib/adapters.sh` | **New** — extracted from install-project.sh |
| `lib/merge.sh` | **New** — extracted from install-project.sh |
| `install-project.sh` | **Refactor** — source lib/ instead of inlining |
| `install-global.sh` | **Rewrite** — adapter support, neutral format |
| `adapters/opencode.sh` | **Update** — add GLOBAL_CONFIG_DIR, prompts |
| `adapters/claude-code.sh` | **Update** — add GLOBAL_CONFIG_DIR |
| `global/` | **Restructure** — neutral format |
| `test-install-global.sh` | **Rewrite** — multi-agent test suite |
| `test-install-project.sh` | **Verify** — must pass unchanged after Phase 1 |

## Open Questions

1. **Multi-source for global?** (e.g., `global/base/` + `global/personal/`) — deferred, add later if needed.
2. **Dry-run for project installer?** — out of scope, easy to add once shared lib exists.
