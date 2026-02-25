# claude-code-kit

> An "Oh My Zsh"-style starter kit for [Claude Code](https://claude.ai/code). Package and share skills, agents, and commands — install them globally or inject them into any project.

---

## Global Installation

Run these two commands in your terminal:

```sh
git clone https://github.com/Devattom/claude-code-kit.git ~/.claude-dev-kit
sh ~/.claude-dev-kit/scripts/install.sh
```

The installer will:

1. Clone this repo to `~/.claude-dev-kit/`
2. Ask a few questions to build your profile (name, role, experience level, preferred language and response style) — written to `~/.claude/CLAUDE.md`
3. Configure permissions in `~/.claude/settings.json` — use the kit's safe defaults or set your own
4. Check that Claude Code is installed, and offer to install it via npm if not
5. Symlink all global skills, agents, and commands into `~/.claude/`

> **Re-running the installer** is safe — it updates the repo (`git pull`) and lets you refresh your profile.

---

## Adding Skills to a Project

Inside Claude Code, use the `import-project` skill to inject tech-specific skill packs into your current project:

```
/import-project laravel inertia
```

This copies the matching packs from `~/.claude-dev-kit/projects/skills/` into your project's `.claude/skills/` directory.

---

## Repository Structure

```
/global/            Tech-agnostic assets, symlinked to ~/.claude/ on install
  /skills/          Global Claude Code skills (e.g. git, import-project)
  /agents/          Global agent definitions
  /commands/        Global slash commands
  /statusLine/      Status line configuration

/projects/          Tech-specific packs, injected per-project via /import-project
  /skills/          e.g. laravel/, inertia/, vue/, react/
  /agents/
  /commands/

/scripts/
  install.sh        Global one-liner installer

/templates/
  settings.json     Base permissions config (safe defaults)
```

---

## Updating

```sh
git -C ~/.claude-dev-kit pull
```

Symlinks stay in place — new skills in `global/` are available immediately after pulling.

---

## Contributing

Pull requests are welcome. To add a new project skill pack, create a directory under `projects/skills/<tech-name>/` with a `SKILL.md` following the [Claude Code skill format](https://code.claude.com/docs/en/skills).
