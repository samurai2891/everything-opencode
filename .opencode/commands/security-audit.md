---
description: Deep security audit for authentication, authorization, input validation, and cryptographic operations. Generates detailed vulnerability report with OWASP references.
agent: security-reviewer
model: "openai/gpt-5.2-codex"
---

# Security Audit Command

This command invokes the **security-reviewer** agent to perform a comprehensive security audit of the codebase.

## What This Command Does

1. **Scan for Vulnerabilities** - Check OWASP Top 10
2. **Review Authentication** - Auth flows and session management
3. **Check Authorization** - Access control and permissions
4. **Validate Inputs** - Input sanitization and validation
5. **Audit Cryptography** - Encryption and key management
6. **Generate Report** - Detailed findings with remediation

## Security Checklist

### Authentication (CRITICAL)
- Password hashing (bcrypt, argon2)
- Session management
- Token security (JWT validation)
- MFA implementation
- Brute force protection

### Authorization (CRITICAL)
- Role-based access control
- Resource ownership validation
- API endpoint protection
- Row-level security (RLS)

### Input Validation (HIGH)
- SQL injection prevention
- XSS prevention
- Path traversal prevention
- File upload validation
- API input sanitization

### Cryptography (HIGH)
- Secure random generation
- Key management
- TLS configuration
- Sensitive data encryption

### Dependencies (MEDIUM)
- Known vulnerabilities (npm audit)
- Outdated packages
- License compliance

## Example Usage

```
User: /security-audit

Agent (security-reviewer):
# Security Audit Report

**Date:** 2025-01-21
**Risk Level:** MEDIUM

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 2 |
| MEDIUM | 3 |

## Critical Findings

### [CRITICAL] SQL Injection in User Search
**File:** src/api/users.ts:45
**OWASP:** A03:2021 Injection

**Vulnerable Code:**
```typescript
const query = `SELECT * FROM users WHERE name = '${searchTerm}'`;
```

**Remediation:**
```typescript
const query = `SELECT * FROM users WHERE name = $1`;
const result = await db.query(query, [searchTerm]);
```

## High Findings

### [HIGH] Missing Rate Limiting on Login
**File:** src/api/auth.ts
**OWASP:** A07:2021 Identification and Authentication Failures

**Remediation:** Implement rate limiting with express-rate-limit

### [HIGH] JWT Secret in Code
**File:** src/lib/auth.ts:10
**Remediation:** Move to environment variable

## Recommendations
1. **Immediate:** Fix SQL injection
2. **This Week:** Implement rate limiting
3. **This Sprint:** Move secrets to env vars
```

## OWASP Top 10 Coverage

| Category | Checked |
|----------|---------|
| A01: Broken Access Control | ✅ |
| A02: Cryptographic Failures | ✅ |
| A03: Injection | ✅ |
| A04: Insecure Design | ✅ |
| A05: Security Misconfiguration | ✅ |
| A06: Vulnerable Components | ✅ |
| A07: Auth Failures | ✅ |
| A08: Data Integrity Failures | ✅ |
| A09: Logging Failures | ✅ |
| A10: SSRF | ✅ |

## Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| CRITICAL | Immediate exploitation risk | Stop and fix now |
| HIGH | Significant vulnerability | Fix before merge |
| MEDIUM | Security weakness | Schedule fix |
| LOW | Best practice improvement | Address when possible |

## When to Use

Use `/security-audit` before production deployment, after adding authentication/authorization code, when handling sensitive data, after adding payment processing, during security review cycles, or after dependency updates.

## Integration with Other Commands

- Use `/plan` to plan security features
- Use `/tdd` to implement with security tests
- Use `/security-audit` for comprehensive audit
- Use `/code-review` for general code review

## Related Agents

This command invokes the `security-reviewer` agent located at: `.opencode/agents/security-reviewer.md`
