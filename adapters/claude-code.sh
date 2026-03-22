#!/usr/bin/env bash
# ABOUTME: Adapter for Claude Code agent — maps neutral .agent/ format to .claude/ structure.
# ABOUTME: Provides config dir name, rules file name, supported subdirs, and settings transform.

# ─── Identity ────────────────────────────────────────────────────────────────
ADAPTER_NAME="claude-code"
ADAPTER_LABEL="Claude Code"

# ─── Directory & file mappings ───────────────────────────────────────────────
# Neutral .agent/ → agent-specific directory name
CONFIG_DIR=".claude"

# Neutral RULES.md → agent-specific rules file name
RULES_FILE="CLAUDE.md"

# Settings file name at the destination
SETTINGS_FILE="settings.json"

# Where the settings file is placed: "root" (project root) or "config_dir" (inside CONFIG_DIR)
SETTINGS_LOCATION="config_dir"

# Global config directory for this agent (used by global installs)
GLOBAL_CONFIG_DIR="${HOME}/.claude"

# Subdirectories inside the config dir that this agent supports
SUPPORTED_SUBDIRS=("agents" "commands" "skills" "rules")

# ─── Settings transform ─────────────────────────────────────────────────────
# Transforms neutral settings.yaml → .claude/settings.json
# Input: path to neutral settings.yaml
# Output: JSON string to stdout
transform_settings() {
    local settings_file="$1"

    if [[ ! -f "$settings_file" ]]; then
        echo '{}'
        return 0
    fi

    # Single jq call: build the final object from all extracted sections
    local permissions mcp_json env_json overrides
    permissions="$(yq -o=json '.permissions // {}' "$settings_file" 2>/dev/null)"
    mcp_json="$(yq -o=json '.mcp // {}' "$settings_file" 2>/dev/null)"
    env_json="$(yq -o=json '.env // {}' "$settings_file" 2>/dev/null)"
    overrides="$(yq -o=json '.agents."claude-code" // {}' "$settings_file" 2>/dev/null)"

    jq -n \
        --argjson permissions "${permissions:-"{}"}" \
        --argjson mcp "${mcp_json:-"{}"}" \
        --argjson env "${env_json:-"{}"}" \
        --argjson ov "${overrides:-"{}"}" \
        '(if $permissions != {} then {permissions: $permissions} else {} end)
         + (if $mcp != {} then {mcpServers: $mcp} else {} end)
         + (if $env != {} then {env: $env} else {} end)
         | . * $ov'
}
