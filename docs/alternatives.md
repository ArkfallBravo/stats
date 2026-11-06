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
