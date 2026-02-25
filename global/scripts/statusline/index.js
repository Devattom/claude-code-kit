#!/usr/bin/env node
// ==============================================================================
// Claude Code kit — statusLine
// Inspired by: github.com/Melvynx/aiblueprint/claude-code-config/scripts/statusline
//
// Output (single line):
//   main* • ~/projects/app • Sonnet 4.6 • $0.05 (3m) • ████░░░░░░ 42%
//
// Runtime:  node (no extra dependencies)
// Install:  Handled by claude-code-kit installer
// ==============================================================================

const { execSync } = require("child_process");
const fs = require("fs");

// --- ANSI helpers ---
const R = "\x1b[0m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const SEP = `${DIM} • ${R}`;

// --- Read payload from stdin (fd 0 works cross-platform) ---
let raw = "";
try {
  raw = fs.readFileSync(0, "utf8");
} catch {
  raw = "{}";
}

let payload = {};
try {
  payload = JSON.parse(raw);
} catch {
  payload = {};
}

// --- Extract fields ---
const model = payload?.model?.display_name ?? "";
const cwd = payload?.workspace?.current_dir ?? payload?.cwd ?? "";
const cost = payload?.cost?.total_cost_usd ?? 0;
const durationMs = payload?.cost?.total_duration_ms ?? 0;
const pct = Math.floor(payload?.context_window?.used_percentage ?? 0);

// --- Git branch ---
function getGitPart(dir) {
  if (!dir) return "";
  try {
    const isGit = execSync(`git -C "${dir}" rev-parse --is-inside-work-tree 2>/dev/null`, {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();
    if (isGit !== "true") return "";

    const branch =
      execSync(`git -C "${dir}" branch --show-current 2>/dev/null`, {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "ignore"],
      }).trim() || "HEAD";

    const dirty = execSync(`git -C "${dir}" status --porcelain 2>/dev/null`, {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();

    return dirty ? `${CYAN}${branch}*${R}` : `${CYAN}${branch}${R}`;
  } catch {
    return "";
  }
}

// --- Short path (last 2 segments, ~ for $HOME) ---
function getPathPart(dir) {
  if (!dir) return "";
  const home = process.env.HOME ?? "";
  let display = home ? dir.replace(home, "~") : dir;
  const segments = display.split("/").filter(Boolean);
  if (segments.length > 3) {
    display = `…/${segments.slice(-2).join("/")}`;
  }
  return `${DIM}${display}${R}`;
}

// --- Duration formatting ---
function formatDuration(ms) {
  const s = Math.floor(ms / 1000);
  if (s <= 0) return "";
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  return `${Math.floor(s / 3600)}h${Math.floor((s % 3600) / 60)}m`;
}

// --- Context progress bar ---
function progressBar(pct, width = 10) {
  const filled = Math.round((pct * width) / 100);
  return "█".repeat(filled) + "░".repeat(width - filled);
}

function pctColor(pct) {
  if (pct >= 80) return RED;
  if (pct >= 50) return YELLOW;
  return GREEN;
}

// --- Build parts ---
const gitPart = getGitPart(cwd);
const pathPart = getPathPart(cwd);
const modelPart = model ? `${BOLD}${model}${R}` : "";

const costStr = `$${cost.toFixed(2)}`;
const durStr = formatDuration(durationMs);
const sessionPart = durStr ? `${costStr} (${durStr})` : costStr;

const bar = progressBar(pct);
const ctxPart = `${pctColor(pct)}${bar} ${pct}%${R}`;

// --- Assemble line ---
const parts = [gitPart, pathPart, modelPart, sessionPart].filter(Boolean);
const line = [...parts, ctxPart].join(SEP);

process.stdout.write(line + "\n");
