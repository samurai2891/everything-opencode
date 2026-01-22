---
description: Safely remove dead code and improve code quality. Runs analysis tools, verifies with tests, and generates cleanup report.
agent: refactor-cleaner
model: "openai/gpt-5.2-codex"
---

# Refactor Command

This command invokes the **refactor-cleaner** agent to safely remove dead code and improve code quality.

## What This Command Does

1. **Analyze Codebase** - Run knip, depcheck, ts-prune
2. **Identify Dead Code** - Find unused exports, files, dependencies
3. **Verify Tests** - Run tests before any changes
4. **Remove Safely** - Delete one item at a time
5. **Re-verify** - Run tests after each removal
6. **Generate Report** - Document all changes

## Analysis Tools Used

```bash
# Find unused exports and files
npx knip

# Find unused dependencies
npx depcheck

# Find unused TypeScript exports
npx ts-prune

# Find duplicate code
npx jscpd src/
```

## Example Usage

```
User: /refactor

Agent (refactor-cleaner):
# Code Cleanup Report

## Analysis Results

### Unused Files
- src/utils/deprecated.ts (not imported)
- src/components/OldButton.tsx (replaced)

### Unused Exports
- formatLegacyDate from src/lib/utils.ts
- useOldHook from src/hooks/index.ts

### Unused Dependencies
- lodash (only one function used)
- moment (replaced with date-fns)

## Pre-Cleanup Verification
```bash
npm test
# ✅ 150 tests passing
```

## Cleanup Actions

### 1. Removed src/utils/deprecated.ts
```bash
npm test  # ✅ 150 tests passing
```

### 2. Removed formatLegacyDate export
```bash
npm test  # ✅ 150 tests passing
```

### 3. Removed unused dependencies
```bash
npm uninstall lodash moment
npm test  # ✅ 150 tests passing
```

## Summary

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Files | 245 | 243 | -2 |
| Lines of Code | 15,420 | 14,890 | -530 |
| Dependencies | 42 | 40 | -2 |
| Bundle Size | 1.2 MB | 1.1 MB | -100 KB |
```

## Refactoring Patterns

### Extract Function
Long functions (>50 lines) are split into smaller, focused functions.

### Reduce Nesting
Deep nesting (>4 levels) is converted to early returns.

### Remove Duplication
Duplicated code is extracted into shared utilities.

## Metrics Targets

| Metric | Target |
|--------|--------|
| Function length | < 50 lines |
| File length | < 400 lines |
| Nesting depth | < 4 levels |
| Test coverage | > 80% |

## Safety Rules

1. **Always run tests first** - Establish baseline
2. **One change at a time** - Don't batch changes
3. **Verify after each removal** - Run tests
4. **Rollback if tests fail** - Revert immediately
5. **Document everything** - Record changes

## When to Use

| USE when | DON'T USE when |
|----------|----------------|
| After major feature completion | During active development |
| Technical debt cleanup sprint | Before understanding codebase |
| Bundle size optimization | When tests are failing |
| Dependency updates | Without test coverage |

## Integration with Other Commands

- Use `/plan` to plan refactoring scope
- Use `/refactor` to clean up code
- Use `/build-fix` if errors occur
- Use `/code-review` to verify quality

## Related Agents

This command invokes the `refactor-cleaner` agent located at: `.opencode/agents/refactor-cleaner.md`
