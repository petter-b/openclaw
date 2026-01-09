---
name: writing-tests
description: Applies TDD practices when writing or modifying tests. Use when implementing features, fixing bugs, or adding test coverage. Provides mocking patterns, test helpers, and red-green-refactor workflow.
---

# Test-Driven Development

Apply TDD practices automatically when writing or modifying code.

## Red-Green-Refactor Cycle

1. **RED**: Write failing test first - confirm it fails for the right reason
2. **GREEN**: Write minimal code to pass - no more than needed
3. **REFACTOR**: Improve with tests passing - clean up, DRY, extract helpers

## Quick Reference

| Concern | Location |
|---------|----------|
| Test location | `src/**/*.test.ts` (colocated with source) |
| Run tests | `pnpm test --run` |
| Coverage | `pnpm test:coverage` (70% threshold) |
| E2E tests | `test/**/*.e2e.test.ts` |

## Test Helpers Available

Import from `src/gateway/test-helpers.ts`:
- `installGatewayTestHooks()` - Gateway test setup/teardown
- `startServerWithClient()`, `rpcReq()` - Server testing
- `getFreePort()`, `occupyPort()` - Port utilities

Import from `test/mocks/`:
- `createMockBaileys()` - WhatsApp mock
- `createMockTypingController()` - Typing controller mock

## Patterns

See `references/patterns.md` for:
- Vitest mocking with `vi.hoisted()`
- Integration tests with gateway helpers
- Live test conditionals (`describeLive`)
- Test file naming conventions

## When This Skill Activates

- Implementing new features (write test first)
- Fixing bugs (write regression test first)
- Adding test coverage to existing code
- Refactoring with test safety net
