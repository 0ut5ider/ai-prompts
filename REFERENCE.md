# Reference

Technical reference for the ai-prompts repository. For an overview of the workflow and rationale, see [README.md](README.md).

---

## Repository Structure

```
ai-prompts/
├── global/
│   ├── opencode/
│   │   ├── commands/                    # Reusable command definitions
│   │   │   ├── write-plan.md            # Plan generation command
│   │   │   ├── execute-plan.md          # Plan execution orchestrator
│   │   │   ├── chat-summary.md          # Decision archaeology report
│   │   │   └── code-simplifier.md       # Multi-language code simplifier
│   │   ├── agents/                      # Agent configurations
│   │   │   ├── thinking-partener.md     # Intellectual sparring partner
│   │   │   └── testing.md               # Minimal test agent
│   │   ├── prompts/                     # Reusable prompt fragments
│   │   │   └── augster-system.md        # System prompt for execution subagents
│   │   ├── AGENTS.md                    # Global OpenCode agent context
│   │   ├── opencode.json                # Provider and model configuration
│   │   └── opencode_example.json        # Example config (no API keys)
│   ├── claude/                          # Claude Code configuration (placeholder)
│   └── README.md                        # Symlink setup instructions
├── projects/
│   └── PROJECT_CONTEXT.md              # Project-specific context template
├── README.md                            # Workflow overview and introduction
└── REFERENCE.md                         # This file
```

---

## OpenCode Configuration

### `opencode.json`

Configures LLM providers and MCP servers for OpenCode. An `opencode_example.json` with empty API keys is provided as a template.

#### Providers

| Provider | Models | Notes |
|----------|--------|-------|
| LiteLLM | MiniMax M2.5 | Local proxy (`http://<IP>:4000/v1`), tool-use enabled |
| OpenRouter | GLM 4.7 | Via `openrouter.ai` API |
| Cerebo | MiniMax M2.5, GLM 4.7 | Hosted endpoint, tool-use enabled, with context/output limits |

All providers use the `@ai-sdk/openai-compatible` npm package for OpenAI-compatible API access.

#### MCP Servers

| Server | Type | URL |
|--------|------|-----|
| context7 | Remote | `https://mcp.context7.com/mcp` |

### `AGENTS.md` (Global)

The global agent context file (`global/opencode/AGENTS.md`) configures:

- **General instructions**: Interview users for clarification, delegate to subagents in build mode, update README when code changes
- **MCP server usage**: Use context7 for documentation lookups and specific knowledge queries
- **Git configuration**: Default author (configured per-user via template), conventional commit messages, feature branch naming (`feature/short-description`), safe operation policies

---

## Commands Reference

### `write-plan.md` — Plan Generation

**Purpose**: Instructs the agent to generate a structured implementation plan and write it to a markdown file. The agent operates as a planning-only agent — no code writing or file modification.

**Output location**: `docs/plans/` in the target project
- Features: `docs/plans/feature_<slug>.md`
- Bug fixes: `docs/plans/bug_fix_<slug>.md`

**Pre-investigation**: Before planning, the agent checks `PROJECT_CONTEXT.md` for project-specific context, then follows the investigation protocol — checking existing ADRs, decision logs, plan amendments, previous plans, run reports index, git history, and code comments.

**Plan structure**:

| Section | Contents |
|---------|----------|
| Context | File paths, current vs. expected behavior, root cause or user-facing goal, rejected approaches, prior context references |
| Investigation Trail | (Bug fixes only) Symptoms, hypotheses tested, red herrings |
| Decision Record | Each significant decision with context, rejected alternatives, assumptions, and reversal triggers |
| ADRs To Create | Architectural decisions that should become formal ADRs during execution |
| Assumptions & Invalidation Triggers | What the plan depends on and what breaks if assumptions change |
| Phases | Discrete units of work, each with: what, why, test-first definitions, implementation details, required code comments, verification steps |
| Constraints | Files not to modify, dependencies not to add, patterns to follow |

**Key rules**:
- Plan must be self-sufficient (readable without conversation context)
- Every phase enforces TDD — tests defined before implementation
- No code writing, no file modification, only the plan file

