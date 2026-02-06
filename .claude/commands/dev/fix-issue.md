---
description: Fix an upstream issue with TDD workflow
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, Task
argument-hint: <issue-ref> [context]
success-criteria: |
  - Test proving the fix exists
  - Implementation passes all tests
  - /dev:gate passes
  - Sub-agent review passes (no outstanding issues)
  - CHANGELOG entry added
  - Draft PR submitted to openclaw/openclaw from fork
---

# Fix Upstream Issue

Fix an issue and submit a draft PR to openclaw/openclaw.

**Issue reference:** $1
**Additional context:** $2

## Issue Reference Format

- `123` → issue #123 on `openclaw/openclaw` (default)
- `openclaw/openclaw#123` → explicit upstream
- `petter-b/openclaw#123` → fork repo
- `petter-b/openclaw-dev#123` → dev repo
- `https://github.com/OWNER/REPO/issues/N` → full URL (extract OWNER/REPO and N)

Parse `$1` to determine `REPO` and `ISSUE`. Default `REPO` to `openclaw/openclaw`.

Set `IS_UPSTREAM` = true if `REPO` is `openclaw/openclaw`, false otherwise.
Issue references (`#$ISSUE`, `Fixes #$ISSUE`) are **only included in PR-facing content when `IS_UPSTREAM`** — otherwise they'd link to nothing or the wrong repo.

## Workflow

### 0. Pre-flight Checks

Verify the environment before doing any work. Fail fast if something is wrong.

```bash
# All checks in one pass — stop on first failure
git remote get-url upstream >/dev/null 2>&1 || { echo "ERROR: 'upstream' remote not configured"; exit 1; }
git remote get-url fork >/dev/null 2>&1 || { echo "ERROR: 'fork' remote not configured"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh not authenticated"; exit 1; }
echo "Pre-flight OK"
```

### 1. Understand the Issue

- Fetch issue details: `gh issue view $ISSUE --repo $REPO`
- Read related code to understand the problem
- Identify the root cause

**If the reference is a PR (not an issue):**

This is likely a "fix review feedback" scenario, not a fresh bug:

- Read PR comments/reviews: `gh pr view $NUM --repo $REPO --comments`
- The "root cause" is the reviewer's concern, not a bug report
- Skip the duplicate search (Step 2) — the PR _is_ the fix attempt
- The worktree may already exist from the original PR work

### 1b. Validate the Bug

Before investing time, determine if the issue is a **real bug** or user error. Check:

1. **Misconfiguration?** — Is the user missing a required config key, using a wrong path, or mixing up profiles? Read the relevant config schema and docs.
2. **User error?** — Are they using the CLI incorrectly, passing wrong flags, or misunderstanding expected behavior?
3. **Environment issue?** — Is it specific to an unsupported platform, an old Node version, or a third-party dependency conflict?
4. **Already works as designed?** — Is the reported behavior actually intentional? Check if docs describe it.
5. **Already fixed upstream?** — Check git history: `git log --oneline --since="<issue-date>" -- <suspected-files>`
6. **Can't reproduce on main?** — For runtime bugs, try live reproduction using `pnpm openclaw --profile test` (isolated test gateway). If it works correctly:
   - Check if fix is in reporter's version: `git log v<reporter-version>..HEAD --oneline -- <suspected-files>`
   - Compare exact error message format against patterns in code (e.g., `ERROR_PATTERNS` in error classification)

**Reproduce mentally or via code reading:** Trace the reported code path. Does the error actually happen in the code, or is the user's description inconsistent with what the code does?

**Verdict:**

- **Real bug** → Proceed to Step 2
- **Not a bug** → Stop. Report findings to the user: what the actual cause is, and suggest they comment on the issue with a workaround or close it
- **Can't reproduce** → Stop. Comment on the issue asking for: exact version, full error message, and reproduction steps. Do not start a worktree.
- **Unclear** → Ask the user before proceeding (includes cases needing live reproduction). Do not start a worktree for an unvalidated issue.

