#!/bin/bash

# Check if the key file exists
if [ -f "$HOME/gemini.key" ]; then
    GEMINI_API_KEY=$(cat "$HOME/gemini.key")
else
    read -r -p "Enter Gemini KEY: " GEMINI_API_KEY
    echo "$GEMINI_API_KEY" > "$HOME/gemini.key"
fi

# Export GEMINI_API_KEY as primary, and GOOGLE_API_KEY for backward compatibility
export GEMINI_API_KEY
export GOOGLE_API_KEY="$GEMINI_API_KEY"

echo "✅ Environment variables GEMINI_API_KEY and GOOGLE_API_KEY successfully exported."

# Write keys to .env file (never hardcode in mcp_config.json)
CURRENT_DIR=$(pwd)
ENV_FILE="$CURRENT_DIR/.env"

cat > "$ENV_FILE" <<EOF
GEMINI_API_KEY=$GEMINI_API_KEY
GOOGLE_API_KEY=$GEMINI_API_KEY
EOF

source .env

echo "✅ Written API keys to $ENV_FILE"

# Update MCP configs with the absolute path based on the current directory:
#   .mcp.json                 -> Claude Code (macOS)
for CONFIG_FILE in "$CURRENT_DIR/.mcp.json" ; do
    if [ -f "$CONFIG_FILE" ]; then
        CONFIG_FILE="$CONFIG_FILE" CURRENT_DIR="$CURRENT_DIR" python3 -c "
import json, os
config_file = os.environ['CONFIG_FILE']
current_dir = os.environ['CURRENT_DIR']
key = os.environ['GEMINI_API_KEY']
with open(config_file) as f:
    data = json.load(f)
if 'mcpServers' in data and 'omni-video-agent' in data['mcpServers']:
    server = data['mcpServers']['omni-video-agent']
    server['args'] = [current_dir + '/server.py']
    # Inject keys directly into env block so the client passes them to the server process
    server.pop('envFile', None)
    server['env'] = {
        'GEMINI_API_KEY': key,
        'GOOGLE_API_KEY': key
    }
with open(config_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        echo "✅ Updated $CONFIG_FILE with path and env keys."
    else
        echo "⚠️  Could not find $CONFIG_FILE to update."
    fi
done