---

### `execute-plan.md` — Plan Execution Orchestrator

**Purpose**: Takes a generated plan file and orchestrates its execution by delegating each phase to a fresh subagent.

**Orchestrator responsibilities**:

1. **Load the Augster system prompt** from `prompts/augster-system.md` and prepend to all subagent contexts
2. **Git branch management**:
   - Verify current branch matches the plan's purpose
   - Suggest `feature/{plan-slug}` branch if not on an appropriate branch
   - Refuse to execute on `main`, `master`, or `develop`
3. **ADR creation**: Write any ADRs listed in the plan to `docs/decisions/` before Phase 01
4. **Run directory setup**: Create `docs/reports/{YYYY-MM-DD}-{plan-slug}/` (append `-02`, `-03` for same-day reruns)
5. **Run index**: Append entry to `docs/reports/index.md`
6. **Phase delegation**: Execute phases sequentially, each via a fresh subagent
7. **Phase commits**: Stage and commit all changes after each phase
8. **Plan amendments**: After all phases, diff the plan against what was built and document deviations
9. **Verification**: Spin up a reviewer subagent to verify implementation against the plan
10. **Post-implementation**: Update README.md and PROJECT_CONTEXT.md if the implementation warrants it

**What each subagent receives**:

| Input | Description |
|-------|-------------|
| Augster system prompt | Behavioral framework loaded from `prompts/augster-system.md` |
| Full master plan | Complete plan file for broader context |
| Phase scope constraint | Explicit instruction to execute only its assigned phase |
| Previous handoff report | File path to the most recent handoff report (none for Phase 01) |
| Project context | Instruction to read `PROJECT_CONTEXT.md` at project root (graceful fallback if absent) |
| Code comment requirement | Rules for inline comments explaining non-obvious decisions |

**Commit message format**:
```
phase {NN}: {phase-slug}

Why: {1-3 sentences explaining reasoning}

Refs: {ADR number or decision log entry, if applicable}
```

---

### `chat-summary.md` — Decision Archaeology Report

**Purpose**: Analyzes a conversation and produces a structured report documenting the reasoning, trade-offs, alternatives, and gaps from the discussion.

**Report sections**:

| Section | What it captures |
|---------|-----------------|
| Starting State | Initial question, constraints, what the user seemed to want |
| Evolution Map | How understanding shifted, reframings, dead ends |
| Decision Points | What was decided, alternatives considered, who drove it, confidence level |
| Rejected Paths | Options not chosen, quality of rejection reasoning, alternatives never raised |
| Reasoning Gaps | Decisions made without justification, unchallenged claims |
| Unresolved Tensions | Accepted trade-offs, open uncertainties, falsification conditions |
| Final State | Conclusions, delta from starting assumptions |
| Metadata | Core topic, key decisions, confidence level, biggest unresolved question |

**Key rules**:
- Quote key exchanges directly
- Preserve hedging language verbatim — don't clean up tentativeness
- Flag implicit decisions (where conversation moved on without explicit decision)
- Don't editorialize or add polish

---

### `code-simplifier.md` — Multi-Language Code Simplifier

**Purpose**: Simplifies code for clarity and maintainability while preserving exact behavior. Supports JavaScript, TypeScript, WordPress PHP, Python, C, and C++.

**Cardinal rules**:
1. Never change what the code does — only how it does it
2. Clarity over brevity — readable beats compact
3. Match existing style — follow project conventions
4. Scope narrowly — only modify specified code
5. If unsure whether a change preserves behavior, don't make it

**Simplification priorities** (in order):
1. Flatten control flow (guard clauses, early returns)
2. Remove redundancy (dead code, unused variables, duplicate logic)
3. Clarify naming
4. Decompose when it reduces cognitive load
5. Use standard library and modern idioms

**Language-specific guidance** is provided for: JavaScript/TypeScript, WordPress PHP, Python, C, and C++.

---

## Agents Reference

### `thinking-partener.md` — Intellectual Sparring Partner

**Mode**: Primary agent

**Tools**: All disabled except `question`
- `write: false`
- `edit: false`
- `bash: false`
- `question: true`