### 1c. Research Existing Patterns

Before implementing a fix, search the codebase for similar patterns:

```bash
# Find similar error handling, guards, or patterns in related files
rg "pattern-keyword" src/ --type ts -C 3
```

Look for:

- How similar code paths handle errors (e.g., `.catch(() => undefined)` vs `.catch((err) => ({ error: String(err) }))`)
- Guard conditions used elsewhere (e.g., `gatewayReachable` checks before gateway calls)
- Return type patterns for functions that can fail

**Why this matters:** Matching existing patterns ensures consistency and avoids rework during review. In PR #9091, the initial fix used `runtime.error()` logging, but `status-all.ts` already had a better pattern (capturing errors in return values) — discovering this early would have saved a restart.

### 2. Search Upstream for Duplicates & Existing Fixes

Before starting any work, search `openclaw/openclaw` for prior art:

```bash
# Search for similar issues (open and closed)
gh search issues --repo openclaw/openclaw "<keywords from issue>"

# Search for PRs that may already fix this
gh search prs --repo openclaw/openclaw "<keywords from issue>"
```

Check the results:

- **Duplicate issue exists?** → Link it and note in deliverables. If upstream already tracks this, **use the upstream issue number** for worktree naming, PR branch naming, and all issue references going forward (e.g., if fixing `petter-b/openclaw-dev#1` and upstream duplicate is `openclaw/openclaw#5790`, use `5790` as `$ISSUE`).
- **Open PR already fixes it?** → Stop. Report the existing PR to the user.
- **Merged PR already fixed it?** → Check if the fix is on `upstream/main`. If so, stop — the issue is already resolved. If not yet released, note it.
- **Nothing found** → Proceed.

### 3. Create Worktree

Work in an isolated worktree based on `upstream/main`. Use a **working branch** (`fix-$ISSUE`) for development — the clean PR branch is created later via squash.

If the worktree or branch already exists from a prior attempt, reuse the existing worktree. Rebase onto latest `upstream/main` if needed (`git fetch upstream && git rebase upstream/main` inside the worktree).

```bash
git fetch upstream
git worktree add .worktrees/fix-$ISSUE -b fix-$ISSUE upstream/main
```

All remaining steps happen inside the worktree. Compute the **absolute worktree path** (e.g., via `realpath .worktrees/fix-$ISSUE`) and use it for all subsequent commands and sub-agent prompts.

Install deps:

```bash
cd $WORKTREE && pnpm install
```

### 4. TDD Cycle

Fix only this issue — no unrelated changes.

**Before writing any test, trace the code path:**

1. Start from the CLI entry point (e.g., `models set` → `src/commands/models/set.ts`)
2. Follow function calls to where the bug actually occurs
3. Identify the **exact file** where the fix will be made
4. Write tests in that file's corresponding `*.test.ts`

This prevents writing tests that pass for the wrong reason (e.g., testing fallback logic when the bug is in model resolution).

Use **targeted test runs** for fast Red/Green feedback (full suite runs in the gate):

```bash
cd $WORKTREE && npx vitest run <test-file> --reporter=verbose
```

- **Red:** Write a test that reproduces the bug. Run the specific test file and confirm it **fails**. Optionally verify the test hits the right code path:
  ```bash
  cd $WORKTREE && npx vitest run <test-file> --coverage --coverage.include=<target-source-file>
  ```
- **Green:** Write minimal code to make the test pass. Run the specific test file until green.
- **Refactor:** Review with KISS/YAGNI lens — can anything be removed rather than added? Inline single-use helpers, delete dead code. No unrelated cleanup.

**Test isolation for multi-layer fixes:** If the fix involves multiple defensive layers (e.g., a reachability guard _and_ a `.catch()`), write separate tests for each layer. A single test can easily pass for the wrong reason — e.g., if a mock rejects a function that the guard already prevents from being called, the `.catch()` is never exercised even though the test _appears_ to cover it.

