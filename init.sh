#!/bin/bash
# Local setup for the Omni Flash video agent repo: checks python3, installs Python
# dependencies, registers the omni-video-agent MCP server in this repo's
# .mcp.json (pointing at the authoritative repo-root server.py), and runs
# set_env.sh to set up the Gemini API key. Safe to rerun.
#
# Run with ./init.sh. Sourcing also works and additionally exports
# GEMINI_API_KEY / GOOGLE_API_KEY into the current shell.

main() {
    local SCRIPT_DIR ERRORS=0
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 not found on PATH." >&2
        return 1
    fi

    echo "--- Installing Python dependencies ---"
    if ! python3 -m pip install -q -r "$SCRIPT_DIR/requirements.txt"; then
        echo "Warning: pip install failed." >&2
        ERRORS=$((ERRORS + 1))
    fi

    # --- Register the omni-video-agent MCP server for this repo ---
    # .mcp.json is generated (and gitignored) because set_env.sh injects the API
    # key into it. The entry points at the repo-root server.py — the authoritative
    # copy — not the mcp/ snapshot that gets installed into other projects. Only
    # create it when missing so a customized entry isn't clobbered; set_env.sh
    # below refreshes the path and key of an existing entry either way.
    echo -e "\n--- Registering the omni-video-agent MCP server (.mcp.json) ---"
    if [ -f "$SCRIPT_DIR/.mcp.json" ] && grep -q '"omni-video-agent"' "$SCRIPT_DIR/.mcp.json"; then
        echo "omni-video-agent already registered in .mcp.json; leaving it in place."
    elif ! SCRIPT_DIR="$SCRIPT_DIR" python3 - <<'EOF'
import json, os
root = os.environ["SCRIPT_DIR"]
path = os.path.join(root, ".mcp.json")
config = {}
if os.path.exists(path):
    with open(path) as f:
        config = json.load(f)
config.setdefault("mcpServers", {})["omni-video-agent"] = {
    "command": "python3",
    "args": [os.path.join(root, "server.py")],
    "env": {},
}
with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
print(f"Registered 'omni-video-agent' in {path}")
EOF
    then
        echo "Warning: MCP server registration failed." >&2
        ERRORS=$((ERRORS + 1))
    fi

    # --- Gemini API key (set_env.sh) ---
    # Reads ~/gemini.key or prompts for the key, persists it, writes .env, and
    # injects the key into the .mcp.json entry created above. Sourced from the
    # repo root because it resolves paths from $PWD.
    echo -e "\n--- Setting up the Gemini API key (set_env.sh) ---"
    local PREV_DIR="$PWD"
    cd "$SCRIPT_DIR" || return 1
    if ! . ./set_env.sh; then
        echo "Warning: set_env.sh failed." >&2
        ERRORS=$((ERRORS + 1))
    fi
    cd "$PREV_DIR" || return 1

    echo
    if [ "$ERRORS" -eq 0 ]; then
        echo "--- Full setup complete ---"
        echo "Restart Claude Code in $SCRIPT_DIR and approve the project MCP server;"
        echo "/mcp should list 'omni-video-agent'. To install the skill into another"
        echo "project: ./project-setup.sh /path/to/project (or make init TARGET=...)."
    else
        echo "--- Setup finished with $ERRORS error(s); see warnings above ---" >&2
        return 1
    fi
}

main "$@"
