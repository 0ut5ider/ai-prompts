# Session History Skill

Query and summarize your OpenCode conversation history directly from the chat window.

## Prerequisites

```bash
# Install dependencies (required)
sudo dnf install -y sqlite jq curl   # Fedora
sudo apt install -y sqlite3 jq curl  # Debian/Ubuntu
```

For AI-summarized digests, set these environment variables (e.g., in `~/.bashrc`):

```bash
export LLM_BASE_URL="https://cerebo.roci.me"
export LLM_API_KEY="your-api-key-here"
export LLM_MODEL="MiniMax M2.5"              # optional, this is the default
```

## Installation

The skill is auto-discovered by OpenCode from:
```
~/.config/opencode/skills/session-history/
```

No additional configuration needed.

## Usage from OpenCode Chat

Simply ask the AI agent questions about your session history:

### List Recent Sessions
```
"What did I work on yesterday?"
"Show me my sessions from last week"
"List all sessions for today"
```

### Search Conversations
```
"Find sessions about texture atlases"
"Search for anything about authentication"
"Did I discuss mesh splitting recently?"
```

### Get Full Transcript
```
"What's in session ses_3abccc83affeB7gQq7Cs6F00Up?"
"Show me the conversation from that session"
```

### Daily Digest
```
"Summarize my coding work today"
"What's my daily digest for yesterday?"
```

The agent will automatically load this skill and use `oc-history.sh` to fetch the data.

## Manual Usage (Bypass Agent)

If you want to run the script directly:

```bash
~/.config/opencode/skills/session-history/scripts/oc-history.sh <command> [options]
```

### Commands

| Command | Description |
|---------|-------------|
| `sessions --date YYYY-MM-DD` | List sessions for a date (default: today) |
| `sessions --project <path>` | Filter by project directory path |
| `transcript <session_id>` | Get full conversation text |
| `search "<keyword>"` | Search all sessions |
| `digest --date YYYY-MM-DD` | Generate AI-summarized daily digest |
| `digest --date YYYY-MM-DD --raw` | Generate raw transcript digest (no LLM) |
| `stats --days N` | Show usage statistics |

### Examples

```bash
# Today's sessions
oc-history.sh sessions

# Sessions from specific date
oc-history.sh sessions --date 2026-02-20

# Get transcript
oc-history.sh transcript ses_3abccc83affeB7gQq7Cs6F00Up

# Search
oc-history.sh search "texture atlas"

# AI-summarized digest to Obsidian
oc-history.sh digest --date 2026-02-20 --write

# Raw transcript digest (no LLM needed)
oc-history.sh digest --date 2026-02-20 --raw --write

# Stats for last 30 days
oc-history.sh stats --days 30

# Get help
oc-history.sh --help
```

## Obsidian Integration

To write digests directly to Obsidian:

1. Set the vault path (or use default `~/obsidian_vault`):
   ```bash
   export OPENCODE_VAULT="$HOME/your-obsidian-vault"
   ```

2. Use `--write` flag:
   ```bash
   oc-history.sh digest --date 2026-02-20 --write
   ```

Output: `~/obsidian_vault/daily-note/2026-02-20.md`

## How It Works

- **SKILL.md**: Teaches the AI agent when to activate and how to use the script
- **oc-history.sh**: Pre-built query interface that runs safe SQL against `opencode.db`
- The agent doesn't compose raw SQL -- it just calls the script with arguments

### Digest Flow (summarized mode)
```
SQLite DB --> Extract transcripts --> Truncate to 12K chars/session --> LLM API --> Structured summary --> Obsidian vault
```

Each session is summarized independently with a structured prompt that produces:
Topics, Key Decisions, Outcomes, Files Modified, Open Questions.

### Architecture
- No risk of arbitrary SQL injection
- The skill is testable independently from the agent
- The human user gets a reliable, predictable interface

## Cron Automation

To run the digest automatically at end of day:

```bash
# Add to crontab -e
55 23 * * * LLM_API_KEY="your-key" /home/outsider/.config/opencode/skills/session-history/scripts/oc-history.sh digest "$(date +\%Y-\%m-\%d)" --write 2>/dev/null
```

## Database Location

The script reads from:
```
~/.local/share/opencode/opencode.db
```

Tables used:
- `session` — Session metadata (title, directory, timestamps)
- `message` — Message metadata (role, model, tokens)
- `part` — Conversation text (type='text' contains actual messages)