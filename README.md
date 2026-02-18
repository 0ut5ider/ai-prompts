# Raison d'etre

The reason this repo exists is because I have noticed certain patterns in my coding workflow which I wanted to standardize. This repo is built around how I work, and will continue to evolve with how I evolve and grow. 
The main tool I use these days for coding is [OpenCode](https://opencode.ai), and everything in this repo is setup for OpenCode.  
However it is easily adaptable to most other coding agents.


The repo consists my Opencode settings, commands, skill, and coding workflow structure.

# My workflow

The way I work today is in two broad phases. 
The first phase is to have a conversation with the AI agent about what I want to accomplish. This involves putting OpenCodee in the "Devils Advocate" agent mode (see prompt in global/opencode/agents/ folder). That prompts acts like an intellectual sparring partner. It surfaces my blind pots, pushes back on inconsistencies in my thinking and much much more. The agent is also set to act in a Plan mode style, where it can't write or edit files without first asking permission. 

I typically use Claude Opus 4.6 (at the time of writing) for this step as it's a very smart agent and it's very thorough in it's analysis of the code-base. It's important to use the smartest agents you have access to for this first conversation since it needs to fully understand both the issue you want resolved (bug-fix, new feature, etc) and the current state of your codebase. 

After the conversation is done, and the agent fully understands what needs to happen it will usually ask to create a plan. This is the point where I bring in the /write-plan command. It instructs the agent to generate and write to a .md file the plan in a very specific format (which will be useful later). There are several instructions the command gives the agent:
- keep enough detail in the plan file so as to make it self-sufficient, so it can exist without the need for the conversation context
- organize the plan in separate phases which can be executed on their own
- what else? Populate with a few more high level points.

Once the plan file is written I start a fresh conversation. This is important so that the ai agent has a fresh context which is not polluted with any other previous conversation.

In this new conversation I use the /execute-plan along with @path to the plan file generated earlier.
This will become the orchestrator agent which will take the plan and will delegate each phase of the plan to a fresh subagent (again to keep clean context for each phase).

{Describe the high level function of the execute-plan command: creation of new git branch, commit after each phase is complete, etc}

Now you wait. This can take quite some time depending on how complex and lengthy the plan was.

# AI Prompts Repository


Configuration and prompts for AI-assisted development workflows.

## Structure

```
ai-prompts/
├── global/                    # OpenCode global configuration
│   ├── opencode/
│   │   ├── commands/         # Reusable command definitions
│   │   ├── agents/          # Agent configurations
│   │   ├── prompts/         # Reusable prompt fragments
│   │   ├── AGENTS.md        # Global agent context
│   │   └── opencode.json    # Provider and model configuration
│   └── README.md
├── projects/                  # Project-specific agent context
│   └── AGENTS.md
└── stacks/                    # Stack-specific agent context
    └── AGENTS.md
```

## OpenCode Configuration

This repository provides configuration for [OpenCode](https://opencode.ai), an AI coding assistant. The configuration includes:

- **Commands** (`global/opencode/commands/`): Reusable prompt templates for common tasks
- **Agents** (`global/opencode/agents/`): Agent-specific instructions and behaviors
- **Prompts** (`global/opencode/prompts/`): Reusable system prompt fragments shared across commands and agents
- **Providers** (`global/opencode/opencode.json`): LLM provider settings for MiniMax M2.5 and other models

### Quick Setup

For OpenCode to use this configuration, create symlinks to the natural storage locations:

```bash
ln -s ai-prompts/opencode/agents/ .
ln -s ai-prompts/opencode/commands/ .
ln -s ai-prompts/opencode/prompts/ .
ln -s ai-prompts/opencode/AGENTS.md .
ln -s ai-prompts/opencode/opencode.json .
```

## Workflow



## Project Documentation Structure (`docs/`)

For each project where AI agents do some work, a docs/ folder structure gets created. 
The info in the docs/ folder is populated by the various commands and agents.

The AGENTS.md files in `projects/` and `stacks/` define a standardized `docs/` folder structure that AI agents create and maintain **inside each target project** that uses these agent configurations. The `docs/` folder does not live in this repository — it is generated in the project root where the agents operate.

### Structure

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
        ├── index.md                             # Master index: date -> run mapping table
        │
        └── {YYYY-MM-DD}-{plan-slug}/           # One directory per orchestrator run
            ├── YYYY-MM-DD-phase-01-<slug>.md    # Handoff report per phase
            ├── YYYY-MM-DD-phase-02-<slug>.md
            ├── ...
            ├── decisions.md                     # Append-only decision log for this run
            ├── YYYY-MM-DD-plan-amendments.md    # Deviations from the original plan
            └── YYYY-MM-DD-verification-report.md # Post-implementation verification
```

### Purpose of Each Subdirectory

#### `docs/decisions/` — Architecture Decision Records (ADRs)

Formal records of architectural decisions affecting the project long-term: technology choices, patterns, dependency selections, and structural decisions. ADRs use 4-digit zero-padded sequential numbering (`0001`, `0002`, ...) with kebab-case titles.

- **Created by:** The orchestrator (`code_implementation-orchestrator.md`)
- **When:** Before Phase 01 (from the plan), or during plan amendments when architectural deviations occur
- **Immutability rule:** Once accepted, ADRs are never edited. Reversals create a new ADR with "Superseded" status.

#### `docs/plans/` — Implementation Plans

Full implementation plans for features and bug fixes, written by the planning agent at the end of a planning conversation.

- **Created by:** The planning agent (`plan-creation+save.md`)
- **Naming:** `feature_<slug>.md` for features, `bug_fix_<slug>.md` for bug fixes

#### `docs/reports/` — Orchestrator Run Reports

Contains outputs from each orchestrator run, organized into date-stamped subdirectories.

- **`index.md`** — A master table mapping dates to implementation runs. Created if missing at the start of each run; appended with one row per run.
- **`{YYYY-MM-DD}-{plan-slug}/`** — One directory per orchestrator run (suffixed `-02`, `-03` for same-day reruns), containing:

| File | Created By | Purpose |
|------|------------|---------|
| `YYYY-MM-DD-phase-NN-<slug>.md` | Subagent | Handoff report for each implementation phase |
| `decisions.md` | Subagent | Append-only decision log shared across all phases |
| `YYYY-MM-DD-plan-amendments.md` | Orchestrator | Documents where implementation deviated from the plan |
| `YYYY-MM-DD-verification-report.md` | Verification subagent | Post-implementation verification results |

### Investigation Protocol

Before starting any implementation, agents follow this lookup order to gather prior context:

1. Search `docs/plans/` for existing plans touching the same area
2. Search `docs/decisions/` for ADRs affecting the relevant modules
3. Search `docs/reports/*/decisions.md` for prior decisions about the relevant modules
4. Search `docs/reports/*/*-plan-amendments.md` for previous deviations

### Key Design Principles

- **ADRs are immutable** — once accepted, never edited; reversals create new ADRs
- **`decisions.md` is append-only** — each phase appends; never overwrite
- **Directories are created lazily** — agents create `decisions/`, `plans/`, and `reports/` if missing
- **Run directories use date prefixes** — with `-02`, `-03` suffixes for same-day reruns
- **Code references documentation** — comments use the pattern `// See ADR {NNNN} or docs/reports/[path] for full context`

## Usage

- Reference `global/opencode/commands/` for reusable command templates
- Configure `global/opencode/opencode.json` to point to your preferred LLM providers
- Modify `global/opencode/agents/` to customize agent behavior
- Copy or symlink `projects/AGENTS.md` into your project root to enable the `docs/` workflow