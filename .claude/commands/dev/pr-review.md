---
description: Review a PR from upstream (uses reviewing-code skill)
allowed-tools: Bash(gh:*), Read, Glob, Grep, WebFetch
argument-hint: <pr-number>
success-criteria: |
  - Security review completed
  - Code quality assessed
  - Test coverage evaluated
  - CHANGELOG entry verified
  - Clear approve/request-changes recommendation
---

# PR Review

Review PR #$1 from clawdbot/clawdbot using the `reviewing-code` skill.

**IMPORTANT: Read-only review. Do NOT checkout the branch or modify any code.**

## Workflow

### 1. Fetch PR Details
```bash
gh pr view $1 --repo clawdbot/clawdbot
gh pr diff $1 --repo clawdbot/clawdbot
```

### 2. Apply Review Checklist

Apply the `reviewing-code` skill checklists (security, quality, style, tests, docs).

### 3. Summarize Findings

Report:
1. **Summary**: What this PR does
2. **Security**: Any concerns? (critical/none)
3. **Quality**: Issues found (high/medium/low/none)
4. **Tests**: Adequate coverage? (yes/no/partial)
5. **CHANGELOG**: Present and correct? (yes/no/needs update)
6. **Recommendation**: APPROVE / REQUEST CHANGES / COMMENT

If requesting changes, list specific items to address.
