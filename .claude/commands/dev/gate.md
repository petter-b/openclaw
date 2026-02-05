---
description: Run full quality gate (lint, build, test) before commits
allowed-tools: Bash(pnpm:*)
success-criteria: |
  - build: TypeScript compiles without errors
  - check: No lint or format errors
  - test: All tests pass
estimated-duration: 2-5 minutes
---

# Quality Gate

Run the full quality gate for openclaw:

```bash
pnpm build && pnpm check && pnpm test
```

Execute each step in sequence. Stop immediately if any step fails.

- `pnpm build` — type-check + produce dist
- `pnpm check` — tsgo + oxlint + oxfmt
- `pnpm test` — vitest (unit, extensions, gateway in parallel)

Report:

1. Status of each gate (pass/fail)
2. If failed: show the specific error
3. If passed: confirm ready for commit
