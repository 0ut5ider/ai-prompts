# AI Prompts Repository

Configuration and prompts for AI-assisted development workflows.

## Structure

```
ai-prompts/
├── global/                    # OpenCode global configuration
│   ├── opencode/
│   │   ├── commands/         # Reusable command definitions
│   │   ├── agents/          # Agent configurations
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
- **Providers** (`global/opencode/opencode.json`): LLM provider settings for MiniMax M2.1 and other models

### Quick Setup

For OpenCode to use this configuration, create symlinks to the natural storage locations:

```bash
ln -s ai-prompts/opencode/agents/ .
ln -s ai-prompts/opencode/commands/ .
ln -s ai-prompts/opencode/AGENTS.md .
ln -s ai-prompts/opencode/opencode.json .
```

## Usage

- Reference `global/opencode/commands/` for reusable command templates
- Configure `global/opencode/opencode.json` to point to your preferred LLM providers
- Modify `global/opencode/agents/` to customize agent behavior