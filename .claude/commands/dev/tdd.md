---
description: TDD workflow - explicit phase control (uses writing-tests skill)
allowed-tools: Bash(pnpm:*), Read, Write, Edit, Glob, Grep
argument-hint: <phase> [feature-description]
success-criteria: |
  - red: Tests written and confirmed FAILING
  - green: All tests PASSING
  - refactor: Tests still passing, code improved
---

# TDD Workflow

Execute a specific TDD phase. For patterns and helpers, see the `writing-tests` skill.

**Phase:** $1 (red | green | refactor)
**Feature:** $2

## Phases

### red - Write Failing Tests
1. Create test file following `<feature>.test.ts` naming
2. Write comprehensive test cases
3. Run `pnpm test --run` - confirm tests FAIL
4. Do NOT write implementation yet

### green - Make Tests Pass
1. Write MINIMAL code to pass all tests
2. Run `pnpm test --run` repeatedly until green
3. Do NOT refactor or add extra features

### refactor - Improve Code
1. All tests must be green first
2. Improve code structure, naming, DRY
3. Run `pnpm test --run` after each change
4. Keep tests passing throughout

Report which phase completed and next steps.
