# PROJECT_CONTEXT.md

This file provides project-specific context for AI agents working on this codebase. It complements `AGENTS.md` which contains the generic agent workflow, documentation structure, and conventions.

Read `AGENTS.md` first for the general framework, then this file for project-specific details.

## Project Overview

<!-- Briefly describe what this project does and its primary language/framework -->

## Project Structure

<!-- UPDATE THE STRUCTURE BELOW TO MATCH YOUR ACTUAL PROJECT LAYOUT -->

```
├── src/               # Application source code
├── tests/             # Test files
├── docs/              # Documentation (see AGENTS.md for structure)
└── README.md          # Project overview
```

## Build & Test Commands

<!-- ADD YOUR PROJECT'S ACTUAL COMMANDS HERE -->
<!-- Examples:
- Install dependencies: `npm install`
- Run tests: `npm test`
- Run single test: `npm test -- --grep "test name"`
- Build: `npm run build`
- Lint: `npm run lint`
-->

## Testing Methodology

<!-- Document your project's testing approach:
- Test framework(s) used
- How to run unit tests vs integration tests
- Test file naming conventions
- Coverage requirements
- Any test-specific environment setup
-->

## Code Change Protocol

When completing a feature, bug fix, or any change that affects user-visible behavior:

### Version Bumping

<!-- UPDATE THE PATHS AND COMMANDS BELOW TO MATCH YOUR PROJECT -->

The version number must be updated in **all** locations and they must match:

1. `<!-- path/to/version/source -->` (e.g., `src/version.h`, `package.json`, `pyproject.toml`)
2. `<!-- path/to/readme -->` (e.g., `README.md`)

**When to bump:**
- Minor version (X.Y → X.Y+1): feature additions, bug fixes that change behavior, new format support
- Major version (X.Y → X+1.0): breaking changes, architectural rewrites

**Do not** use suffixes like `-alpha` or `-custom`. Use plain `major.minor` format unless the project uses semver with patch versions.

Verify after bumping:
```
<!-- ADD YOUR VERSION VERIFICATION COMMAND -->
<!-- Example: make build && ./build/bin/myapp --version -->
```

### README Updates

If your changes add a new feature or change user-facing behavior, update the project README accordingly. The README documents the tool's capabilities — it must stay current.

## Project-Specific Paths

<!-- Document key paths that agents need to know about:
- Source code: `src/`
- Configuration: `config/`
- Generated files: `build/`
- Entry points: `src/main.c`, `src/index.ts`, etc.
-->

## Dependencies & Environment

<!-- Document any environment setup, required tools, or dependencies:
- Required tools (compilers, runtimes, etc.)
- Environment variables
- External services
- OS-specific requirements
-->
