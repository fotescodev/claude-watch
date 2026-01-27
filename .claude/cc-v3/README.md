# Claude Watch V2 Documentation

> **Foundation docs for V2 redesign implementation**
> **Created:** 2026-01-24

---

## Document Index

| # | Document | Purpose |
|---|----------|---------|
| 00 | [IMPLEMENTATION-PLAN.md](00-IMPLEMENTATION-PLAN.md) | **START HERE** - Main implementation plan with phases 0-8 + stretch goals |
| 01 | [ARCHITECTURE-CONTEXT.md](01-ARCHITECTURE-CONTEXT.md) | 7-state model, watchOS 26 features, file structure |
| 02 | [DESIGN-SYSTEM-CONTEXT.md](02-DESIGN-SYSTEM-CONTEXT.md) | Liquid Glass, colors, typography, animations |
| 03 | [ORIGINAL-SPEC.md](03-ORIGINAL-SPEC.md) | Original V2 spec for reference |

---

## Quick Reference

### Implementation Order

| Order | Phase | Priority |
|-------|-------|----------|
| 0 | Pencil Design Fixes | P0 |
| 1 | Design System | P0 |
| 2 | Working State | P0 |
| 3 | Tiered Approval | P0 |
| 4 | F18 Question Fix | P0 |
| 5 | Task Outcome | P0 |
| 6 | Breathing Animation | P1 |
| 7 | Swipe Gesture | P1 |
| 8 | Action Button | P1 |

### Key Decisions

- **Colors**: Hybrid (Anthropic accent + Apple semantic)
- **Architecture**: 7-state model (simplified from Phase 8)
- **watchOS 26**: Controls API + Siri + Action Button + Double Tap + RelevanceKit

### Flows Kept

| Flow | Description |
|------|-------------|
| F16 | Context Warning (75%/85%/95%) |
| F18 | Question Response (binary) |
| F21 | Background Task (notification) |

### Flows Dropped

- F15: Session Resume (re-run `npx cc-watch`)
- F17: Quick Undo (too dangerous)
- F19: Sub-Agent Monitor (too complex)
- F20: Todo Progress (read-only)

---

## Stretch Goals (Post-Launch)

See [00-IMPLEMENTATION-PLAN.md](00-IMPLEMENTATION-PLAN.md#stretch-goals-fomo-features-post-launch) for FOMO features:
- Stats & Shareability (weekly stats, share cards)
- Celebration & Personality (ship-it haptic, voice personality)
- Visibility (complications, menu bar companion)
- Smart Features (away mode, offline celebration)
- Annual (Wrapped, badges)
- Enterprise (team presence)

---

*This folder is the canonical source for V2 implementation.*
