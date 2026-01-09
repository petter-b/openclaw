# Code Review Checklists

## Security Checklist

### Input Validation
- [ ] User input validated before use
- [ ] Path traversal prevention (no `../` in paths)
- [ ] File extension validation where applicable
- [ ] Size limits on uploads/inputs

### Injection Prevention
- [ ] No string concatenation in SQL queries
- [ ] Command arguments properly escaped
- [ ] HTML output escaped to prevent XSS
- [ ] JSON parsing with error handling

### Secrets & Credentials
- [ ] No hardcoded API keys or passwords
- [ ] Environment variables used for secrets
- [ ] Secrets not logged or exposed in errors
- [ ] `.env` files in `.gitignore`

### Authentication & Authorization
- [ ] Auth checks on sensitive endpoints
- [ ] Session tokens properly validated
- [ ] Rate limiting where appropriate

## Quality Checklist

### Error Handling
- [ ] Try/catch around external calls
- [ ] Meaningful error messages
- [ ] Errors logged appropriately
- [ ] Graceful degradation where possible

### Type Safety
- [ ] No `any` types without justification
- [ ] Proper null/undefined checks
- [ ] Generic types used appropriately
- [ ] Return types explicit where complex

### Code Structure
- [ ] Functions do one thing well
- [ ] No deeply nested conditionals
- [ ] Early returns for guard clauses
- [ ] Consistent naming conventions

### Performance
- [ ] No N+1 query patterns
- [ ] Appropriate caching
- [ ] Async operations where beneficial
- [ ] Memory-conscious data structures

## Style Checklist (from CLAUDE.md)

### File Organization
- [ ] Files under ~700 LOC (guideline)
- [ ] Related code colocated
- [ ] Clear module boundaries
- [ ] Appropriate file naming

### Code Clarity
- [ ] Self-documenting code preferred
- [ ] Comments explain "why" not "what"
- [ ] No commented-out code
- [ ] No TODO without issue reference

### Simplicity
- [ ] No over-engineering
- [ ] No premature abstraction
- [ ] No feature flags for simple changes
- [ ] Three similar lines better than bad abstraction

## Test Checklist

### Coverage
- [ ] New behavior has tests
- [ ] Bug fixes have regression tests
- [ ] Edge cases covered
- [ ] Error paths tested

### Quality
- [ ] Tests are readable
- [ ] Clear test names (describe what, not how)
- [ ] Appropriate use of mocks
- [ ] No flaky tests

## Documentation Checklist

### CHANGELOG
- [ ] Entry added for user-facing changes
- [ ] PR number included
- [ ] External contributor thanked
- [ ] Format matches existing entries

### Code Comments
- [ ] Complex logic explained
- [ ] Non-obvious decisions documented
- [ ] API boundaries documented
- [ ] No obvious/redundant comments
