---
description: Diagnose and fix build/lint/type errors. Runs build, captures errors, analyzes root cause, and applies fixes iteratively.
agent: build-error-resolver
model: "openai/gpt-5.2-codex"
---

# Build Fix Command

This command invokes the **build-error-resolver** agent to diagnose and fix build, lint, and type errors.

## What This Command Does

1. **Run Build** - Execute `npm run build` or `npm run lint`
2. **Capture Errors** - Parse error output
3. **Analyze Root Cause** - Identify the source of errors
4. **Apply Fixes** - Fix one error at a time
5. **Verify** - Re-run build to confirm fix
6. **Iterate** - Repeat until all errors resolved

## Error Types Handled

| Error Type | Detection | Fix Strategy |
|------------|-----------|--------------|
| TypeScript | `TS2xxx` codes | Type annotations, imports |
| ESLint | `eslint` rules | Auto-fix or manual |
| Import | Module not found | Path correction, install |
| Syntax | Parse errors | Code correction |
| Runtime | Build-time errors | Logic fixes |

## Example Usage

```
User: /build-fix

Agent (build-error-resolver):
# Build Error Resolution

## Running Build
```bash
npm run build
```

## Errors Found (3)

### Error 1: TS2322
**File:** src/components/Button.tsx:15
**Message:** Type 'string' is not assignable to type 'number'

**Fix Applied:**
```typescript
// Before
const count: number = props.value;

// After
const count: number = parseInt(props.value, 10);
```

### Error 2: Module not found
**File:** src/api/client.ts:1
**Fix:** Added missing export to src/lib/utils/index.ts

### Error 3: ESLint
**File:** src/hooks/useData.ts:20
**Fix:** Added missing dependency to useEffect

## Verification
```bash
npm run build
# ✅ Build successful
```

## Summary
- Errors fixed: 3/3
- Build status: ✅ PASSING
```

## Resolution Strategy

The agent follows this priority order:
1. Fix type errors first (they often cause cascading errors)
2. Fix import/module errors
3. Fix lint errors
4. Fix runtime errors

## When to Use

Use `/build-fix` when `npm run build` fails, when TypeScript shows type errors, when ESLint reports issues, after refactoring causes errors, or after dependency updates break build.

## Important Notes

- The agent fixes ONE error at a time and re-runs build
- This prevents cascading fixes that might be unnecessary
- Some errors are related - fixing one may fix others

## Integration with Other Commands

- Use `/tdd` for test-driven development
- Use `/build-fix` when build fails
- Use `/code-review` after fixes are applied
- Use `/refactor` if code needs cleanup after fixes

## Related Agents

This command invokes the `build-error-resolver` agent located at: `.opencode/agents/build-error-resolver.md`
