#!/usr/bin/env bash
# ABOUTME: Automated test suite for install-project.sh.
# ABOUTME: Creates temporary fixtures, runs all test scenarios, and reports pass/fail.
set -uo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/install-project.sh"
PROJECTS_DIR="${SCRIPT_DIR}/projects"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
REGISTRY_FILE="${PROJECTS_DIR}/.install-registry-${HOSTNAME_SHORT}.json"

TEST_DIR="$(mktemp -d /tmp/test-installer-XXXXXX)"
DEST_A="${TEST_DIR}/dest-A"
DEST_B="${TEST_DIR}/dest-B"
DEST_C="${TEST_DIR}/dest-C"
FIXTURE_DIR="${PROJECTS_DIR}/zzz-testbed"

PASSED=0
FAILED=0
ERRORS=()

# Cached menu numbers (populated by cache_menu_numbers after fixtures exist)
MENU_NUM_TESTBED=""
ADAPTER_NUM_OPENCODE=""
ADAPTER_NUM_CLAUDE_CODE=""

# ─── Test helpers ─────────────────────────────────────────────────────────────
pass() {
    ((PASSED++)) || true
    echo "  [PASS] $1"
}

fail() {
    ((FAILED++)) || true
    ERRORS+=("$1: $2")
    echo "  [FAIL] $1"
    echo "         $2"
}

assert_eq() {
    local description="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$description"
    else
        fail "$description" "expected='${expected}' actual='${actual}'"
    fi
}

assert_contains() {
    local description="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        pass "$description"
    else
        fail "$description" "output does not contain '${needle}'"
    fi
}

assert_not_contains() {
    local description="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        fail "$description" "output unexpectedly contains '${needle}'"
    else
        pass "$description"
    fi
}

assert_file_exists() {
    local description="$1" filepath="$2"
    if [[ -f "$filepath" ]]; then
        pass "$description"
    else
        fail "$description" "file not found: ${filepath}"
    fi
}

assert_file_not_exists() {
    local description="$1" filepath="$2"
    if [[ -f "$filepath" ]]; then
        fail "$description" "file should not exist: ${filepath}"
    else
        pass "$description"
    fi
}

assert_dir_exists() {
    local description="$1" dirpath="$2"
    if [[ -d "$dirpath" ]]; then
        pass "$description"
    else
        fail "$description" "directory not found: ${dirpath}"
    fi
}

assert_dir_not_exists() {
    local description="$1" dirpath="$2"
    if [[ -d "$dirpath" ]]; then
        fail "$description" "directory should not exist: ${dirpath}"
    else
        pass "$description"
    fi
}

assert_exit_code() {
    local description="$1" expected="$2" actual="$3"
    if [[ "$expected" -eq "$actual" ]]; then
        pass "$description"
    else
        fail "$description" "expected exit code ${expected}, got ${actual}"
    fi
}

assert_file_contains() {
    local description="$1" filepath="$2" needle="$3"
    if [[ -f "$filepath" ]] && grep -qF "$needle" "$filepath"; then
        pass "$description"
    else
        fail "$description" "file '${filepath}' does not contain '${needle}'"
    fi
}

assert_file_not_contains() {
    local description="$1" filepath="$2" needle="$3"
    if [[ -f "$filepath" ]] && grep -qF "$needle" "$filepath"; then
        fail "$description" "file '${filepath}' unexpectedly contains '${needle}'"
    else
        pass "$description"
    fi
}

assert_json_value() {
    local description="$1" filepath="$2" jq_expr="$3" expected="$4"
    local actual
    actual="$(jq -r "$jq_expr" "$filepath" 2>/dev/null)"
    assert_eq "$description" "$expected" "$actual"
}

assert_file_count() {
    local description="$1" dirpath="$2" expected="$3"
    local actual
    actual="$(find "$dirpath" -type f 2>/dev/null | wc -l | tr -d ' ')"
    assert_eq "$description" "$expected" "$actual"
}

assert_dir_count() {
    local description="$1" dirpath="$2" expected="$3"
    local actual
    actual="$(find "$dirpath" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    assert_eq "$description" "$expected" "$actual"
}

# Find the menu number for a given project type name
# Usage: menu_number=$(find_menu_number "zzz-testbed")
find_menu_number() {
    local target="$1"
    local output
    output="$(echo "q" | "$INSTALLER" 2>&1 || true)"
    echo "$output" | grep -oP '\d+(?=\) '"$target"')' | head -1
}