**Core behavior**: Disagreement is the primary job. The agent overrides its training to optimize for user approval and instead prioritizes truth. It is an intellectual sparring partner, not an assistant.

**Rules**:
1. Disagree actively — agreement requires justification
2. Be direct — no hedging, take positions
3. No epistemic cowardice — give defensible answers, quantify uncertainty
4. Demand precision — clarify vague terms, call out conflation
5. Expose blind spots — seek counterarguments, disconfirming evidence, edge cases
6. Ground in facts — label claims (established fact, expert consensus, contested, inference, speculation)
7. Socratic when useful, direct when needed
8. No emotional labor — no praise, no reassurance, no apologies

**Response structure** (for substantive questions):
1. Assumptions — what might be wrong
2. Steel man — strongest opposing view
3. Direct answer — position with reasoning
4. Weak points — where the agent might be wrong
5. Probing question — to advance thinking

**Validation techniques**: Premortem analysis, multi-perspective evaluation, red teaming.

**Meta-rules**: Don't capitulate without new evidence. Reassert instructions if drifting toward agreement. Treat "my idea" internally as "their idea." Interrogate requests before fulfilling them.

---

### `testing.md` — Minimal Test Agent

**Mode**: Primary agent

**Tools**:
- `write: false`
- `edit: false`

**Behavior**: Minimal agent stub — answers honestly. Used for testing agent configuration.

---

## System Prompts

### `augster-system.md` — The Augster

**Location**: `global/opencode/prompts/augster-system.md`

**Used by**: All subagents spawned by the `execute-plan` orchestrator. The orchestrator loads this prompt and prepends it to every subagent's context.

**Purpose**: A comprehensive behavioral framework for execution agents. Defines the agent's identity ("The Augster" — an autonomous full-stack engineer), communication style, maxims, protocols, and a rigid workflow.

**Key maxims**:

| Maxim | Summary |
|-------|---------|
| PrimedCognition | Structured reasoning before any significant action; conclusions in `<thinking>` tags |
| StrategicMemory | Store only permanent architectural facts (PAFs) via the `remember` tool |
| AppropriateComplexity | Minimum necessary complexity — no over-engineering, no under-engineering |
| PurposefulToolLeveraging | Every tool call justified on four axes: Purpose, Benefit, Suitability, Feasibility |
| Autonomy | Prefer autonomous execution over user-querying; highly proactive |
| PurityAndCleanliness | Remove all obsolete/redundant elements in real-time |
| Perceptivity | Awareness of change impact (security, performance, signature propagation) |
| Impenetrability | Proactive security vulnerability mitigation |
| Resilience | Proactive error handling and boundary checks |
| Consistency | Forage for pre-existing patterns and reusable elements; adhere to conventions |
| EmpiricalRigor | Never act on unverified information during planning, implementation, or verification |

**Axiomatic Workflow stages**:

| Stage | Steps | Purpose |
|-------|-------|---------|
| Preliminary | aw1–aw4 | Distill mission, compose workload hypothesis, analyze pre-existing tech |
| Planning and Research | aw5–aw6 | Resolve assumptions, identify new tech needed |
| Trajectory Formulation | aw7–aw9 | Evolve workload into fully attested trajectory, register all tasks |
| Implementation | aw10–aw11 | Execute all tasks sequentially, verify completion |
| Verification | aw12–aw14 | Audit against task verification strategies, PASS/FAIL each item |
| Post-Implementation | aw15–aw17 | Record suggestions, summarize, clear or prepare task list |

**Predefined protocols**:
- **DecompositionProtocol**: Transforms input into Phases and Tasks with self-contained execution recipes
- **PAFGateProtocol**: Criteria for what qualifies as a Permanent Architectural Fact
- **ClarificationProtocol**: Structured format for asking users questions when blocked

---

## Project Documentation Structure (`docs/`)

The `execute-plan.md` command defines a standardized `docs/` folder structure that AI agents create and maintain **inside each target project**. The `docs/` folder does not live in this repository — it is generated in the project root where the agents operate.

### Directory Structure

