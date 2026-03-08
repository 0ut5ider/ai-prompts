#!/usr/bin/env bash
# ABOUTME: Automated test suite for install-global.sh.
# ABOUTME: Creates temporary targets, runs all test scenarios, and reports pass/fail.
set -uo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/install-global.sh"
SOURCE_DIR="${SCRIPT_DIR}/global/opencode"

TEST_DIR="$(mktemp -d /tmp/test-global-installer-XXXXXX)"

# Track source files that we temporarily rename during tests, so the trap
# can restore them if the test is interrupted.
MOVED_SOURCE_FILES=()

PASSED=0
FAILED=0
ERRORS=()

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

# Compare a source file's content to a destination file via checksum
assert_checksum_match() {
    local description="$1" src="$2" dest="$3"
    if [[ ! -f "$src" ]]; then
        fail "$description" "source file not found: ${src}"
        return
    fi
    if [[ ! -f "$dest" ]]; then
        fail "$description" "dest file not found: ${dest}"
        return
    fi
    local src_hash dest_hash
    src_hash="$(md5sum "$src" | cut -d' ' -f1)"
    dest_hash="$(md5sum "$dest" | cut -d' ' -f1)"
    if [[ "$src_hash" == "$dest_hash" ]]; then
        pass "$description"
    else
        fail "$description" "checksum mismatch: src=${src_hash} dest=${dest_hash}"
    fi
}

# Count regular files under a directory, excluding .backups/
assert_file_count() {
    local description="$1" dirpath="$2" expected="$3"
    local actual
    actual="$(find "$dirpath" -path "${dirpath}/.backups" -prune -o -type f -print 2>/dev/null | wc -l | tr -d ' ')"
    assert_eq "$description" "$expected" "$actual"
}

# Safely rename a source file and track it for cleanup
safe_move_source() {
    local src="$1" backup="$2"
    mv "$src" "$backup"
    MOVED_SOURCE_FILES+=("${backup}|${src}")
}

# Restore a previously moved source file and remove from tracking
safe_restore_source() {
    local backup="$1" src="$2"
    mv "$backup" "$src"
    # Remove from tracking array
    local new_array=()
    for entry in "${MOVED_SOURCE_FILES[@]}"; do
        if [[ "$entry" != "${backup}|${src}" ]]; then
            new_array+=("$entry")
        fi
    done
    MOVED_SOURCE_FILES=("${new_array[@]+"${new_array[@]}"}")
}

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Restore any source files that were moved during tests
    for entry in "${MOVED_SOURCE_FILES[@]+"${MOVED_SOURCE_FILES[@]}"}"; do
        local backup="${entry%%|*}"
        local original="${entry##*|}"
        if [[ -e "$backup" && ! -e "$original" ]]; then
            mv "$backup" "$original"
            echo "  Restored source file: $original"
        fi
    done

    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# ─── Test Groups ──────────────────────────────────────────────────────────────

test_group_1_cli_arguments() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 1: CLI Arguments"
    echo "═══════════════════════════════════════════"

    local output rc

    # Test 1.1: --help prints usage and exits 0
    output="$("$INSTALLER" --help 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.1 --help exits 0" 0 "$rc"
    assert_contains "1.1 --help shows Usage" "$output" "Usage:"
    assert_contains "1.1 --help shows --dry-run" "$output" "--dry-run"
    assert_contains "1.1 --help shows --target" "$output" "--target"

    # Test 1.2: Unknown argument exits non-zero
    output="$("$INSTALLER" --bogus 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.2 --bogus exits 1" 1 "$rc"
    assert_contains "1.2 --bogus shows error" "$output" "Unknown option"

    # Test 1.3: --target without argument exits non-zero
    output="$("$INSTALLER" --target 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.3 --target without arg exits 1" 1 "$rc"
    assert_contains "1.3 --target error message" "$output" "requires a directory"

    # Test 1.4: --target with flag as value rejected
    output="$("$INSTALLER" --target --dry-run 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.4 --target --dry-run exits 1" 1 "$rc"
    assert_contains "1.4 --target flag-as-value error" "$output" "requires a directory"

    # Test 1.5: --target with empty string rejected
    output="$("$INSTALLER" --target "" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "1.5 --target empty string exits 1" 1 "$rc"
}