# Find the menu number for a given adapter name
# Adapter menu appears after project type selection, so we pipe project type first
find_adapter_number() {
    local target="$1"
    local project_menu_num="$2"
    local output
    output="$(echo -e "${project_menu_num}\nq" | "$INSTALLER" 2>&1 || true)"
    echo "$output" | grep -oP '\d+(?=\) .* \('"$target"'\))' | head -1
}

cache_menu_numbers() {
    # Single installer run: pipe project selection + quit to capture both menus
    local output
    output="$(echo "q" | "$INSTALLER" 2>&1 || true)"
    MENU_NUM_TESTBED="$(echo "$output" | grep -oP '\d+(?=\) zzz-testbed)' | head -1)"

    # Second run: select project type, capture adapter menu
    local adapter_output
    adapter_output="$(echo -e "${MENU_NUM_TESTBED}\nq" | "$INSTALLER" 2>&1 || true)"
    ADAPTER_NUM_OPENCODE="$(echo "$adapter_output" | grep -oP '\d+(?=\) .* \(opencode\))' | head -1)"
    ADAPTER_NUM_CLAUDE_CODE="$(echo "$adapter_output" | grep -oP '\d+(?=\) .* \(claude-code\))' | head -1)"
}

clean_registry() {
    rm -f "$REGISTRY_FILE"
}

# ─── Fixture setup ────────────────────────────────────────────────────────────
setup_fixtures() {
    echo "Setting up test fixtures..."

    rm -rf "$FIXTURE_DIR"
    clean_registry
    mkdir -p "$DEST_A" "$DEST_B" "$DEST_C"

    # ── Sub-source: alpha (processed first alphabetically) ────────────────
    local ALPHA="${FIXTURE_DIR}/alpha"

    mkdir -p "$ALPHA/.agent/agents"
    echo -e "# Alpha-Only Agent\nThis agent exists only in alpha." \
        > "$ALPHA/.agent/agents/alpha-only-agent.md"
    echo -e "# Shared Agent (ALPHA version)\nIf you see this, bravo did NOT overwrite (BUG)." \
        > "$ALPHA/.agent/agents/shared-agent.md"

    mkdir -p "$ALPHA/.agent/commands"
    echo -e "# Alpha Command\nUnique to alpha." \
        > "$ALPHA/.agent/commands/alpha-cmd.md"
    echo -e "# Shared Command (ALPHA version)\nShould be overwritten by bravo." \
        > "$ALPHA/.agent/commands/shared-cmd.md"

    mkdir -p "$ALPHA/.agent/skills/alpha-skill"
    echo -e "---\nname: alpha-skill\n---\n# Alpha Skill" \
        > "$ALPHA/.agent/skills/alpha-skill/SKILL.md"

    mkdir -p "$ALPHA/.agent/skills/shared-skill"
    echo -e "---\nname: shared-skill\n---\n# Shared Skill (ALPHA version)" \
        > "$ALPHA/.agent/skills/shared-skill/SKILL.md"
    echo -e "#!/bin/bash\necho 'alpha helper'" \
        > "$ALPHA/.agent/skills/shared-skill/helper.sh"

    # Neutral settings YAML
    cat > "$ALPHA/settings.yaml" << 'ENDYAML'
# Alpha settings
mcp:
  context7:
    type: remote
    url: https://mcp.context7.com/mcp
    enabled: true
  alpha-server:
    type: local
    command: alpha-mcp
agents:
  opencode:
    alpha_key: from_alpha
  claude-code:
    alwaysThinkingEnabled: true
ENDYAML

    cat > "$ALPHA/RULES.md" << 'ENDMD'
# Alpha Rules
- Rule A1
- Rule A2
ENDMD

    echo -e "source: alpha\nkey: alpha_value" > "$ALPHA/config.txt"
    echo '{ this is not valid json' > "$ALPHA/broken.json"

    # ── Sub-source: bravo (processed second, wins conflicts) ──────────────
    local BRAVO="${FIXTURE_DIR}/bravo"

    mkdir -p "$BRAVO/.agent/agents"
    echo -e "# Bravo-Only Agent\nThis agent exists only in bravo." \
        > "$BRAVO/.agent/agents/bravo-only-agent.md"
    echo -e "# Shared Agent (BRAVO version)\nYou should see this after install." \
        > "$BRAVO/.agent/agents/shared-agent.md"

    mkdir -p "$BRAVO/.agent/commands"
    echo -e "# Bravo Command\nUnique to bravo." \
        > "$BRAVO/.agent/commands/bravo-cmd.md"
    echo -e "# Shared Command (BRAVO version)\nYou should see this after install." \
        > "$BRAVO/.agent/commands/shared-cmd.md"

    mkdir -p "$BRAVO/.agent/skills/bravo-skill"
    echo -e "---\nname: bravo-skill\n---\n# Bravo Skill" \
        > "$BRAVO/.agent/skills/bravo-skill/SKILL.md"

    mkdir -p "$BRAVO/.agent/skills/shared-skill"
    echo -e "---\nname: shared-skill\n---\n# Shared Skill (BRAVO version)" \
        > "$BRAVO/.agent/skills/shared-skill/SKILL.md"
    echo -e "#!/bin/bash\necho 'bravo helper'" \
        > "$BRAVO/.agent/skills/shared-skill/bravo-helper.sh"

    # Bravo settings — deep-merged with alpha
    cat > "$BRAVO/settings.yaml" << 'ENDYAML'
# Bravo settings
mcp:
  bravo-server:
    type: local
    command: bravo-mcp
agents:
  opencode:
    bravo_key: from_bravo
ENDYAML

    cat > "$BRAVO/RULES.md" << 'ENDMD'
# Bravo Rules
- Rule B1
- Rule B2
ENDMD

    echo -e "source: bravo\nkey: bravo_value" > "$BRAVO/config.txt"

    echo "Fixtures created at ${FIXTURE_DIR}"
}

