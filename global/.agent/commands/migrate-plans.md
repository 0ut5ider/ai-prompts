---
description: Migrate legacy plan files from feature_/bug_fix_ naming to YYYY-MM-DD-type-slug-plan.md convention, and patch all references in docs/reports/index.md
---

# Migrate Legacy Plan Files

Rename plan files in `docs/plans/` from the old `write-plan` naming convention
(`feature_<slug>.md`, `bug_fix_<slug>.md`) to the compound-engineering convention
(`YYYY-MM-DD-<type>-<descriptive-slug>-plan.md`), and update all references in
`docs/reports/index.md`.

## Step 1: Discover Legacy Files

Find all plan files that use the old naming pattern:

```bash
ls docs/plans/ | grep -E '^(feature|bug_fix)_'
```

If no files match, report: "No legacy plan files found. Nothing to migrate." and stop.

## Step 2: For Each Legacy File, Derive the New Name

For each file found:

1. Read the file's frontmatter (if present) for `title`, `type`, and `date`.
2. If no frontmatter, read the first heading (`# Title`) for the title, and infer
   type from filename prefix:
   - `feature_*` -> type `feat`
   - `bug_fix_*` -> type `fix`
3. For date: use frontmatter `date` if present; otherwise use the file's modification
   date (`stat -c %y <file> | cut -d' ' -f1`).
4. Derive slug: take the title, lowercase it, strip special characters, replace spaces
   with hyphens, keep 3-5 meaningful words (drop articles, prepositions, conjunctions).
5. Construct new filename: `YYYY-MM-DD-<type>-<slug>-plan.md`

Present the proposed renames to the user before doing anything:

```
Proposed renames:
  feature_texture_pipeline.md
    -> 2026-02-20-feat-texture-pipeline-plan.md

  bug_fix_cart_total.md
    -> 2026-02-15-fix-cart-total-plan.md

Proceed? (yes/no)
```

Do not rename until the user confirms.

## Step 3: Rename Files

For each confirmed rename:

```bash
mv docs/plans/<old-name> docs/plans/<new-name>
```

## Step 4: Patch docs/reports/index.md

Read `docs/reports/index.md`. For each renamed file, find any row in the table
where the `Plan Source` column contains the old filename and replace it with the
new filename path.

If the old filename in the index does not exactly match what was on disk (e.g.,
underscores vs hyphens, minor slug differences), use fuzzy matching: strip
punctuation, lowercase, and compare slugs. Report any ambiguous matches to the
user before patching.

After patching, show a diff of the index changes and ask for confirmation before
writing.

## Step 5: Add YAML Frontmatter (if missing)

For each renamed file that had no YAML frontmatter, prepend:

```yaml
---
title: [derived from first heading]
type: [feat|fix|refactor]
status: active
date: YYYY-MM-DD
---
```

Use the same date and type derived in Step 2.

## Step 6: Commit

```bash
git add docs/plans/ docs/reports/index.md
git commit -m "refactor(plans): migrate legacy plan filenames to compound-engineering convention

Why: Unified naming across write-plan, execute-plan, and workflows:plan.
All plans now use YYYY-MM-DD-<type>-<slug>-plan.md format."
```

## Step 7: Report

Print a summary:
- Files renamed: N
- Index rows updated: N
- Frontmatter added: N
- Any files skipped and why
