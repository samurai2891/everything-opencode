---
description: Design system architecture and technical decisions. Creates architecture diagrams, evaluates trade-offs, and documents decisions in ADRs.
agent: architect
model: openai/gpt-5.2-codex
---

# Architect Command

This command invokes the **architect** agent to design system architecture and make technical decisions.

## What This Command Does

1. **Analyze Requirements** - Understand system needs
2. **Design Architecture** - Create component diagrams
3. **Evaluate Trade-offs** - Compare alternatives
4. **Document Decisions** - Create ADRs (Architecture Decision Records)
5. **Review Patterns** - Apply appropriate design patterns

## When to Use

Use `/architect` when designing new systems or features, making technology choices, evaluating architectural trade-offs, documenting technical decisions, reviewing existing architecture, or planning major refactoring.

## Example Usage

```
User: /architect Design a real-time notification system

Agent (architect):
# Architecture Design: Real-Time Notification System

## Requirements Analysis

### Functional Requirements
- Real-time delivery (< 5 seconds)
- Multiple channels (in-app, email, push)
- User preferences management

### Non-Functional Requirements
- Scale: 10,000+ concurrent users
- Availability: 99.9% uptime

## Architecture Options

### Option A: WebSocket + Redis Pub/Sub
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│  WebSocket  │────▶│   Redis     │
│  (Browser)  │◀────│   Server    │◀────│   Pub/Sub   │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Pros:** Low latency, simple implementation
**Cons:** Requires sticky sessions

### Option B: Server-Sent Events (SSE)
**Pros:** HTTP-based, simpler
**Cons:** One-way communication only

## Recommendation

**Option A: WebSocket + Redis Pub/Sub**

Best balance of real-time performance and scalability.

## Architecture Decision Record (ADR)

### ADR-001: Real-Time Notification Transport

**Status:** Proposed

**Context:** Need real-time notifications for market events

**Decision:** Use WebSocket with Redis Pub/Sub

**Consequences:**
- (+) Sub-second delivery latency
- (+) Scales horizontally with Redis
- (-) Requires WebSocket infrastructure
```

## Architecture Patterns

| Pattern | Use Case |
|---------|----------|
| Event-Driven | Async processing, decoupling |
| CQRS | Read/write separation |
| Saga | Distributed transactions |
| Circuit Breaker | Fault tolerance |
| API Gateway | Request routing |

## ADR Template

```markdown
# ADR-XXX: [Title]

## Status
Proposed / Accepted / Deprecated / Superseded

## Context
What is the issue we're addressing?

## Decision
What is the change we're proposing?

## Consequences
What are the positive and negative results?
```

## Integration with Other Commands

- Use `/architect` to design system
- Use `/plan` to plan implementation
- Use `/tdd` to implement with tests
- Use `/security-audit` to verify security

## Related Agents

This command invokes the `architect` agent located at: `.opencode/agents/architect.md`