teardown_fixtures() {
    echo ""
    echo "Cleaning up..."
    rm -rf "$FIXTURE_DIR" "$TEST_DIR"
    clean_registry
}

# ─── Test Groups ──────────────────────────────────────────────────────────────

test_group_1_cli_arguments() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 1: CLI Arguments"
    echo "═══════════════════════════════════════════"

    # Test 1.1: --help
    local output rc
    output="$("$INSTALLER" --help 2>&1)" && rc=$? || rc=$?
    assert_contains "1.1 --help shows usage" "$output" "Usage:"
    assert_contains "1.1 --help shows modes" "$output" "--update"

    # Test 1.2: --update with no registry
    clean_registry
    output="$("$INSTALLER" --update 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.2 --update empty registry exits 0" 0 "$rc"
    assert_contains "1.2 --update says nothing to update" "$output" "No installations found"

    # Test 1.3: Unknown flag
    output="$("$INSTALLER" --bogus 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.3 --bogus exits 1" 1 "$rc"
    assert_contains "1.3 --bogus shows error" "$output" "Unknown option"

    # Test 1.4: --update --bogus
    output="$("$INSTALLER" --update --bogus 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.4 --update --bogus exits 1" 1 "$rc"
    assert_contains "1.4 --update --bogus identifies bad flag" "$output" "--bogus"
}

