# Apply Progress: per-screen-overlay-coordination

- Foundation commit: `752f07e`
- Architecture: one global coordinator plus fixed per-screen `Variants` instances for Launcher, Dashboard, and PowerMenu.
- Migration: legacy `ShellState` overlay writers removed; widget and IPC consumers use `OverlayCoordinator`.
- Budget: 329 changed lines against `752f07e`, below the 400-line limit.

## TDD Cycle Evidence

| Cycle | Evidence | Result |
|---|---|---|
| RED | `qmltestrunner` before `Services/OverlayState.js` existed | 0 passed, 1 failed: reducer script unavailable |
| GREEN | `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/overlay-state -import . -o -,txt` | 15 passed, 0 failed |
| TRIANGULATE | `PYTHONDONTWRITEBYTECODE=1 python -m unittest tests.test_overlay_foundation tests.test_selene_corrections -v` | 19 tests, OK; covers registration, readonly state, migration, Variants, and publication order |
| REFACTOR | Fixed per-screen materialization replaced unreliable cross-output PanelWindow retargeting; duplicated contracts and progress transcripts were compacted | Deterministic suites remained green |

## Runtime Evidence

| Task | Result |
|---|---|
| Widget origins | Human-assisted PASS for launcher/dashboard/power; MediaWidget runtime N/A without active MPRIS, structural propagation PASS |
| IPC focus and target capture | PASS |
| Global overlay replacement/exclusivity | PASS |
| Explicit fullscreen opening | UNAVAILABLE, no current fullscreen DP-2 client; deterministic policy test PASS |
| Hotplug close/no migration | PASS using temporary `HEADLESS-1`; physical monitors untouched |
| Cleanup and compatibility | PASS; temporary output/artifacts removed, dunst untouched, one Selene instance healthy |

No functional FAIL findings remain. Fullscreen and exact cursor restoration are recorded as unavailable rather than fabricated passes.
