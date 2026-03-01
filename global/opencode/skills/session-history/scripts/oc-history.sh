#!/bin/bash
set -euo pipefail

DB_PATH="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
VAULT_PATH="${OPENCODE_VAULT:-$HOME/obsidian_vault}"
LLM_BASE_URL="${LLM_BASE_URL:-https://cerebo.roci.me}"
LLM_API_KEY="${LLM_API_KEY:-}"
LLM_MODEL="${LLM_MODEL:-MiniMax M2.5}"
MAX_TRANSCRIPT_CHARS=12000

usage() {
    cat <<'EOF'
oc-history - Query OpenCode session history

USAGE:
    oc-history sessions [--date YYYY-MM-DD] [--project <path>]
    oc-history transcript <session_id>
    oc-history search <keyword> [--limit N]
    oc-history digest [--date YYYY-MM-DD] [--write] [--raw]
    oc-history stats [--days N]

COMMANDS:
    sessions     List sessions for a date (default: today)
    transcript   Get full conversation for a session
    search       Search across all sessions for keyword
    digest       Generate summarized daily digest (requires LLM_API_KEY)
    stats        Show usage statistics

OPTIONS:
    --date YYYY-MM-DD    Filter by date (default: today)
    --project <path>     Filter by project directory path
    --limit N            Search result limit (default: 20)
    --days N             Stats period in days (default: 7)
    --write              Write digest to Obsidian vault
    --raw                Skip LLM summarization, output raw transcripts

ENVIRONMENT:
    LLM_BASE_URL    OpenAI-compatible API base URL (default: https://cerebo.roci.me)
    LLM_API_KEY     API key for summarization (required for digest without --raw)
    LLM_MODEL       Model name (default: MiniMax M2.5)
    OPENCODE_DB     Path to opencode.db (default: ~/.local/share/opencode/opencode.db)
    OPENCODE_VAULT  Obsidian vault path (default: ~/obsidian_vault)

EXAMPLES:
    oc-history sessions
    oc-history sessions --date 2026-02-20
    oc-history transcript ses_3abccc83affeB7gQq7Cs6F00Up
    oc-history search "texture atlas"
    oc-history digest --date 2026-02-20 --write
    oc-history digest --date 2026-02-20 --raw
    oc-history stats --days 30
EOF
}

die() {
    echo "Error: $1" >&2
    exit 1
}

check_deps() {
    command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 is required but not installed"
    command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
    command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
    [[ -f "$DB_PATH" ]] || die "Database not found at $DB_PATH"
}

epoch_to_date() {
    local ms="$1"
    date -d "@$((ms / 1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$((ms / 1000))" '+%Y-%m-%d %H:%M:%S'
}

get_date_range() {
    local date_str="${1:-$(date +%Y-%m-%d)}"
    local start_ms end_ms
    start_ms=$(date -d "$date_str 00:00:00" +%s)000
    end_ms=$(date -d "$date_str 23:59:59" +%s)000
    echo "$start_ms $end_ms"
}

get_session_transcript() {
    local session_id="$1"
    sqlite3 -json "$DB_PATH" \
        "SELECT json_extract(m.data, '\$.role') as role, p.time_created, json_extract(p.data, '\$.text') as text FROM message m JOIN part p ON p.message_id = m.id WHERE m.session_id = '$session_id' AND json_extract(p.data, '\$.type') = 'text' ORDER BY m.time_created, p.time_created" 2>/dev/null
}

format_transcript_text() {
    local json_data="$1"
    echo "$json_data" | jq -r '.[] |
        "[\(.role | ascii_upcase)] \(.time_created / 1000 | strftime("%H:%M:%S")):\n\(.text)\n"
    ' 2>/dev/null
}

summarize_session() {
    local title="$1"
    local transcript_text="$2"

    if [[ -z "$LLM_API_KEY" ]]; then
        die "LLM_API_KEY is required for summarization. Set it or use --raw for raw transcripts."
    fi

    local truncated="$transcript_text"
    if [[ ${#truncated} -gt $MAX_TRANSCRIPT_CHARS ]]; then
        truncated="${truncated:0:$MAX_TRANSCRIPT_CHARS}... [truncated]"
    fi

    local system_prompt='You summarize AI coding assistant conversations into structured Obsidian notes. Be concise and factual. No filler. Use markdown formatting.'

    local user_prompt="Summarize this coding session titled \"${title}\".

Output EXACTLY this structure (no extra sections):

### Topics
- bullet list of topics discussed

### Key Decisions
- bullet list of decisions made (or \"None\" if purely exploratory)

### Outcomes
- bullet list: what was built, fixed, or changed

### Files Modified
- bullet list of files created/edited (or \"None\" if no file changes)

### Open Questions
- bullet list of unresolved items (or \"None\")

TRANSCRIPT:
${truncated}"

    local payload
    payload=$(jq -n \
        --arg model "$LLM_MODEL" \
        --arg system "$system_prompt" \
        --arg user "$user_prompt" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $system},
                {role: "user", content: $user}
            ],
            temperature: 0.3,
            max_tokens: 1024
        }')

    local response
    response=$(curl -s --max-time 120 \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -d "$payload" \
        "${LLM_BASE_URL}/v1/chat/completions" 2>/dev/null)

    local summary
    summary=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

    if [[ -z "$summary" ]]; then
        local err_msg
        err_msg=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        echo "_Summarization failed: ${err_msg:-unknown error}_"
    else
        # Strip reasoning: keep only content after the last </think> tag
        if echo "$summary" | grep -q '</think>'; then
            summary=$(echo "$summary" | sed -n '/<\/think>/,$p' | tail -n +2)
        fi
        echo "$summary"
    fi
}

cmd_sessions() {
    local opt_date="" opt_project=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --date)
                opt_date="$2"
                shift 2
                ;;
            --project)
                opt_project="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    local date="${opt_date:-$(date +%Y-%m-%d)}"
    local start end
    read start end <<< "$(get_date_range "$date")"

    local where_clause="s.time_created >= $start AND s.time_created <= $end"
    if [[ -n "$opt_project" ]]; then
        where_clause="$where_clause AND s.directory LIKE '%$opt_project%'"
    fi

    sqlite3 -header -column "$DB_PATH" \
        "SELECT s.id, s.title, s.directory, s.time_created, s.time_updated, (SELECT COUNT(*) FROM message m WHERE m.session_id = s.id) as msg_count FROM session s WHERE $where_clause ORDER BY s.time_created DESC" 2>/dev/null || echo "No sessions found for $date"
}

cmd_transcript() {
    local session_id="$1"
    [[ -z "$session_id" ]] && die "session_id is required"

    local results
    results=$(sqlite3 -json "$DB_PATH" \
        "SELECT m.id as msg_id, m.time_created, json_extract(m.data, '\$.role') as role, p.id as part_id, json_extract(p.data, '\$.type') as part_type, json_extract(p.data, '\$.text') as text FROM message m JOIN part p ON p.message_id = m.id WHERE m.session_id = '$session_id' AND json_extract(p.data, '\$.type') = 'text' ORDER BY m.time_created, p.time_created" 2>/dev/null) || die "Session not found: $session_id"

    if [[ -z "$results" || "$results" == "[]" ]]; then
        die "No transcript found for session: $session_id"
    fi

    echo "$results" | jq -r '.[] |
        "[\(.role | ascii_upcase)] \(.msg_id[:12]) \(.time_created / 1000 | strftime("%Y-%m-%d %H:%M:%S"))\n\(.text)\n"
    ' 2>/dev/null || echo "$results"
}

cmd_search() {
    local keyword="$1"
    local limit="${2:-20}"
    [[ -z "$keyword" ]] && die "keyword is required"

    sqlite3 -header -column "$DB_PATH" \
        "SELECT s.id as session_id, s.title, s.time_created, json_extract(p.data, '\$.text') as text FROM session s JOIN message m ON m.session_id = s.id JOIN part p ON p.message_id = m.id WHERE json_extract(p.data, '\$.type') = 'text' AND LOWER(json_extract(p.data, '\$.text')) LIKE '%' || LOWER('$keyword') || '%' ORDER BY s.time_created DESC LIMIT $limit" 2>/dev/null | head -$((limit + 1)) || echo "No matches found for: $keyword"
}

cmd_digest() {
    local opt_date="${1:-$(date +%Y-%m-%d)}"
    local write_flag=""
    local raw_flag=""

    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --write)
                write_flag="1"
                shift
                ;;
            --raw)
                raw_flag="1"
                shift
                ;;
            --date)
                opt_date="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    local start end
    read start end <<< "$(get_date_range "$opt_date")"

    local sessions
    sessions=$(sqlite3 -json "$DB_PATH" \
        "SELECT s.id, s.title, s.directory, s.time_created, s.time_updated, (SELECT COUNT(*) FROM message m WHERE m.session_id = s.id) as msg_count FROM session s WHERE s.time_created >= $start AND s.time_created <= $end ORDER BY s.time_created" 2>/dev/null) || die "No sessions found for $opt_date"

    if [[ -z "$sessions" || "$sessions" == "[]" ]]; then
        die "No sessions found for $opt_date"
    fi

    if [[ -z "$raw_flag" && -z "$LLM_API_KEY" ]]; then
        die "LLM_API_KEY is required for summarized digest. Set it or use --raw for raw transcripts."
    fi

    local output
    output="# OpenCode Daily Summary: $opt_date"
    output+=$'\n\n'

    local session_count
    session_count=$(echo "$sessions" | jq 'length')
    output+="**Sessions:** $session_count"$'\n\n'

    local session_ids
    session_ids=$(echo "$sessions" | jq -r '.[] | .id')

    local idx=0
    while IFS= read -r sid; do
        idx=$((idx + 1))
        local sess_info
        sess_info=$(echo "$sessions" | jq -r ".[] | select(.id == \"$sid\")")

        local title directory start_time msg_count
        title=$(echo "$sess_info" | jq -r '.title')
        directory=$(echo "$sess_info" | jq -r '.directory')
        start_time=$(echo "$sess_info" | jq -r '.time_created')
        msg_count=$(echo "$sess_info" | jq -r '.msg_count')

        echo "[$idx/$session_count] Processing: $title" >&2

        output+="## $title"$'\n'
        output+="| | |"$'\n'
        output+="|---|---|"$'\n'
        output+="| **ID** | \`$sid\` |"$'\n'
        output+="| **Path** | \`$directory\` |"$'\n'
        output+="| **Time** | $(epoch_to_date "$start_time") |"$'\n'
        output+="| **Messages** | $msg_count |"$'\n'
        output+=$'\n'

        local transcript
        transcript=$(get_session_transcript "$sid")

        if [[ -n "$transcript" && "$transcript" != "[]" ]]; then
            if [[ -n "$raw_flag" ]]; then
                local text_output
                text_output=$(format_transcript_text "$transcript")
                output+="### Conversation"$'\n\n'
                output+="$text_output"
            else
                local plain_text
                plain_text=$(echo "$transcript" | jq -r '.[] | "[\(.role)]: \(.text)"' 2>/dev/null)
                local summary
                summary=$(summarize_session "$title" "$plain_text")
                output+="$summary"$'\n'
            fi
        else
            output+="_No transcript content (subagent or tool-only session)_"$'\n'
        fi

        output+=$'\n---\n\n'
    done <<< "$session_ids"

    echo "$output"

    if [[ -n "$write_flag" ]]; then
        local vault_file="$VAULT_PATH/daily-note/$(date -d "$opt_date" +%Y-%m-%d).md"
        mkdir -p "$(dirname "$vault_file")"
        echo "$output" > "$vault_file"
        echo "" >&2
        echo "Digest written to: $vault_file" >&2
    fi
}

