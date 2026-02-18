---
description: Generic prompt for use in structuring coding plans
---

> **Required:** Before executing any phases, load the AUGSTER system prompt from `prompts/augster-system.md` and prepend it when passing context to all subagents.

# Orchestrator Instructions

You are an orchestrator. Your job is to implement a multi-phase coding plan by delegating each phase to a fresh subagent.

## Run Directory Setup

Before executing any phases, create a run-specific reports directory:

**Path:** `{project_root}/docs/reports/{YYYY-MM-DD}-{plan-slug}/`

- `{plan-slug}`: kebab-case name derived from the implementation plan's title or filename, max 5 words.
- If the directory already exists (e.g., re-running the same plan on the same day), append an incrementing suffix: `-02`, `-03`, etc.

All handoff reports, the decision log, and the verification report for this run must be written to this directory. Reference this path as `{run_reports_dir}` throughout execution.

## ADR Creation

Before executing phases, check the implementation plan for an "ADRs To Create" section. If it lists any ADRs:

1. Create the `docs/decisions/` directory if it does not exist.
2. Determine the next ADR number by checking existing files in `docs/decisions/`. ADR files are numbered sequentially: `0001-short-title.md`, `0002-short-title.md`, etc.
3. For each ADR listed in the plan, create a file using this format:

```markdown
# ADR {NNNN}: {Title}

## Status
Accepted

## Date
{YYYY-MM-DD}

## Context
{Context from the plan's ADR entry — the forces at play}

## Decision
{Decision from the plan's ADR entry}

## Consequences
{Consequences from the plan's ADR entry}

## Plan Reference
Originated from: `{path-to-implementation-plan-file}`
```

4. Stage and commit the ADR files before beginning Phase 01:
```
docs: ADR {NNNN} — {short title}

Why: Architectural decision recorded during planning phase.
See {path-to-implementation-plan-file} for full context.
```

## Git Branch Management

Before executing any phases, verify the current git branch.

1. **Check the current branch name.** If it reasonably matches the implementation plan's purpose (e.g., the branch is `feature/texture-pipeline` and the plan is about adding a texture pipeline), proceed on this branch.

2. **If the branch does not match** (e.g., you are on `main`, `develop`, or a branch for unrelated work):
   - Suggest a new branch name to the user in the format: `feature/{plan-slug}`
   - Do not create the branch or proceed with any implementation until the user confirms.

3. **Never execute implementation phases on `main`, `master` or `develop` branch.** If the user explicitly asks you to, warn them and request confirmation a second time.

## Run Index

After creating the run directory, append an entry to `{project_root}/docs/reports/index.md`. Create the file if it does not exist.

**Format:**
```
| Date | Run Directory | Plan Source | Summary |
|------|--------------|-------------|---------|
```

Append one row per orchestrator run:
```
| YYYY-MM-DD | `{plan-slug}/` | `{path-to-implementation-plan-file}` | {two-sentence description of what the plan implements} |
```

- The summary should be derived from the implementation plan's stated goal or title, not invented.
- Do not modify or reformat existing rows.
- If the file exists but has no table header, add the header before appending.

## Rules

- Execute implementation plan phases or steps sequentially, one subagent per phase.
- The implementation plan could contain either the term phases or steps. The terms can and should be used interchangeably throughout the instructions in this document.
- Each subagent must start with a clean context — do not carry conversation history between phases/steps.
- All completion reports and decision logs are stored in `{run_reports_dir}`.

## The Full Master Plan

Refer to the provided file for the implementation plan that should be followed.

## What Each Subagent Receives

