#!/usr/bin/env bash
# Generate a single markdown file with key source components + concept docs.
# Usage: bash docs/repo2txt-core.sh > openclaw-core.md

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

SOURCE_FILES=(
  # Gateway
  src/gateway/server.impl.ts
  src/gateway/server-chat.ts
  src/gateway/server-channels.ts
  src/gateway/server-startup.ts
  src/gateway/boot.ts

  # Channels
  src/channels/registry.ts
  src/channels/dock.ts
  src/channels/plugins/types.plugin.ts
  src/channels/session.ts

  # Routing
  src/routing/resolve-route.ts
  src/routing/bindings.ts
  src/routing/session-key.ts

  # Agents
  src/agents/pi-embedded-runner.ts
  src/agents/pi-embedded-runner/run.ts
  src/agents/pi-embedded-runner/runs.ts
  src/agents/pi-embedded-runner/types.ts
  src/agents/pi-tools.ts
  src/agents/models-config.ts
  src/agents/system-prompt.ts
  src/agents/context.ts
  src/agents/skills.ts
  src/agents/subagent-registry.ts

  # Plugins
  src/plugins/types.ts
  src/plugins/registry.ts
  src/plugins/hooks.ts
  src/plugins/loader.ts
  src/plugin-sdk/index.ts

  # Config
  src/config/config.ts
  src/config/types.ts
  src/config/schema.ts
)

echo "# OpenClaw Core — Source + Docs"
echo ""
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- Project structure ---
echo "## Project Structure"
echo ""
echo '```'
echo "Source files:"
for f in "${SOURCE_FILES[@]}"; do
  echo "  $f"
done
echo ""
echo "Documentation:"
for f in docs/concepts/*.md; do
  echo "  $f"
done
echo '```'
echo ""

# --- Source files ---
echo "## Source Files"
echo ""

for f in "${SOURCE_FILES[@]}"; do
  echo "### $f"
  echo ""
  echo '```typescript'
  cat "$f"
  echo '```'
  echo ""
done

# --- Docs ---
echo "## Documentation (docs/concepts/)"
echo ""

for f in docs/concepts/*.md; do
  name=$(basename "$f")
  echo "### $name"
  echo ""
  cat "$f"
  echo ""
done