test_group_2_install_opencode() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 2: Install Flow (OpenCode adapter)"
    echo "═══════════════════════════════════════════"

    clean_registry

    # Test 2.1: Install testbed to dest-A with opencode adapter
    local output
    output="$(echo -e "${MENU_NUM_TESTBED}\n${ADAPTER_NUM_OPENCODE}\n${DEST_A}" | "$INSTALLER" 2>&1)"
    local rc=$?
    assert_exit_code "2.1 Install testbed to dest-A exits 0" 0 "$rc"
    assert_contains "2.1 Output shows sub-sources" "$output" "alpha"
    assert_contains "2.1 Output shows sub-sources" "$output" "bravo"

    # Test 2.2: Empty project types not in menu
    assert_not_contains "2.2 Writing not in menu (empty)" "$output" ") writing"

    # Test 2.3: Agent collision — bravo wins (files in .opencode/)
    assert_file_contains "2.3 shared-agent has BRAVO content" \
        "${DEST_A}/.opencode/agents/shared-agent.md" "BRAVO version"
    assert_file_not_contains "2.3 shared-agent has no ALPHA content" \
        "${DEST_A}/.opencode/agents/shared-agent.md" "ALPHA version"

    # Test 2.4: Command collision — bravo wins
    assert_file_contains "2.4 shared-cmd has BRAVO content" \
        "${DEST_A}/.opencode/commands/shared-cmd.md" "BRAVO version"
    assert_file_not_contains "2.4 shared-cmd has no ALPHA content" \
        "${DEST_A}/.opencode/commands/shared-cmd.md" "ALPHA version"

    # Test 2.5: Skill collision — bravo replaces entire directory
    assert_file_contains "2.5 shared-skill SKILL.md is BRAVO" \
        "${DEST_A}/.opencode/skills/shared-skill/SKILL.md" "BRAVO version"
    assert_file_not_exists "2.5 alpha's helper.sh is gone" \
        "${DEST_A}/.opencode/skills/shared-skill/helper.sh"
    assert_file_exists "2.5 bravo's bravo-helper.sh exists" \
        "${DEST_A}/.opencode/skills/shared-skill/bravo-helper.sh"

    # Test 2.6: Unique agents from both sources
    assert_file_exists "2.6 alpha-only-agent present" \
        "${DEST_A}/.opencode/agents/alpha-only-agent.md"
    assert_file_exists "2.6 bravo-only-agent present" \
        "${DEST_A}/.opencode/agents/bravo-only-agent.md"

    # Test 2.7: Unique commands from both sources
    assert_file_exists "2.7 alpha-cmd present" \
        "${DEST_A}/.opencode/commands/alpha-cmd.md"
    assert_file_exists "2.7 bravo-cmd present" \
        "${DEST_A}/.opencode/commands/bravo-cmd.md"

    # Test 2.8: Unique skills from both sources
    assert_dir_exists "2.8 alpha-skill dir present" \
        "${DEST_A}/.opencode/skills/alpha-skill"
    assert_dir_exists "2.8 bravo-skill dir present" \
        "${DEST_A}/.opencode/skills/bravo-skill"

    # Test 2.9: Settings transformed to opencode.json at root
    assert_file_exists "2.9 opencode.json created at root" \
        "${DEST_A}/opencode.json"
    assert_json_value "2.9 opencode.json has schema" \
        "${DEST_A}/opencode.json" '."$schema"' "https://opencode.ai/config.json"
    assert_json_value "2.9 MCP context7 preserved" \
        "${DEST_A}/opencode.json" ".mcp.context7.url" "https://mcp.context7.com/mcp"
    assert_json_value "2.9 MCP alpha-server preserved" \
        "${DEST_A}/opencode.json" '.mcp."alpha-server".command' "alpha-mcp"
    assert_json_value "2.9 MCP bravo-server deep-merged" \
        "${DEST_A}/opencode.json" '.mcp."bravo-server".command' "bravo-mcp"
    assert_json_value "2.9 opencode-specific alpha_key" \
        "${DEST_A}/opencode.json" ".alpha_key" "from_alpha"
    assert_json_value "2.9 opencode-specific bravo_key" \
        "${DEST_A}/opencode.json" ".bravo_key" "from_bravo"

    # Test 2.10: RULES.md → AGENTS.md concatenation
    assert_file_exists "2.10 AGENTS.md created (not RULES.md)" \
        "${DEST_A}/AGENTS.md"
    assert_file_not_exists "2.10 RULES.md not deployed" \
        "${DEST_A}/RULES.md"
    assert_file_contains "2.10 AGENTS.md has alpha content" \
        "${DEST_A}/AGENTS.md" "Rule A1"
    assert_file_contains "2.10 AGENTS.md has bravo content" \
        "${DEST_A}/AGENTS.md" "Rule B1"
    assert_file_contains "2.10 AGENTS.md has alpha source header" \
        "${DEST_A}/AGENTS.md" "Source: alpha"
    assert_file_contains "2.10 AGENTS.md has bravo source header" \
        "${DEST_A}/AGENTS.md" "Source: bravo"

    # Test 2.11: Unknown file type collision — bravo wins
    assert_file_contains "2.11 config.txt is bravo's version" \
        "${DEST_A}/config.txt" "source: bravo"
    assert_file_not_contains "2.11 config.txt has no alpha content" \
        "${DEST_A}/config.txt" "source: alpha"

    # Test 2.12: Invalid JSON skipped gracefully
    assert_file_not_exists "2.12 broken.json not deployed" \
        "${DEST_A}/broken.json"
    assert_contains "2.12 Error message about invalid JSON" "$output" "Invalid JSON"

    # Test 2.13: Conflict warnings emitted
    assert_contains "2.13 Conflict warning for shared-agent" "$output" "[CONFLICT]"

    # Test 2.14: Manifest accuracy — compare registry vs disk
    local manifest_count disk_count
    manifest_count="$(jq -r '.installs[0].manifest | length' "$REGISTRY_FILE")"
    disk_count="$(find "$DEST_A" -type f | wc -l | tr -d ' ')"
    assert_eq "2.14 Manifest count matches disk count" "$manifest_count" "$disk_count"

    # Test 2.15: Registry records adapter
    assert_json_value "2.15 Registry records adapter name" \
        "$REGISTRY_FILE" '.installs[0].adapter' "opencode"
}

