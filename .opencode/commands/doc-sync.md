---
description: Synchronize documentation with code changes. Updates README, API docs, and generates documentation from source files.
agent: doc-updater
model: "{env:OPENCODE_MODEL:openai/gpt-5.2-codex}"
---

# Doc Sync Command

This command invokes the **doc-updater** agent to synchronize documentation with code changes.

## What This Command Does

1. **Identify Changes** - Find modified code files
2. **Update README** - Sync scripts, env vars, features
3. **Update API Docs** - Sync endpoint documentation
4. **Generate References** - Create docs from code
5. **Find Stale Docs** - Identify outdated documentation
6. **Verify Links** - Check all links work

## When to Use

Use `/doc-sync` after implementing new features, after API changes, before releases, after configuration changes, during documentation reviews, or when README is outdated.

## Example Usage

```
User: /doc-sync

Agent (doc-updater):
# Documentation Sync Report

## Changes Detected

### Modified Files (last 5 commits)
- src/api/markets.ts (new endpoint)
- package.json (new script)
- .env.example (new variable)

## Updates Made

### README.md

#### Scripts Section (Updated)
Added new script:
| `npm run seed` | Seed database with test data |

#### Environment Variables (Updated)
Added new variable:
| `REDIS_URL` | No | Redis connection URL |

### docs/API.md

#### New Endpoint Added
```markdown
## GET /api/markets/trending
Returns trending markets based on volume.
```

## Stale Documentation Found

| File | Issue |
|------|-------|
| docs/old-api.md | References deprecated endpoint |

## Verification
- [x] All links work
- [x] Code examples compile
```

## Documentation Sources

| Source | Generates |
|--------|-----------|
| `package.json` scripts | README scripts section |
| `.env.example` | Environment variables docs |
| TypeScript interfaces | API documentation |
| JSDoc comments | Function documentation |

## Documentation Checklist

- [ ] README reflects current functionality
- [ ] All public APIs have JSDoc
- [ ] API endpoints documented
- [ ] Configuration options listed
- [ ] Code examples tested
- [ ] Changelog updated

## Verification Steps

```bash
# Check all links work
npx markdown-link-check README.md

# Verify code examples compile
npx ts-node --eval "import { fn } from './src'"

# Format markdown
npx prettier --write "**/*.md"
```

## Integration with Other Commands

- Use `/plan` to plan features
- Use `/tdd` to implement
- Use `/doc-sync` to update docs
- Use `/code-review` to verify quality

## Related Agents

This command invokes the `doc-updater` agent located at: `.opencode/agents/doc-updater.md`
