#!/usr/bin/env sh
# ==============================================================================
# claude-code-kit — Global Installer
# ==============================================================================
# Usage:
#   git clone https://github.com/Devattom/claude-code-kit.git ~/.claude-dev-kit
#   sh ~/.claude-dev-kit/scripts/install.sh
# ==============================================================================

set -e

REPO_URL="https://github.com/Devattom/claude-code-kit.git"
KIT_DIR="$HOME/.claude-dev-kit"
CLAUDE_DIR="$HOME/.claude"

# ------------------------------------------------------------------------------
# Output helpers (POSIX-compatible colors via tput with graceful fallback)
# ------------------------------------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  BOLD=$(tput bold    2>/dev/null || true)
  GREEN=$(tput setaf 2 2>/dev/null || true)
  YELLOW=$(tput setaf 3 2>/dev/null || true)
  BLUE=$(tput setaf 4 2>/dev/null || true)
  RED=$(tput setaf 1 2>/dev/null || true)
  NC=$(tput sgr0     2>/dev/null || true)
else
  BOLD="" GREEN="" YELLOW="" BLUE="" RED="" NC=""
fi

info()    { printf "%s→%s %s\n"  "$BLUE"   "$NC" "$1"; }
success() { printf "%s✓%s %s\n"  "$GREEN"  "$NC" "$1"; }
warn()    { printf "%s!%s %s\n"  "$YELLOW" "$NC" "$1"; }
error()   { printf "%s✗%s %s\n"  "$RED"    "$NC" "$1" >&2; }
title()   { printf "\n%s=== %s ===%s\n\n" "$BOLD" "$1" "$NC"; }
ask()     { printf "%s?%s %s " "$BOLD" "$NC" "$1"; }

# Prompts yes/no, returns 0 for yes, 1 for no
# Usage: confirm "question" "Y"   (second arg = default: Y or N)
confirm() {
  _default="${2:-N}"
  if [ "$_default" = "Y" ]; then _hint="[Y/n]"; else _hint="[y/N]"; fi
  ask "$1 $_hint:"
  read -r _ans
  [ -z "$_ans" ] && _ans="$_default"
  case "$_ans" in y|Y) return 0 ;; *) return 1 ;; esac
}

# ==============================================================================
# STEP 1 — Clone or update the repository
# ==============================================================================
title "Repository Setup"

if [ -d "$KIT_DIR/.git" ]; then
  info "claude-code-kit already installed at $KIT_DIR — updating…"
  git -C "$KIT_DIR" pull --ff-only
  success "Repository updated"
else
  info "Cloning claude-code-kit into $KIT_DIR…"
  git clone "$REPO_URL" "$KIT_DIR"
  success "Repository cloned"
fi

# ==============================================================================
# STEP 2 — Profile interview
# ==============================================================================
title "Your Profile"
info "This information will be written to $CLAUDE_DIR/CLAUDE.md so Claude knows who you are."
printf "\n"

ask "Your name:"
read -r PROFILE_NAME

ask "Your role (e.g. Fullstack Dev, Backend Dev, DevOps Engineer):"
read -r PROFILE_ROLE

printf "%s  Experience level:%s\n" "$BOLD" "$NC"
printf "    1) Junior\n"
printf "    2) Mid\n"
printf "    3) Senior\n"
printf "    4) Lead / Architect\n"
ask "Choose [1-4] (default: 3):"
read -r _lvl
case "$_lvl" in
  1) PROFILE_LEVEL="Junior" ;;
  2) PROFILE_LEVEL="Mid" ;;
  4) PROFILE_LEVEL="Lead / Architect" ;;
  *) PROFILE_LEVEL="Senior" ;;
esac

printf "%s  Response style:%s\n" "$BOLD" "$NC"
printf "    1) Concise and direct\n"
printf "    2) Detailed with explanations\n"
ask "Choose [1-2] (default: 1):"
read -r _style
case "$_style" in
  2) PROFILE_STYLE="Detailed — include explanations, rationale, and examples" ;;
  *) PROFILE_STYLE="Concise and direct — short answers, no fluff" ;;
esac

ask "Preferred language for Claude responses (e.g. English, French) [English]:"
read -r _lang
PROFILE_LANG="${_lang:-English}"

# ==============================================================================
# STEP 3 — Security & permissions
# ==============================================================================
title "Security & Permissions"

BASE_SETTINGS="$KIT_DIR/templates/settings.json"
USE_BASE_SETTINGS="false"
BYPASS_PERMS="false"
DENY_RULES=""

if [ -f "$BASE_SETTINGS" ]; then
  info "A base settings.json is provided by the kit (safe defaults: no bypass, dangerous commands blocked)."
  if confirm "Use the kit's base settings.json?" "Y"; then
    USE_BASE_SETTINGS="true"
    success "Will use kit base settings"
  else
    info "Skipping base — configuring manually…"
  fi
fi

