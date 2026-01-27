# DragonShield - Thesis Management
**Business Specification (v1.3)**
*Authoritative Reference Document*

---

## Versioning
- **v1.0** - Initial business specification
- **v1.1** - Integrated useful operational and UX aspects
- **v1.2** - KPI framework tightened (primary vs secondary limits)
- **v1.3** - Guided thesis import and weekly review workflow (prompt provenance + state gating)

---

## Uncertainty
No material uncertainty.

---

## 1. Purpose & Design Intent

DragonShield provides a **disciplined, repeatable, low-friction system** for managing a small number of intellectually strong investment theses in complex global macro environments.

The system is explicitly designed to:
- Preserve **thesis integrity over time**
- Detect **early degradation**
- Force **explicit judgement and action**
- Operate within a **strict 15-minute weekly review budget per thesis**
- Support **LLM-assisted analysis with zero retyping**

DragonShield manages **ideas and decisions**, not instruments, execution, or pricing.

---

## 2. Scope & Operating Assumptions

- **Number of theses**
  - Baseline: 8 active theses
  - Scalable to: 12
- **Priority structure**
  - 3 **Core / Tier-1 theses** (pinned, visually prioritised)
  - Remaining theses treated as Tier-2
- **Asset classes**
  - Fully agnostic (FX derivatives, structured products, crypto rails, etc.)
  - Instruments are treated as *expressions* of a thesis, not system drivers
- **User model**
  - Single primary decision-maker
  - High intellectual rigor, limited time

---

## 3. Conceptual Loop

```
THESIS (why it exists)
  |
  v
MEASUREMENT (what must hold)
  |
  v
WEEKLY JUDGEMENT (what changed)
  |
  v
DECISION (what to do)
  |
  v
HISTORY (what actually happened)
```

Breaking any link invalidates the system.

---

## 4. Core Objects

### 4.1 Thesis (Stable Intellectual Capital)

**Purpose**
Defines *why capital is committed* and *when that commitment must end*.

**Required Components**
- **North Star** (5-8 sentences, durable)
- **Investment Role** (hedge, convexity, growth, income, optionality)
- **Core Assumptions (3-5)**
  - Explicitly falsifiable
- **Key Drivers**
- **Structural Risks**
- **Kill Criteria (Breakers)**
  - Binary, non-negotiable invalidation conditions
- **Non-Goals**
- **Priority Flag**
  - Tier-1 or Tier-2

**Business Rules**
- Theses change rarely
- Weekly reviews must never mutate thesis logic
- Kill criteria override all other signals

---

### 4.2 KPI Framework (Operational Pressure Gauges)

**Purpose**
Translate abstract assumptions into **observable pressure signals** while enforcing cognitive discipline.

#### KPI Structure (Strict Limits)

- **Primary KPIs**
  - **Exactly 3-5 per thesis**
  - Mandatory for every weekly review
  - Drive overall thesis status
- **Secondary KPIs**
  - **0-4 per thesis (hard cap)**
  - Contextual or confirmatory
  - Reviewed opportunistically, not always weekly

> **Hard Rule:**
> A thesis may never have more than **9 KPIs total**
> (5 primary + 4 secondary).
> Exceeding this indicates conceptual dilution.

#### KPI Rules (Non-Negotiable)

- Every KPI must have:
  - Directionality (higher/lower is better)
  - Explicit **Green / Amber / Red ranges**
- KPIs measure **stress on the thesis**, not performance or PnL
- Primary KPIs must map directly to **core assumptions or kill criteria**
- Secondary KPIs may *support*, but never override, primary KPIs

#### KPI Dimensions (Allowed)

- Macro
- Structural / Fundamentals
- Adoption / Behavior
- Valuation / Pricing (contextual only)
- Risk / Fragility

#### Normalisation Layer (Optional, Retained)

- Optional **1-10 score per dimension**
- Used only for **cross-thesis comparison**
- Mapped to RAG:
  - 7-10 -> Green
  - 4-6 -> Amber
  - 1-3 -> Red

---

### 4.3 Weekly Review (Decision Engine)

**Purpose**
Convert new information into **explicit judgement and action**.

**Cadence & Constraints**
- Weekly, time-boxed (<=15 minutes)
- Sunday nudge if incomplete
- Same structure every week
- No retroactive editing

**Weekly Review Must Contain**
1. **One-line headline**
   - "What changed materially, if anything?"
2. **Primary KPI Snapshot**
   - Current value vs range
   - Trend (up / flat / down)
3. **Secondary KPI Notes** (if relevant)
4. **Material Events**
   - Macro (only if material)
   - Thesis-specific
5. **Assumption Integrity Check**
   - Intact / Stressed / Violated
6. **Confidence Score** (1-5)
7. **Single Explicit Decision**
   - Add / Trim / Hold / Pause / Exit / Monitor
8. **Rationale**
   - <=3 bullets
9. **Watch Items**
   - What must be checked next week