cmd_stats() {
    local days="${1:-7}"

    local start_ms end_ms
    end_ms=$(date +%s)000
    start_ms=$(date -d "$days days ago 00:00:00" +%s)000

    echo "=== OpenCode Statistics (last $days days) ==="
    echo ""

    local total_sessions
    total_sessions=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM session WHERE time_created >= $start_ms AND time_created <= $end_ms" 2>/dev/null) || total_sessions=0
    echo "Total Sessions: $total_sessions"

    local total_messages
    total_message=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM message m JOIN session s ON s.id = m.session_id WHERE m.time_created >= $start_ms AND m.time_created <= $end_ms" 2>/dev/null) || total_message=0
    echo "Total Messages: $total_message"
    echo ""

    echo "--- Sessions by Day ---"
    sqlite3 -header -column "$DB_PATH" "SELECT date(time_created/1000, 'unixepoch') as day, COUNT(*) as sessions FROM session WHERE time_created >= $start_ms AND time_created <= $end_ms GROUP BY day ORDER BY day DESC" 2>/dev/null

    echo ""
    echo "--- Top Projects ---"
    sqlite3 -header -column "$DB_PATH" "SELECT directory as project, COUNT(*) as sessions FROM session WHERE time_created >= $start_ms AND time_created <= $end_ms GROUP BY directory ORDER BY sessions DESC LIMIT 5" 2>/dev/null

    local total_tokens
    total_tokens=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(CAST(json_extract(data, '\$.input') AS INTEGER) + CAST(json_extract(data, '\$.output') AS INTEGER)), 0) FROM part WHERE type = 'step-finish' AND time_created >= $start_ms AND time_created <= $end_ms" 2>/dev/null) || total_tokens=0
    echo ""
    echo "--- Token Usage ---"
    echo "Total Tokens: $total_tokens"

    local total_cost
    total_cost=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(CAST(json_extract(data, '\$.cost') AS REAL)), 0) FROM part WHERE type = 'step-finish' AND time_created >= $start_ms AND time_created <= $end_ms" 2>/dev/null) || total_cost=0
    echo "Total Cost: \$$total_cost"
}

main() {
    [[ $# -eq 0 ]] && usage && return

    check_deps

    local cmd="$1"
    shift

    case "$cmd" in
        -h|--help|help)
            usage
            ;;
        sessions)
            cmd_sessions "$@"
            ;;
        transcript)
            cmd_transcript "$1"
            ;;
        search)
            cmd_search "$1" "${2:-20}"
            ;;
        digest)
            cmd_digest "$@"
            ;;
        stats)
            cmd_stats "${1:-7}"
            ;;
        *)
            die "Unknown command: $cmd"
            ;;
    esac
}

main "$@"
