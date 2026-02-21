# PROJECT_CONTEXT.md

This file provides project-specific context for AI agents working on this codebase. It contains project-specific paths, build commands, testing methodology, and environment details. Workflow conventions, documentation structure, and agent protocols are defined in the global command files (`write-plan.md` and `execute-plan.md`).

## Project Overview

<!-- Briefly describe what this project does and its primary language/framework -->

## Project Structure

<!-- UPDATE THE STRUCTURE BELOW TO MATCH YOUR ACTUAL PROJECT LAYOUT -->

```
├── src/               # Application source code
├── tests/             # Test files
├── docs/              # Documentation (decisions, plans, reports)
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

## Test Fixtures

<!-- Document test fixtures and sample data used for validation:
- Path to fixture files (relative to project root)
- What each fixture contains and what it's used for
- File types/formats involved
- Any setup required before tests can use them

Example:
- Fixture path: `tests/fixtures/sample_model/`
- Contents: Sample .obj, .mtl, and .jpg files for 3D model validation
- Used by: Integration tests in `tests/integration/`
-->

## Cleanup Rules

<!-- Define what generated files should be cleaned up after tests pass.
Only list file types or patterns that are GENERATED during testing — not source files.

Example:
- Delete `*.obj`, `*.mtl`, `*.jpg` files created during testing
- Do NOT delete source fixtures in `tests/fixtures/`
- Do NOT delete files listed in handoff reports

If no cleanup is needed, write: "No automated cleanup required."
-->

## Dependencies & Environment

<!-- Document any environment setup, required tools, or dependencies:
- Required tools (compilers, runtimes, etc.)
- Environment variables
- External services
- OS-specific requirements
-->
