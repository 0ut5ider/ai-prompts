# AGENTS.md

This file provides context for any AI agent working on this codebase. Read this before beginning any task.

For project-specific context (build commands, paths, testing methodology, versioning), see `PROJECT_CONTEXT.md`.

## Project Knowledge Sources

This project maintains institutional knowledge in several locations. Before investigating any bug or planning any feature, check these sources for prior context:

### 1. Decision Logs

Location: `docs/reports/*/decisions.md`
Contains: Architectural decisions, trade-offs, and rejected approaches from previous implementation runs. Check these BEFORE proposing an approach — the thing you're about to suggest may have already been tried and rejected.

### 2. Plan Amendments

Location: `docs/reports/*/*-plan-amendments.md`
Contains: Where previous implementations deviated from their original plans, and why. Useful for understanding why the code doesn't match what you'd expect from reading the plans alone.

### 3. Architecture Decision Records

Location: `docs/decisions/`
Contains: Formal records of architectural decisions that affect the project long-term — technology choices, patterns, dependency selections, and structural decisions. These are the most durable form of "why" documentation in the project. See the ADR Format section below for the template.

### 4. Git Commit History

Commit messages in this project carry reasoning, not just labels. Use `git log --grep="<keyword>"` to search for prior decisions about specific areas. Use `git log -p -- <filepath>` to see why specific files changed over time. Do this before assuming you understand why code looks the way it does.

### 5. Code Comments

Comments in this codebase explain *why*, not *what*. If a block of code has a comment, it likely documents a non-obvious decision. Read them before modifying the surrounding code.

### 6. Previous Implementation Plans

Location: `docs/plans/`
Contains: Full implementation plans for past features and bug fixes, including root cause analysis, rejected approaches, and debugging trails.

### 7. Run Reports Index

Location: `docs/reports/index.md`
A table mapping dates to implementation runs. Use this to find which reports relate to which features.

## Investigation Protocol

When investigating a bug or planning a feature:

1. Search `docs/plans/` for existing plans touching the same area
2. Search `docs/decisions/` for ADRs affecting the relevant modules
3. Search `docs/reports/*/decisions.md` for prior decisions about the relevant modules
4. Run `git log -p -- <relevant files>` to understand recent changes and their reasoning
5. Read code comments in the affected area before forming hypotheses
6. Only after checking these sources, begin your own investigation

If you find relevant prior context, surface it explicitly: "I found a previous decision in [location] that affects this..."

## Documentation Structure

```
docs/
├── decisions/                              # Architecture Decision Records (ADRs)
│   ├── 0001-short-title.md                 # Numbered sequentially
│   ├── 0002-short-title.md
│   └── ...
│
├── plans/                                  # Implementation plans
│   ├── feature_<slug>.md                   # Feature plans
│   └── bug_fix_<slug>.md                   # Bug fix plans
│
└── reports/                                # Orchestrator run outputs
    ├── index.md                            # Master index of all runs
    │
    └── {YYYY-MM-DD}-{plan-slug}/           # One directory per orchestrator run
        ├── YYYY-MM-DD-phase-01-<slug>.md   # Handoff report: phase 1
        ├── YYYY-MM-DD-phase-02-<slug>.md   # Handoff report: phase 2
        ├── ...                             # One handoff report per phase
        ├── decisions.md                    # Append-only decision log for this run
        ├── YYYY-MM-DD-plan-amendments.md   # Deviations from the original plan
        └── YYYY-MM-DD-verification-report.md  # Post-implementation verification
```

### Who creates what

| File / Directory | Created by | When |
|---|---|---|
| `docs/plans/*.md` | Planning agent | End of planning conversation |
| `docs/decisions/NNNN-*.md` | Orchestrator | Before Phase 01 (from plan) or during plan amendments (from deviations) |
| `docs/reports/index.md` | Orchestrator | Start of each run (append one row) |
| `docs/reports/{date}-{slug}/` | Orchestrator | Start of each run |
| `*-phase-{NN}-*.md` (handoff) | Subagent | End of each phase |
| `decisions.md` (run log) | Subagent | End of each phase (append) |
| `*-plan-amendments.md` | Orchestrator | After all phases, before verification |
| `*-verification-report.md` | Verification subagent | During post-implementation verification |

### Naming conventions

- **ADRs**: `NNNN-kebab-case-title.md` — zero-padded four-digit number, sequential. Example: `0003-use-redis-for-caching.md`
- **Plans**: `feature_<slug>.md` or `bug_fix_<slug>.md` — underscore-separated slug. Example: `feature_texture_pipeline.md`
- **Run directories**: `{YYYY-MM-DD}-{plan-slug}/` — date prefix, kebab-case slug, max 5 words. Append `-02`, `-03` if the directory already exists.
- **Handoff reports**: `{YYYY-MM-DD}-phase-{NN}-{phase-slug}.md` — zero-padded two-digit phase number, kebab-case slug max 5 words.

## ADR Format

Architecture Decision Records in `docs/decisions/` use this format:

```markdown
# ADR {NNNN}: {Title}

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-NNNN]

## Date
{YYYY-MM-DD}

## Context
[Value-neutral description of the forces at play — technological,
political, social, project-specific. What problem or choice prompted
this decision?]

## Decision
We will [specific decision in active voice].

## Consequences
[ALL consequences — positive, negative, and neutral. What becomes
easier? What becomes harder? What are we accepting as trade-offs?]

## Plan Reference
Originated from: `{path to implementation plan or plan amendments file}`
```

**When to create an ADR:**
- A technology or dependency is chosen over alternatives
- A pattern is established that future work must follow
- A structural decision affects multiple modules
- A decision constrains future work beyond the current plan

**ADRs are immutable once accepted.** If a decision is reversed, create a new ADR with status "Superseded by ADR-NNNN" on the old one and explain the reversal in the new one. Do not edit the original decision or consequences.

## Code Comment Convention

When adding or modifying code, follow these comment patterns for non-obvious decisions:

- `// Chosen over [alternative] because [reason]`
- `// Workaround for [issue]: [explanation]`
- `// WARNING: assumes [assumption] — if this changes, [consequence]`
- `// See ADR {NNNN} or docs/reports/[path] for full context`

Do not comment what code does — only why it does it this way.

## Commit Message Convention

This project uses structured commit messages with reasoning in the body:

```
<type>(scope): <short description>

Why: <1-3 sentences explaining reasoning, not just what changed>

Refs: <ADR number or decision log path, if applicable>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

## Decision Recording Threshold

Log any implementation decision where the reasoning isn't obvious from reading the code. When uncertain whether a decision qualifies, log it. A verbose decision log costs the next agent a few hundred tokens; missing context costs a full re-investigation.