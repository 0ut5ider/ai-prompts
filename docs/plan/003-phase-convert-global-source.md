# Phase 3: Convert Global Source to Neutral Format

**Risk:** Medium — content moves, must preserve file integrity
**Verification:** File checksums match before/after move; content unchanged

## Goal

Restructure the global source from OpenCode-specific format to the same neutral `.agent/` format used by project sources.

## Current Structure

```
global/
  opencode/
    AGENTS.md                      # OpenCode-specific rules file
    opencode.json                  # User's real config (has API keys — gitignored or should be)
    opencode_example.json          # Template config (no real keys)
    .gitignore
    .private-journal/              # Runtime artifact
    agents/
      testing.md
      thinking-partener.md
    commands/
      chat-summary.md
      google-alerts-digest.md
      migrate-plans.md
    prompts/
      augster-system.md
      coding.md
    skills/
      gog/SKILL.md
      session-history/{SKILL.md, README.md, scripts/oc-history.sh}
      writing-clearly-and-concisely/{SKILL.md, elements-of-style.md}
```

## Target Structure

```
global/
  RULES.md                         # Renamed from AGENTS.md (neutral name)
  settings.yaml                    # New: MCP config in neutral format
  .gitignore                       # Updated
  .agent/
    agents/
      testing.md
      thinking-partener.md
    commands/
      chat-summary.md
      google-alerts-digest.md
      migrate-plans.md
    prompts/
      augster-system.md
      coding.md
    skills/
      gog/SKILL.md
      session-history/{SKILL.md, README.md, scripts/oc-history.sh}
      writing-clearly-and-concisely/{SKILL.md, elements-of-style.md}
  credentials/
    opencode_example.json          # Provider/credential template (OpenCode-specific)
```

## File Moves

| From | To | Notes |
|------|----|-------|
| `global/opencode/AGENTS.md` | `global/RULES.md` | Rename to neutral |
| `global/opencode/agents/` | `global/.agent/agents/` | Move into neutral config dir |
| `global/opencode/commands/` | `global/.agent/commands/` | Move into neutral config dir |
| `global/opencode/prompts/` | `global/.agent/prompts/` | Move into neutral config dir |
| `global/opencode/skills/` | `global/.agent/skills/` | Move into neutral config dir |
| `global/opencode/opencode_example.json` | `global/credentials/opencode_example.json` | Credential template stays agent-specific |
| `global/opencode/opencode.json` | **Delete from repo** | Contains real API keys, should not be in source |
| `global/opencode/.private-journal/` | **Delete from repo** | Runtime artifact, not source content |
| `global/opencode/.gitignore` | `global/.gitignore` | Update paths |

## New File: `global/settings.yaml`

Extract MCP config from `opencode_example.json` into neutral format:

```yaml
# Global MCP server configuration
# Shared across all agents — transformed per adapter at install time
mcp:
  context7:
    type: remote
    url: https://mcp.context7.com/mcp
  private-journal:
    type: local
    command: ["npx", "-y", "github:obra/private-journal-mcp"]
    enabled: true
```

This contains only the MCP section. Provider/credential config stays in `credentials/opencode_example.json` because:
- Provider config is OpenCode-specific (Claude Code doesn't use provider blocks)
- API keys must never be in the neutral format
- The credential template is deployed separately with "skip if exists" semantics

## Credential Handling Design

The current `opencode_example.json` serves as a credential template — it has the provider structure with empty API key fields. In the new system:

- `global/credentials/opencode_example.json` — OpenCode credential template
- Future: `global/credentials/claude-code_example.json` if Claude Code needs one
- The global installer deploys the credential template **only if no settings file exists** at the destination (same "skip if exists" behavior as today)
- The adapter contract could optionally declare a `CREDENTIALS_TEMPLATE` path, or the global installer can use the convention `credentials/${ADAPTER_NAME}_example.json`

## Execution Order

1. Create `global/.agent/` directory
2. Move subdirs (agents, commands, prompts, skills) into `global/.agent/`
3. Rename `AGENTS.md` → `RULES.md` at `global/` root
4. Create `global/settings.yaml` with MCP config
5. Create `global/credentials/` and move `opencode_example.json` there
6. Remove `global/opencode/opencode.json` (real credentials — should not be in repo)
7. Remove `global/opencode/.private-journal/`
8. Update `global/.gitignore`
9. Remove now-empty `global/opencode/` directory
10. Verify all files moved correctly (checksums)
