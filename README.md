# AI Prompts

This repo exists because I kept doing the same things over and over in my AI-assisted coding sessions — and doing them inconsistently. Planning conversations that lost context. Execution runs that forgot what the planning phase decided. Decision records that lived only in chat history. So I codified the patterns that worked and threw away the ones that didn't.

Everything here is built around [OpenCode](https://opencode.ai), which is what I use daily. But the ideas — the two-phase workflow, the separation of planning from execution, the obsessive context isolation — are tool-agnostic. You could adapt this to Claude Code, Cursor, Aider, or whatever comes next. There's even an empty `global/claude/` directory waiting for when I get around to that.

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
├── global/
│   └── opencode/              # Global OpenCode config (agents, commands, prompts, skills)
│       └── install.sh         # Installs global config to ~/.config/opencode/
├── projects/
│   ├── coding/                # Coding project type
│   │   ├── compound-engineering/  # Compound Engineering sub-source
│   │   └── personal/              # Personal customizations sub-source
│   └── writing/               # Writing project type (empty)
├── install-project.sh         # Installs project configs to a target directory
└── README.md
```

- **`global/opencode/`** contains the commands (`/write-plan`, `/execute-plan`, `/chat-summary`, code simplifiers), agents (Devil's Advocate, testing), the Augster system prompt, and OpenCode provider/model configuration. The `AGENTS.md` file is generated locally from `AGENTS.md.template` — it contains personal git config and is gitignored.
- **`projects/PROJECT_CONTEXT.md`** is a template you drop into target projects for project-specific context — build commands, key paths, testing methodology, versioning, and project structure. Fill in the placeholders for your project.

For the full technical details — command specifications, agent behavior rules, docs/ structure, ADR format, report schemas — see [REFERENCE.md](REFERENCE.md).

## Quick Setup

### Install

Run the install script to set up OpenCode configuration files in `~/.config/opencode/`:

```bash
./global/opencode/install.sh
```

The script merges `agents/`, `commands/`, `prompts/`, and `skills/` into `~/.config/opencode/`, and copies `AGENTS.md` and `opencode.json` (from `opencode_example.json`). Only files that collide with source entries are backed up to `~/.config/opencode/.backups/<timestamp>/` — other files in those directories (e.g., from other frameworks) are left untouched. Edit the target `opencode.json` with your API keys and server IP.

**Options:**
- `--dry-run` — Preview changes without modifying anything
- `--help` — Show usage

### Project Install

Install project-specific OpenCode configurations (agents, commands, skills) into a target project directory:

```bash
./install-project.sh
```

The script will:
1. Show available project types (e.g., `coding`) — empty types are skipped
2. Ask for the destination path (creates the directory structure if needed)
3. Merge content from all sub-sources in alphabetical order (e.g., `compound-engineering` then `personal`)
4. Record the installation in a hostname-specific registry for future updates

**Merge rules:**
- **Agents/commands:** All files copied. Name collisions → last source wins (with warning)
- **Skills:** Entire skill folders copied. Name collisions → last source wins (with warning)
- **`opencode.json`:** Deep-merged via `jq` (last source wins on key conflicts)
- **Root `.md` files:** Concatenated with source attribution headers

**Updating existing installs:**

```bash
./install-project.sh --update
```

This reads the registry, creates a dated backup at each destination (`.opencode-backups/<timestamp>/`), surgically deletes previously installed files, and pushes a clean merge from current sources. Files not in the manifest are left untouched.

**Requirements:** `jq`

### Testing

Run the automated test suite to verify the project installer works correctly:

```bash
./test-install-project.sh
```

The script creates temporary fixtures (a `zzz-testbed` project type with two sub-sources designed to exercise all merge and conflict paths), runs 81 assertions across 8 test groups, and cleans up all artifacts on completion. Exit code 0 means all tests passed; non-zero means failures occurred.

**Test groups:**
1. CLI arguments and flag parsing
2. Install flow — collisions (agents, commands, skills), JSON deep-merge, MD concatenation, manifest accuracy
3. Re-install collision detection, path validation
4. Update flow — backup, surgical delete, file restoration, custom file preservation
5. Source content changes — add/remove/rename files between install and update
6. Backup completeness — file counts, directory structure, user modification capture
7. Edge cases — deleted destinations, removed source projects, registry integrity
8. Empty directory cleanup after surgical updates

**Requirements:** `bash` (4.0+), `jq`

Always run the test suite after modifying `install-project.sh` to catch regressions.

For target projects, copy `projects/PROJECT_CONTEXT.md` into the project root and fill in the placeholders.

## Reference

All technical specifications — the full docs/ directory structure, ADR rules, investigation protocol, command and agent details, report formats, naming conventions — live in [REFERENCE.md](REFERENCE.md).
