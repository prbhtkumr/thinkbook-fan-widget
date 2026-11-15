# Changelog

## 0.2.0 - 2026-11-16

- Add an Unpin button to the popup while a level is pinned
- Write control files atomically with a temporary file and rename
- Only create missing control files at panel start instead of overwriting CLI
  or service choices
- Show minimum-level write errors in the Fan settings page
- Show `MAX` when the emergency temperature override is active
- Mark the state stale after 15 seconds and show `STALE` and `N/A` instead
  of old values
- Validate state field types and cap the status file read

## 0.1.0 - 2026-11-14

- Dual ring level gauge with full circle and arc shapes
- Optional level number, level segments, and temperature arc
- Selectable gauge colors and curve-based level coloring
- Popup with swipeable Control and Graph pages
- Graph line styles, raw and smoothed visibility, guides, peak line, legend,
  fill, and color pickers
- Three settings pages: Fan, Appearance, Graph
- Minimum fan level 0 to 7 across the widget and service
- Minimum-level changes written directly from settings
- Level text, status, temperature, icon, and gauge toggles
- Decoupled from the standalone `thinkbook-fan` service
- Removed the unused RPM and EC read-back display
