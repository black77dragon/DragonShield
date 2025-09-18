# New Alerts Timeline Tab

This proposal reimagines the Alerts Timeline tab as a narrative-first cockpit for risk monitoring. It combines timeline visualization best practices (clarity of temporal direction, progressive disclosure, semantic color language) with modern portfolio dashboards that emphasize focus, storytelling, and immediate actionability.

## Design Goals
- Help users answer **"What should I care about right now?"** within three seconds of opening the tab.
- Preserve the familiar concept of recent vs upcoming alerts while presenting it in a more cinematic, low-noise layout.
- Make clustering, severity, and alert type filters effortless to understand and manipulate.
- Encourage exploration by pairing a zoomable timeline canvas with a curated stream of AI-assisted summaries.

## Inspiration & Best Practices
- **Figma/Linear incident timelines:** Use a vertical spine with clearly separated past and future to aid scanning and reduce horizontal scroll fatigue.
- **Bloomberg Launchpad alerting & Apple Weather narratives:** Start with a hero story point ("Now" card) backed by micro-visuals so context is absorbed quickly.
- **Material Design data viz guidelines:** Limit simultaneous color channels, use shared axes, and favor layering + focus mode over crowded legends.
- **Observability tools (Datadog / Grafana):** Provide elastic zoom, brushing, and quick filters that reveal clusters without overwhelming the primary view.

## Experience Blueprint
1. **Hero Strip (top, 88pt height)**
   - Left: pill showing `NOW • <weekday>` with severity-colored glow reflecting the highest urgency within ±24h.
   - Center: stacked chips summarizing counts by severity (Critical/Warning/Info) with delta vs previous period.
   - Right: primary CTA "Jump to Critical" (opens first high-severity item) and secondary "Create Scenario" to generate what-if simulation.
2. **Timeline Canvas (main, vertical scroll, 3 lanes)**
   - Uses `Chart` with a vertical axis = chronological order (today anchored mid-screen) and three horizontal swimlanes: *Triggered*, *Upcoming*, *System*. Events attach to the spine with connector lines to cards.
   - A translucent "focus window" shows the current viewport; dragging it snaps to week chunks and updates all summaries.
   - Dot glyphs scale by severity confidence; upcoming alerts render with soft blur until confirmed.
   - Hover/long-press reveals microcards with key metrics (trigger threshold, affected instruments, next action).
3. **Context Ribbon (left drawer, collapsible 260pt width)**
   - Filter chips: Severity, Trigger type, Asset scope, Watchlists.
   - Range scrubber slider: -90d to +365d with quick presets and textual explanation.
   - Pattern detector toggles (e.g. "Cluster anomalies", "Regulatory focus"). When enabled, AI service annotates clusters ("5 FX alerts within 2h").
4. **Narrative Stream (right column, 320pt width)**
   - Chronological cards stitched into a storyline: `Headline`, `Impact`, `Recommended play`, optional `Link to MacroView`.
   - Cards share accent color w/ severity to reinforce connection and include `Open Alert` button.
   - When a timeline point is highlighted, the corresponding card pulses and scrolls into view (bidirectional sync).
5. **Micro-interactions**
   - Scroll-to-now button pinned bottom center.
   - Command bar search (⌘K) focusing the timeline; typing auto-filters.
   - Keyboard shortcuts for jumping between severity lanes (↑/↓) and timeline clusters (←/→).

## Component Architecture (SwiftUI)
- `NewAlertsTimelineView` (root) arranges a flexible grid with `HeroStrip`, `TimelineCanvas`, `ContextRibbon`, and `NarrativeStream` subviews.
- `TimelineCanvas` leverages `Charts` with a custom vertical orientation (flip axes) and uses `PlotOverlay` to handle dragging, hover, and snapping.
- `TimelineCluster` model groups alerts by day + severity; clusters feed both the chart and narrative to keep references in sync.
- `AlertStoryCard` handles the narrative stream with accessibility support (VoiceOver reads "Happened 2 hours ago" etc.).
- `TimelineNowIndicator` manages the glowing NOW pill, refreshing on midnight or time zone change.

## Data & Interaction Model
- Continue using existing DB queries (`listAlertEvents`, `listUpcomingDateAlerts`) but add a clustering layer that produces:
  ```swift
  struct TimelineCluster: Identifiable {
      let id: UUID
      let window: DateInterval
      let severity: AlertSeverity
      let triggerType: String
      let alerts: [AlertRow]
      let score: Double // for intensity + sorting
  }
  ```
- Maintain derived signals such as `highestSeverityInWindow`, `totalUpcomingWithin(range:)`, and `trendDelta` to populate the hero strip.
- Highlight logic: selecting a cluster highlights the lane, centers the timeline on the cluster, and surfaces the matching narrative card.
- Provide asynchronous AI hooks: supply a summary API helper `AlertNarrativeBuilder` that crafts a 2–3 sentence story per cluster (can be stubbed initially).

## Visual Language
- Background: muted slate gradient (secondary system background) to create depth, with content cards sitting on translucent surfaces (Material effect on macOS / iOS).
- Severity colors: reuse existing palette but add subtle inner shadows for upcoming events.
- Typography: `Large Title` for hero headline, `Body` for cards, `Caption2` for timestamps.
- Motion: 150ms ease-out for focus window snapping, 300ms spring for card hover expansions.

## Implementation Phasing
1. **MVP (1 sprint)**
   - Build new SwiftUI layout skeleton with placeholder data.
   - Implement vertical timeline canvas with snapping and `ScrollViewReader` for center-on-now.
   - Sync selection between canvas and narrative cards.
2. **Enhancements (Sprint 2)**
   - Add clustering algorithm (bin by hour w/ severity weighting).
   - Wire hero strip metrics, delta calculations, and CTA flows.
   - Integrate filter drawer with existing DB queries + new derived metrics.
3. **Innovations (Sprint 3+)**
   - Plug in AI narrative builder for auto-summaries.
   - Introduce scenario mode (simulate muting an alert or delaying triggers).
   - Add collaborative notes (tag teammates, leave decisions) for enterprise use.

## Why This Feels Sleek & Innovative
- **Narrative-first:** Timeline becomes a story rather than a dot plot; users consume context quickly.
- **Reduced cognitive load:** Clear lanes, glowing NOW indicator, and focus window prevent the "constellation" effect of overlapping markers.
- **Actionable flow:** Every component ties back to a next step (open alert, simulate, jump to cluster).
- **Future-ready:** Design accommodates AI-assisted annotations, scenario planning, and keyboard-driven power use without redesigning the core layout.

## Implementation Snapshot
- `NewAlertsTimelineView` scaffolds the hero strip, context ribbon, vertical timeline, and narrative stream with live data powered by the new `TimelineClusterBuilder`.
- `AlertNarrativeBuilder` currently returns heuristic summaries asynchronously and is ready to swap in an AI backend.
- The new "Timeline+" tab in `AlertsSettingsView` runs side-by-side with the classic timeline so we can dogfood and iterate quickly.

Next up: tune the clustering heuristics with real telemetry, plug in the AI summary service, and layer on the immersive chart once the data model settles.
