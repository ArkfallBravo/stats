# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Stats is a native macOS menu bar system monitor (Swift/AppKit/Cocoa), Xcode-project-based (`Stats.xcodeproj`, no SPM/CocoaPods package manifest). This is a personal fork of [exelban/stats](https://github.com/exelban/stats); `master` tracks upstream, and custom work lives on `my-changes` (merge `master` into `my-changes` to pick up upstream — don't rebase, see branch protection note below).

## Commands

### Build
```bash
xcodebuild -scheme Stats -destination 'platform=macOS' -configuration Debug build
```
CI builds Release with code signing disabled: `xcodebuild -scheme Stats -destination 'platform=macOS' -configuration Release archive CODE_SIGNING_ALLOWED=NO` (`.github/workflows/build.yaml`).

Each module and `Kit` also has its own scheme (`xcodebuild -list -project Stats.xcodeproj` to see all: `Stats`, `Kit`, `CPU`, `GPU`, `RAM`, `Disk`, `Net`, `Battery`, `Sensors`, `Bluetooth`, `Clock`, `Remote`, `LaunchAtLogin`, `SMC`, `Helper`, `WidgetsExtension`).

### Test
There's no standalone `Tests` scheme — the test target (`Tests.xctest`) is wired into the `Stats` scheme's test action:
```bash
xcodebuild test -scheme Stats -destination 'platform=macOS'
```
Run a single test with `-only-testing:Tests/<ClassName>/<testMethodName>`. Tests currently live in `Tests/Kit.swift` (pure-logic tests against `Kit`, e.g. version comparison, unit formatting) and `Tests/RAM.swift`.

### Lint
```bash
swiftlint
```
Rules are in `.swiftlint.yml` at the repo root; CI runs this on every push/PR touching `*.swift` (`.github/workflows/linter.yaml`). Several rules are deliberately disabled (`force_cast`, `type_name`, `cyclomatic_complexity`, etc.) — don't re-enable them incidentally by "fixing" unrelated code.

### i18n check
`.strings` files are validated by `python3 Kit/scripts/i18n.py` (CI: `.github/workflows/i18n.yaml`) — checks translation key consistency across locales.

### Release packaging (Makefile)
The `Makefile` targets (`archive`, `notarize`, `sign`, `verify`, `prepare-dmg`, `prepare-dSYM`) drive the full notarized-release pipeline and assume Apple Developer signing/notarization credentials (`AC_PASSWORD` keychain profile) — not relevant for local dev builds. `make smc` builds the standalone SMC helper CLI in `SMC/`; `make leveldb` builds the vendored LevelDB static lib used by `Kit/lldb`.

## Architecture

### Module system
Each system-monitoring feature (CPU, GPU, RAM, Disk, Net, Battery, Sensors, Bluetooth, Clock, Remote) is its own Xcode framework target under `Modules/<Name>/`, statically linked into the `Stats` app. `Kit` is the shared framework all modules depend on; it has no reverse dependency on any module.

A module target follows a fixed file layout:
- `main.swift` — the `class X: Module` subclass, plus any `Codable`/`RemoteType` data structs for that module's readings
- `readers.swift` — one or more `Reader_p`/`Reader<T>` subclasses that poll system data on an interval
- `config.plist` / `Info.plist` — declares the module's name, icon symbol, available widgets, and settings schema; `module_c` (`Kit/module/module.swift`) parses this at init
- `widget.swift`, `popup.swift`, `portal.swift`, `settings.swift`, `notifications.swift`, `preview.swift` — the module's menu bar widget view, popup (dropdown) view, "combined view" portal row, settings pane, notification thresholds UI, and window preview, respectively

`Kit/module/` holds the base classes every module builds on: `Module` (lifecycle: mount/enable/disable/terminate, notification-driven popup/window/widget toggling), `Reader<T>` (interval-based polling with pause/lock semantics for popup vs. background state, backed by `DB` for history), `Portal_p`/`PortalWrapper` (rows in the combined menu bar view), `widget.swift`/`window.swift` (menu bar rendering).

`Stats/AppDelegate.swift` imports every module framework and instantiates them into a single `var modules: [Module]` array — this is the entire module registry; there's no dynamic/plugin-bundle loading.

### Shared infrastructure (`Kit/plugins/`)
- `Store` — wraps `UserDefaults` with an in-memory cache for settings/state persistence, keyed per-module (e.g. `"<ModuleName>_state"`)
- `DB` — LevelDB-backed (`Kit/lldb`) time-series storage for reader history
- `SystemKit` — hardware/platform identification (Intel vs. Apple Silicon variants)
- `SystemStats`, `Updater`, `Reachability`, `Repeater`, `Charts`, `Logger` — telemetry-free stats reporting, update checking (against `api.mac-stats.com`, falling back to GitHub releases), network reachability, interval repeating, chart rendering primitives, and logging

`Kit/Widgets/` holds shared SwiftUI/AppKit chart & widget-rendering components (line/bar/pie charts, tachometer, etc.) used across modules' `widget.swift` files.

### Other targets
- `SMC/` — a privileged helper (`eu.exelban.Stats.SMC.Helper`) installed via `SMJobBless` for fan control and sensor access that requires elevated privileges; also buildable standalone as a CLI (`make smc`)
- `LaunchAtLogin/` — small helper target for the login-item launcher
- `Widgets/` (root) — the `WidgetsExtension` target (macOS desktop widgets), separate from `Kit/Widgets/` (in-app chart components) — don't confuse the two
- `Stats/Views/` — app-level UI: settings window, combined menu bar view, setup/update/support windows

### Data flow
Reader → (interval tick) → `read()` populates `value` → `callback()` fans out to: the module's widget/popup views (live UI), `SystemStats` (telemetry-free local stats), and `DB` (history, throttled). Widgets and popups pull from the reader's `value`; nothing pushes into a global app-state store.
