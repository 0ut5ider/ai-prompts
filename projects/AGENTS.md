# AGENTS.md

This file provides context for any AI agent working on this codebase. Read this before beginning any task.

## Project Knowledge Sources

### Investigation Protocol

When investigating a bug or planning a feature, check these sources BEFORE forming hypotheses:

1. **Decision logs** — `docs/reports/*/decisions.md` contain implementation decisions and trade-offs from previous runs. Check these before proposing an approach — the thing you're about to suggest may have already been tried and rejected.
2. **Plan amendments** — `docs/reports/*/*-plan-amendments.md` document where previous implementations deviated from their original plans, and why. Useful for understanding why the code doesn't match what you'd expect.
3. **Implementation plans** — `docs/plans/` contain full plans for past features and bug fixes, including root cause analysis, rejected approaches, and debugging trails.
4. **Git commit history** — Commit messages in this project carry reasoning in their bodies. Use `git log --grep="<keyword>"` to search for prior decisions. Use `git log -p -- <filepath>` to see why specific files changed over time.
5. **Code comments** — Comments in this codebase explain *why*, not *what*. If a block of code has a comment, it documents a non-obvious decision. Read comments before modifying surrounding code.
6. **Run reports index** — `docs/reports/index.md` maps dates to implementation runs. Use this to find which reports relate to which features.

If prior context is found, surface it explicitly: "Found previous decision in [path] that affects this approach..."

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

## Project Structure

```
├── AGENTS.md              # This file — agent context and conventions
├── README.md              # Project overview, setup, usage
├── docs/
│   ├── decisions/         # Architecture Decision Records (ADRs)
│   ├── plans/             # Implementation plans (features and bug fixes)
│   └── reports/           # Run reports, decision logs, verification reports
│       └── index.md       # Index mapping dates to implementation runs
├── src/                   # Application source code
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
