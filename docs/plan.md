# plan.md

## In flight: compression history chart in the RAM popup

**Status (2026-10-09):** the user tested it in the installed app and confirmed it works. Committed on `my-changes` together with the combined chart below; not pushed. The RAM scheme compiles. Five new files were added to `project.pbxproj` with IDs `CC0000012F…` through `CC00000A2F…`.

- **"Chart data" has a third option:** `compression` ("Compression ratio"). It plots `compressionPercent / 100`. The existing keys `usage` and `pressure` are unchanged, so saved settings still load.
- **It reuses `PressureHistoryView`.** Each slice is colored by `value.pressure.level`, the same kernel level that tints CMPR. The "Chart color" setting doesn't apply to it, and doesn't apply to the pressure chart either. In the popup the property is now named `levelChart`, and `usesLevelChart` (pressure or compression), `usesCombinedChart` and `showSelectedChart()` drive visibility and reinit. The class name was kept so the pbxproj wouldn't need editing.
- **Switching between pressure and compression** reinits the level chart, so the two metrics' histories never mix.
- **Interpretation:** "compressor history" was read as the compression ratio C/(A+C), not compressed bytes. Revisit this if the user meant bytes.
- **Also fixed in this batch:** the chart title now updates on toggle (`replaceChartSeparator()` rebuilds the separator with `separatorView`, because setting `stringValue` would drop its styling). The "Scale value" row is now hidden through a stored `scaleValueRow` reference instead of index 3, which the "Chart data" row had shifted onto "Main chart scaling".
- **No unit test for the metric switch.** It's a three-way mapping inside a UI class, with no logic worth isolating.

### Combined line chart and OKHSL palette (added 2026-10-09, same uncommitted batch)
- **The fourth "Chart data" option is `combined` ("Combined").** Its separator title is "Memory history". `CombinedHistoryView` draws three lines and no fill:
  - usage, solid blue
  - pressure %, solid and colored by level
  - compression %, dotted (`[3, 2]`) and colored by level
  - all at `combinedLineWidth` 1.5pt
- **Level coloring:** each segment takes its starting sample's level, mirroring the pressure chart's fill. `HistoryRuns.levelPolylines` groups segments into same-level runs, and the dash phase carries across runs by cumulative length. At 180 points, a segment is about 1.5pt, so restarting the dash on every segment would draw a solid smear.
- **OKHSL:** `Kit/plugins/OKHSL.swift` is a reshaped port of the user's Color Picker `ColorMath.swift`, itself from Ottosson's ok_color.h. It's a struct with `init(_ NSColor)` and `.color`. One change from the reference: lightness 0 or 1 gives saturation 0 instead of a divide-by-zero NaN. The gamut cusp uses the reference polynomial fit plus one Halley step, which isn't exact. That's disclosed in the file.
- **Palette (`HistoryPalette`):** the user chose system hues at a shared OKHSL saturation and lightness, and chose to apply it to both the combined chart and the existing pressure chart.
  - The hues come from `systemGreen`/`systemYellow`/`systemRed`/`systemBlue`, resolved in `draw()` so the current appearance applies.
  - Saturation 0.85 and lightness 0.65 are first guesses for the user to tune.
  - Warning stays yellow in the charts, while the gauge, widgets and popup text keep `pressureColor()` orange. That follows the scope the user chose.
- **Shared plumbing:** `Kit/plugins/HistoryRing.swift` is a thread-safe generic ring buffer, and `Modules/RAM/HistoryGeometry.swift` holds the point layout and the polyline splitting. `PressureHistoryView` was refactored onto both; its drawing is unchanged apart from colors.
- **Tests: all the new ones pass** (2026-10-09, `xcodebuild test -scheme Stats`, 25 run). `testProcessReader_parsePSLine`, `testRAMPressure_alertColor` and the rest of the earlier work pass too. The only failure is `testIsNewestVersion_beta`, which is upstream's code and is tracked in `todo.md`. The tests added in this batch:
  - in `Tests/Kit.swift`: `testOKHSL_roundTrip`, `testOKHSL_achromatic`, `testOKHSL_fullSaturationReachesGamutEdge`, `testOKHSL_keepsHueAcrossLightness`, `testHistoryRing_ordersOldestFirst`
  - in `Tests/RAM.swift`: `testHistoryRuns_polylines`, `testHistoryRuns_levelPolylines`

## In flight: compression ratio for the RAM module

**Status (2026-10-04):** committed on `my-changes` as `25ec615f` (feature) and `9a9e9252` (the /simplify pass), on top of the upstream merge `30ef4934`. Pushed: `origin/my-changes` was at `9a9e9252` on 2026-10-09. The user asked to commit without reporting a manual test result, so in-app behaviour is still unconfirmed.

What's verified:
- The RAM scheme compiles. It builds `Kit` too and doesn't touch `/Applications`.
- `testUsageReader_compressionPercent` and `testRAMPressure_textColor` passed (2026-10-03).