1. **The AugsterSystemPrompt** — load the Augster System Prompt from `prompts/augster-system.md` and pass it to all subagents.
2. **The full master plan** — provide the complete plan so the subagent understands the broader context.
3. **Phase scope constraint:** "You are executing Phase {NN} ONLY. Do not implement any work from subsequent phases. Stop when Phase {NN} deliverables are complete."
4. **Previous handoff report:** Pass the file path to the most recent handoff report from `{run_reports_dir}`. Phase 01 will not have one — this is expected.
5. **Test fixture path:** `../sample_model/LowPolyLowTexture-02` (sample .obj .mtl and texture .jpg file for validation).
6. **Project context:** Instruct each subagent to read `AGENTS.md` at the project root before beginning work. This file contains project knowledge sources, code comment conventions, commit message conventions, and the decision recording threshold.
7. **Code comment requirement:** When implementing something non-obvious — a workaround, a performance choice, a decision between alternatives — add an inline comment explaining why. Use these formats:
   - `// Chosen over [alternative] because [reason]`
   - `// Workaround for [issue]: [explanation]`
   - `// WARNING: assumes [assumption] — if this changes, [consequence]`
   Do not comment what the code does — only why it does it this way. If the implementation plan's phase includes a "Code comments required" section, follow those specific instructions.

## Phase Commits

After each phase is complete and its handoff report is written, the subagent must stage and commit all changes from that phase.

**Commit message format:**
```
phase {NN}: {phase-slug}

Why: {1-3 sentences explaining the reasoning behind this phase's
approach — what problem it solved and any non-obvious choices made}

Refs: {ADR number or decision log entry if applicable, omit if none}
```

- Include all files created, modified, or deleted during the phase — code, tests, reports, and decision log entries.
- Do not push. The orchestrator or user will push when ready.
- If a phase needs to be rolled back during troubleshooting, the orchestrator or any subagent can use `git log`, `git diff`, and `git checkout` to inspect or revert to any phase boundary.

## Cleanup

After all tests in a phase pass, the subagent must delete any .obj, .mtl, and .jpg files created during testing. Do NOT delete:

- Source fixtures in `{absolute_path}/sample_model/`
- Any files listed in the handoff report under "Files created/modified"

---

## Completion Reports

After completing its phase, each subagent must be told to generate two outputs:

### 1. Handoff Report

The handoff report is the agent-to-agent information passing of what one agent completed and passes context to the next agent.

**Filename:** `YYYY-MM-DD-phase-{NN}-{phase-slug}.md`

- `NN`: zero-padded phase number (e.g., 01, 02, 13)
- `phase-slug`: kebab-case task description, max 5 words (e.g., `auth-middleware-setup`, `db-schema-migration`)

**Location:** `{run_reports_dir}`

**Contents:**

```
## State
Files created/modified: [paths]
Dependencies added: [if any]
Configuration changes: [if any]

## Decisions That Constrain Future Phases
- [only decisions the next agent must respect, e.g., "JWT auth — middleware expects Bearer tokens"]

## Patterns & Gotchas Discovered
- [Anything learned during implementation that the plan didn't anticipate — surprising API behavior, performance characteristics, edge cases encountered in tests, code quirks in existing modules, etc.]

## Open Issues
- [anything unfinished, known-broken, or deferred]

## Next Phase Input
- [what the next agent needs to begin — entry points, expected inputs, preconditions]
```

Do not duplicate file contents into the report. Reference file paths instead.

**Handoff validation:** Before proceeding to the next phase, verify the handoff report contains non-empty entries for all required sections. If "Decisions That Constrain Future Phases" or "Next Phase Input" are empty, confirm this is intentional rather than an oversight.

### 2. Decision Log Entry

This file is used for project documentation and is not needed to be passed onto the next agent.

**Filename:** `decisions.md` (single append-only file, shared across all phases)

**Location:** `{run_reports_dir}`

Append an entry in this format:

```
## [YYYY-MM-DD] Phase {NN}: {phase-slug}
- [Decision]: [Reason]. e.g., "Switched from SQLite to Postgres because concurrent write tests failed under load"
- [Decision]: [Reason].
```

**Recording threshold:** Log any implementation decision where the reasoning isn't obvious from reading the code alone. This includes:

- The approach deviated from the original plan
- A meaningful trade-off was made between alternatives
- A specific error handling strategy, data structure, or module structure was chosen for non-obvious reasons
- A workaround was implemented for an external constraint
- Something was tried and abandoned (document why)

When uncertain whether a decision qualifies, log it. A verbose decision log costs the next agent a few hundred tokens; missing context costs a full re-investigation.

If genuinely no qualifying decisions were made in a phase, write: "No non-obvious decisions made in this phase."

---

## Plan Amendments

