---
name: security
description: Security guidelines and mandatory checks for all code changes. Covers OWASP Top 10, authentication, authorization, input validation, and secret management.
---

# Security Guidelines

## Mandatory Security Checks

Before ANY commit, verify the following:

### Secrets Management
No hardcoded secrets (API keys, passwords, tokens) in source code. All sensitive data must use environment variables.

```typescript
// ❌ NEVER: Hardcoded secrets
const apiKey = "sk-proj-xxxxx"

// ✅ ALWAYS: Environment variables
const apiKey = process.env.OPENAI_API_KEY

if (!apiKey) {
  throw new Error('OPENAI_API_KEY not configured')
}
```

### Input Validation
All user inputs must be validated before processing. Never trust client-side data.

```typescript
import { z } from 'zod'

const UserInputSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().positive().max(150)
})

function processUserInput(input: unknown) {
  const validated = UserInputSchema.parse(input)
  // Now safe to use
}
```

### SQL Injection Prevention
Always use parameterized queries. Never concatenate user input into SQL strings.

```typescript
// ❌ NEVER: String concatenation
const query = `SELECT * FROM users WHERE name = '${userInput}'`

// ✅ ALWAYS: Parameterized queries
const query = 'SELECT * FROM users WHERE name = $1'
const result = await db.query(query, [userInput])

// ✅ ALWAYS: ORM/Query builder
const { data } = await supabase
  .from('users')
  .select('*')
  .eq('name', userInput)
```

### XSS Prevention
Sanitize all HTML output. Use framework-provided escaping mechanisms.

```typescript
// React automatically escapes by default
<div>{userContent}</div>  // Safe

// ⚠️ DANGEROUS: Bypassing escaping
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// ✅ If you must use dangerouslySetInnerHTML, sanitize first
import DOMPurify from 'dompurify'
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />
```

### CSRF Protection
Enable CSRF tokens for all state-changing operations. Verify origin headers.

### Authentication & Authorization
Verify authentication on all protected routes. Check authorization for every action. Never expose user IDs in predictable patterns.

### Rate Limiting
Implement rate limiting on all public endpoints. Protect against brute force attacks.

```typescript
import rateLimit from 'express-rate-limit'

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: 'Too many login attempts'
})

app.post('/api/login', loginLimiter, loginHandler)
```

### Error Messages
Never expose sensitive information in error messages. Log detailed errors server-side only.

```typescript
// ❌ BAD: Exposes internal details
throw new Error(`Database error: ${dbError.message}`)

// ✅ GOOD: Generic message to client
throw new Error('An error occurred. Please try again.')
// Log full error server-side
console.error('Database error:', dbError)
```

## OWASP Top 10 Checklist

| Vulnerability | Prevention |
|---------------|------------|
| A01: Broken Access Control | Authorization checks, RLS |
| A02: Cryptographic Failures | Use strong algorithms, secure secrets |
| A03: Injection | Parameterized queries, input validation |
| A04: Insecure Design | Threat modeling, security reviews |
| A05: Security Misconfiguration | Secure defaults, hardening |
| A06: Vulnerable Components | Dependency scanning, updates |
| A07: Auth Failures | MFA, rate limiting, secure sessions |
| A08: Data Integrity Failures | Signed updates, integrity checks |
| A09: Logging Failures | Audit logs, monitoring |
| A10: SSRF | URL validation, allowlists |

## Security Response Protocol

If a security issue is found:

1. **STOP** immediately
2. Use the **security-reviewer** agent (`/security-audit`)
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues
6. Document the vulnerability and fix
7. Add tests to prevent regression

## Common Vulnerabilities

### Authentication Bypass
Ensure all routes check authentication. Don't rely on client-side checks alone.

### Privilege Escalation
Verify user permissions for every action. Don't trust user-provided role information.

### Insecure Direct Object References
Validate that users can only access their own resources. Use UUIDs instead of sequential IDs.

### Sensitive Data Exposure
Encrypt sensitive data at rest and in transit. Use HTTPS everywhere. Set secure cookie flags.

### Dependency Vulnerabilities
Regularly run `npm audit` or `pnpm audit`. Keep dependencies updated. Review security advisories.

## Security Headers

Ensure these headers are set:

```
Content-Security-Policy: default-src 'self'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-XSS-Protection: 1; mode=block
```

## Secure Cookie Configuration

```typescript
const cookieOptions = {
  httpOnly: true,      // Prevent XSS access
  secure: true,        // HTTPS only
  sameSite: 'strict',  // CSRF protection
  maxAge: 3600000      // 1 hour
}
```

## Logging Security Events

Log all security-relevant events:
- Failed login attempts
- Password changes
- Permission changes
- Access to sensitive data
- API key usage

Never log:
- Passwords (even hashed)
- Full credit card numbers
- API keys or tokens
- Personal identification numbers

## Security Audit Commands

```bash
# Check for known vulnerabilities
npm audit

# Fix vulnerabilities automatically
npm audit fix

# Scan for hardcoded secrets
npx secretlint "**/*"
```

**Remember**: Security is not optional. Every vulnerability is a potential breach. When in doubt, ask for a security review.
