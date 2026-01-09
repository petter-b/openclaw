# E2E Environment Variables

> Source of truth: `test/gateway.multi.e2e.test.ts`

## Process Isolation

| Variable | Purpose | Example |
|----------|---------|---------|
| `HOME` | Isolated home directory | `/tmp/clawdbot-e2e-test-xyz/` |
| `CLAWDBOT_CONFIG_PATH` | Config file location | `$HOME/.clawdbot/clawdbot.json` |
| `CLAWDBOT_STATE_DIR` | State directory | `$HOME/.clawdbot/state/` |

## Authentication

| Variable | Purpose | Example |
|----------|---------|---------|
| `CLAWDBOT_GATEWAY_TOKEN` | Auth token (empty = no auth) | `token-test-123` |
| `CLAWDBOT_GATEWAY_PORT` | Gateway port | `8080` |

## Feature Toggles

| Variable | Purpose | When to Use |
|----------|---------|-------------|
| `CLAWDBOT_SKIP_PROVIDERS` | Skip provider init | Fast startup tests |
| `CLAWDBOT_SKIP_BROWSER_CONTROL_SERVER` | Skip browser server | Non-browser tests |
| `CLAWDBOT_SKIP_CANVAS_HOST` | Skip canvas host | Non-canvas tests |
| `CLAWDBOT_ENABLE_BRIDGE_IN_TESTS` | Enable bridge | Bridge testing |

## Example: Minimal Isolated Gateway

```typescript
const env = {
  ...process.env,
  HOME: tempHomeDir,
  CLAWDBOT_GATEWAY_TOKEN: "",  // No auth
  CLAWDBOT_SKIP_PROVIDERS: "1",
  CLAWDBOT_SKIP_BROWSER_CONTROL_SERVER: "1",
  CLAWDBOT_SKIP_CANVAS_HOST: "1",
};
```