if [ "$USE_BASE_SETTINGS" = "false" ]; then
  if confirm "Allow Claude to run tool calls without asking for confirmation? (bypass mode)" "N"; then
    BYPASS_PERMS="true"
    if confirm "Still block dangerous commands? (rm -rf, sudo, force push…)" "Y"; then
      DENY_RULES='"Bash(rm -rf *)", "Bash(rm -r /*)", "Bash(sudo *)", "Bash(git push --force *)", "Bash(git push -f *)", "Bash(git reset --hard *)", "Bash(git clean -f *)", "Bash(DROP *)", "Bash(truncate *)"'
      success "Dangerous command filters will be applied"
    else
      warn "No filters applied — Claude will have full bypass access"
    fi
  fi
fi

# ==============================================================================
# STEP 4 — Check Claude Code installation
# ==============================================================================
title "Claude Code"

if command -v claude >/dev/null 2>&1; then
  _ver=$(claude --version 2>/dev/null || echo "unknown version")
  success "Claude Code is installed ($_ver)"
else
  warn "Claude Code not found in PATH"
  if confirm "Install Claude Code now via npm?" "Y"; then
    if command -v npm >/dev/null 2>&1; then
      info "Installing @anthropic-ai/claude-code globally…"
      npm install -g @anthropic-ai/claude-code
      success "Claude Code installed"
    else
      error "npm not found. Install Node.js first: https://nodejs.org"
      error "Then re-run this installer."
      exit 1
    fi
  else
    warn "Skipping Claude Code install — some features won't be available until it's installed"
  fi
fi

# ==============================================================================
# STEP 5 — Write profile to ~/.claude/CLAUDE.md
# ==============================================================================
title "Writing Profile"

mkdir -p "$CLAUDE_DIR"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

PROFILE_BLOCK="<!-- BEGIN: claude-code-kit profile -->
## User Profile

- **Name**: $PROFILE_NAME
- **Role**: $PROFILE_ROLE
- **Level**: $PROFILE_LEVEL
- **Response language**: $PROFILE_LANG
- **Response style**: $PROFILE_STYLE

*Managed by claude-code-kit — edit freely or re-run the installer to update.*
<!-- END: claude-code-kit profile -->"

if [ -f "$CLAUDE_MD" ]; then
  # Remove the previous profile block (if any), then append the new one
  _tmpfile="${CLAUDE_MD}.kit.tmp"
  sed '/<!-- BEGIN: claude-code-kit profile -->/,/<!-- END: claude-code-kit profile -->/d' "$CLAUDE_MD" > "$_tmpfile"
  printf "\n%s\n" "$PROFILE_BLOCK" >> "$_tmpfile"
  mv "$_tmpfile" "$CLAUDE_MD"
  success "Profile updated in $CLAUDE_MD"
else
  printf "%s\n" "$PROFILE_BLOCK" > "$CLAUDE_MD"
  success "Profile written to $CLAUDE_MD"
fi

# ==============================================================================
# STEP 6 — Write ~/.claude/settings.json
# ==============================================================================
title "Permissions Settings"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"
_write_settings="true"

if [ -f "$SETTINGS_FILE" ]; then
  warn "settings.json already exists at $SETTINGS_FILE"
  if ! confirm "Overwrite it?" "N"; then
    _write_settings="false"
    info "Keeping existing settings.json"
  fi
fi

if [ "$_write_settings" = "true" ]; then
  if [ "$USE_BASE_SETTINGS" = "true" ]; then
    cp "$BASE_SETTINGS" "$SETTINGS_FILE"
    success "Base settings.json copied to $SETTINGS_FILE"
  else
    if [ "$BYPASS_PERMS" = "true" ]; then
      if [ -n "$DENY_RULES" ]; then
        _allow_block='"allow": ["*"]'
        _deny_block="\"deny\": [$DENY_RULES]"
      else
        _allow_block='"allow": ["*"]'
        _deny_block='"deny": []'
      fi
    else
      _allow_block='"allow": []'
      _deny_block='"deny": []'
    fi
    cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    $_allow_block,
    $_deny_block
  }
}
EOF
    success "settings.json created at $SETTINGS_FILE"
  fi
fi

# ==============================================================================
# STEP 7 — StatusLine
# ==============================================================================
title "Status Line"

STATUSLINE_SRC="$KIT_DIR/global/scripts/statusline"
STATUSLINE_DEST="$CLAUDE_DIR/scripts/statusline"
STATUSLINE_ENTRY="$STATUSLINE_DEST/index.js"
INSTALL_STATUSLINE="false"