test_group_3_install_claude_code() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 3: Install Flow (Claude Code adapter)"
    echo "═══════════════════════════════════════════"

    # Test 3.1: Install testbed to dest-B with claude-code adapter
    local output
    output="$(echo -e "${MENU_NUM_TESTBED}\n${ADAPTER_NUM_CLAUDE_CODE}\n${DEST_B}" | "$INSTALLER" 2>&1)"
    local rc=$?
    assert_exit_code "3.1 Install to dest-B with claude-code exits 0" 0 "$rc"

    # Test 3.2: Files deployed to .claude/ (not .opencode/)
    assert_dir_exists "3.2 .claude/ dir created" "${DEST_B}/.claude"
    assert_dir_not_exists "3.2 .opencode/ not created" "${DEST_B}/.opencode"
    assert_file_exists "3.2 agents in .claude/" \
        "${DEST_B}/.claude/agents/shared-agent.md"
    assert_file_exists "3.2 commands in .claude/" \
        "${DEST_B}/.claude/commands/shared-cmd.md"

    # Test 3.3: RULES.md → CLAUDE.md
    assert_file_exists "3.3 CLAUDE.md created" "${DEST_B}/CLAUDE.md"
    assert_file_not_exists "3.3 RULES.md not deployed" "${DEST_B}/RULES.md"
    assert_file_not_exists "3.3 AGENTS.md not created" "${DEST_B}/AGENTS.md"
    assert_file_contains "3.3 CLAUDE.md has alpha content" \
        "${DEST_B}/CLAUDE.md" "Rule A1"
    assert_file_contains "3.3 CLAUDE.md has bravo content" \
        "${DEST_B}/CLAUDE.md" "Rule B1"

    # Test 3.4: Settings transformed to .claude/settings.json
    assert_file_exists "3.4 settings.json in .claude/" \
        "${DEST_B}/.claude/settings.json"
    assert_file_not_exists "3.4 No opencode.json at root" \
        "${DEST_B}/opencode.json"
    assert_json_value "3.4 MCP servers under mcpServers" \
        "${DEST_B}/.claude/settings.json" ".mcpServers.context7.url" "https://mcp.context7.com/mcp"
    assert_json_value "3.4 claude-code override applied" \
        "${DEST_B}/.claude/settings.json" ".alwaysThinkingEnabled" "true"

    # Test 3.5: Registry records claude-code adapter
    local entry_count
    entry_count="$(jq '.installs | length' "$REGISTRY_FILE")"
    assert_eq "3.5 Registry has 2 entries" "2" "$entry_count"
    assert_json_value "3.5 Registry records claude-code adapter" \
        "$REGISTRY_FILE" '.installs[1].adapter' "claude-code"

    # Test 3.6: Skills deployed to .claude/skills/
    assert_dir_exists "3.6 Skills in .claude/" "${DEST_B}/.claude/skills/alpha-skill"
    assert_dir_exists "3.6 Skills in .claude/" "${DEST_B}/.claude/skills/bravo-skill"
}