test_group_2_clean_install() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 2: Clean Install (no existing target)"
    echo "═══════════════════════════════════════════"

    local dest="${TEST_DIR}/clean-install"
    local output rc

    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "2.1 Clean install exits 0" 0 "$rc"

    # Test 2.2: Target directory created
    assert_dir_exists "2.2 Target dir created" "$dest"

    # Test 2.3: Subdirectories created
    assert_dir_exists "2.3 agents/ created" "${dest}/agents"
    assert_dir_exists "2.3 commands/ created" "${dest}/commands"
    assert_dir_exists "2.3 prompts/ created" "${dest}/prompts"
    assert_dir_exists "2.3 skills/ created" "${dest}/skills"

    # Test 2.4: Agent files copied with correct content
    assert_checksum_match "2.4 testing.md content matches source" \
        "${SOURCE_DIR}/agents/testing.md" "${dest}/agents/testing.md"
    assert_checksum_match "2.4 thinking-partener.md content matches source" \
        "${SOURCE_DIR}/agents/thinking-partener.md" "${dest}/agents/thinking-partener.md"

    # Test 2.5: Command files copied with correct content
    assert_checksum_match "2.5 chat-summary.md content matches source" \
        "${SOURCE_DIR}/commands/chat-summary.md" "${dest}/commands/chat-summary.md"
    assert_checksum_match "2.5 google-alerts-digest.md content matches source" \
        "${SOURCE_DIR}/commands/google-alerts-digest.md" "${dest}/commands/google-alerts-digest.md"
    assert_checksum_match "2.5 migrate-plans.md content matches source" \
        "${SOURCE_DIR}/commands/migrate-plans.md" "${dest}/commands/migrate-plans.md"

    # Test 2.6: Prompt files copied with correct content
    assert_checksum_match "2.6 augster-system.md content matches source" \
        "${SOURCE_DIR}/prompts/augster-system.md" "${dest}/prompts/augster-system.md"
    assert_checksum_match "2.6 coding.md content matches source" \
        "${SOURCE_DIR}/prompts/coding.md" "${dest}/prompts/coding.md"

    # Test 2.7: Skill directories copied recursively with nested files
    assert_dir_exists "2.7 gog/ skill dir" "${dest}/skills/gog"
    assert_dir_exists "2.7 session-history/ skill dir" "${dest}/skills/session-history"
    assert_dir_exists "2.7 writing-clearly-and-concisely/ skill dir" "${dest}/skills/writing-clearly-and-concisely"
    assert_checksum_match "2.7 gog SKILL.md content" \
        "${SOURCE_DIR}/skills/gog/SKILL.md" "${dest}/skills/gog/SKILL.md"
    assert_checksum_match "2.7 session-history SKILL.md content" \
        "${SOURCE_DIR}/skills/session-history/SKILL.md" "${dest}/skills/session-history/SKILL.md"
    # Deep recursive copy: nested script inside subdir
    assert_checksum_match "2.7 session-history/scripts/oc-history.sh content" \
        "${SOURCE_DIR}/skills/session-history/scripts/oc-history.sh" \
        "${dest}/skills/session-history/scripts/oc-history.sh"
    assert_checksum_match "2.7 session-history/README.md content" \
        "${SOURCE_DIR}/skills/session-history/README.md" \
        "${dest}/skills/session-history/README.md"
    assert_checksum_match "2.7 writing/elements-of-style.md content" \
        "${SOURCE_DIR}/skills/writing-clearly-and-concisely/elements-of-style.md" \
        "${dest}/skills/writing-clearly-and-concisely/elements-of-style.md"

    # Test 2.8: AGENTS.md copied with correct content
    assert_checksum_match "2.8 AGENTS.md content matches source" \
        "${SOURCE_DIR}/AGENTS.md" "${dest}/AGENTS.md"

    # Test 2.9: opencode.json created from example on clean install
    assert_file_exists "2.9 opencode.json created" "${dest}/opencode.json"
    assert_checksum_match "2.9 opencode.json matches example" \
        "${SOURCE_DIR}/opencode_example.json" "${dest}/opencode.json"

    # Test 2.10: Summary counters — exact values
    # 10 subdir entries + AGENTS.md + opencode.json = 12
    assert_contains "2.10 Installed: 12" "$output" "Installed:  12"
    assert_contains "2.10 Skipped: 0" "$output" "Skipped:    0"
    assert_contains "2.10 Backed up: 0" "$output" "Backed up:  0"

    # Test 2.11: No backup dir created on clean install
    if [[ -d "${dest}/.backups" ]]; then
        fail "2.11 No .backups dir on clean install" ".backups directory exists"
    else
        pass "2.11 No .backups dir on clean install"
    fi

    # Test 2.12: Exact file count — only expected files, nothing extra
    # 2 agents + 3 commands + 2 prompts + 6 skill files + AGENTS.md + opencode.json = 15
    assert_file_count "2.12 Exact file count after clean install" "$dest" "15"
}