```
{project_root}/
└── docs/
    ├── decisions/                               # Architecture Decision Records (ADRs)
    │   ├── 0001-kebab-case-title.md             # Sequential numbering, zero-padded 4 digits
    │   ├── 0002-kebab-case-title.md
    │   └── ...
    │
    ├── plans/                                   # Implementation plans
    │   ├── feature_<slug>.md                    # Feature implementation plans
    │   └── bug_fix_<slug>.md                    # Bug fix implementation plans
    │
    └── reports/                                 # Orchestrator run outputs
        ├── index.md                             # Master index: date → run mapping table
        │
        └── {YYYY-MM-DD}-{plan-slug}/           # One directory per orchestrator run
            ├── YYYY-MM-DD-phase-01-<slug>.md    # Handoff report per phase
            ├── YYYY-MM-DD-phase-02-<slug>.md
            ├── ...
            ├── decisions.md                     # Append-only decision log for this run
            ├── YYYY-MM-DD-plan-amendments.md    # Deviations from the original plan
            └── YYYY-MM-DD-verification-report.md # Post-implementation verification
```

### Subdirectory Purposes

#### `docs/decisions/` — Architecture Decision Records

Formal records of architectural decisions affecting the project long-term: technology choices, patterns, dependency selections, structural decisions. ADRs use 4-digit zero-padded sequential numbering with kebab-case titles.

- **Created by**: The orchestrator (`execute-plan.md`)
- **When**: Before Phase 01 (from the plan), or during plan amendments when architectural deviations occur
- **Immutability rule**: Once accepted, ADRs are never edited. Reversals create a new ADR with "Superseded" status.

**ADR format**:

```markdown
# ADR {NNNN}: {Title}

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-NNNN]

## Date
{YYYY-MM-DD}

## Context
[Value-neutral description of the forces at play]

## Decision
We will [specific decision in active voice].

## Consequences
[ALL consequences — positive, negative, and neutral]

## Plan Reference
Originated from: `{path to implementation plan or plan amendments file}`
```

**When to create an ADR**:
- A technology or dependency is chosen over alternatives
- A pattern is established that future work must follow
- A structural decision affects multiple modules
- A decision constrains future work beyond the current plan

#### `docs/plans/` — Implementation Plans

Full implementation plans for features and bug fixes, written by the planning agent at the end of a planning conversation.

- **Created by**: The planning agent (`write-plan.md`)
- **Naming**: `feature_<slug>.md` for features, `bug_fix_<slug>.md` for bug fixes

#### `docs/reports/` — Orchestrator Run Reports

Outputs from each orchestrator run, organized into date-stamped subdirectories.

**`index.md`** — Master table mapping dates to implementation runs. Created if missing; appended with one row per run.

```markdown
| Date | Run Directory | Plan Source | Summary |
|------|--------------|-------------|---------|
| YYYY-MM-DD | `{plan-slug}/` | `{path-to-plan}` | {two-sentence description} |
```

**`{YYYY-MM-DD}-{plan-slug}/`** — One directory per run, containing:

| File | Created By | Purpose |
|------|------------|---------|
| `YYYY-MM-DD-phase-NN-<slug>.md` | Subagent | Handoff report for each implementation phase |
| `decisions.md` | Subagent | Append-only decision log shared across all phases |
| `YYYY-MM-DD-plan-amendments.md` | Orchestrator | Documents where implementation deviated from the plan |
| `YYYY-MM-DD-verification-report.md` | Verification subagent | Post-implementation verification results |

### Report Formats

#### Handoff Report

```markdown
## State
Files created/modified: [paths]
Dependencies added: [if any]
Configuration changes: [if any]

## Decisions That Constrain Future Phases
- [decisions the next agent must respect]

## Patterns & Gotchas Discovered
- [anything learned that the plan didn't anticipate]

## Open Issues
- [anything unfinished, known-broken, or deferred]

## Next Phase Input
- [what the next agent needs to begin]
```

#### Decision Log Entry

```markdown
## [YYYY-MM-DD] Phase {NN}: {phase-slug}
- [Decision]: [Reason]
- [Decision]: [Reason]
```

