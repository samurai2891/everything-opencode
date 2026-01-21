---
name: git-workflow
description: Git workflow, commit conventions, and branching strategy.
---

# Git Workflow

## Commit Message Convention

Use conventional commit format for all commits:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| feat | New feature |
| fix | Bug fix |
| refactor | Code improvement (no feature change) |
| docs | Documentation only |
| test | Adding or updating tests |
| chore | Maintenance, dependencies |
| style | Formatting, whitespace |
| perf | Performance improvement |
| ci | CI/CD changes |

### Examples

```bash
# Feature
git commit -m "feat(auth): add OAuth2 login support"

# Bug fix
git commit -m "fix(api): handle null response in user endpoint"

# Refactor
git commit -m "refactor(utils): extract date formatting to utility"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Tests
git commit -m "test(auth): add unit tests for login flow"
```

## Branching Strategy

### Main Branches

- **main**: Production-ready code, always deployable
- **develop**: Integration branch for features

### Feature Branches

```bash
# Create feature branch
git checkout -b feature/user-authentication

# Work on feature...

# Merge back
git checkout develop
git merge feature/user-authentication
```

### Naming Convention

```
feature/short-description
fix/issue-number-description
refactor/component-name
docs/topic
```

## Workflow Steps

### Starting New Work

```bash
# Update main branch
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/new-feature

# Make changes...
```

### During Development

```bash
# Stage changes
git add .

# Commit with conventional message
git commit -m "feat(component): add new functionality"

# Push to remote
git push origin feature/new-feature
```

### Before Merging

```bash
# Update from main
git checkout main
git pull origin main
git checkout feature/new-feature
git rebase main

# Resolve any conflicts...

# Push updated branch
git push origin feature/new-feature --force-with-lease
```

### Creating Pull Request

```bash
# Using GitHub CLI
gh pr create --title "feat: add user authentication" --body "Description of changes"

# Review PR
gh pr view

# Merge when approved
gh pr merge
```

## Best Practices

### Commit Frequently
Make small, focused commits. Each commit should represent one logical change.

### Write Good Messages
The commit message should explain what changed and why. Future developers (including yourself) will thank you.

### Keep Branches Short-Lived
Feature branches should be merged within a few days. Long-lived branches lead to merge conflicts.

### Review Before Pushing
Always review your changes before pushing:

```bash
# See what changed
git diff

# Review staged changes
git diff --staged

# Check commit history
git log --oneline -10
```

### Clean Up Branches

```bash
# Delete merged local branch
git branch -d feature/completed-feature

# Delete remote branch
git push origin --delete feature/completed-feature

# Prune stale remote branches
git fetch --prune
```

## Useful Commands

### Viewing History

```bash
# Pretty log
git log --oneline --graph --all

# Show changes in commit
git show <commit-hash>

# Find who changed a line
git blame <file>
```

### Undoing Changes

```bash
# Discard unstaged changes
git checkout -- <file>

# Unstage file
git reset HEAD <file>

# Amend last commit
git commit --amend

# Revert a commit
git revert <commit-hash>
```

### Stashing

```bash
# Stash changes
git stash

# List stashes
git stash list

# Apply stash
git stash pop

# Apply specific stash
git stash apply stash@{0}
```

## Pre-Commit Checklist

Before every commit:

1. Run tests: `npm test`
2. Check for linting errors: `npm run lint`
3. Remove console.log statements
4. Review diff: `git diff`
5. Write meaningful commit message

## Integration with OpenCode

Use the `/code-review` command before pushing to catch issues early. The code-reviewer agent will check for:

- Security issues
- Code quality problems
- Missing tests
- Documentation gaps

Always address review feedback before merging.
