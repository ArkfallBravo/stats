# plan.md

## In flight: compression ratio for the RAM module

**Status (2026-10-04):** implemented in the working tree on `my-changes`, uncommitted and unstaged. Waiting on the user's manual test in the running app; commit only after they confirm. The upstream merge was committed separately as `30ef4934`, so the feature diff sits cleanly on top of it.

What's verified:
- The RAM scheme compiles. It builds `Kit` too and doesn't touch `/Applications`.
- `testUsageReader_compressionPercent` and `testRAMPressure_textColor` passed (2026-10-03).

What hasn't run yet:
- `testRAMPressure_alertColor`, added later. It compiles but hasn't been run.
- swiftlint. It isn't installed locally.
- The full `Stats` scheme build after the latest edits.
- `testProcessReader_parsePSLine`, added in the 2026-10-04 /simplify pass. It hasn't been compiled, because building the test target means a `Stats`-scheme build, which reinstalls the app.

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