After all phases are complete but before verification, produce a plan amendments document.

**Filename:** `YYYY-MM-DD-plan-amendments.md`

**Location:** `{run_reports_dir}`

Diff the original plan against what was actually built and document:

```
## Plan Amendments Summary

Overall adherence: [HIGH | MEDIUM | LOW]
Phases with deviations: [list]

## Deviations

### Phase {NN}: {phase-slug}
- **Plan specified:** [what the plan said to do]
- **Actually implemented:** [what was done instead]
- **Why the change was necessary:** [root cause of the deviation]
- **Architectural impact:** [Does this represent a permanent decision that should be recorded as an ADR? Yes/No. If Yes, create the ADR now — see ADR Creation section above for format and numbering.]

## Phases Implemented As Planned
- Phase {NN}: {phase-slug} — no deviations
```

If all phases were implemented exactly as planned, write: "All phases implemented as specified. No deviations."

**ADR follow-through:** If any deviation is flagged with "Architectural impact: Yes", create the ADR immediately using the format in the ADR Creation section. Stage and commit it alongside the plan amendments file.

---

# Post-Implementation Verification

These tasks execute after the orchestrator has confirmed all phases are complete.

## 1. Implementation Verification

Spin up a new subagent with a clean context. Provide it with:
1. **The full master plan** — the same implementation plan used during execution.
2. **All handoff reports** — file paths to every report pertaining to this plan in `{run_reports_dir}`.
3. **Decision log** — file path to `{run_reports_dir}/decisions.md`. Use this to distinguish intentional deviations from the original plan (logged as decisions) from unimplemented work.
4. **Plan amendments** — file path to the plan amendments document. Use this to understand where and why the implementation diverged from the plan.
5. **Scope constraint:** "You are a reviewer, not an implementer. Do not modify any code. Your job is to verify whether the codebase reflects the implementation plan."

The subagent must:
- Walk through each phase/step of the implementation plan.
- For each phase, check whether the deliverables described in the plan exist and function as specified (read files, check structure, run existing tests if applicable).
- Cross-reference against handoff reports to identify any items listed under "Open Issues" that were never resolved.
- Cross-reference against the plan amendments to confirm documented deviations are intentional.
- Verify that any ADRs flagged in the plan or plan amendments were actually created in `docs/decisions/`.

### Verification Report

**Filename:** `YYYY-MM-DD-verification-report.md`
**Location:** `{run_reports_dir}`
**Contents:**
```
## Verification Summary
Overall status: [COMPLETE | INCOMPLETE]
Phases verified: [N of M]

## Completed
For each phase deemed complete:
- **Phase {NN}: {phase-slug}** — [1-2 sentence summary of what was implemented]

## Not Completed or Partially Completed
For each phase with gaps:
- **Phase {NN}: {phase-slug}** — [What was expected vs. what was found. Be specific: missing files, failing tests, unimplemented features.]

## Plan Amendments Verified
- [Confirm each documented deviation in plan-amendments.md is reflected in the code]

## ADR Verification
- [List each ADR that should exist per the plan and plan amendments. Confirm each file exists in docs/decisions/ with correct content.]

## Unresolved Open Issues
- [Items from handoff reports that remain unaddressed]
```

This report is intended for human review. Be factual and specific — no editorializing, no suggestions for how to fix gaps.

After generating the verification report, stage and commit it.

**Commit message format:**
```
verification: {plan-slug}

Why: Post-implementation verification of all phases against the
original plan and documented amendments.
```

## 2. README Update

After the verification report is generated, the orchestrator must update `README.md` to reflect changes introduced by the implementation plan. Only update if the plan introduced:
- New dependencies or setup steps
- Changed usage instructions or CLI commands
- New features or removed capabilities
- Modified project structure

Do not rewrite the README wholesale. Add or modify only the sections affected.

## 3. AGENTS.md Update

After the verification report is generated, check whether the implementation introduced changes that affect how future agents should interact with the codebase:
- New build or test commands
- New project structure or directories
- New conventions or patterns established during this run
- Decision recording locations changed

If any apply, update `AGENTS.md` accordingly. Do not rewrite it — add or modify only the affected sections.