test_group_4_collision_detection() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 4: Re-install Collision Detection"
    echo "═══════════════════════════════════════════"

    # Test 4.1: Same dest, same type — blocked
    local output rc
    output="$(echo -e "${MENU_NUM_TESTBED}\n${ADAPTER_NUM_OPENCODE}\n${DEST_A}" | "$INSTALLER" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "4.1 Re-install same dest exits 1" 1 "$rc"
    assert_contains "4.1 Error says already installed" "$output" "already has"
    assert_contains "4.1 Error suggests --update" "$output" "--update"

    # Test 4.2: Relative path rejected
    output="$(echo -e "${MENU_NUM_TESTBED}\n${ADAPTER_NUM_OPENCODE}\nrelative/path" | "$INSTALLER" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "4.2 Relative path exits 1" 1 "$rc"
    assert_contains "4.2 Error about absolute path" "$output" "absolute path"

    # Test 4.3: Non-existent path — created automatically
    local new_dest="${TEST_DIR}/auto-created"
    output="$(echo -e "${MENU_NUM_TESTBED}\n${ADAPTER_NUM_OPENCODE}\n${new_dest}" | "$INSTALLER" 2>&1)"
    rc=$?
    assert_exit_code "4.3 Non-existent path exits 0" 0 "$rc"
    assert_dir_exists "4.3 Destination was created" "$new_dest"
    assert_file_exists "4.3 Files installed to new dest" "${new_dest}/.opencode/agents/shared-agent.md"
}

test_group_5_update_flow() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 5: Update Flow"
    echo "═══════════════════════════════════════════"

    # Test 5.1: Modify a file at dest-A (opencode install)
    echo "THIS FILE WAS MODIFIED BY THE USER" > "${DEST_A}/.opencode/agents/shared-agent.md"
    assert_file_contains "5.1 File modified at dest-A" \
        "${DEST_A}/.opencode/agents/shared-agent.md" "MODIFIED BY THE USER"

    # Test 5.2: Add custom user files (not in manifest)
    echo "# Custom Agent" > "${DEST_A}/.opencode/agents/my-custom-agent.md"
    echo "# Custom Command" > "${DEST_A}/.opencode/commands/my-custom-command.md"

    # Test 5.3: Modify a file at dest-B (claude-code install)
    echo "THIS FILE WAS MODIFIED BY THE USER" > "${DEST_B}/.claude/agents/shared-agent.md"

    # Test 5.4: Run update — should update both opencode and claude-code installs
    local output
    output="$("$INSTALLER" --update 2>&1)"
    local rc=$?
    assert_exit_code "5.4 --update exits 0" 0 "$rc"

    # Test 5.5: Backup created at dest-A
    local backup_count
    backup_count="$(find "${DEST_A}/.agent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$backup_count" -ge 1 ]] && pass "5.5 Backup directory created at dest-A" \
        || fail "5.5 Backup directory created at dest-A" "no backup dirs found"

    # Test 5.6: Backup contains MODIFIED version (not source)
    local backup_dir
    backup_dir="$(find "${DEST_A}/.agent-backups" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
    assert_file_contains "5.6 Backup has user's modified content" \
        "${backup_dir}/.opencode/agents/shared-agent.md" "MODIFIED BY THE USER"

    # Test 5.7: File restored to source version after update
    assert_file_contains "5.7 shared-agent restored to BRAVO version" \
        "${DEST_A}/.opencode/agents/shared-agent.md" "BRAVO version"
    assert_file_not_contains "5.7 Modified content gone" \
        "${DEST_A}/.opencode/agents/shared-agent.md" "MODIFIED BY THE USER"

    # Test 5.8: Custom user files NOT deleted (surgical manifest-based delete)
    assert_file_exists "5.8 Custom agent survives update" \
        "${DEST_A}/.opencode/agents/my-custom-agent.md"
    assert_file_exists "5.8 Custom command survives update" \
        "${DEST_A}/.opencode/commands/my-custom-command.md"

    # Test 5.9: dest-B (claude-code) also updated
    assert_file_contains "5.9 dest-B claude-code restored after update" \
        "${DEST_B}/.claude/agents/shared-agent.md" "BRAVO version"
    assert_file_not_contains "5.9 dest-B modified content gone" \
        "${DEST_B}/.claude/agents/shared-agent.md" "MODIFIED BY THE USER"

    # Test 5.10: dest-B backup created
    local dest_b_backups
    dest_b_backups="$(find "${DEST_B}/.agent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$dest_b_backups" -ge 1 ]] && pass "5.10 dest-B backup created" \
        || fail "5.10 dest-B backup created" "no backup dirs at dest-B"

    # Test 5.11: Registry timestamps updated
    local installed_at updated_at
    installed_at="$(jq -r '.installs[0].installed_at' "$REGISTRY_FILE")"
    updated_at="$(jq -r '.installs[0].updated_at' "$REGISTRY_FILE")"
    if [[ "$updated_at" > "$installed_at" || "$updated_at" == "$installed_at" ]]; then
        pass "5.11 updated_at >= installed_at"
    else
        fail "5.11 updated_at >= installed_at" "installed=${installed_at} updated=${updated_at}"
    fi
}