Split into independent tests:

- **Guard test:** verify the dangerous call is never made when the guard is active (e.g., `expect(fn).not.toHaveBeenCalled()`)
- **Catch test:** mock the guard to allow the call through, _then_ reject — verify the error is handled gracefully

**Debugging:** If a test fails unexpectedly or the root cause is unclear, use `/gsd:debug` for systematic investigation before guessing at fixes.

### 5. Quality Gate & Commit

Run the full gate inside the worktree:

```bash
cd $WORKTREE && pnpm build && pnpm check && pnpm test
```

**Build first** — catches type errors early. Then lint, then tests.

**Pre-existing lint failures:** `pnpm check` may report pre-existing lint errors in extension packages. If the gate fails on lint, verify no **new** errors in changed files:

```bash
npx oxlint --type-aware <changed-file-1> <changed-file-2> ...
```

If all errors are pre-existing (not in your changed files), the gate passes.

**Agent note:** Do not run `pnpm test` with output pipes (`| tail`, `| grep`) in background mode — the pipe stalls. Run without pipes for background tasks, or use foreground execution.

**Pre-existing test failures:** The full test suite may have pre-existing failures unrelated to the fix. If `pnpm test` fails, first run targeted tests on changed files only:

```bash
cd $WORKTREE && npx vitest run <changed-test-file-1> <changed-test-file-2> --reporter=verbose
```

If targeted tests pass but the full suite fails, check whether failures are in unrelated files. If so, the gate passes for this PR.

Fix any issues before proceeding.

After the gate passes:

- Add a CHANGELOG entry in `CHANGELOG.md` at the repo root (include `(#$ISSUE)` only if `IS_UPSTREAM`)
- Commit changes on the working branch using `scripts/committer` (these get squashed later, so messages are informal)

### 6. Sub-Agent Review

Before pushing, review with a fresh-context sub-agent.

Run `git diff --name-only upstream/main` inside the worktree to get the list of changed files.

**Spawn one review agent using the Task tool.** Pass it the absolute worktree path and the list of changed files. The agent should read each changed file at its absolute path.

```
You are reviewing changes for a bug fix.

Worktree: $ABSOLUTE_WORKTREE_PATH
Changed files:
$CHANGED_FILES_LIST

Read each changed file and its surrounding code. Review for:

1. Correctness: does the fix address the root cause?
2. Security: any new vulnerabilities introduced?
3. KISS/YAGNI: is anything over-engineered or unnecessary?
4. Project patterns: does it follow existing conventions?
5. No AI mentions: commits, comments, and code must not reference Claude, AI, LLM, or similar
6. Error handling quality:
   - Are catches overly broad? (blanket `.catch(() => undefined)` can swallow actionable config errors)
   - Would specific error types be safer, or does a guard make the broad catch acceptable?
   - Should caught errors be logged at debug level for observability?
   - Cross-check: read the functions being called to see what errors they can throw
7. Test adequacy:
   - Does the test reproduce the original bug?
   - Are edge cases covered?
   - If multiple defensive layers exist (guard + catch), are they tested independently?
   - Mock verification: do mocks actually exercise the intended code path? (A mock that rejects a function the guard prevents from being called gives false confidence — the test passes for the wrong reason.)
   - Is the test minimal and clear?
   - Would it catch regressions?

Report:
# Review
## Issues (list each with File:Line, description, fix suggestion)
## Verdict: PASS / NEEDS CHANGES
```

**After the agent reports:**

- If NEEDS CHANGES → fix issues in the worktree → re-run gate → re-run review
- If PASS → proceed to step 7

**Max 2 review rounds.** If issues remain after 2 rounds, list them and proceed to PR submission.

### 7. Squash, Push & Submit Draft PR

All commands run inside the worktree. Create a clean PR branch with a single squashed commit.

**PR branch naming:**

