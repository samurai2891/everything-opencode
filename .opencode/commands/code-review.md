---
description: Comprehensive security and quality review of uncommitted changes. Checks for hardcoded secrets, vulnerabilities, code quality issues, and best practices.
agent: code-reviewer
model: openai/gpt-5.2-codex
---

# Code Review Command

This command invokes the **code-reviewer** agent to perform comprehensive security and quality review of code changes.

## What This Command Does

1. **Get Changed Files** - `git diff --name-only HEAD`
2. **Security Checks** - Scan for vulnerabilities and secrets
3. **Code Quality** - Check for maintainability issues
4. **Best Practices** - Verify coding standards
5. **Generate Report** - Severity-based findings with fixes

## Review Checklist

### Security Issues (CRITICAL)
- Hardcoded credentials, API keys, tokens
- SQL injection vulnerabilities
- XSS vulnerabilities
- Missing input validation
- Insecure dependencies
- Path traversal risks

### Code Quality (HIGH)
- Functions > 50 lines
- Files > 800 lines
- Nesting depth > 4 levels
- Missing error handling
- console.log statements
- TODO/FIXME comments
- Missing JSDoc for public APIs

### Best Practices (MEDIUM)
- Mutation patterns (use immutable)
- Missing tests for new code
- Accessibility issues (a11y)
- Inconsistent formatting

## Example Usage

```
User: /code-review

Agent (code-reviewer):
# Code Review Report

## Summary
- Files reviewed: 5
- Critical issues: 1
- High issues: 2
- Medium issues: 3

## Critical Issues

### [CRITICAL] Hardcoded API key
**File:** src/api/client.ts:42
**Issue:** API key exposed in source code
**Fix:** Move to environment variable

```typescript
// BAD
const apiKey = "sk-abc123";

// GOOD
const apiKey = process.env.API_KEY;
```

## High Issues

### [HIGH] Function too long (85 lines)
**File:** src/utils/processor.ts:15-100
**Fix:** Extract into smaller functions

### [HIGH] Missing error handling
**File:** src/api/users.ts:30
**Fix:** Add try/catch block

---

**Recommendation:** BLOCK - Fix critical issues before merging
```

## Approval Criteria

| Status | Condition |
|--------|-----------|
| APPROVE | No CRITICAL or HIGH issues |
| WARNING | MEDIUM issues only |
| BLOCK | CRITICAL or HIGH issues found |

## When to Use

Use `/code-review` after writing new code, before committing changes, before creating pull requests, after refactoring, or when reviewing others' code.

## Integration with Other Commands

- Use `/plan` before implementing
- Use `/tdd` for test-driven development
- Use `/code-review` after implementation
- Use `/security-audit` for deeper security analysis
- Use `/build-fix` if issues are found

## Related Agents

This command invokes the `code-reviewer` agent located at: `.opencode/agents/code-reviewer.md`
