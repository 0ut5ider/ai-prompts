---
description: Extract and summarize articles from Google Alert Daily Digest emails
---

## Google Alerts Digest Extraction

Parse the arguments provided. The following flags are supported with these defaults:

- `--topic` (default: `photogrammetry`) — the topic section to extract from digest emails (case-insensitive match)
- `--days` (default: `30`) — how many days back to search
- `--email` (default: `aonsen@gmail.com`) — Gmail account to search
- `--output` (default: `./google_alerts_digest.csv`) — CSV file path (append-only, never overwrite)

Arguments provided: $ARGUMENTS

If no arguments are provided, use all defaults.

---

### Step 1: Search Gmail

Run the following command using Bash (set GOG_ACCOUNT to the email param):

```
export GOG_ACCOUNT=<email>
gog --json gmail messages search 'subject:"Google Alert - Daily Digest" newer_than:<days>d' --max 100 --include-body
```

This returns JSON with a `messages` array. Each message has `date`, `subject`, and `body` fields.

### Step 2: Parse Email Bodies for Topic Articles

Each email body contains one or more sections with this structure:

```
=== News - N new results for [topic_name] ===

Article Title Line 1
Article Title Line 2 (optional continuation)
Source Name
Snippet text line 1
snippet text line 2...
<https://www.google.com/url?...&url=ACTUAL_ENCODED_URL&...>

Next Article Title
...

- - - - - - - - - - - - - - - - - -
Unsubscribe from this Google Alert:
```

For each email:
1. Split the body by `=== News -` section headers
2. Keep ONLY sections where the header contains `[<topic>]` (case-insensitive match against the --topic param)
3. Within each matching section, extract each article block. An article block consists of:
   - **Title**: The text lines before the source name (may span 1-2 lines, typically the first line(s) after a blank line)
   - **Source**: The short source name line (e.g., "Nature", "Drone Life")
   - **Snippet**: The descriptive text between the source and the URL
   - **URL**: Inside angle brackets `<...>`, it's a Google redirect URL. Extract the actual destination URL from the `url=` query parameter. URL-decode it.
4. Record the email `date` for each article extracted from that email.

### Step 3: Load Existing CSV and Deduplicate

1. If the output CSV file exists, read it and build a set of all URLs already present (the `url` column)
2. Normalize URLs for comparison: lowercase, strip trailing slashes, remove `utm_*` query parameters
3. Filter the extracted articles: skip any article whose normalized URL already exists in the CSV
4. If zero new articles remain, report "0 new articles found, CSV unchanged" and stop

### Step 4: Fetch and Summarize Each New Article (via Subagents)

For each new article, launch a **general subagent** using the Task tool. Launch them in **parallel batches** (6-8 at a time) for throughput.

Each subagent receives this prompt (fill in the URL, title, and snippet):

---

**Instructions**: Fetch the article at the following URL using WebFetch and extract information **strictly from the article content only**. Do NOT supplement, infer, or fill gaps with your training knowledge. If a detail is not explicitly stated in the article, do not include it. If the article is too thin to extract meaningful information, say so rather than fabricating detail.

URL: <article_url>

Extract the following in 3-4 sentences:
1. What happened (the core news event or finding)
2. What specific technologies, software, or hardware are mentioned in the article
3. The application domain or industry
4. Any notable numbers explicitly stated (accuracy, market size, performance metrics, cost)

Then assign ONE category tag from this list: `software-release`, `research-paper`, `market-report`, `heritage`, `surveying`, `agriculture`, `VFX`, `industry-news`, `acquisition`, `education`, `infrastructure`, `defense`, `gaming`

If the article URL is inaccessible (403, paywall, timeout), extract what you can from this snippet ONLY — do not infer beyond what the snippet says:
Title: <article_title>
Snippet: <email_snippet>
And prefix the summary with "(from email snippet only)".

Return in this exact format:
CATEGORY: [tag]
SUMMARY: [your 3-4 sentence extraction]

---

### Step 5: Parse Subagent Results

From each subagent response, extract:
- The `CATEGORY:` line value (strip whitespace, lowercase)
- The `SUMMARY:` line value (everything after "SUMMARY: ")

### Step 6: Append to CSV

CSV columns: `date,title,url,category,summary`

1. If the output file does not exist, create it with the header row: `date,title,url,category,summary`
2. Append each new article as a row. Properly escape/quote fields containing commas or double quotes (standard CSV quoting rules).
3. Do NOT rewrite existing rows. Only append.

### Step 7: Report Results

Output a summary:
- Total digest emails found
- Total articles extracted for the topic
- Number skipped (already in CSV)
- Number of new articles appended
- Number where webfetch failed (used email snippet fallback)
- The output file path
