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

Parse `$1` to determine `REPO` and `ISSUE`. Default `REPO` to `openclaw/openclaw`.

Set `IS_UPSTREAM` = true if `REPO` is `openclaw/openclaw`, false otherwise.
Issue references (`#$ISSUE`, `Fixes #$ISSUE`) are **only included in PR-facing content when `IS_UPSTREAM`** — otherwise they'd link to nothing or the wrong repo.

## Workflow

### 1. Understand the Issue
- Fetch issue details: `gh issue view $ISSUE --repo $REPO`
- Read related code to understand the problem
- Identify the root cause

### 2. Search Upstream for Duplicates & Existing Fixes

Before starting any work, search `openclaw/openclaw` for prior art:

```bash
# Search for similar issues (open and closed)
gh search issues --repo openclaw/openclaw "<keywords from issue>"

# Search for PRs that may already fix this
gh search prs --repo openclaw/openclaw "<keywords from issue>"
```

Check the results:
- **Duplicate issue exists?** → Link it and note in deliverables. If upstream already tracks this, the PR should reference their issue number instead.
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

- **Red:** Write a test that reproduces the bug. Run `pnpm test` in the worktree and confirm it **fails**.
- **Green:** Write minimal code to make the test pass. Run `pnpm test` until green.
- **Refactor:** Review with KISS/YAGNI lens — can anything be removed rather than added? Inline single-use helpers, delete dead code. No unrelated cleanup.

### 5. Quality Gate & Commit

Run the full gate inside the worktree:

```bash
cd $WORKTREE && pnpm check && pnpm build && pnpm test
```

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
6. Test adequacy:
   - Does the test reproduce the original bug?
   - Are edge cases covered?
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

All commands run inside the worktree. Create a clean PR branch with a single squashed commit:

```bash
cd $WORKTREE

# Ensure upstream ref is fresh
git fetch upstream

# Create PR branch from upstream/main
git checkout -b pr/fix-$ISSUE upstream/main

# Squash all working branch commits into one
git merge --squash fix-$ISSUE

# Single clean commit — only include (#$ISSUE) if IS_UPSTREAM
scripts/committer "fix: handle nil channel in routing lookup" .
# ↑ Write a real description for the actual fix

# Push PR branch to fork (petter-b/openclaw)
git push fork pr/fix-$ISSUE

# Submit draft PR against upstream — only include issue ref if IS_UPSTREAM
gh pr create \
  --repo openclaw/openclaw \
  --head petter-b:pr/fix-$ISSUE \
  --base main \
  --draft \
  --title "fix: description" \
  --body "$(cat <<'EOF'
## Summary

[Brief description of the fix and root cause]

## Changes
- [List of changes]

## Test Plan
- [How the fix was tested]
EOF
)"
```

**Issue references:** Only if `IS_UPSTREAM`, append `(#$ISSUE)` to the commit message and PR title, and add `Fixes #$ISSUE.` to the PR body. For non-upstream issues, omit all issue references from PR-facing content.

**Important:** The PR is created as a **draft**. The user will manually mark it as "ready for review".

The worktree is left in place for future reference. Clean up after the PR is merged: `git worktree remove .worktrees/fix-$ISSUE`

## Deliverables
1. Root cause identified
2. Test file and case added
3. Implementation summary
4. Gate status: PASS
5. Review status: PASS
6. Draft PR URL on openclaw/openclaw

## Constraints
- Follow existing code patterns; keep under 100 lines changed if possible
- All work happens in a worktree — never modify the main working tree
- **No AI attribution**: never mention Claude, AI, LLM, or similar in commits, PR title, PR body, code comments, or CHANGELOG entries
- **Issue references are conditional**: only reference `#$ISSUE` in PR-facing content when `IS_UPSTREAM`
