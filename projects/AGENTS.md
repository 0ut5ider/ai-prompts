# AGENTS.md

This file provides context for any AI agent working on this codebase. Read this before beginning any task.

## Project Knowledge Sources

This project maintains institutional knowledge in several locations. Before investigating any bug or planning any feature, check these sources for prior context:

### 1. Decision Logs

Location: `docs/reports/*/decisions.md`
Contains: Architectural decisions, trade-offs, and rejected approaches from previous implementation runs. Check these BEFORE proposing an approach — the thing you're about to suggest may have already been tried and rejected.

### 2. Plan Amendments

Location: `docs/reports/*/*-plan-amendments.md`
Contains: Where previous implementations deviated from their original plans, and why. Useful for understanding why the code doesn't match what you'd expect from reading the plans alone.

### 3. Git Commit History

Commit messages in this project carry reasoning, not just labels. Use `git log --grep="<keyword>"` to search for prior decisions about specific areas. Use `git log -p -- <filepath>` to see why specific files changed over time. Do this before assuming you understand why code looks the way it does.

### 4. Code Comments

Comments in this codebase explain *why*, not *what*. If a block of code has a comment, it likely documents a non-obvious decision. Read them before modifying the surrounding code.

### 5. Previous Implementation Plans

Location: `docs/plans/`
Contains: Full implementation plans for past features and bug fixes, including root cause analysis, rejected approaches, and debugging trails.

### 6. Run Reports Index

Location: `docs/reports/index.md`
A table mapping dates to implementation runs. Use this to find which reports relate to which features.

## Investigation Protocol

When investigating a bug or planning a feature:

1. Search `docs/plans/` for existing plans touching the same area
2. Search `docs/reports/*/decisions.md` for prior decisions about the relevant modules
3. Run `git log -p -- <relevant files>` to understand recent changes and their reasoning
4. Read code comments in the affected area before forming hypotheses
5. Only after checking these sources, begin your own investigation

If you find relevant prior context, surface it explicitly: "I found a previous decision in [location] that affects this..."

## Code Comment Convention

When adding or modifying code, follow these comment patterns for non-obvious decisions:

- `// Chosen over [alternative] because [reason]`
- `// Workaround for [issue]: [explanation]`
- `// WARNING: assumes [assumption] — if this changes, [consequence]`
- `// See ADR [number] or docs/reports/[path] for full context`

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

## Code Change Protocol

When completing a feature, bug fix, or any change that affects user-visible behavior:

### Version Bumping

The version number must be updated in **both** locations and they must match:

1. `split/src/split.c` line 3: `#define VERSION "X.Y"`
2. `split/README.md` line 3: `**Version:** X.Y`

**When to bump:**
- Minor version (X.Y → X.Y+1): feature additions, bug fixes that change behavior, new format support
- Major version (X.Y → X+1.0): breaking changes, architectural rewrites

**Do not** use suffixes like `-atlas` or `-split-context`. Use plain `major.minor` format.

Verify after bumping:
```
make build/bin/split && ./build/bin/split 2>&1 | grep Version
```

The output must show the new version number.

### README Updates

If your changes add a new feature or change user-facing behavior, update `split/README.md` accordingly. The README documents the tool's capabilities — it must stay current.

## Project Structure

```
├── AGENTS.md              # This file — agent context and conventions
├── README.md              # Project overview, setup, usage
├── docs/
│   ├── decisions/         # Architecture Decision Records (ADRs)
│   ├── plans/             # Implementation plans (features and bug fixes)
│   └── reports/           # Run reports, decision logs, verification reports
│       └── index.md       # Index mapping dates to implementation runs
├── split/
│   ├── src/               # Application source code
│   └── README.md          # Tool-specific documentation
└── tests/                 # Test files
```

<!-- UPDATE THE STRUCTURE ABOVE TO MATCH YOUR ACTUAL PROJECT LAYOUT -->

## Build & Test Commands

<!-- ADD YOUR PROJECT'S ACTUAL COMMANDS HERE -->
<!-- Example:
- Install dependencies: `npm install`
- Run tests: `npm test`
- Run single test: `npm test -- --grep "test name"`
- Build: `npm run build`
- Lint: `npm run lint`
-->