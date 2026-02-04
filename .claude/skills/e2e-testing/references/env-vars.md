# E2E Environment Variables

> Source of truth: `test/gateway.multi.e2e.test.ts`

## Process Isolation

| Variable | Purpose | Example |
|----------|---------|---------|
| `HOME` | Isolated home directory | `/tmp/openclaw-e2e-test-xyz/` |
| `OPENCLAW_CONFIG_PATH` | Config file location | `$HOME/.openclaw/openclaw.json` |
| `OPENCLAW_STATE_DIR` | State directory | `$HOME/.openclaw/state/` |

## Authentication

| Variable | Purpose | Example |
|----------|---------|---------|
| `OPENCLAW_GATEWAY_TOKEN` | Auth token (empty = no auth) | `token-test-123` |
| `OPENCLAW_GATEWAY_PORT` | Gateway port | `8080` |

## Feature Toggles

| Variable | Purpose | When to Use |
|----------|---------|-------------|
| `OPENCLAW_SKIP_PROVIDERS` | Skip provider init | Fast startup tests |
| `OPENCLAW_SKIP_BROWSER_CONTROL_SERVER` | Skip browser server | Non-browser tests |
| `OPENCLAW_SKIP_CANVAS_HOST` | Skip canvas host | Non-canvas tests |
| `OPENCLAW_ENABLE_BRIDGE_IN_TESTS` | Enable bridge | Bridge testing |

## Example: Minimal Isolated Gateway

```typescript
const env = {
  ...process.env,
  HOME: tempHomeDir,
  OPENCLAW_GATEWAY_TOKEN: "",  // No auth
  OPENCLAW_SKIP_PROVIDERS: "1",
  OPENCLAW_SKIP_BROWSER_CONTROL_SERVER: "1",
  OPENCLAW_SKIP_CANVAS_HOST: "1",
};
```
