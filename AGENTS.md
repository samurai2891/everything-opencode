# Project Guidelines for OpenCode

This document defines the rules and guidelines that OpenCode agents must follow when working on this project.

## Core Principles

### Code Quality
All code must be simple, readable, and maintainable. Prefer clarity over cleverness. Functions should be small and focused, with a maximum of 50 lines. Files should not exceed 400 lines.

### Security First
Never commit hardcoded secrets, API keys, or credentials. All sensitive data must use environment variables. Validate all user inputs. Use parameterized queries for database operations.

### Testing Requirements
Write tests before implementation (TDD). Maintain minimum 80% test coverage. Critical business logic requires 100% coverage. All new features must include unit tests.

### Immutability
Use spread operators for object and array updates. Avoid direct mutation of state. Prefer `const` over `let`.

## Development Workflow

### Before Starting Work
1. Understand the requirements completely
2. Create a plan using `/plan` command for complex features
3. Review existing code patterns
4. Identify affected components

### During Development
1. Write tests first (RED phase)
2. Implement minimal code to pass (GREEN phase)
3. Refactor for quality (REFACTOR phase)
4. Run tests after every change
5. Commit small, focused changes

### Before Committing
1. Run `/code-review` to check for issues
2. Ensure all tests pass
3. Remove console.log statements
4. Update documentation if needed
5. Run `/security-audit` for security-critical code

## File Organization

```
src/
├── app/           # Next.js App Router pages
├── components/    # React components
│   ├── ui/       # Generic UI components
│   └── features/ # Feature-specific components
├── hooks/        # Custom React hooks
├── lib/          # Utilities and configurations
├── types/        # TypeScript type definitions
└── styles/       # Global styles
```

## Naming Conventions

### Files
- Components: PascalCase (Button.tsx)
- Hooks: camelCase with 'use' prefix (useAuth.ts)
- Utilities: camelCase (formatDate.ts)
- Types: camelCase with .types suffix (user.types.ts)

### Variables and Functions
- Use descriptive names that explain purpose
- Boolean variables: prefix with is, has, can, should
- Functions: use verb-noun pattern (fetchUser, calculateTotal)

## TypeScript Standards

### Type Safety
Always use explicit types for function parameters and return values. Avoid `any` type. Use `unknown` when type is truly unknown. Define interfaces for complex objects.

### Error Handling
Wrap async operations in try-catch. Provide meaningful error messages. Never swallow errors silently. Log errors with context.

## React Standards

### Component Structure
Use functional components with TypeScript. Define prop interfaces explicitly. Use default parameter values. Keep components focused on single responsibility.

### State Management
Use React hooks for local state. Lift state up when needed. Consider context for widely-shared state. Use functional updates for state based on previous value.

### Performance
Memoize expensive computations with useMemo. Memoize callbacks with useCallback. Use lazy loading for heavy components. Avoid unnecessary re-renders.

## Git Workflow

### Commit Messages
Use conventional commit format:
- feat: new feature
- fix: bug fix
- refactor: code improvement
- docs: documentation
- test: test changes
- chore: maintenance

### Branch Strategy
- main: production-ready code
- develop: integration branch
- feature/*: new features
- fix/*: bug fixes

## Environment Setup

### Required Environment Variables
```
# API Keys (never commit these)
OPENAI_API_KEY=
ZAI_API_KEY=

# Database
DATABASE_URL=

# Authentication
NEXTAUTH_SECRET=
NEXTAUTH_URL=
```

### Development Tools
- Node.js 18+
- pnpm for package management
- TypeScript strict mode
- ESLint + Prettier
- Playwright for E2E tests

## Agent Usage

### Available Agents
- **planner**: Complex feature planning
- **code-reviewer**: Code quality review
- **security-reviewer**: Security audit
- **architect**: System design
- **tdd-guide**: Test-driven development
- **build-error-resolver**: Fix build errors
- **e2e-runner**: E2E test generation
- **refactor-cleaner**: Code refactoring
- **doc-updater**: Documentation sync

### When to Use Each Agent
- Starting new feature: `/plan`
- After writing code: `/code-review`
- Before release: `/security-audit`
- Build fails: `/build-fix`
- Need tests: `/tdd` or `/e2e`
- Code cleanup: `/refactor`
- Docs outdated: `/doc-sync`
- Architecture questions: `/architect`

## Prohibited Practices

The following practices are strictly prohibited:

1. Hardcoding secrets or API keys
2. Committing console.log statements
3. Using `any` type without justification
4. Skipping tests for new features
5. Direct state mutation
6. Ignoring TypeScript errors
7. Pushing without code review
8. Creating unnecessary documentation files
9. Using emojis in code or comments
10. Leaving TODO without ticket reference

## tmux Integration

For long-running processes, always use tmux:

```bash
# Start dev server in tmux
tmux new-session -d -s dev 'npm run dev'

# Attach to session
tmux attach -t dev

# List sessions
tmux ls
```

This ensures logs are accessible and processes persist across sessions.
