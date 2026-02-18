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
- **Test-first.** Every phase defines its tests before its implementation. The executing agent writes tests first, watches them fail, implements, then watches them pass.
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
The AGENTS.md file provides context for any AI agent working on this codebase. It is meant to be read by OpenCode before beginning any task.

The file structure:

```
ai-prompts/
├── global/
│   └── opencode/          # OpenCode configuration, commands, agents, prompts
├── projects/
│   └── AGENTS.md          # Project-level agent context template
├── stacks/
│   ├── AGENTS.md          # Stack-level agent context template
│   ├── c/                 # C-specific configuration (placeholder)
│   └── general/           # General stack configuration (placeholder)
└── README.md
```

- **`global/opencode/`** contains the commands (`/write-plan`, `/execute-plan`, `/chat-summary`, code simplifiers), agents (Devil's Advocate, testing), the Augster system prompt, and OpenCode provider/model configuration.
- **`projects/AGENTS.md`** and **`stacks/AGENTS.md`** are templates you drop into target projects. They establish the `docs/` folder convention (decisions, plans, reports) and define investigation protocols, code comment conventions, and commit message formats.

For the full technical details — command specifications, agent behavior rules, docs/ structure, ADR format, report schemas — see [REFERENCE.md](REFERENCE.md).

## Quick Setup

For OpenCode to use this configuration, symlink from your home directory to the appropriate locations:

```bash
ln -s ai-prompts/global/opencode/agents/ .
ln -s ai-prompts/global/opencode/commands/ .
ln -s ai-prompts/global/opencode/prompts/ .
ln -s ai-prompts/global/opencode/AGENTS.md .
ln -s ai-prompts/global/opencode/opencode.json .
```

For target projects, copy or symlink `projects/AGENTS.md` into the project root to enable the `docs/` workflow. If you have stack-specific needs, also pull in the relevant `stacks/` template.

## Reference

All technical specifications — the full docs/ directory structure, ADR rules, investigation protocol, command and agent details, report formats, naming conventions — live in [REFERENCE.md](REFERENCE.md).
