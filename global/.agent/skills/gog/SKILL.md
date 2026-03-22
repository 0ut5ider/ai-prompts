---
name: gog
description: Google Workspace CLI (gogcli) for Gmail. JSON-first output, multiple accounts, least-privilege auth.
homepage: https://gogcli.sh , https://github.com/steipete/gogcli
---

# gog

CLI for Gmail. Requires OAuth setup.

## Setup (once)

- `gog auth credentials /path/to/client_secret.json`
- `gog auth add you@gmail.com --services gmail`
- `gog auth list`
- To add more scopes later: `gog auth add you@gmail.com --services gmail --force-consent`

## Account Selection

Before running any `gog` command, check if `GOG_ACCOUNT` is set. If not, run:

```bash
export GOG_ACCOUNT=aonsen@gmail.com
```

Other options:
- Flag: `--account you@gmail.com`
- Aliases: `gog auth alias set personal me@gmail.com`, then `--account personal`
- Auto-select (single account): `--account auto`

## Output Formats

- Default: human-friendly table
- `--json`: JSON on stdout (best for scripting/agents)
- `--plain`: stable TSV on stdout (tabs preserved)
- Errors/progress go to stderr
- Useful pattern: `gog --json gmail search '...' | jq .`

## Global Flags

- `--account <email|alias|auto>` - account to use
- `--json` - JSON output
- `--plain` - TSV output
- `--force` - skip confirmations
- `--no-input` - never prompt, fail instead (CI/agents)
- `--verbose` - verbose logging

## Gmail

### Search and Read

- Thread search (one row per thread): `gog gmail search 'newer_than:7d' --max 10`
- Message search (one row per email): `gog gmail messages search "in:inbox from:ryanair.com" --max 20`
- Message search with body: `gog gmail messages search 'newer_than:1d' --max 5 --include-body --json`
- Get thread: `gog gmail thread get <threadId>`
- Get thread + download attachments: `gog gmail thread get <threadId> --download --out-dir ./attachments`
- Get message: `gog gmail get <messageId>`
- Get message metadata only: `gog gmail get <messageId> --format metadata`
- Get attachment: `gog gmail attachment <messageId> <attachmentId> --out ./file.bin`
- Gmail web URL: `gog gmail url <threadId>`

### Send and Compose

- Plain text: `gog gmail send --to a@b.com --subject "Hi" --body "Hello"`
- Multi-line from file: `gog gmail send --to a@b.com --subject "Hi" --body-file ./message.txt`
- From stdin: `gog gmail send --to a@b.com --subject "Hi" --body-file -`
- HTML body: `gog gmail send --to a@b.com --subject "Hi" --body-html "<p>Hello</p>"`
- Reply with quoted original: `gog gmail send --reply-to-message-id <msgId> --quote --to a@b.com --subject "Re: Hi" --body "My reply"`

### Drafts

- List: `gog gmail drafts list`
- Create: `gog gmail drafts create --to a@b.com --subject "Draft" --body "Body"`
- Create from file: `gog gmail drafts create --to a@b.com --subject "Draft" --body-file ./message.txt`
- Update: `gog gmail drafts update <draftId> --subject "Updated" --body "New body"`
- Send draft: `gog gmail drafts send <draftId>`

### Labels

- List labels: `gog gmail labels list`
- Get label (with counts): `gog gmail labels get INBOX --json`
- Create label: `gog gmail labels create "My Label"`
- Modify thread labels: `gog gmail thread modify <threadId> --add STARRED --remove INBOX`
- Delete label: `gog gmail labels delete <labelIdOrName>`

### Batch Operations

- Batch delete: `gog gmail batch delete <msgId1> <msgId2>`
- Batch modify: `gog gmail batch modify <msgId1> <msgId2> --add STARRED --remove INBOX`

### Filters

- List: `gog gmail filters list`
- Create: `gog gmail filters create --from 'noreply@example.com' --add-label 'Notifications'`
- Delete: `gog gmail filters delete <filterId>`

### Settings

- Auto-forward: `gog gmail autoforward get|enable|disable`
- Forwarding: `gog gmail forwarding list|add`
- Send-as: `gog gmail sendas list|create`
- Vacation: `gog gmail vacation get|enable|disable`
- Delegates (Workspace): `gog gmail delegates list|add|remove`

### Email Tracking

- Setup: `gog gmail track setup --worker-url https://gog-email-tracker.<acct>.workers.dev`
- Send with tracking: `gog gmail send --to a@b.com --subject "Hi" --body-html "<p>Hello</p>" --track`
- Check opens: `gog gmail track opens <tracking_id>` or `gog gmail track opens --to a@b.com`
- `--track` requires exactly 1 recipient and an HTML body (`--body-html` or `--quote`)

### Watch (Pub/Sub Push)

- Start: `gog gmail watch start --topic projects/<p>/topics/<t> --label INBOX`
- Serve: `gog gmail watch serve --bind 127.0.0.1 --token <shared> --hook-url <url>`
- History: `gog gmail history --since <historyId>`

## Email Formatting

- Prefer plain text. Use `--body-file` for multi-paragraph messages (or `--body-file -` for stdin).
- Same `--body-file` pattern works for drafts and replies.
- `--body` does not unescape `\n`. For inline newlines, use a heredoc or `$'Line 1\n\nLine 2'`.
- Use `--body-html` only when rich formatting is needed.
- HTML tags: `<p>` for paragraphs, `<br>` for line breaks, `<strong>` for bold, `<em>` for italic, `<a href="url">` for links, `<ul>`/`<li>` for lists.

Plain text via stdin example:

```bash
gog gmail send --to recipient@example.com \
  --subject "Meeting Follow-up" \
  --body-file - <<'EOF'
Hi Name,

Thanks for meeting today. Next steps:
- Item one
- Item two

Best regards,
Your Name
EOF
```

HTML example:

```bash
gog gmail send --to recipient@example.com \
  --subject "Meeting Follow-up" \
  --body-html "<p>Hi Name,</p><p>Next steps:</p><ul><li>Item one</li><li>Item two</li></ul><p>Best regards,<br>Your Name</p>"
```

## Batch Processing Examples

```bash
# Mark all emails from a sender as read
gog --json gmail search 'from:noreply@example.com' --max 200 | \
  jq -r '.threads[].id' | \
  xargs -n 50 gog gmail labels modify --remove UNREAD

# Archive old emails
gog --json gmail search 'older_than:1y' --max 200 | \
  jq -r '.threads[].id' | \
  xargs -n 50 gog gmail labels modify --remove INBOX
```

## Notes

- Set `GOG_ACCOUNT=you@gmail.com` to avoid repeating `--account`.
- For scripting/agents, prefer `--json` plus `--no-input`.
- `gog gmail search` returns one row per thread; use `gog gmail messages search` when you need every individual email returned separately.
- Add `--include-body` to `gog gmail messages search` to fetch and decode message bodies.
- Confirm before sending mail.
- Config file: `~/.config/gogcli/config.json` (JSON5)
- Config commands: `gog config path|list|get|set|unset`