test_group_3_repeat_install() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 3: Repeat Install (collisions & backup)"
    echo "═══════════════════════════════════════════"

    local dest="${TEST_DIR}/clean-install"  # reuse from group 2
    local output rc

    # Modify a file so we can check backup captures user changes
    echo "USER MODIFIED THIS FILE" > "${dest}/agents/testing.md"

    # Add a user-created file that doesn't collide with source
    echo "# My Custom Agent" > "${dest}/agents/my-custom-agent.md"

    # Run install again
    sleep 1  # ensure different timestamp for backup dir
    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "3.1 Repeat install exits 0" 0 "$rc"

    # Test 3.2: Backup directory created
    local backup_count
    backup_count="$(find "${dest}/.backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$backup_count" -ge 1 ]] && pass "3.2 Backup directory created" \
        || fail "3.2 Backup directory created" "no backup dirs found"

    # Test 3.3: Backup contains user's modified content
    local backup_dir
    backup_dir="$(find "${dest}/.backups" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
    assert_file_contains "3.3 Backup has user modified content" \
        "${backup_dir}/agents/testing.md" "USER MODIFIED THIS FILE"

    # Test 3.4: Source version restored after reinstall
    assert_checksum_match "3.4 testing.md restored to source version" \
        "${SOURCE_DIR}/agents/testing.md" "${dest}/agents/testing.md"

    # Test 3.5: AGENTS.md backed up and overwritten
    assert_file_exists "3.5 AGENTS.md still present" "${dest}/AGENTS.md"
    assert_file_exists "3.5 AGENTS.md in backup" "${backup_dir}/AGENTS.md"

    # Test 3.6: opencode.json NOT overwritten — skip message with specific text
    assert_contains "3.6 Skip mentions opencode.json" "$output" "opencode.json already exists"
    assert_contains "3.6 Skip mentions keeping existing" "$output" "keeping existing config"

    # Test 3.7: opencode.json content unchanged
    assert_checksum_match "3.7 opencode.json still matches example" \
        "${SOURCE_DIR}/opencode_example.json" "${dest}/opencode.json"

    # Test 3.8: Summary counters — exact values
    # 10 subdir entries + AGENTS.md = 11 installed (opencode.json skipped)
    assert_contains "3.8 Installed: 11" "$output" "Installed:  11"
    assert_contains "3.8 Skipped: 1" "$output" "Skipped:    1"
    # All 10 subdir entries + AGENTS.md = 11 backed up
    assert_contains "3.8 Backed up: 11" "$output" "Backed up:  11"

    # Test 3.9: User-added file that doesn't collide is untouched
    assert_file_exists "3.9 Custom agent survives reinstall" "${dest}/agents/my-custom-agent.md"
    assert_file_contains "3.9 Custom agent content intact" \
        "${dest}/agents/my-custom-agent.md" "My Custom Agent"

    # Test 3.10: Backup of a skill directory (recursive dir backup)
    assert_dir_exists "3.10 Skill dir backed up" "${backup_dir}/skills/gog"
    assert_file_exists "3.10 Skill SKILL.md in backup" "${backup_dir}/skills/gog/SKILL.md"
}

