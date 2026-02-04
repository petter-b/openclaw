---
name: e2e-testing
description: Provides E2E test patterns for gateway integration testing. Use when writing tests that spawn real gateway processes, test CLI commands, or validate multi-instance scenarios.
---

# End-to-End Testing

Apply E2E patterns when writing integration tests against real processes.

## When to Use E2E vs Unit

| Aspect | Unit | E2E |
|--------|------|-----|
| Location | `src/**/*.test.ts` | `test/**/*.e2e.test.ts` |
| Config | `vitest.config.ts` | `vitest.e2e.config.ts` |
| Dependencies | Mocked | Real processes |
| Speed | Fast (ms) | Slow (seconds) |
| Timeout | Default 10s | Extended 120s |

## Quick Reference

```bash
pnpm test:e2e              # Run all E2E tests
pnpm test:e2e --grep auth  # Filter by pattern
```

## Key Patterns

See `references/patterns.md` for:
- `getFreePort()` - Ephemeral port allocation
- `waitForPortOpen()` - Port readiness with stdout/stderr capture
- `spawnGatewayInstance()` - Process isolation with temp HOME
- Graceful cleanup with SIGTERM → SIGKILL fallback

## Environment Variables

See `references/env-vars.md` for:
- `HOME` - Isolated home directory per test
- `OPENCLAW_GATEWAY_TOKEN` - Auth token (empty for no auth)
- `OPENCLAW_SKIP_PROVIDERS` - Skip provider initialization

## Source of Truth

`test/gateway.multi.e2e.test.ts` - Reference implementation for all E2E patterns.
Check this file for current signatures (they may evolve).

## When This Skill Activates

- Writing integration tests against real gateway
- Testing CLI commands with JSON output
- Multi-instance gateway scenarios
- Process lifecycle testing (spawn, wait, cleanup)
