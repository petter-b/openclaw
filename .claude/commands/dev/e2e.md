---
description: Run end-to-end tests (uses e2e-testing skill for patterns)
allowed-tools: Bash(pnpm:*), Read, Grep
argument-hint: [pattern]
success-criteria: |
  - All E2E tests pass
  - No orphan processes left
estimated-duration: 3-10 minutes
---

# E2E Tests

Run end-to-end tests. For patterns, see the `e2e-testing` skill.

**Pattern:** $1 (or all E2E tests if not specified)

```bash
pnpm test:e2e $ARGUMENTS
```

If tests fail, analyze the failure and check `test/gateway.multi.e2e.test.ts` for reference patterns.

Report detailed results including any stderr output.
