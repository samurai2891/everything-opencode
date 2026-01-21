---
description: Restate requirements, assess risks, and create step-by-step implementation plan. WAIT for user CONFIRM before touching any code.
agent: planner
model: openai/gpt-5.2-codex
---

# Plan Command

This command invokes the **planner** agent to create a comprehensive implementation plan before writing any code.

## What This Command Does

1. **Restate Requirements** - Clarify what needs to be built
2. **Identify Risks** - Surface potential issues and blockers
3. **Create Step Plan** - Break down implementation into phases
4. **Wait for Confirmation** - MUST receive user approval before proceeding

## When to Use

Use `/plan` when starting a new feature, making significant architectural changes, working on complex refactoring, multiple files/components will be affected, or requirements are unclear or ambiguous.

## Example Usage

```
User: /plan I need to add real-time notifications when markets resolve

Agent (planner):
# Implementation Plan: Real-Time Market Resolution Notifications

## Requirements Restatement
- Send notifications to users when markets they're watching resolve
- Support multiple notification channels (in-app, email, webhook)
- Ensure notifications are delivered reliably
- Include market outcome and user's position result

## Implementation Phases

### Phase 1: Database Schema
- Add notifications table
- Add user_notification_preferences table
- Create indexes for performance

**Estimated Time:** 2 hours | **Complexity:** Low

### Phase 2: Notification Service
- Create notification service
- Implement queue with BullMQ/Redis
- Add retry logic

**Estimated Time:** 4 hours | **Complexity:** Medium

### Phase 3: Integration Points
- Hook into market resolution logic
- Query affected users
- Enqueue notifications

**Estimated Time:** 3 hours | **Complexity:** Medium

### Phase 4: Frontend Components
- Create NotificationBell component
- Add NotificationList modal
- Implement real-time updates

**Estimated Time:** 4 hours | **Complexity:** Medium

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Email deliverability | Medium | High | SPF/DKIM setup |
| Performance with 1000+ users | Medium | Medium | Batch notifications |

## Total Estimates

| Metric | Estimate |
|--------|----------|
| Total Time | 13-16 hours |
| Complexity | Medium |

---

**WAITING FOR CONFIRMATION**: Proceed with this plan? (yes/no/modify)
```

## Important Notes

**CRITICAL**: The planner agent will **NOT** write any code until you explicitly confirm the plan with "yes" or "proceed".

If you want changes, respond with:
- "modify: [your changes]"
- "different approach: [alternative]"

## Integration with Other Commands

After planning is confirmed:
- Use `/tdd` to implement with test-driven development
- Use `/build-fix` if build errors occur
- Use `/code-review` to review implementation
- Use `/security-audit` for security-critical code

## Related Agents

This command invokes the `planner` agent located at: `.opencode/agents/planner.md`
