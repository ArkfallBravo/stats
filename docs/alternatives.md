# alternatives.md

Designs that were considered but not chosen. Read this before redesigning one of these pieces, or when a fix isn't working.

## RAM history chart colors: how picked colors are drawn (decided 2026-10-09)
- **Chosen:** a picked color is drawn as-is. Only the "Default" entry uses the OKHSL palette.
- **Rejected: equalize the picked hue.** The pick would supply only the hue, then be forced to the shared OKHSL saturation and lightness. Grays, white and black have no hue, so they'd need special-casing. The user preferred exact picks.
- **Rejected: an "Equalize chart colors (OKHSL)" settings toggle.** It would add a setting to switch between the two behaviours.
- **What would bring one back:** if picked colors clash in brightness (e.g. a pale yellow next to a dark red), the hue-only option keeps choice while restoring equal visual weight.

## RAM history chart palette scope (decided 2026-10-09)
- **Chosen:** OKHSL colors apply to the history charts only. Warning is yellow in the charts but stays orange (`RAMPressure.pressureColor()`) in the gauge, widgets and popup text.
- **Deferred:** applying OKHSL to every pressure display through `pressureColor()`. That would touch Kit and change the widget tints. It's worth revisiting if the yellow/orange mismatch bothers the user.

## Fork update mechanism (decided 2026-11-06)
- **Chosen:** the update button and notification run `scripts/sync-upstream.sh`, a local merge plus build (see the source-sync item in `docs/todo.md`).
- **Rejected for now: fork-published DMG releases.** A GitHub Action on the fork would merge upstream, build and publish a DMG, and `Updater` would point at `ArkfallBravo/stats`. It needs conflict handling in CI, a rework of `validateAppSignature`'s team-ID check for ad-hoc builds, and probably a workaround for macOS blocking quarantined ad-hoc apps (inferred, not tested). That's too much machinery for one user on one Mac. **Would come back if** the fork is installed on more than one machine, or a Developer ID becomes available.
- **Rejected: Silent mode only notifies** and never runs the script unattended. This was the safer default, but the user wanted hands-off syncing with a result notification.
- **Rejected test gates:** comparing the failing-test set before and after the merge (exact, but the suite runs twice), and `-skip-testing` the known failures (the list needs upkeep and hides the tests). The user chose fixing the two failing tests and keeping a strict gate. **Baseline comparison would come back if** upstream starts shipping tests that fail often on this machine.
- **Rejected: skip lint when swiftlint is missing.** The user chose installing it.

## RAM popup gauge: title and band thresholds (decided 2026-11-06; gauge removed 2026-11-24)
- **Chosen:** the title shows the kernel pressure level, and the critical band starts at 23/35 (~65.7%).
- **Rejected after trying it: the ratio percent as the title.** It hid the only pressure-level name in the popup and repeated the details row's number.
- **Rejected: a 2/3 (66.6%) critical band.** It sits about a point above the kernel's real threshold.
- **Would come back if** the gauge moves somewhere without the details row, so the number has no other home.

## RAM popup dashboard after upstream's redesign (decided 2026-11-24)
- **Chosen:** upstream's redesigned dashboard (usage pie plus Usage / Memory pressure / SWAP rows) with compression ratio as a 4th row. The fork's compression gauge and its band constants were deleted.
- **Rejected: compression gauge in place of upstream's pie** (keeping upstream's rows). Usage would only appear as text.
- **Rejected: keep the fork's old gauge + pie dashboard.** Most conflict surface on every future upstream sync.
- **Would come back if** a needle view of the ratio against the kernel thresholds is missed; the band math (warning 1/2, critical 23/35) is in the entry above and in git history (`e50ee0f0`).

## RAM pressure percentage source (decided 2026-11-24)
- **Chosen:** upstream's `Pressure.percentage: Int?` (checks the sysctl result and reads `Int32`). The fork's `RAM_Usage.pressurePercent` and its second `kern.memorystatus_level` read were dropped; consumers skip a tick when it's nil.
- **Rejected: keep both fields.** Two reads of the same sysctl, and two values that could disagree.
