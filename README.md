# TOCK

TOCK is a minimal macOS Pomodoro app focused on fast, calm, native-feeling focus sessions.

## Current Status

This is an early local-first MVP. It already supports:

- Focus timer with countdown and count-up modes
- Editable default focus and break duration
- Overtime after countdown reaches zero
- Manual transition from focus to break
- Menu bar timer with hide/show option
- System notification toggle
- Task and category management
- Category colors used across tasks and statistics
- Local persistence in Application Support
- Daily rollover for "today" task duration
- Statistics for day, week, month, and year

## Run Locally

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift run --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

## Build

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift build --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

## Package as a Local macOS App

```sh
scripts/package_app.sh
open dist/TOCK.app
```

For a release build:

```sh
scripts/package_app.sh release
open dist/TOCK.app
```

The package script creates a local app bundle at `dist/TOCK.app`.

## Smoke Test

```sh
scripts/smoke_test.sh
```

This builds and packages the app, then checks that `dist/TOCK.app` has the expected bundle structure.

To run only the deterministic timer-rule checks:

```sh
scripts/check_timer_engine.sh
```

The GitHub Actions workflow in `.github/workflows/smoke.yml` runs the same smoke test on macOS.

## Product Notes

The product direction is documented in [PRD.md](PRD.md). Wireframes and visual decisions are in [WIREFRAMES.md](WIREFRAMES.md).

The implementation structure is documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Next Priorities

- Generate a production `.icns` app icon from `Assets/TOCK.svg`
- Add a signed/notarized release workflow when the app is ready to share outside local use