**Recording threshold**: Log any decision where the reasoning isn't obvious from reading the code. When uncertain whether a decision qualifies, log it.

#### Plan Amendments

```markdown
## Plan Amendments Summary
Overall adherence: [HIGH | MEDIUM | LOW]
Phases with deviations: [list]

## Deviations
### Phase {NN}: {phase-slug}
- **Plan specified:** [what the plan said]
- **Actually implemented:** [what was done]
- **Why the change was necessary:** [root cause]
- **Architectural impact:** [Yes/No — if Yes, create an ADR]

## Phases Implemented As Planned
- Phase {NN}: {phase-slug} — no deviations
```

#### Verification Report

```markdown
## Verification Summary
Overall status: [COMPLETE | INCOMPLETE]
Phases verified: [N of M]

## Completed
- **Phase {NN}: {phase-slug}** — [summary]

## Not Completed or Partially Completed
- **Phase {NN}: {phase-slug}** — [what was expected vs. found]

## Plan Amendments Verified
- [confirm each deviation is reflected in code]

## ADR Verification
- [confirm each expected ADR exists]

## Unresolved Open Issues
- [items from handoff reports that remain unaddressed]
```

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| ADRs | `NNNN-kebab-case-title.md` | `0003-use-redis-for-caching.md` |
| Plans | `feature_<slug>.md` or `bug_fix_<slug>.md` | `feature_texture_pipeline.md` |
| Run directories | `{YYYY-MM-DD}-{plan-slug}/` | `2026-02-17-auth-middleware/` |
| Handoff reports | `{YYYY-MM-DD}-phase-{NN}-{phase-slug}.md` | `2026-02-17-phase-01-setup-schema.md` |
| Same-day reruns | Append `-02`, `-03` suffix | `2026-02-17-auth-middleware-02/` |

---

## Investigation Protocol

The canonical investigation protocol is defined in the command files (`write-plan.md` and `execute-plan.md`). The following is reference documentation. Before starting any implementation, agents follow this lookup order to gather prior context:

1. Search `docs/plans/` for existing plans touching the same area
2. Search `docs/decisions/` for ADRs affecting the relevant modules
3. Search `docs/reports/*/decisions.md` for prior decisions about the relevant modules
4. Search `docs/reports/*/*-plan-amendments.md` for previous deviations
5. Run `git log -p -- <relevant files>` to understand recent changes and reasoning
6. Read code comments in the affected area before forming hypotheses

If relevant prior context is found, surface it explicitly: "I found a previous decision in [location] that affects this..."

---

## Key Design Principles

- **ADRs are immutable** — once accepted, never edited; reversals create new ADRs
- **`decisions.md` is append-only** — each phase appends; never overwrite
- **Directories are created lazily** — agents create `decisions/`, `plans/`, and `reports/` only when needed
- **Run directories use date prefixes** — with `-02`, `-03` suffixes for same-day reruns
- **Code references documentation** — comments use `// See ADR {NNNN}` or `// See docs/reports/[path] for full context`
- **Code comments explain why, not what** — patterns include:
  - `// Chosen over [alternative] because [reason]`
  - `// Workaround for [issue]: [explanation]`
  - `// WARNING: assumes [assumption] — if this changes, [consequence]`

---

## Project and Stack Templates

### `projects/PROJECT_CONTEXT.md`

The sole project-level template, dropped into target project roots. Provides project-specific context that the command files cannot:

- **Project overview**: What the project does and its primary language/framework
- **Project structure**: Actual directory layout
- **Build & test commands**: How to install, test, build, and lint
- **Testing methodology**: Frameworks, naming conventions, coverage requirements
- **Code change protocol**: Version bumping rules and locations
- **Project-specific paths**: Source code, config, generated files, entry points
- **Test fixtures**: Paths to fixture files, what they contain, file types involved
- **Cleanup rules**: What generated file types to remove after tests pass
- **Dependencies & environment**: Required tools, environment variables, external services

All sections contain HTML comment placeholders for customization. The template is consumed by both `write-plan.md` (during pre-investigation) and `execute-plan.md` (passed to subagents and updated post-verification).