- Derive a short kebab-case slug from the issue title (3-5 words max, e.g. `status-deep-gateway-crash`).
- If `IS_UPSTREAM`: `fix/$ISSUE-$SLUG` (e.g. `fix/8392-status-deep-crash`)
- Otherwise: `fix/$SLUG` (e.g. `fix/status-deep-gateway-crash`)

The issue number is only included when it references the upstream repo where the PR is submitted — otherwise it would be meaningless.

```bash
cd $WORKTREE

# Ensure upstream ref is fresh
git fetch upstream

# Create PR branch from upstream/main (use naming convention above)
git checkout -b $PR_BRANCH upstream/main

# Squash all working branch commits into one
git merge --squash fix-$ISSUE

# Single clean commit — list changed files explicitly (committer rejects ".")
# Only include (#$ISSUE) in the message if IS_UPSTREAM
scripts/committer "fix: handle nil channel in routing lookup" CHANGELOG.md src/path/to/changed.ts src/path/to/changed.test.ts
# ↑ Write a real description for the actual fix; list all changed files

# Re-run gate on the PR branch — the squash rebased onto fresh upstream/main,
# which may have introduced conflicts or semantic breakage
pnpm build && pnpm test

# Push PR branch to fork (petter-b/openclaw)
git push fork $PR_BRANCH

# Submit draft PR against upstream
# PR body is concise — optimized for automated reviewer approval
gh pr create \
  --repo openclaw/openclaw \
  --head petter-b:$PR_BRANCH \
  --base main \
  --draft \
  --title "fix: description" \
  --body "$(cat <<'EOF'
Root cause: [one sentence]

Fix: [one sentence]

Test: [what the test verifies]
EOF
)"
```

**Issue references:** Only if `IS_UPSTREAM`, append `(#$ISSUE)` to the commit message and PR title, and add `Fixes #$ISSUE` on its own line in the PR body. For non-upstream issues, omit all issue references from PR-facing content.

**Important:** The PR is created as a **draft**. The user will manually mark it as "ready for review".

### 8. Respond to Automated Review Feedback

After submission, automated reviewers (e.g., Greptile) may flag concerns. When this happens:

1. **Evaluate**: Is the concern valid, mitigated by context, or a false positive?
2. **Respond on the PR** with the "acknowledge, contextualize, offer" pattern:
   - Acknowledge the concern (don't dismiss it)
   - Explain why the current approach is acceptable (cite guards, precedent across the codebase, etc.)
   - Offer a compromise if reasonable (e.g., "happy to add a debug log if desired")
3. **If the concern reveals a real gap**, fix it in the worktree, re-run the gate, force-push the PR branch, and note the update.

**Worktree gone?** If returning to address feedback and the worktree was deleted, recreate it from the PR branch:

```bash
git fetch fork $PR_BRANCH && git worktree add .worktrees/fix-$ISSUE fork/$PR_BRANCH
```

Then amend the existing commit (not a new one) to keep history clean for squash-merge.

The worktree is left in place for future reference. Clean up after the PR is merged: `git worktree remove .worktrees/fix-$ISSUE` and `git branch -d fix-$ISSUE $PR_BRANCH`

## Deliverables

1. Root cause identified
2. Test file and case added (with independent tests per defensive layer where applicable)
3. Implementation summary
4. Gate status: PASS
5. Review status: PASS
6. Draft PR URL on openclaw/openclaw
7. Automated review feedback addressed (if any)

## Constraints

- Follow existing code patterns; keep under 100 lines changed if possible
- All work happens in a worktree — never modify the main working tree
- **No AI attribution**: never mention Claude, AI, LLM, or similar in commits, PR title, PR body, code comments, or CHANGELOG entries
- **Issue references are conditional**: only reference `#$ISSUE` in PR-facing content when `IS_UPSTREAM`
- **No git stash**: never use `git stash` — it creates permission issues and complicates multi-agent workflows. If you need to test whether failures are pre-existing, use `git diff` to save changes, `git checkout .` to test clean state, then reapply via `git apply`
