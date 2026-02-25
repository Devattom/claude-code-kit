# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This is **claude-code-kit** — a public, open-source "Oh My Zsh"-style starter kit for Claude Code. It packages skills, commands, agents, and status line configs that any developer can install globally or inject into a specific project. The repo contains zero personal/user data; everything user-specific is generated locally at install time.

## Architecture

```
/claude-code-kit
  /global/                  # Tech-agnostic configs, available on every project
    /skills/
      /import-project/      # Skill to inject project packs into the current project
        SKILL.md
        /scripts/
          import-project.sh
      /git/
        SKILL.md
    /agents/
    /commands/
    /statusLine/
  /projects/                # Tech-specific packs (mirrors /global/ structure)
    /skills/
      /laravel/
        SKILL.md
        /scripts/
      /inertia/
        SKILL.md
      /vue/
        SKILL.md
    /agents/
    /commands/
  /scripts/
    install.sh              # Global one-liner installer
  /templates/
    profile.md.tpl          # Template for ~/.claude/profile.md
  README.md
  CLAUDE.md
```

## Install Flows

**Global install** (`scripts/install.sh`):
1. Clone the repo to `~/.claude-dev-kit/`
2. Interactive profile interview → appended to `~/.claude/CLAUDE.md` between kit-managed markers
3. Security interview → writes `~/.claude/settings.json` (`permissions.allow` / `permissions.deny`)
4. Checks Claude Code is installed, offers npm install if not
5. Symlinks each subdirectory of `global/skills/`, `global/agents/`, `global/commands/` into the matching `~/.claude/` directory
6. The `import-project` skill is now globally available in Claude Code

One-liner install:
```sh
curl -sL https://raw.githubusercontent.com/<user>/claude-code-kit/main/scripts/install.sh | sh
```

Re-running the installer does a `git pull` + re-asks profile questions (safe to run multiple times).

**Per-project** (via the `import-project` global skill):
- Invoked with tech arguments: `/import-project laravel inertia`
- Its `scripts/import-project.sh` copies matching packs from `~/.claude-dev-kit/projects/skills/`, `projects/agents/`, `projects/commands/` into `./.claude/` of the current project

## Skill Structure

Claude Code loads skills from `~/.claude/skills/<skill-name>/SKILL.md` (personal, all projects) or `.claude/skills/<skill-name>/SKILL.md` (project-scoped).

Every entry in `global/skills/` and `projects/skills/` follows this layout:

```
my-skill/
├── SKILL.md          # Required — YAML frontmatter + markdown instructions
└── scripts/          # Optional — shell helpers the skill can invoke
    └── helper.sh
```

`SKILL.md` frontmatter reference (all fields optional except `description` is strongly recommended):

```yaml
---
name: skill-name                  # defaults to directory name
description: When and why to use this skill
disable-model-invocation: true    # user-only invocation (/skill-name)
allowed-tools: Bash, Read         # tools allowed without per-use approval
context: fork                     # run in isolated subagent
---
```

## Conventions

- `install.sh` is POSIX sh (`#!/usr/bin/env sh`); skill `scripts/` may use `#!/usr/bin/env bash`
- Each skill directory is self-contained — everything it needs lives inside it
- `global/` = tech-agnostic skills available everywhere; `projects/` = tech-specific skill packs
- Profile block in `~/.claude/CLAUDE.md` is delimited by `<!-- BEGIN: claude-code-kit profile -->` / `<!-- END: claude-code-kit profile -->` markers so re-installs update it cleanly
