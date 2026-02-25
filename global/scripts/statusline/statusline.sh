#!/usr/bin/env sh
# Claude Code kit — statusLine entry point
# Delegates to index.js via node
# Note: the installer registers the full `node <path>/index.js` command in settings.json
# This wrapper is provided for manual testing convenience.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$SCRIPT_DIR/index.js"
