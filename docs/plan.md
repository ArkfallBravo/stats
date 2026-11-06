# plan.md

## In flight: pickable history chart colors

**Status (2026-10-09):** implemented in the working tree on `my-changes`, uncommitted. The full `Stats` scheme builds and is installed in `/Applications`. It was rebuilt on 2026-11-06 on top of the upstream v3.0.25 merge (`a0045768`). Waiting on the user's manual test; commit only after they confirm.

- **Four new rows** in the RAM popup's chart settings, after "Chart color": Normal, Warning and Critical pressure color, and Combined usage color. They use the stock `colorSelectView` dropdown (including Custom…), with the items `[Default, separator] + SColor.allColors`.
- **"Default" is the OKHSL color** (system hue at the shared saturation and lightness, resolved per draw). **Any other pick is drawn as-is**, with no OKHSL equalizing; the user chose that over "equalize the picked hue" and an "equalize" toggle (see `docs/alternatives.md`). Compression shares the level colors, as before.
- **Model (`Modules/RAM/HistoryPalette.swift`):**
  - `HistoryRole` (normal/warning/critical/usage) gives each role its system hue, row title, Store key (`RAM_history_<role>Color`), "Default" `SColor` (key `okhslDefault`) and menu items.
  - `historyOverride(_:)` maps a pick to nil for Default, otherwise to its color.
  - `HistoryPalette(overrides)` resolves all four colors once per draw.
- **Views:** `PressureHistoryView` and `CombinedHistoryView` take `colorOverrides` and redraw when it's set. The popup keeps `historyColorStates`, pushes them in through `applyHistoryColors()`, and has one `@objc` toggle per role, all funneling into `setHistoryColor(_:from:)`.
- **Kit changes (upstream files, so new merge-conflict surface):**
  - `SColor.named(key:value:color:)` in `Kit/types.swift`.
  - `SColorSelectView` in `Kit/extensions.swift` now resolves keys against its own `items` before falling back to `SColor.fromString`. That way, a module's own entry (like Default) shows its real swatch instead of the accent color.
- **No new unit tests.** The new logic is a nil-for-default mapping and an `items.first ?? fromString` lookup inside a private UI class; neither is worth isolating.

## Archived initiatives
- RAM compression ratio, CMPR widget, and compression/combined history charts with OKHSL: `docs/archive/ram-compression-and-history-charts.md`