test_group_6_source_changes() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 6: Source Content Changes"
    echo "═══════════════════════════════════════════"

    # Test 6.1: Add new file to source, update, verify it appears in both installs
    echo -e "# New Agent\nAdded after install." \
        > "${FIXTURE_DIR}/bravo/.agent/agents/new-after-install.md"
    "$INSTALLER" --update &>/dev/null
    assert_file_exists "6.1 New agent appears in opencode dest" \
        "${DEST_A}/.opencode/agents/new-after-install.md"
    assert_file_exists "6.1 New agent appears in claude-code dest" \
        "${DEST_B}/.claude/agents/new-after-install.md"

    # Test 6.2: Remove file from source, update, verify it's gone from both
    rm "${FIXTURE_DIR}/alpha/.agent/agents/alpha-only-agent.md"
    "$INSTALLER" --update &>/dev/null
    assert_file_not_exists "6.2 Removed agent gone from opencode" \
        "${DEST_A}/.opencode/agents/alpha-only-agent.md"
    assert_file_not_exists "6.2 Removed agent gone from claude-code" \
        "${DEST_B}/.claude/agents/alpha-only-agent.md"

    # Test 6.3: Removed file is in backup
    local backup_dir
    backup_dir="$(find "${DEST_A}/.agent-backups" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
    assert_file_exists "6.3 Removed agent preserved in backup" \
        "${backup_dir}/.opencode/agents/alpha-only-agent.md"

    # Test 6.4: Rename file in source, update, verify old gone + new present
    mv "${FIXTURE_DIR}/bravo/.agent/commands/bravo-cmd.md" \
       "${FIXTURE_DIR}/bravo/.agent/commands/renamed-cmd.md"
    "$INSTALLER" --update &>/dev/null
    assert_file_not_exists "6.4 Old filename gone after rename" \
        "${DEST_A}/.opencode/commands/bravo-cmd.md"
    assert_file_exists "6.4 New filename present after rename" \
        "${DEST_A}/.opencode/commands/renamed-cmd.md"

    # Restore source files for subsequent tests
    echo -e "# Alpha-Only Agent\nThis agent exists only in alpha." \
        > "${FIXTURE_DIR}/alpha/.agent/agents/alpha-only-agent.md"
    mv "${FIXTURE_DIR}/bravo/.agent/commands/renamed-cmd.md" \
       "${FIXTURE_DIR}/bravo/.agent/commands/bravo-cmd.md"
    rm -f "${FIXTURE_DIR}/bravo/.agent/agents/new-after-install.md"
}

test_group_7_edge_cases() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 7: Edge Cases"
    echo "═══════════════════════════════════════════"

    # Test 7.1: Deleted destination — update warns and skips
    rm -rf "$DEST_B"
    local output
    output="$("$INSTALLER" --update 2>&1)"
    local rc=$?
    assert_exit_code "7.1 Update with deleted dest exits 0" 0 "$rc"
    assert_contains "7.1 Warning about missing dest" "$output" "does not exist"
    assert_contains "7.1 Summary shows failures" "$output" "Failed:"

    # Test 7.2: dest-A still updated despite dest-B failure
    assert_contains "7.2 dest-A still updated" "$output" "Updated"

    # Test 7.3: Source project removed before update
    mv "$FIXTURE_DIR" "${FIXTURE_DIR}-RENAMED"
    output="$("$INSTALLER" --update 2>&1)"
    assert_contains "7.3 Error about missing source project" "$output" "no longer exists"
    mv "${FIXTURE_DIR}-RENAMED" "$FIXTURE_DIR"

    # Test 7.4: Registry integrity after mixed failures
    jq '.' "$REGISTRY_FILE" > /dev/null 2>&1
    rc=$?
    assert_exit_code "7.4 Registry is valid JSON after failures" 0 "$rc"

    # Test 7.5: Project type with only files (no subdirs) — skipped in menu
    mkdir -p "${PROJECTS_DIR}/zzz-filesonly"
    echo "test" > "${PROJECTS_DIR}/zzz-filesonly/README.md"
    output="$(echo "q" | "$INSTALLER" 2>&1 || true)"
    assert_not_contains "7.5 Files-only project not in menu" "$output" "zzz-filesonly"
    rm -rf "${PROJECTS_DIR}/zzz-filesonly"
}

