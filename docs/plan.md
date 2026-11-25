# plan.md

## In flight: upstreaming the CMPR widget to exelban/stats

**Status (2026-11-06):** proposal posted on upstream issue #318 (https://github.com/exelban/stats/issues/318#issuecomment-6693274518). We're waiting for exelban to answer before opening a PR.

- **Why ask first:** exelban closed four memory-pressure PRs (#3239, #3068, #3134, #3020). On #3134 he refused multi-feature PRs, said pressure should be a colorize option rather than a value, and doubted that `memorystatus_level` reads correctly on Intel. Upstream's feature-request template forbids new issues on topics already covered, so the proposal went to #318, where he once asked for an algorithm to compute pressure.
- **PR branch:** `feat/ram-compression-ratio-widget`, in a worktree at `~/stats-pr/cmpr` (outside iCloud), cut from `upstream/master`. It's uncommitted and not pushed. It's a hand-port in upstream style, not a cherry-pick:
  - `LabeledPercentWidget` is folded into `CompressionRatioWidget`.
  - The popup gets one row (`22*7`).
  - The notification Store keys match the fork's (`compressionPercent`).
  - Release build and the new tests pass.
- **Draft PR body:** `~/stats-pr/cmpr-pr-body.md`. Planned title: `feat: added compression ratio widget to RAM`.
- **Next:** reshape the branch to match exelban's answer (a widget, or a colorize/fill source for the existing widgets). Probably drop the portal row and the notification so the PR is smaller. The user has to test the branch build before it's committed.
- **Merge-back note:** once upstream lands it, merging master into `my-changes` will conflict where the fork's `MemoryPressureWidget` subclasses `LabeledPercentWidget`.

## Archived initiatives
- RAM compression ratio, CMPR widget, and compression/combined history charts with OKHSL: `docs/archive/ram-compression-and-history-charts.md`
