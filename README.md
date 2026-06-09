# jerb-skills

Agent skills authored by [@JERB78](https://github.com/JERB78). Compatible with [Claude Code](https://github.com/anthropics/claude-code), Cursor, Continue, Codex, Gemini CLI, and other agents that support the [Anthropic Skills](https://www.anthropic.com/news/agent-skills) progressive-disclosure format.

## Install

### All skills

```bash
npx skills add JERB78/jerb-skills --all
```

### One skill

```bash
npx skills add JERB78/jerb-skills --skill forms-builder-pro
npx skills add JERB78/jerb-skills --skill docker-master
```

### Globally (user-level)

```bash
npx skills add JERB78/jerb-skills --all -g
```

## Available skills

### [`forms-builder-pro`](./skills/forms-builder-pro/)

Build professional Google Forms (Apps Script paste-and-run) with rich content: charts, tables, lists, embedded images via base64, YouTube videos. Includes auto-slug to snake_case headers, NPS / Dashboard tabs, webhook + email notifications. Inspired by the Claude Code `AskUserQuestion` visual style.

**Use when:** the user asks to create surveys, internal feedback forms, NPS questionnaires, customer onboarding forms, or any structured data collection workflow on Google Forms.

### [`docker-master`](./skills/docker-master/)

Kitchen-sink Docker skill for create/modify/manage/analyze/debug operations. Covers containers, images, compose, Dockerfile authoring, multi-source builds (Docker Hub, GHCR, GitHub direct, local, ECR), security scanning, and cleanup. Includes 9 production-grade Dockerfile templates (Node, Python, Rust, Go, .NET, PHP, Ruby, Java, Tauri), 3 compose templates, and 5 cross-platform scripts (PS1 + Bash). Windows-aware (WSL2, VHDX shrink, CRLF gotchas).

**Use when:** the user asks to dockerize an app, debug a failing container, build from GitHub, design a multi-service compose stack, clean up Docker disk usage, scan images for vulnerabilities, or any Docker-related task.

## Format

Each skill follows the modern progressive-disclosure layout:

```
skills/<skill-name>/
├── SKILL.md           # Entry point with YAML frontmatter (name + description)
├── references/        # Detailed docs loaded on-demand
├── scripts/           # Deterministic helpers (PS1 / Bash / Python)
├── assets/            # Templates, snippets, boilerplate
└── evals/             # Test cases with assertions
```

## License

[MIT](./LICENSE)

## Author

Jorge ([@JERB78](https://github.com/JERB78))
