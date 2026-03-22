# AI Prompts

This repo exists because I kept doing the same things over and over in my AI-assisted coding sessions — and doing them inconsistently. Planning conversations that lost context. Execution runs that forgot what the planning phase decided. Decision records that lived only in chat history. So I codified the patterns that worked and threw away the ones that didn't.

Everything here is built around [OpenCode](https://opencode.ai), which is what I use daily, and [Claude Code](https://docs.anthropic.com/en/docs/claude-code), which is also supported. But the ideas — the two-phase workflow, the separation of planning from execution, the obsessive context isolation — are tool-agnostic. The project installer uses an adapter system that can deploy to any AI agent, and adding support for a new one (Cursor, Aider, etc.) requires only a single adapter file.

## The Workflow

This is the core of how I work. Two phases, deliberately separated, with a hard boundary between them.

### Phase 1: Think Before You Touch Anything

I start every non-trivial task by switching OpenCode to the **Devil's Advocate** agent. This agent can't edit files, can't run commands, can't write code. All it can do is talk and ask questions. That's the point.

It's an intellectual sparring partner. It surfaces blind spots in my thinking, pushes back on inconsistencies, demands precision when I'm being vague, and refuses to let me skip over hard questions. It doesn't validate — it interrogates. If my premise is broken, it says so before we build on it.

I use the smartest model available for this step (currently Claude Opus 4.6). This phase needs to fully understand both the problem I'm trying to solve and the current state of my codebase. Cheap models cut corners here, and you pay for it later.

The conversation usually goes through several rounds of challenge and refinement. The agent might ask me to clarify my assumptions, point out that a similar approach was tried and abandoned six months ago, or force me to articulate why I'm choosing one approach over another.

### The Plan

When the conversation reaches clarity — when the agent understands both the problem and the solution well enough to stop pushing back — I run `/write-plan`. This generates a structured implementation plan as a markdown file, with several properties that matter:

- **Self-sufficient.** The plan must be readable without the conversation that produced it. All relevant context, decisions, root cause analysis, and technical details get embedded directly.
- **Phased.** Work is organized into discrete phases that can be executed independently. Each phase is one logical unit of work.
- **Grounded in prior decisions.** Before writing anything, the planning agent checks existing ADRs, previous decision logs, git history, and prior plans touching the same area. It doesn't plan in a vacuum.
- **Decisions are explicit.** Every significant choice includes what was decided, what alternatives were rejected and why, what assumptions must hold, and what would invalidate the decision.
- **Test-first.** Every phase defines its tests before its implementation. The executing agent writes tests first, watches them fail, implements, then watches them pass. I find this to be very useful as we build unit tests for all the code that is written and that helps in telling the agent if the phase is complete or not. 
- **Assumption-aware.** The plan lists what it assumes to be true, and what parts of the plan break if each assumption turns out to be wrong.

### Phase 2: Execute Without Looking Back

I start a **fresh conversation**. This is important — clean context, no pollution from the planning discussion. The executing agent doesn't need to know about the dead ends we explored or the arguments we had. It needs the plan.

I run `/execute-plan` with the plan file. This turns the agent into an orchestrator that:

- **Creates a feature branch.** It refuses to run on `main`, `master`, or `develop`. If you're on a protected branch, it asks you to confirm a new branch name.
- **Creates Architecture Decision Records.** If the plan identified any architectural decisions, the orchestrator writes them as formal ADRs before execution begins.
- **Delegates each phase to a fresh subagent.** Each subagent gets clean context, the Augster system prompt (a detailed behavioral framework for execution agents), the full plan, its specific phase scope, and the previous phase's handoff report. No context leakage between phases.
- **Tracks decisions across phases.** Each subagent appends to a shared, append-only decision log. Nothing gets lost between handoffs.
- **Commits after each phase.** Every completed phase gets its own git commit with structured messages that explain the reasoning, not just the changes.
- **Reviews the result.** After all phases complete, a separate reviewer subagent verifies the entire implementation against the original plan. It checks that deliverables exist, tests pass, documented deviations are intentional, and ADRs were actually created.
- **Documents deviations.** Any differences between the plan and what was actually built get recorded in a plan amendments file.

Then you wait. Depending on the plan's complexity, this can take a while. Go get coffee.

## What's In This Repo

Along with the prompts and workflow, there are also a few other files I place in the folder of the project I'm working on.
Workflow conventions, documentation structure definitions, and execution protocols live directly inside the global command files (`/write-plan` and `/execute-plan`), making each command self-contained.

The file structure:

```
ai-prompts/
├── adapters/                  # Agent adapter scripts (one per AI agent)
│   ├── opencode.sh                # OpenCode: .opencode/, AGENTS.md, opencode.json
│   └── claude-code.sh             # Claude Code: .claude/, CLAUDE.md, settings.json
├── lib/                       # Shared functions used by both installers
│   ├── adapters.sh                # Adapter loading, validation, dependency checks
│   └── merge.sh                   # Merge, transform, deploy, backup functions
├── global/                    # Global config source (neutral format)
│   ├── .agent/                    # agents/, commands/, prompts/, skills/
│   ├── credentials/               # Agent-specific credential templates
│   ├── RULES.md                   # Global rules (transformed per agent)
│   └── settings.yaml              # Global settings (MCP config, transformed per agent)
├── projects/
│   ├── coding/                # Coding project type
│   │   ├── compound-engineering/  # Compound Engineering sub-source
│   │   │   ├── .agent/            # Neutral format: agents/, commands/, skills/
│   │   │   └── settings.yaml      # Neutral settings (transformed per agent)
│   │   └── personal/              # Personal customizations sub-source
│   └── writing/               # Writing project type (empty)
├── docs/
│   ├── decisions/             # Architecture decision records
│   └── plan/                  # Implementation plans
├── install-global.sh          # Installs global config (multi-agent, manifest-tracked)
├── install-project.sh         # Installs project configs to a target directory
└── README.md
```

- **`global/`** contains global agent configuration in the same neutral format as project sources. Commands (`/write-plan`, `/execute-plan`, `/chat-summary`), agents (thinking partner, testing), the Augster system prompt, and skills are stored under `.agent/`. Credential templates (e.g., OpenCode provider config with empty API keys) live in `credentials/` and are only deployed on first install.
- **`lib/`** contains shared functions used by both installers — adapter loading/validation, merge logic, settings transformation, manifest building, and deployment. Both scripts source these files rather than duplicating the code.
- **`projects/PROJECT_CONTEXT.md`** is a template you drop into target projects for project-specific context — build commands, key paths, testing methodology, versioning, and project structure. Fill in the placeholders for your project.

For the full technical details — command specifications, agent behavior rules, docs/ structure, ADR format, report schemas — see [REFERENCE.md](REFERENCE.md).

## Quick Setup

### Global Install

Install global AI agent configuration (agents, commands, prompts, skills) to the agent's config directory:

```bash
./install-global.sh
```

The script will prompt you to select an agent (OpenCode or Claude Code), then deploy global configuration to the agent's default location:

| Agent | Destination |
|-------|-------------|
| OpenCode | `~/.config/opencode/` |
| Claude Code | `~/.claude/` |

Content is stored in a neutral format (`global/.agent/`, `RULES.md`, `settings.yaml`) and transformed at install time — the same adapter system used by the project installer. Credential templates (provider config with empty API keys) are deployed only on first install to avoid overwriting existing API keys.

The installer writes an `.agent-manifest.json` file at the destination, enabling surgical updates that only touch managed files.

**Options:**
- `--agent NAME` — Skip the menu and install for a specific agent (e.g., `opencode`, `claude-code`)
- `--target DIR` — Install to DIR instead of the agent's default location
- `--update` — Update existing global installations using their manifests
- `--dry-run` — Preview changes without modifying anything
- `--help` — Show usage

### Project Install

Install project-specific AI agent configurations (agents, commands, skills) into a target project directory:

```bash
./install-project.sh
```

The script will:
1. Show available project types (e.g., `coding`) — empty types are skipped
2. Show available agents (e.g., `OpenCode`, `Claude Code`) — select which agent to install for
3. Ask for the destination path (creates the directory structure if needed)
4. Merge content from all sub-sources in alphabetical order (e.g., `compound-engineering` then `personal`)
5. Transform neutral `settings.yaml` into the agent-specific format and deploy
6. Record the installation (including which adapter was used) in a hostname-specific registry

**Source format:** Project content is stored in a neutral format (`.agent/` directories, `RULES.md`, `settings.yaml`). At install time, the selected adapter transforms this to the agent's conventions:

| Neutral | OpenCode | Claude Code |
|---------|----------|-------------|
| `.agent/` | `.opencode/` | `.claude/` |
| `RULES.md` | `AGENTS.md` | `CLAUDE.md` |
| `settings.yaml` | `opencode.json` (at root) | `.claude/settings.json` |

**Merge rules:**
- **Agents/commands:** All files copied. Name collisions → last source wins (with warning)
- **Skills:** Entire skill folders copied. Name collisions → last source wins (with warning)
- **`settings.yaml`:** Deep-merged via `yq`, then transformed to agent-specific JSON
- **Root `.md` files:** Concatenated with source attribution headers

**Updating existing installs:**

```bash
./install-project.sh --update
```

This reads the registry, loads the correct adapter for each install, creates a dated backup at each destination (`.agent-backups/<timestamp>/`), surgically deletes previously installed files, and pushes a clean merge from current sources. Files not in the manifest are left untouched.

**Adding a new agent:** Create a single adapter file in `adapters/` (see existing adapters for the contract). The installer discovers adapters automatically.

**Requirements:** `jq`, `yq`

### Testing

Both install scripts have automated test suites.

**Global installer:**

```bash
./test-install-global.sh
```

Runs 81 assertions across 9 test groups using self-contained test fixtures. Exit code 0 means all tests passed.

**Test groups:**
1. CLI arguments (`--help`, `--agent`, `--update`, unknown flags)
2. Clean install — OpenCode (RULES.md→AGENTS.md, all subdirs including prompts, settings transform, credential template)
3. Clean install — Claude Code (RULES.md→CLAUDE.md, prompts excluded, flat layout, no credential template)
4. Re-install / collision handling (overwrite, credential preservation, user file survival)
5. Dry-run mode
6. Manifest tracking (valid JSON, correct fields, excludes self and backups)
7. Update mode (new files appear, removed files disappear, backups created, user files survive)
8. Edge cases (empty subdirs, auto-created paths, spaces in paths)
9. Idempotency

Always run after modifying `install-global.sh` or `lib/`.

**Project installer:**

```bash
./test-install-project.sh
```

Runs 103 assertions across 9 test groups using temporary fixtures. Exit code 0 means all tests passed.

**Test groups:**
1. CLI arguments and flag parsing
2. Install flow (OpenCode adapter) — collisions, settings transform, RULES.md→AGENTS.md, manifest accuracy
3. Install flow (Claude Code adapter) — .claude/ structure, CLAUDE.md, settings.json placement, mcpServers mapping
4. Re-install collision detection, path validation
5. Update flow — backup, surgical delete, file restoration, custom file preservation, multi-adapter updates
6. Source content changes — add/remove/rename files between install and update (verified across both adapters)
7. Edge cases — deleted destinations, removed source projects, registry integrity
8. Empty directory cleanup after surgical updates
9. Settings YAML transform — MCP server merging, agent-specific overrides, neutral file removal

**Requirements:** `bash` (4.0+), `jq`, `yq`

Always run after modifying `install-project.sh` or `lib/`.

For target projects, copy `projects/PROJECT_CONTEXT.md` into the project root and fill in the placeholders.

## Reference

All technical specifications — the full docs/ directory structure, ADR rules, investigation protocol, command and agent details, report formats, naming conventions — live in [REFERENCE.md](REFERENCE.md).
