---
description: Generate and run end-to-end tests with Playwright. Creates test journeys, runs tests, captures screenshots/videos/traces, and uploads artifacts.
agent: e2e-runner
model: "{env:OPENCODE_MODEL:openai/gpt-5.2-codex}"
---

# E2E Command

This command invokes the **e2e-runner** agent to generate, maintain, and execute end-to-end tests using Playwright.

## What This Command Does

1. **Generate Test Journeys** - Create Playwright tests for user flows
2. **Run E2E Tests** - Execute tests across browsers
3. **Capture Artifacts** - Screenshots, videos, traces on failures
4. **Upload Results** - HTML reports and JUnit XML
5. **Identify Flaky Tests** - Quarantine unstable tests

## When to Use

Use `/e2e` when testing critical user journeys (login, trading, payments), verifying multi-step flows work end-to-end, testing UI interactions and navigation, validating integration between frontend and backend, or preparing for production deployment.

## Example Usage

```
User: /e2e Test the market search and view flow

Agent (e2e-runner):
# E2E Test Generation: Market Search and View Flow

## Generated Test Code

```typescript
// tests/e2e/markets/search-and-view.spec.ts
import { test, expect } from '@playwright/test'
import { MarketsPage } from '../../pages/MarketsPage'

test.describe('Market Search and View Flow', () => {
  test('user can search markets and view details', async ({ page }) => {
    const marketsPage = new MarketsPage(page)
    await marketsPage.goto()
    await expect(page).toHaveTitle(/Markets/)

    await marketsPage.searchMarkets('election')
    await page.waitForResponse(resp =>
      resp.url().includes('/api/markets/search') && resp.status() === 200
    )

    const marketCards = marketsPage.marketCards
    await expect(marketCards.first()).toBeVisible()
    await marketCards.first().click()

    await expect(page).toHaveURL(/\/markets\/[a-z0-9-]+/)
    await page.screenshot({ path: 'artifacts/market-details.png' })
  })

  test('search with no results shows empty state', async ({ page }) => {
    const marketsPage = new MarketsPage(page)
    await marketsPage.goto()
    await marketsPage.searchMarkets('xyznonexistentmarket')
    await expect(page.locator('[data-testid="no-results"]')).toBeVisible()
  })
})
```

## Running Tests

```bash
npx playwright test tests/e2e/markets/search-and-view.spec.ts
# 2 passed (6.0s)
```
```

## Quick Commands

```bash
# Run all E2E tests
npx playwright test

# Run specific test file
npx playwright test tests/e2e/markets/search.spec.ts

# Run in headed mode (see browser)
npx playwright test --headed

# Debug test
npx playwright test --debug

# Generate test code interactively
npx playwright codegen http://localhost:3000

# View report
npx playwright show-report
```

## Test Artifacts

| Artifact | When Captured |
|----------|---------------|
| HTML Report | All tests |
| JUnit XML | All tests |
| Screenshot | On failure |
| Video | On failure |
| Trace file | On failure |

## Critical User Flows to Test

| Priority | Flow |
|----------|------|
| CRITICAL | User authentication |
| CRITICAL | Core actions (trading, posting) |
| CRITICAL | Payment processing |
| HIGH | Search functionality |
| HIGH | Navigation and routing |
| MEDIUM | Profile management |

## Best Practices

| DO | DON'T |
|----|-------|
| Use data-testid for selectors | Use brittle CSS selectors |
| Wait for API responses | Use arbitrary timeouts |
| Test critical user journeys | Test every edge case with E2E |
| Use Page Object Model | Duplicate selectors |

## CI/CD Integration

```yaml
- name: Install Playwright
  run: npx playwright install --with-deps
- name: Run E2E tests
  run: npx playwright test
- name: Upload artifacts
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: playwright-report
    path: playwright-report/
```

## Important Notes

**CRITICAL**: E2E tests involving real money MUST run on testnet/staging only. Never run trading tests against production.

## Related Agents

This command invokes the `e2e-runner` agent located at: `.opencode/agents/e2e-runner.md`
