# TOCK Architecture

TOCK is currently a local-first SwiftUI macOS app built with Swift Package Manager.

## Core Flow

```text
FocusView / TasksView / StatisticsView
        |
        v
     AppState
        |
        +-- TimerEngine
        +-- PersistenceStore
        +-- NotificationManager
        +-- StatusBarController
```

## Responsibilities

- `AppState` is the single source of truth for UI state, tasks, categories, timer state, settings, and statistics filters.
- `TimerEngine` is pure Swift timer logic. It advances timer state and emits deterministic events such as `focusFinished` and `breakFinished`.
- `PersistenceStore` saves and loads local JSON state in Application Support.
- `StatusBarController` owns the macOS menu bar item and mirrors `AppState`.
- `NotificationManager` owns system notification categories and actions.
- SwiftUI views render state and call AppState actions.

## Persistence

The app stores a single JSON snapshot containing:

- user preferences
- focus/break durations
- tasks and categories
- focus session history
- statistics filters
- active day identifier for daily rollover

Daily task durations reset when the stored day changes, but focus session history remains intact.

## Timer Rules

Timer behavior is intentionally centralized in `TimerEngine`:

- Countdown focus tracks all focused seconds.
- When countdown reaches zero, overflow seconds become overtime.
- Count-up focus stays open-ended until the user chooses rest or end.
- Break time does not count as focused time.
- Break completion waits for the user to explicitly start the next focus session.

Run deterministic timer checks with:

```sh
scripts/check_timer_engine.sh
```

## Packaging

`scripts/package_app.sh` builds the SwiftPM executable and assembles `dist/TOCK.app`.

The app icon is generated locally from `scripts/generate_icon.py` into `TOCK.icns`, so packaging does not depend on Xcode asset catalogs.

Run the full local verification with:

```sh
scripts/smoke_test.sh
```
