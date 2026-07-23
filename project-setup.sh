#!/usr/bin/env bash
# project-setup.sh — repo-root wrapper around mcp/project-setup.sh.
#
# Refreshes the bundled mcp/ snapshot from the authoritative repo-root copies
# (server.py, requirements.txt), then delegates to mcp/project-setup.sh with
# the same arguments. Use this from a checkout of this repo; inside an
# installed skill bundle run mcp/project-setup.sh directly.
#
# Usage:
#   ./project-setup.sh /path/to/project [options]   # one project
#   ./project-setup.sh --global [options]           # all projects (user scope)
#
# See mcp/project-setup.sh --help for all options
# (--model, --server-name, --skip-deps).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/mcp/project-setup.sh"

if [ ! -f "$INSTALLER" ]; then
    echo "error: mcp/project-setup.sh not found next to this script" >&2
    exit 1
fi

# The repo-root server.py and requirements.txt are authoritative; the installer
# copies the mcp/ snapshot into target projects, so bring it up to date first.
for f in server.py requirements.txt; do
    if ! cmp -s "$SCRIPT_DIR/$f" "$SCRIPT_DIR/mcp/$f"; then
        cp "$SCRIPT_DIR/$f" "$SCRIPT_DIR/mcp/$f"
        echo "==> refreshed mcp/$f from repo-root $f"
    fi
done

exec bash "$INSTALLER" "$@"
