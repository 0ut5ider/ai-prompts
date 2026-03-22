---
name: session-history
description: |
  Query and summarize your OpenCode conversation history. Use when the user asks about:
  - "What sessions did I work on today/yesterday?"
  - "Show me my conversations from this week"
  - "Find sessions about X" or "search for topic Y"
  - "Summarize my coding sessions"
  - "How much did I use OpenCode?" or "show my stats"
  - "What did I do last Tuesday?"
  - Read or review a specific session's transcript
  Trigger with phrases like "session history", "my conversations", "what did I work on", "show me sessions", "search sessions", "daily digest", "stats", "token usage", "conversation transcript"
allowed-tools: Bash, Read, Write
version: 1.0.0
author: Adrian <adrian@construkted.com>
license: MIT
---

# Session History Skill

This skill provides access to your complete OpenCode conversation history stored in the local SQLite database. Use it to help users review, search, and summarize their coding sessions.

## How I Work

When activated, I load the `oc-history.sh` script which provides a safe interface to query the OpenCode database. The script handles all SQL queries and returns clean, structured output.

## Available Commands

### 1. List Sessions

Shows all sessions for a given date:

```bash
oc-history.sh sessions --date 2026-02-21
oc-history.sh sessions                    # today (default)
oc-history.sh sessions --project my-project
```

Output includes: session ID, title, timestamp, message count, project.

### 2. Get Transcript

Retrieves the full conversation text for a specific session:

```bash
oc-history.sh transcript ses_3abccc83affeB7gQq7Cs6F00Up
```

Output format:
```
[USER] ses_3abccc83aff 2026-02-21 09:30:00
<prompt text>

[ASSISTANT] ses_3abccc83aff 2026-02-21 09:30:15
<response text>
```

### 3. Search Sessions

Searches across all your conversation history for a keyword:

```bash
oc-history.sh search "texture atlas"
oc-history.sh search "authentication" --limit 10
```

Returns session ID, title, timestamp, and text snippet for each match.

### 4. Daily Digest (AI-Summarized)

Generates an AI-summarized daily digest. Each session transcript is sent to an LLM for concise structured summarization.

```bash
oc-history.sh digest --date 2026-02-21              # summarized to stdout
oc-history.sh digest --date 2026-02-21 --write       # summarized to Obsidian vault
oc-history.sh digest --date 2026-02-21 --raw         # raw transcripts, no LLM
oc-history.sh digest --date 2026-02-21 --raw --write  # raw transcripts to vault
```

Requires `LLM_API_KEY` and `LLM_BASE_URL` env vars (unless `--raw`).

Each session summary includes: Topics, Key Decisions, Outcomes, Files Modified, Open Questions.

The `--write` flag saves output to `~/obsidian_vault/daily-note/YYYY-MM-DD-opencode_digest.md`.

### 5. Statistics

Shows usage statistics:

```bash
oc-history.sh stats --days 7           # last 7 days (default)
oc-history.sh stats --days 30         # last 30 days
```

Shows:
- Total sessions and messages
- Sessions per day breakdown
- Top projects by session count
- Total tokens used
- Total API cost

## Common Usage Patterns

### Finding Recent Work
```
User: "What did I work on yesterday?"
→ oc-history.sh sessions --date yesterday's date
```

### Searching Past Conversations
```
User: "Did I have any sessions about texture atlases?"
→ oc-history.sh search "texture atlas"
→ If found, get transcript: oc-history.sh transcript <session_id>
```

### Daily Summary
```
User: "Summarize my coding work today"
→ oc-history.sh digest --date today
→ Present the markdown to user for review
→ Optionally write to vault: oc-history.sh digest --date today --write
```

### Checking Usage
```
User: "How much have I used OpenCode this week?"
→ oc-history.sh stats --days 7
```

### Reviewing a Specific Session
```
User: "What was that session about mesh splitting?"
→ oc-history.sh search "mesh split"
→ oc-history.sh transcript <session_id>
```

## Script Location

The script is located at:
```
~/.config/opencode/skills/session-history/scripts/oc-history.sh
```

The skill automatically adds this to PATH, so you can call `oc-history.sh` directly.

## Database

The script reads from:
```
~/.local/share/opencode/opencode.db
```

This is the same database OpenCode uses. It contains:
- `session` table: session metadata (title, project, timestamps)
- `message` table: message metadata (role, model, tokens)
- `part` table: actual conversation text (in JSON `text` field where `type='text'`)

## Output Formatting

- All output is plain text formatted for readability
- Timestamps are converted from epoch milliseconds to human-readable format
- JSON data is parsed and extracted for clean presentation
- Errors include helpful messages (e.g., "Session not found", "No matches for keyword")

## Limits

- Search returns max 20 results by default (use `--limit N` to adjust)
- Stats default to 7 days (use `--days N` to adjust)
- Transcript returns all message parts with `type='text'` — tool calls and reasoning are excluded

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_BASE_URL` | `https://cerebo.roci.me` | OpenAI-compatible API endpoint |
| `LLM_API_KEY` | (none) | API key for LLM summarization |
| `LLM_MODEL` | `MiniMax-M1-80k` | Model name for summarization |
| `OPENCODE_DB` | `~/.local/share/opencode/opencode.db` | Database path |
| `OPENCODE_VAULT` | `~/obsidian_vault` | Obsidian vault path |

## Notes

- If the user asks for a specific date that doesn't exist, the script returns "No sessions found"
- The `--write` flag on digest requires the vault path to be set via `OPENCODE_VAULT` env var
- The script requires `sqlite3`, `jq`, and `curl` to be installed
- Transcripts are truncated to 12,000 chars before sending to the LLM to manage token costs
- Use `--raw` to bypass LLM summarization entirely
