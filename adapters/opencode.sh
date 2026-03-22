#!/usr/bin/env bash
# ABOUTME: Adapter for OpenCode agent — maps neutral .agent/ format to .opencode/ structure.
# ABOUTME: Provides config dir name, rules file name, supported subdirs, and settings transform.

# ─── Identity ────────────────────────────────────────────────────────────────
ADAPTER_NAME="opencode"
ADAPTER_LABEL="OpenCode"

# ─── Directory & file mappings ───────────────────────────────────────────────
# Neutral .agent/ → agent-specific directory name
CONFIG_DIR=".opencode"

# Neutral RULES.md → agent-specific rules file name
RULES_FILE="AGENTS.md"

# Settings file name at the destination
SETTINGS_FILE="opencode.json"

# Where the settings file is placed: "root" (project root) or "config_dir" (inside CONFIG_DIR)
SETTINGS_LOCATION="root"

# Global config directory for this agent (used by global installs)
GLOBAL_CONFIG_DIR="${HOME}/.config/opencode"

# Subdirectories inside the config dir that this agent supports
SUPPORTED_SUBDIRS=("agents" "commands" "prompts" "skills")

# ─── Settings transform ─────────────────────────────────────────────────────
# Transforms neutral settings.yaml → opencode.json
# Input: path to neutral settings.yaml
# Output: JSON string to stdout
transform_settings() {
    local settings_file="$1"

    if [[ ! -f "$settings_file" ]]; then
        echo '{}'
        return 0
    fi

    # Single jq call: build the final object from all extracted sections
    local mcp_json overrides
    mcp_json="$(yq -o=json '.mcp // {}' "$settings_file" 2>/dev/null)"
    overrides="$(yq -o=json '.agents.opencode // {}' "$settings_file" 2>/dev/null)"

    jq -n \
        --argjson mcp "${mcp_json:-"{}"}" \
        --argjson ov "${overrides:-"{}"}" \
        '{"$schema": "https://opencode.ai/config.json"}
         + (if $mcp != {} then {mcp: $mcp} else {} end)
         | . * $ov'
}