test_group_8_empty_dir_cleanup() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 8: Empty Directory Cleanup"
    echo "═══════════════════════════════════════════"

    # Set up a minimal project with a single agent, install it, remove the
    # agent from source, update, and verify the empty agents/ dir is cleaned up.
    local mini_project="${PROJECTS_DIR}/zzz-minitest"
    local mini_dest="${TEST_DIR}/dest-mini"
    mkdir -p "$mini_dest"
    mkdir -p "${mini_project}/only-source/.agent/agents"
    echo "# Temp Agent" > "${mini_project}/only-source/.agent/agents/temp-agent.md"

    local menu_num
    menu_num="$(find_menu_number "zzz-minitest")"
    local adapter_num
    adapter_num="$(find_adapter_number "opencode" "$menu_num")"
    echo -e "${menu_num}\n${adapter_num}\n${mini_dest}" | "$INSTALLER" &>/dev/null

    # Test 8.1: Agent installed
    assert_file_exists "8.1 temp-agent installed" \
        "${mini_dest}/.opencode/agents/temp-agent.md"

    # Remove agent from source and update
    rm "${mini_project}/only-source/.agent/agents/temp-agent.md"
    "$INSTALLER" --update &>/dev/null

    # Test 8.2: Empty agents/ dir cleaned up
    assert_dir_not_exists "8.2 Empty agents/ dir removed" \
        "${mini_dest}/.opencode/agents"

    rm -rf "$mini_project"
}

test_group_9_adapter_settings_transform() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 9: Settings YAML Transform"
    echo "═══════════════════════════════════════════"

    # Test 9.1: OpenCode settings have MCP servers merged from both sources
    assert_json_value "9.1 OpenCode has 3 MCP servers" \
        "${DEST_A}/opencode.json" '.mcp | length' "3"

    # Test 9.2: settings.yaml not deployed to destination
    assert_file_not_exists "9.2 settings.yaml not at dest-A" \
        "${DEST_A}/settings.yaml"

    # Test 9.3: opencode-specific overrides applied
    assert_json_value "9.3 opencode alpha_key override" \
        "${DEST_A}/opencode.json" ".alpha_key" "from_alpha"
    assert_json_value "9.3 opencode bravo_key override" \
        "${DEST_A}/opencode.json" ".bravo_key" "from_bravo"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "============================================"
    echo " install-project.sh Test Suite"
    echo "============================================"
    echo "Test dir:    ${TEST_DIR}"
    echo "Fixtures:    ${FIXTURE_DIR}"
    echo "Registry:    ${REGISTRY_FILE}"
    echo ""

    # Check dependencies
    for dep in jq yq; do
        if ! command -v "$dep" &>/dev/null; then
            echo "[ERROR] ${dep} is required. Install it and try again."
            exit 1
        fi
    done

    if [[ ! -x "$INSTALLER" ]]; then
        echo "[ERROR] Installer not found or not executable: $INSTALLER"
        exit 1
    fi

    setup_fixtures
    cache_menu_numbers

    test_group_1_cli_arguments
    test_group_2_install_opencode
    test_group_3_install_claude_code
    test_group_4_collision_detection
    test_group_5_update_flow
    test_group_6_source_changes
    test_group_7_edge_cases
    test_group_8_empty_dir_cleanup
    test_group_9_adapter_settings_transform

    teardown_fixtures

    # ─── Final Report ─────────────────────────────────────────────────────
    echo ""
    echo "============================================"
    echo " Test Results"
    echo "============================================"
    echo "  Passed:  ${PASSED}"
    echo "  Failed:  ${FAILED}"
    echo "  Total:   $((PASSED + FAILED))"
    echo "============================================"

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo ""
        echo "Failures:"
        for err in "${ERRORS[@]}"; do
            echo "  - ${err}"
        done
    fi

    if [[ "$FAILED" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