if [ -d "$STATUSLINE_SRC" ]; then
  info "The kit includes a built-in status line (Node.js, no extra dependencies):"
  info "  git branch • project path • model • cost (duration) • context bar%"
  printf "\n"
  printf "%s  Options:%s\n" "$BOLD" "$NC"
  printf "    1) Install kit statusLine (recommended)\n"
  printf "    2) Skip — I'll set up my own statusLine\n"
  printf "    3) Skip — I don't want a statusLine\n"
  ask "Choose [1-3] (default: 1):"
  read -r _sl_choice
  case "${_sl_choice:-1}" in
    2)
      warn "Skipping statusLine — configure manually in $CLAUDE_DIR/settings.json"
      ;;
    3)
      info "No statusLine will be configured"
      ;;
    *)
      INSTALL_STATUSLINE="true"
      ;;
  esac
fi

if [ "$INSTALL_STATUSLINE" = "true" ]; then
  mkdir -p "$CLAUDE_DIR/scripts"

  # Copy the statusline directory (overwrites on re-install to pick up updates)
  rm -rf "$STATUSLINE_DEST"
  cp -r "$STATUSLINE_SRC" "$STATUSLINE_DEST"
  chmod +x "$STATUSLINE_ENTRY"
  success "StatusLine copied to $STATUSLINE_DEST"

  # Patch settings.json to add the statusLine config
  # Uses node (already required by Claude Code) — no extra dependencies
  if [ -f "$SETTINGS_FILE" ]; then
    SETTINGS_FILE="$SETTINGS_FILE" STATUSLINE_ENTRY="$STATUSLINE_ENTRY" node -e "
const fs = require('fs');
const p = process.env.SETTINGS_FILE;
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.statusLine = {
  type: 'command',
  command: 'node ' + process.env.STATUSLINE_ENTRY
};
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"
    success "statusLine config added to $SETTINGS_FILE"
  else
    warn "settings.json not found — add this to $SETTINGS_FILE manually:"
    warn "  \"statusLine\": { \"type\": \"command\", \"command\": \"node $STATUSLINE_ENTRY\" }"
  fi
fi

# ==============================================================================
# STEP 8 — Merge global MCPs into ~/.claude.json
# ==============================================================================
title "Global MCPs"

MCPS_DIR="$KIT_DIR/global/mcps"
CLAUDE_JSON="$HOME/.claude.json"

if [ -d "$MCPS_DIR" ]; then
  for _mcp_file in "$MCPS_DIR"/*.json; do
    [ -f "$_mcp_file" ] || continue
    _mcp_name=$(basename "$_mcp_file" .json)

    _already=$(CLAUDE_JSON="$CLAUDE_JSON" MCP_NAME="$_mcp_name" node -e "
const fs = require('fs');
const p = process.env.CLAUDE_JSON;
if (!fs.existsSync(p)) { process.stdout.write('no'); process.exit(); }
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
process.stdout.write(d.mcpServers && d.mcpServers[process.env.MCP_NAME] ? 'yes' : 'no');
")

    if [ "$_already" = "yes" ]; then
      info "MCP $_mcp_name already configured — skipping"
    else
      CLAUDE_JSON="$CLAUDE_JSON" MCP_FILE="$_mcp_file" MCP_NAME="$_mcp_name" node -e "
const fs = require('fs');
const p = process.env.CLAUDE_JSON;
const mcp = JSON.parse(fs.readFileSync(process.env.MCP_FILE, 'utf8'));
const d = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
d.mcpServers = d.mcpServers || {};
d.mcpServers[process.env.MCP_NAME] = mcp;
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"
      success "MCP $_mcp_name configured"
    fi
  done
else
  info "No global MCPs to configure"
fi

# ==============================================================================
# STEP 9 — Create symlinks for global assets
# ==============================================================================
title "Linking Global Assets"

# link_dir <category>
# Links each subdirectory of $KIT_DIR/global/<category>/ into $CLAUDE_DIR/<category>/

link_dir() {
  _cat="$1"
  _src="$KIT_DIR/global/$_cat"
  _dest="$CLAUDE_DIR/$_cat"

  if [ ! -d "$_src" ]; then
    return 0
  fi

  mkdir -p "$_dest"

  for _item in "$_src"/*/; do
    [ -d "$_item" ] || continue
    _name=$(basename "$_item")
    _link="$_dest/$_name"

    if [ -L "$_link" ]; then
      info "$_cat/$_name already linked — skipping"
    elif [ -e "$_link" ]; then
      warn "$_link exists and is not a symlink — skipping (remove it manually to link)"
    else
      ln -s "$_item" "$_link"
      success "Linked $_cat/$_name"
    fi
  done
}

link_dir "skills"
link_dir "agents"
link_dir "commands"


# ==============================================================================
# Done
# ==============================================================================
printf "\n%s✓ claude-code-kit installed successfully!%s\n\n" "$GREEN$BOLD" "$NC"
printf "What's next:\n"
printf "  • Edit your profile:        %s\n" "$CLAUDE_MD"
printf "  • Edit permissions:         %s\n" "$SETTINGS_FILE"
printf "  • Add skills to a project:  use the /import-project skill inside Claude Code\n"
printf "  • Update the kit:           git -C %s pull\n\n" "$KIT_DIR"
