---
description: Enforce test-driven development workflow. Scaffold interfaces, generate tests FIRST, then implement minimal code to pass. Ensure 80%+ coverage.
agent: tdd-guide
model: "openai/gpt-5.2-codex"
---

# TDD Command

This command invokes the **tdd-guide** agent to enforce test-driven development methodology.

## What This Command Does

1. **Scaffold Interfaces** - Define types/interfaces first
2. **Generate Tests First** - Write failing tests (RED)
3. **Implement Minimal Code** - Write just enough to pass (GREEN)
4. **Refactor** - Improve code while keeping tests green (REFACTOR)
5. **Verify Coverage** - Ensure 80%+ test coverage

## When to Use

Use `/tdd` when implementing new features, adding new functions/components, fixing bugs (write test that reproduces bug first), refactoring existing code, or building critical business logic.

## TDD Cycle

```
RED → GREEN → REFACTOR → REPEAT

RED:      Write a failing test
GREEN:    Write minimal code to pass
REFACTOR: Improve code, keep tests passing
REPEAT:   Next feature/scenario
```

## Example Usage

```
User: /tdd I need a function to calculate market liquidity score

Agent (tdd-guide):
# TDD Session: Market Liquidity Score Calculator

## Step 1: Define Interface (SCAFFOLD)

```typescript
// lib/liquidity.ts
export interface MarketData {
  totalVolume: number
  bidAskSpread: number
  activeTraders: number
  lastTradeTime: Date
}

export function calculateLiquidityScore(market: MarketData): number {
  throw new Error('Not implemented')
}
```

## Step 2: Write Failing Test (RED)

```typescript
// lib/liquidity.test.ts
describe('calculateLiquidityScore', () => {
  it('should return high score for liquid market', () => {
    const market = {
      totalVolume: 100000,
      bidAskSpread: 0.01,
      activeTraders: 500,
      lastTradeTime: new Date()
    }
    const score = calculateLiquidityScore(market)
    expect(score).toBeGreaterThan(80)
  })

  it('should handle edge case: zero volume', () => {
    const market = { totalVolume: 0, bidAskSpread: 0, activeTraders: 0, lastTradeTime: new Date() }
    expect(calculateLiquidityScore(market)).toBe(0)
  })
})
```

## Step 3: Run Tests - Verify FAIL

```bash
npm test lib/liquidity.test.ts
# FAIL - Error: Not implemented
```

## Step 4: Implement Minimal Code (GREEN)

```typescript
export function calculateLiquidityScore(market: MarketData): number {
  if (market.totalVolume === 0) return 0
  const volumeScore = Math.min(market.totalVolume / 1000, 100)
  const spreadScore = Math.max(100 - (market.bidAskSpread * 1000), 0)
  return (volumeScore * 0.6 + spreadScore * 0.4)
}
```

## Step 5: Run Tests - Verify PASS

```bash
npm test lib/liquidity.test.ts
# PASS - 2 tests passed
```

## Step 6: Refactor (IMPROVE)

Extract constants, improve naming, add helper functions while keeping tests green.

## Step 7: Check Coverage

```bash
npm test -- --coverage
# Coverage: 100%
```
```

## TDD Best Practices

| DO | DON'T |
|----|-------|
| Write the test FIRST | Write implementation before tests |
| Run tests and verify FAIL first | Skip the RED phase |
| Write minimal code to pass | Write too much code at once |
| Refactor only when green | Ignore failing tests |
| Test behavior, not implementation | Mock everything |

## Test Types to Include

**Unit Tests**: Happy path, edge cases (empty, null, max), error conditions, boundary values.

**Integration Tests**: API endpoints, database operations, external services.

**E2E Tests**: Critical user flows, multi-step processes (use `/e2e` command).

## Coverage Requirements

| Code Type | Minimum |
|-----------|---------|
| Financial calculations | 100% |
| Authentication/Security | 100% |
| Core business logic | 100% |
| All other code | 80% |

## Important Notes

**MANDATORY**: Tests must be written BEFORE implementation. Never skip the RED phase. Never write code before tests.

## Integration with Other Commands

Use `/plan` first to understand what to build, `/tdd` to implement with tests, `/build-fix` if errors occur, `/code-review` to review, and `/e2e` for end-to-end testing.

## Related Agents

This command invokes the `tdd-guide` agent located at: `.opencode/agents/tdd-guide.md`
