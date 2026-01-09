---
name: reviewing-code
description: Reviews code for security, quality, and style issues. Use PROACTIVELY after writing significant code, before commits, or when reviewing PRs. Checks for injection vulnerabilities, type safety, test coverage, and CHANGELOG entries.
---

# Code Review

Apply these checks proactively after writing or modifying code.

## Quick Checklist

### Security
- [ ] Input validation on user data
- [ ] No injection vulnerabilities (SQL, command, XSS)
- [ ] No secrets/credentials in code
- [ ] Safe file operations

### Quality
- [ ] Error handling for edge cases
- [ ] Type safety (no `any` unless justified)
- [ ] Follows existing patterns in codebase
- [ ] Files under ~700 LOC

### Style
- [ ] No over-engineering
- [ ] No unrelated refactoring bundled in
- [ ] Clear naming and structure

### Tests
- [ ] New/changed behavior has tests
- [ ] Tests are meaningful (not just coverage padding)
- [ ] Edge cases covered

### Documentation
- [ ] CHANGELOG entry with PR # (if applicable)
- [ ] Contributor thanked if external
- [ ] Code comments for non-obvious logic

## When This Skill Activates

- After implementing a feature
- After fixing a bug
- Before creating commits
- When reviewing PR diffs
- When asked to review code

## Detailed Checks

See `references/checklists.md` for comprehensive review criteria.

## Severity Levels

- **Critical**: Security vulnerabilities, data loss potential
- **High**: Logic errors, missing error handling
- **Medium**: Code quality, style violations
- **Low**: Suggestions, minor improvements