**Decision Discipline**
- Exactly one decision required
- "Hold" during Red status requires explicit justification
- Breaker triggered -> Exit suggestion surfaced automatically

---

### 4.4 History (Immutable Evidence Layer)

**Purpose**
Preserve decision context and prevent narrative rewriting.

**Stored Over Time**
- Weekly headlines
- KPI values & RAG states (primary and secondary)
- Decisions taken
- Assumption status changes

**Derived Views**
- 12-week KPI trends (primary by default)
- RAG drift (time spent in Amber/Red)
- Review punctuality
- Decision consistency

**Rules**
- Append-only
- View-only for archived theses
- Exportable (e.g., CSV)

---

## 5. Attention & Prioritisation Model

- **Tier-1 theses**
  - Pinned to top of dashboard
  - Lower tolerance for Amber drift
  - Visual prominence
- **Tier-2 theses**
  - Standard monitoring
  - Wider acceptable variance

This reflects **attention economics**, not capital allocation.

---

## 6. Dashboard & UX Principles (Business Level)

**Global Dashboard**
- Card per thesis showing:
  - Overall RAG
  - 3 most critical **primary KPIs**
  - Last decision
  - Review urgency

**Sorting Defaults**
1. Red / Amber first
2. Overdue reviews
3. Tier-1 priority

**Interaction Constraints**
- <=3 clicks from dashboard to completed review
- Status > trends > numbers > text
- Exceptions dominate averages

---

## 7. Guided Thesis Import & Weekly Review (LLM Round-Trip)

### Purpose
- Guided, explicit workflow for thesis import and weekly updates
- User never has to remember internal mechanics
- Schema validation gates all progression
- No hidden automation; user runs LLM externally

### Scope & Constraints
- Native macOS desktop, single user
- Manual LLM interaction only
- Prompt inspection is read-only
- No background execution or orchestration

### Artifact Model (Authoritative)
| Artifact | Description | Persisted |
| --- | --- | --- |
| Thesis | Core investment thesis | Yes |
| Prompt Template (Import / Weekly) | Global, versioned templates | Yes |
| KPI Pack Prompt | Optional, per-thesis prompt | Yes |
| Combined Prompt (C) | Generated at runtime | No |
| Import JSON / Patch JSON | Applied then discarded | No |

### Prompt Model (A/B/C)
- A: Global prompt templates (import + weekly), versioned, one active
- B: Per-thesis KPI pack prompt, optional, versioned
- C: Combined prompt generated at runtime from A + thesis data + history + optional B; never persisted

### User Journeys
Thesis Import (initial creation)
1. Show active thesis import prompt
2. User runs prompt externally
3. User pastes JSON output
4. Validate against thesis_import_v1
5. Load draft, review, confirm, save

Weekly Thesis Update
1. Retrieve active weekly template (A) and thesis data
2. Inject KPI pack prompt (B) if active
3. Generate combined prompt (C) and present for copy (not persisted)
4. User runs prompt externally
5. User pastes patch JSON
6. Validate against WeeklyReviewPatch v1
7. Apply patch incrementally; preserve history

### UI Structure (Fixed)
- Process spine (sectioned, always visible)
- Step header uses: "Step X of Y - Typical time: ~N minutes"
- System state bar with a single-sentence operational truth

Process spine states
- o = not started
- * = active
- x = completed
- ! = blocked (hover explains why)
Rules
- Only current and completed steps are clickable
- Blocked steps show a reason

### Prompt Inspector (Optional)
- Read-only drawer showing source, key, version, and full prompt text

### Validation & Error Handling
- Invalid schema blocks progression
- Errors are inline and explain impact
- State bar reflects current status (no modal dialogs)

### Explicit Non-Goals
- No auto-run LLMs
- No silent prompt modifications
- No overwriting thesis data
- No hidden automation

---

## 8. Edge-Case Handling

- **First review**
  - Neutral deltas, trends = N/A
- **Breaker triggered**
  - Red alert, exit suggested, archive option surfaced
- **Overdue reviews (>6 days)**
  - Persistent nudges, urgency sorting
- **Archived theses**
  - Read-only, excluded from nudges
- **Complex instruments**
  - Exposure logged qualitatively (descriptive, not priced)

---

## 9. Success Criteria

DragonShield is successful if:
- Current step and next action are obvious in under 3 seconds
- Prompt provenance (A/B/C) is always clear
- Invalid LLM output is caught early
- The workflow is understandable after long absence
- The UI feels calm, explicit, and professional
- Weekly reviews are completed consistently
- Decisions are traceable to thesis logic
- Thesis degradation is detected earlier
- Decision stress during volatility is reduced
- The system is used continuously, not episodically

---

## 10. Mental Model

- **Thesis:** Flight plan
- **Primary KPIs:** Critical instruments
- **Secondary KPIs:** Supporting gauges
- **Weekly review:** Instrument scan
- **History:** Black box
- **LLM:** Ground control advisory
- **User:** Pilot in command

---

**Status:** v1.3 frozen
**Purpose:** Canonical business reference for DragonShield Thesis Management
