# OpenCode Global Configuration

## General Instructions

Interview the user for any clarification for all prompts except ones where the requet is trivial. Use the question tool to format the questions. 

If a README.md file exists, always update it (if changes affect the contents) when making changes to the code. Delegate this task to a subagent.

ONLY IN BUILD MODE
- Delegate this task to a sub-agent to do coding implementations. 
- Delegate this task to a sub-agent for any other general file modifications. 

## MCP Server Usage

- Use context7 MPC server whenever the user requests the docs or documentation to be read.
- Use context7 MCP server whenever specific knowledge is required that context7 can provide. Error on the side of using context7 instead of not using it.
 


## Git Configuration

### Default Author Information
```yaml
git:
  username: "YOUR_NAME"
  email: "YOUR_EMAIL"
```

### Git Operations Policy

#### Repository Initialization
When initializing new git repositories, automatically configure:
```
git init
git config user.name "YOUR_NAME"
git config user.email "YOUR_EMAIL"
```

#### Commit Guidelines
- Always use conventional commit messages
- Include meaningful commit summaries (50 chars max)
- Add detailed descriptions for complex changes
- Reference issue/PR numbers when applicable
- Create feature branches for new work:
  - Naming convention: `feature/short-description`
  - Branch from main/develop as appropriate
  - Merge via PR when working in teams

#### Staging & Commits
- Stage changes intentionally: `git add <specific-files>`
- Write clear commit messages following format:
  ```
  <type>(<scope>): <subject>

  <body>

  <footer>
  ```
- Types: feat, fix, docs, style, refactor, perf, test, chore

#### Safe Operations
- Never force push to shared/main branches
- Create backups with `git stash` before risky operations
- Always verify changes with `git diff --staged` before commit