test_group_4_dry_run() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 4: --dry-run Mode"
    echo "═══════════════════════════════════════════"

    local output rc

    # Test 4.1: Dry run on fresh target — nothing created
    local dest="${TEST_DIR}/dry-run-target"
    output="$("$INSTALLER" --target "$dest" --dry-run 2>&1)" && rc=$? || rc=$?
    assert_exit_code "4.1 Dry run exits 0" 0 "$rc"
    assert_contains "4.1 Output shows dry-run" "$output" "(dry-run)"
    assert_dir_not_exists "4.1 Target not created in dry-run" "$dest"

    # Test 4.2: Dry run with existing target and opencode.json — skip message, no changes
    local dest2="${TEST_DIR}/dry-run-existing"
    mkdir -p "$dest2"
    echo '{"custom": true}' > "${dest2}/opencode.json"
    output="$("$INSTALLER" --target "$dest2" --dry-run 2>&1)" && rc=$? || rc=$?
    assert_exit_code "4.2 Dry run with existing target exits 0" 0 "$rc"
    assert_contains "4.2 Skip message for existing opencode.json" "$output" "opencode.json already exists"
    assert_file_contains "4.2 opencode.json unchanged after dry run" \
        "${dest2}/opencode.json" '"custom": true'
    assert_dir_not_exists "4.3 No agents/ created in dry run" "${dest2}/agents"

    # Test 4.4: Dry run with existing collisions in subdirs — backup messages but no moves
    local dest3="${TEST_DIR}/dry-run-collisions"
    mkdir -p "${dest3}/agents"
    echo "EXISTING CONTENT" > "${dest3}/agents/testing.md"
    output="$("$INSTALLER" --target "$dest3" --dry-run 2>&1)" && rc=$? || rc=$?
    assert_exit_code "4.4 Dry run with collisions exits 0" 0 "$rc"
    assert_contains "4.4 Backup message in dry-run output" "$output" "(dry-run) Would back up"
    assert_file_contains "4.4 Original file untouched after dry-run" \
        "${dest3}/agents/testing.md" "EXISTING CONTENT"
    # No .backups dir should be created
    if [[ -d "${dest3}/.backups" ]]; then
        fail "4.4 No .backups dir created in dry-run" ".backups was created"
    else
        pass "4.4 No .backups dir created in dry-run"
    fi
}

test_group_5_opencode_json_behavior() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 5: opencode.json Skip Behavior"
    echo "═══════════════════════════════════════════"

    # Test 5.1: Clean install — opencode.json created from example
    local dest="${TEST_DIR}/json-clean"
    local output rc
    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    assert_checksum_match "5.1 opencode.json matches example on clean install" \
        "${SOURCE_DIR}/opencode_example.json" "${dest}/opencode.json"

    # Test 5.2: Modify opencode.json, reinstall — original preserved
    echo '{"user_customized": true, "api_key": "secret123"}' > "${dest}/opencode.json"
    sleep 1
    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    assert_file_contains "5.2 User content preserved after reinstall" \
        "${dest}/opencode.json" '"user_customized": true'
    assert_file_contains "5.2 User API key preserved" \
        "${dest}/opencode.json" "secret123"
    assert_file_not_contains "5.2 Example content NOT written over user config" \
        "${dest}/opencode.json" "opencode.ai/config.json"

    # Test 5.3: Skip counter incremented
    assert_contains "5.3 Skipped: 1" "$output" "Skipped:    1"

    # Test 5.4: opencode.json is NOT in backup (it was never touched)
    local backup_dir
    backup_dir="$(find "${dest}/.backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
    if [[ -n "$backup_dir" ]]; then
        assert_file_not_exists "5.4 opencode.json not in backup" \
            "${backup_dir}/opencode.json"
    else
        pass "5.4 opencode.json not in backup (no backup dir)"
    fi

    # Test 5.5: Missing example file when opencode.json already exists — should succeed
    local dest2="${TEST_DIR}/json-missing-example"
    mkdir -p "$dest2"
    echo '{"existing": true}' > "${dest2}/opencode.json"
    local example_file="${SOURCE_DIR}/opencode_example.json"
    local example_backup="${SOURCE_DIR}/opencode_example.json.test-backup"
    safe_move_source "$example_file" "$example_backup"
    output="$("$INSTALLER" --target "$dest2" 2>&1)" && rc=$? || rc=$?
    safe_restore_source "$example_backup" "$example_file"
    assert_exit_code "5.5 Missing example OK when opencode.json exists" 0 "$rc"
    assert_file_contains "5.5 Existing opencode.json preserved" \
        "${dest2}/opencode.json" '"existing": true'
}

