# DS-030 – Risk Report Visual Layout (Mock)

Purpose: bold, scannable visuals at the top of the Risk Management view with drill-down hooks for each subsection.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Hero strip                                                                   │
│ ┌────────────┬─────────────────────┬──────────────────┬────────────────────┐ │
│ │Risk Gauge  │SRI Donuts           │Liquidity Donut   │Overrides Status   │ │
│ │(score+Δ)   │(Count | Value)      │(+ Illiquid chip) │(Active/Exp/Expd)  │ │
│ └────────────┴─────────────────────┴──────────────────┴────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────────┐
│ Exposure Heatmap: rows = top asset classes/issuers, cols = SRI buckets       │
│  - cell click: filter instruments table; tooltip: value, % of portfolio      │
└──────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────────┐
│ Detail panels (stacked or tabs)                                              │
│ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐               │
│ │SRI Distribution │  │Liquidity Tiers  │  │Overrides/Expiries│              │
│ │(donut+table)    │  │(donut+table)    │  │(timeline+table)  │              │
│ └─────────────────┘  └─────────────────┘  └─────────────────┘               │
│ Additional: Allocation vs SRI bars, Concentration treemap                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Hero strip (top of view)
- **Risk Gauge (overall score + delta)**: semicircle or meter; center shows current portfolio risk score; badge shows delta vs previous period (green/red arrow); click opens full scoring breakdown (weights, last calc time).
- **Dual SRI Donuts (Count | Value)**: toggle buttons switch metric; slices map to SRI 1–7; slice click filters the instruments list; tooltip shows count/value and % of total.
- **Liquidity Donut + Illiquid Chip**: donut for tiers (Highly Liquid → Restricted); center chip highlights total illiquid %; slice click filters the liquidity section.
- **Overrides Status Bar**: three pills (Active / Expiring soon / Expired) with counts; pill click jumps to the overrides panel filtered accordingly.
- (Removed in DS-057) Trend sparklines were dropped to prioritize the main hero cards and simplify the layout.

## Exposure heatmap
- Grid with rows = top N asset classes/issuers; columns = SRI buckets; color intensity = value share.
- Cell click opens filtered instruments list; tooltip: absolute value, % of portfolio, count; optional legend to normalize by row or portfolio.

## Detail panels (below fold)
- **SRI Distribution panel**: donut + sortable table; toggle Count/Value; quick filter chips for high risk (6–7).
- **Liquidity panel**: donut + sortable table; center callout repeats illiquid %; add badge for “Missing liquidity” if fallbacks were used.
- **Overrides/Expiries panel**: horizontal timeline ribbon for expiries (now → 90d); compact table with columns: Instrument, Computed vs Override, Owner, Set at, Expires at, Status; row click opens instrument detail/maintenance.
- **Allocation vs SRI bars**: 100% stacked bars per asset class showing SRI mix; useful for comparing classes; click a segment to filter instruments.
- **Concentration treemap**: by issuer or asset class, colored by SRI bucket to flag concentrated high-risk pockets.

## Interaction notes for implementation
- Use consistent color palette: SRI buckets keep their standard risk colors; liquidity tiers use a separate neutral→warning ramp; overrides use info/warning/error pills.
- All charts emit filters (bucket, tier, override status) to refresh underlying tables; maintain clear “clear filter” affordance.
- Provide loading/empty states: skeleton for charts; empty illustration with “No data” messaging and disabled drill-down.
- Keep accessibility: ensure color + label; tooltips include numeric values; keyboard focusable segments; high-contrast mode.

## Placement in `RiskManagementMaintenanceView`
- Hero strip sits above existing tabs; heatmap follows; detail panels can be in a stacked vertical layout or as tabs if vertical space is constrained.
- Reuse existing design system cards/tiles for each panel to stay consistent with other DS views.
