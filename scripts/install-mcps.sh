#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_JSON="${ROOT_DIR}/.mcp.json"
CONFIG_DIR="${HOME}/.codex"
CONFIG_PATH="${CONFIG_DIR}/config.toml"

if [[ ! -f "${MCP_JSON}" ]]; then
  echo "Missing ${MCP_JSON}. Expected repo MCP config."
  exit 1
fi

mkdir -p "${CONFIG_DIR}"
touch "${CONFIG_PATH}"

python3 - "${MCP_JSON}" "${CONFIG_PATH}" <<'PY'
import json
import pathlib
import sys

mcp_json = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])

data = json.loads(mcp_json.read_text())
servers = data.get("mcpServers", {})
target_names = ("sosumi", "XcodeBuildMCP")

text = config_path.read_text()

def add_server(name: str, server: dict, content: str) -> str:
    lines = [f"\n[mcp_servers.{name}]"]
    command = server.get("command")
    if command:
        lines.append(f'command = "{command}"')
    args = server.get("args")
    if args:
        args_list = ", ".join(f'"{arg}"' for arg in args)
        lines.append(f"args = [{args_list}]")
    env = server.get("env")
    if env:
        lines.append(f"[mcp_servers.{name}.env]")
        for key, value in env.items():
            lines.append(f'{key} = "{value}"')
    return content + "\n".join(lines) + "\n"

for name in target_names:
    if f"[mcp_servers.{name}]" in text:
        continue
    server = servers.get(name)
    if not server:
        continue
    text = add_server(name, server, text)
config_path.write_text(text)
print("✅ Codex MCP servers installed")
PY