test_group_6_target_flag() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 6: --target Flag"
    echo "═══════════════════════════════════════════"

    # Test 6.1: --target installs to specified directory
    local dest="${TEST_DIR}/custom-target"
    local output rc
    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "6.1 --target install exits 0" 0 "$rc"
    assert_dir_exists "6.1 Custom target created" "$dest"
    assert_file_exists "6.1 AGENTS.md in custom target" "${dest}/AGENTS.md"

    # Test 6.2: Output shows custom target path
    assert_contains "6.2 Output shows custom target" "$output" "$dest"

    # Test 6.3: Backups go under the custom target's .backups/
    sleep 1
    "$INSTALLER" --target "$dest" &>/dev/null
    local backup_count
    backup_count="$(find "${dest}/.backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$backup_count" -ge 1 ]] && pass "6.3 Backups under custom target" \
        || fail "6.3 Backups under custom target" "no backup dirs found under ${dest}/.backups"

    # Test 6.4: --target with --dry-run
    local dest2="${TEST_DIR}/custom-dry"
    output="$("$INSTALLER" --target "$dest2" --dry-run 2>&1)" && rc=$? || rc=$?
    assert_exit_code "6.4 --target --dry-run exits 0" 0 "$rc"
    assert_contains "6.4 Output shows custom target in dry-run" "$output" "$dest2"

    # Test 6.5: --target pointing to an existing file (not a dir)
    local file_target="${TEST_DIR}/im-a-file"
    echo "not a directory" > "$file_target"
    output="$("$INSTALLER" --target "$file_target" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "6.5 --target to a file exits non-zero" 1 "$rc"
}

test_group_7_edge_cases() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 7: Edge Cases"
    echo "═══════════════════════════════════════════"

    local output rc

    # Test 7.1: Missing opencode_example.json on clean install causes error
    local dest="${TEST_DIR}/missing-example"
    local example_file="${SOURCE_DIR}/opencode_example.json"
    local example_backup="${SOURCE_DIR}/opencode_example.json.test-backup"
    safe_move_source "$example_file" "$example_backup"
    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    safe_restore_source "$example_backup" "$example_file"
    assert_exit_code "7.1 Missing example exits 1" 1 "$rc"
    assert_contains "7.1 Error about missing example" "$output" "[ERROR]"
    assert_contains "7.1 Error mentions file" "$output" "opencode_example.json"

    # Test 7.2: Symlink at target is backed up and replaced
    local dest2="${TEST_DIR}/symlink-test"
    mkdir -p "${dest2}/agents"
    ln -s /dev/null "${dest2}/agents/testing.md"
    output="$("$INSTALLER" --target "$dest2" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "7.2 Install over symlinks exits 0" 0 "$rc"
    assert_file_exists "7.2 testing.md is now a real file" "${dest2}/agents/testing.md"
    if [[ -L "${dest2}/agents/testing.md" ]]; then
        fail "7.2 testing.md is no longer a symlink" "still a symlink"
    else
        pass "7.2 testing.md is no longer a symlink"
    fi

    # Test 7.3: Dangling symlink is backed up (exercises -L branch)
    local dest3="${TEST_DIR}/dangling-symlink"
    mkdir -p "${dest3}/agents"
    ln -s /nonexistent/path/that/does/not/exist "${dest3}/agents/testing.md"
    output="$("$INSTALLER" --target "$dest3" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "7.3 Install over dangling symlink exits 0" 0 "$rc"
    assert_file_exists "7.3 testing.md replaced dangling symlink" "${dest3}/agents/testing.md"
    if [[ -L "${dest3}/agents/testing.md" ]]; then
        fail "7.3 testing.md is no longer a dangling symlink" "still a symlink"
    else
        pass "7.3 testing.md is no longer a dangling symlink"
    fi
    # Verify dangling symlink was backed up
    local dangling_backup
    dangling_backup="$(find "${dest3}/.backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
    if [[ -n "$dangling_backup" && -L "${dangling_backup}/agents/testing.md" ]]; then
        pass "7.3 Dangling symlink preserved in backup"
    else
        fail "7.3 Dangling symlink preserved in backup" "symlink not found in backup"
    fi

    # Test 7.4: Target path with spaces works
    local dest4="${TEST_DIR}/path with spaces"
    output="$("$INSTALLER" --target "$dest4" 2>&1)" && rc=$? || rc=$?
    assert_exit_code "7.4 Path with spaces exits 0" 0 "$rc"
    assert_file_exists "7.4 AGENTS.md in spaced path" "${dest4}/AGENTS.md"
    assert_file_exists "7.4 opencode.json in spaced path" "${dest4}/opencode.json"
}

