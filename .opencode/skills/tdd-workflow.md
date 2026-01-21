---
name: tdd-workflow
description: Test-Driven Development workflow and methodology.
---

# TDD Workflow

## The TDD Cycle

Test-Driven Development follows a strict cycle:

```
RED → GREEN → REFACTOR → REPEAT
```

### RED Phase
Write a failing test first. The test should fail because the implementation doesn't exist yet.

### GREEN Phase
Write the minimum code necessary to make the test pass. Don't add extra functionality.

### REFACTOR Phase
Improve the code while keeping tests green. Clean up duplication, improve naming, optimize.

### REPEAT
Move to the next requirement and start the cycle again.

## Step-by-Step Process

### Step 1: Define Interface (SCAFFOLD)
Before writing tests, define the types and interfaces:

```typescript
interface MarketData {
  id: string
  name: string
  status: 'active' | 'resolved'
}

function calculateScore(data: MarketData): number {
  throw new Error('Not implemented')
}
```

### Step 2: Write Failing Test (RED)
Write tests that will fail:

```typescript
describe('calculateScore', () => {
  it('should return high score for active market', () => {
    const data = { id: '1', name: 'Test', status: 'active' }
    const score = calculateScore(data)
    expect(score).toBeGreaterThan(50)
  })
})
```

### Step 3: Verify Test Fails
Run the test and confirm it fails for the expected reason:

```bash
npm test
# FAIL: Error: Not implemented
```

### Step 4: Implement Minimal Code (GREEN)
Write just enough code to pass:

```typescript
function calculateScore(data: MarketData): number {
  return data.status === 'active' ? 100 : 0
}
```

### Step 5: Verify Test Passes
Run the test and confirm it passes:

```bash
npm test
# PASS
```

### Step 6: Refactor (IMPROVE)
Improve code quality while keeping tests green:

```typescript
const SCORE_MAP = {
  active: 100,
  resolved: 0
} as const

function calculateScore(data: MarketData): number {
  return SCORE_MAP[data.status]
}
```

### Step 7: Verify Tests Still Pass
Confirm refactoring didn't break anything:

```bash
npm test
# PASS
```

## Test Types

### Unit Tests
Test individual functions in isolation. Mock external dependencies. Fast execution (milliseconds). High coverage of edge cases.

### Integration Tests
Test component interactions. Use real or in-memory databases. Test API endpoints. Verify data flows.

### E2E Tests
Test complete user journeys. Use browser automation. Slower but high confidence. Focus on critical paths.

## Coverage Requirements

| Code Type | Minimum Coverage |
|-----------|------------------|
| Business Logic | 100% |
| API Endpoints | 90% |
| UI Components | 80% |
| Utilities | 80% |
| Overall | 80% |

## Best Practices

### DO
- Write the test FIRST, before any implementation
- Run tests and verify they FAIL before implementing
- Write minimal code to make tests pass
- Refactor only after tests are green
- Add edge cases and error scenarios
- Aim for 80%+ coverage (100% for critical code)

### DON'T
- Write implementation before tests
- Skip running tests after each change
- Write too much code at once
- Ignore failing tests
- Test implementation details (test behavior)
- Mock everything (prefer integration tests)

## Edge Cases to Always Test

- Empty inputs (null, undefined, [], '')
- Boundary values (0, -1, MAX_INT)
- Invalid inputs (wrong types, malformed data)
- Error conditions (network failures, timeouts)
- Concurrent access (race conditions)
- Large inputs (performance)

## Test Naming Convention

```typescript
// Format: should [expected behavior] when [condition]
it('should return empty array when no matches found', () => {})
it('should throw error when input is null', () => {})
it('should cache result when called multiple times', () => {})
```

## AAA Pattern

Structure tests using Arrange-Act-Assert:

```typescript
test('calculates total correctly', () => {
  // Arrange: Set up test data
  const items = [{ price: 10 }, { price: 20 }]

  // Act: Execute the function
  const total = calculateTotal(items)

  // Assert: Verify the result
  expect(total).toBe(30)
})
```

## Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run specific file
npm test -- path/to/file.test.ts

# Watch mode
npm test -- --watch
```

Remember: Tests are documentation. They should clearly communicate what the code does and why.
