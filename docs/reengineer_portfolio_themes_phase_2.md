# Re-engineer Portfolio Themes — Phase 2 Plan

This document tracks the Phase 2 scope for the new Portfolio Theme Workspace.

## Goals
- Inline editing in Holdings (research %, user %, notes) with validation and debounced saves
- Column customization (visibility, order, width) with persisted user defaults
- Quick filters: out-of-tolerance, search by name, status filters
- Analytics: contribution by sector/asset class, currency exposure, movers
- UX/Perf: keyboard shortcuts, skeleton states, toasts, virtualized lists

## Acceptance
- Edits persist and reflect immediately
- Sorting/filters persist across launches
- Analytics derive from existing valuation data (no duplication)
- No regressions to the classic editor or updates flow

---
This file exists to seed the Phase 2 branch for an initial draft PR.