test_group_8_source_anomalies() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 8: Source Directory Anomalies"
    echo "═══════════════════════════════════════════"

    local output rc

    # Test 8.1: Missing source subdirectory — skipped gracefully
    # Temporarily rename the agents/ source dir
    local agents_src="${SOURCE_DIR}/agents"
    local agents_backup="${SOURCE_DIR}/agents.test-backup"
    safe_move_source "$agents_src" "$agents_backup"
    local dest="${TEST_DIR}/missing-subdir"
    output="$("$INSTALLER" --target "$dest" 2>&1)" && rc=$? || rc=$?
    safe_restore_source "$agents_backup" "$agents_src"
    assert_exit_code "8.1 Missing source subdir exits 0" 0 "$rc"
    assert_contains "8.1 Skip message for missing agents/" "$output" "[SKIP]"
    assert_contains "8.1 Skip mentions agents" "$output" "agents"
    # agents/ dir should NOT be created at destination when source is missing
    assert_dir_not_exists "8.1 agents/ not created when source missing" "${dest}/agents"
    # Other subdirs should still be installed
    assert_dir_exists "8.1 commands/ still installed" "${dest}/commands"

    # Test 8.2: Empty source subdirectory — handled by glob guard
    # Create a temporary empty subdir by renaming agents contents
    local dest2="${TEST_DIR}/empty-subdir"
    mkdir -p "${SOURCE_DIR}/agents.test-contents"
    for f in "${SOURCE_DIR}/agents"/*; do
        [[ -e "$f" ]] && mv "$f" "${SOURCE_DIR}/agents.test-contents/"
    done
    output="$("$INSTALLER" --target "$dest2" 2>&1)" && rc=$? || rc=$?
    # Restore agents contents
    for f in "${SOURCE_DIR}/agents.test-contents"/*; do
        [[ -e "$f" ]] && mv "$f" "${SOURCE_DIR}/agents/"
    done
    rmdir "${SOURCE_DIR}/agents.test-contents"
    assert_exit_code "8.2 Empty source subdir exits 0" 0 "$rc"
    # agents/ dir IS created at destination (ensure_dir runs) but has no files
    assert_dir_exists "8.2 agents/ dir created even when empty" "${dest2}/agents"
    local agents_file_count
    agents_file_count="$(find "${dest2}/agents" -type f 2>/dev/null | wc -l | tr -d ' ')"
    assert_eq "8.2 No files in agents/ from empty source" "0" "$agents_file_count"
}

test_group_9_idempotency() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Group 9: Idempotency"
    echo "═══════════════════════════════════════════"

    local dest="${TEST_DIR}/idempotent"

    # Run 1: clean install
    "$INSTALLER" --target "$dest" &>/dev/null

    # Run 2
    sleep 1
    "$INSTALLER" --target "$dest" &>/dev/null

    # Snapshot after run 2 (exclude .backups)
    local snapshot_run2
    snapshot_run2="$(find "$dest" -path "${dest}/.backups" -prune -o -type f -print | sort | xargs md5sum)"

    # Run 3
    sleep 1
    local output
    output="$("$INSTALLER" --target "$dest" 2>&1)"

    # Snapshot after run 3 (exclude .backups)
    local snapshot_run3
    snapshot_run3="$(find "$dest" -path "${dest}/.backups" -prune -o -type f -print | sort | xargs md5sum)"

    assert_eq "9.1 File contents identical after run 2 and 3" \
        "$snapshot_run2" "$snapshot_run3"

    # Test 9.2: Multiple backup dirs exist (one per re-run)
    local backup_count
    backup_count="$(find "${dest}/.backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    assert_eq "9.2 Two backup dirs from two re-runs" "2" "$backup_count"

    # Test 9.3: Counters are consistent on run 3
    assert_contains "9.3 Installed: 11 on run 3" "$output" "Installed:  11"
    assert_contains "9.3 Skipped: 1 on run 3" "$output" "Skipped:    1"
    assert_contains "9.3 Backed up: 11 on run 3" "$output" "Backed up:  11"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "============================================"
    echo " install-global.sh Test Suite"
    echo "============================================"
    echo "Test dir:    ${TEST_DIR}"
    echo "Source:      ${SOURCE_DIR}"
    echo ""

    if [[ ! -x "$INSTALLER" ]]; then
        echo "[ERROR] Installer not found or not executable: $INSTALLER"
        exit 1
    fi

    test_group_1_cli_arguments
    test_group_2_clean_install
    test_group_3_repeat_install
    test_group_4_dry_run
    test_group_5_opencode_json_behavior
    test_group_6_target_flag
    test_group_7_edge_cases
    test_group_8_source_anomalies
    test_group_9_idempotency

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