- `testRAMPressure_alertColor` and `testProcessReader_parsePSLine` passed, and the full `Stats` scheme built and installed (2026-10-09).

What hasn't run yet: swiftlint, which isn't installed locally.

### What's built
- **Data:** `UsageReader.compressionPercent(compressedPages:availablePages:)`, a public static pure helper. `UsageReader` was made `public` so plain `import RAM` tests can reach it. The value is stored as `RAM_Usage.compressionPercent`, computed in `UsageReader.read()` next to `pressurePercent`.
- **Widget:** a separate **CMPR** menu bar widget (`widget_t.compressionRatio` = `"compression_ratio"`, `CompressionRatioWidget` in `Kit/Widgets/CompressionRatio.swift`). In the RAM `config.plist` it has Order 10 and is off by default. The caption and value are both tinted by the kernel level through `RAMPressure.alertColor()` (nil at normal).
- **Shared base:** CMPR and PRES share `LabeledPercentWidget` (`Kit/Widgets/LabeledPercent.swift`). It owns the frame, the percent and `setValue`, the preview value (read from the plist's `Preview > Value`), and the caption-over-percent drawing. Redraws go through `needsDisplay`, so a value change and a pressure change in one tick produce a single draw. `MemoryPressureWidget` subclasses it and passes `tint: nil`, so PRES looks unchanged and keeps its PRES/ROOM picker.
- **Tint helpers:** `RAMPressure.alertColor()` and `textColor()` (`alertColor() ?? .textColor`) in `Kit/types.swift` hold the one "tint only above normal" rule.
- **Extras:**
  - a "Compression ratio" notification (stepper, default 50)
  - a `$pressure.compression` text widget token
  - popup rows below Swap: "RAM pressure" (`pressurePercent`, untinted), then "Compression ratio" (tinted via `textColor()`)
  - a "Compression" row in the portal (combined view), untinted

### User-driven design history (not visible in the diff)
- **The user first wanted a separate widget.** They first asked for the ratio "like we did for ram pressure". I offered a "3rd mode on pressure widget" (a picker entry) and built that. The user had actually meant a separate widget next to PRES, and misread the option. It was reworked into the standalone widget, and the picker mode was removed.
- **Caption name:** briefly "RATIO". The user preferred "CMPR".
- **"Tint CMPR"** meant tinting the caption *in addition to* the already-tinted number. It didn't mean an earlier tint. Rejected alternatives the user didn't take: yellow from 40% before warning, green at normal.
- **Thresholds:** the tint uses the kernel's reported level (`kern.memorystatus_vm_pressure_level`), not recomputed thresholds. So hysteresis and the compressor-full trigger match the system exactly, and no RAM-size divisor logic was needed.

### Background: how the kernel picks normal/warning/critical
First worked out in session `e984b0fc-bf61-4c93-b331-a4b66b688721` (claude-history ref `ch_967e580a7eb7`, messages m21/m27/m41). Re-verified 2026-10-03 against the xnu source at `../xnu`.
- **A and C:** A = `AVAILABLE_NON_COMPRESSED_MEMORY` = active + inactive + free + speculative (`osfmk/vm/vm_page.h`). C = `VM_PAGE_COMPRESSOR_COUNT`.
- **The tests:** `VM_PRESSURE_*` predicates (`osfmk/vm/vm_pageout.c` ~10297-10362) test `A < k·(A+C)`, which is the same as `C/(A+C) > 1−k`. So C/(A+C) is exactly the kernel's metric.
- **Divisors:** chosen by `max_mem <= 3 GB` (11/20) vs larger (20/35) (`vm_compressor.c:1067-1077`).
- **Thresholds for over 3 GB:**
  - Normal→Warning above 50%
  - →Critical above ~65.7%
  - Critical→Warning below 60%
  - Warning→Normal below 40%
- **Second critical trigger:** critical also fires on `vm_compressor_low_on_space()`, when compressed pages or segments reach ≥98% of their limit (`vm_compressor.c:569`, `:903`, `:918`).

### Implementation pitfalls
- **A from `vm_statistics64`:** A = `free_count + active_count + inactive_count`. Don't add `speculative_count`, because `free_count` already includes it (`osfmk/kern/host.c` `vm_stats()`).
- **C from `vm_statistics64`:** C = `compressor_page_count`, which is assigned `VM_PAGE_COMPRESSOR_COUNT` (`host.c:861`). Don't use `total_uncompressed_pages_in_compressor`.

### Accepted limits (signed off 2026-10-03)
- **Divisors can't be read at runtime.** The `vm.compressor_*_threshold_divisor` sysctls exist only on DEVELOPMENT/DEBUG kernels (`bsd/kern/kern_sysctl.c:4559`). The 50%/~66% figures appear only in the text-token help and the notification default.
- **A reads slightly high.** `vm_statistics64.active_count` includes the per-CPU local queues, which the kernel's A leaves out.
- **The number can't show the compressor-full trigger.** The tint does, because it comes from the kernel level. Surfacing compressor fullness is optional and listed in `todo.md`.
