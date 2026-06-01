# Testing Guide

This repo has both automated tests (XCTest) and a manual QA checklist. For a "production readiness" pass, run the automated suite first, then do the manual flows that cover UI + device behaviors.

## Automated Tests

### One-command Verify

```bash
./scripts/verify.sh
```

`verify.sh` will auto-pick an available iPhone Simulator (preferring a booted one).

The checked-in `InOffice.xcodeproj` is the source of truth for build settings.
If you change signing, bundle identifiers, device families, deployment targets, or release settings in Xcode, commit the resulting project file changes directly. `verify.sh` will use the existing project and will not regenerate it.

You can override the destination, scheme, and DerivedData path:

```bash
DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=latest" DERIVED_DATA_PATH=/tmp/InOfficeDD ./scripts/verify.sh
SCHEME=InOffice ./scripts/verify.sh
```

### What The Suite Covers

- Goal math and lock modes (`GoalManagerTests`)
- Dashboard aggregation (`DashboardMetricsTests`, `DashboardMetricsBoundaryTests`)
- Calendar month lookup correctness (`CalendarMonthSnapshotTests`)
- Batch edit persistence (`CalendarBatchEditManagerTests`)
- CSV parsing and round-trip behavior (`CSVImportExportTests`, `CSVEdgeCaseTests`, `CSVTimeZoneRoundTripTests`)
- Workplace storage + migration (`WorkplaceStoreTests`, `WorkplaceStoreMoreTests`)
- Large dataset sanity (`LargeDatasetRoundTripTests`, `PerformanceSanityTests`)

### Interpreting Results

- All tests must pass.
- Performance tests are trend indicators; treat major regressions seriously.

## Manual QA (Production Readiness)

Run these on at least:

- One iPhone on iOS 17+
- One iPad (to validate multitasking orientations + layout)
- At least one device with a different timezone than your usual environment (or change timezone temporarily)

### First-Run / Empty States

- Fresh install: Dashboard shows empty state and CTA routes to first entry flow.
- Log tab shows empty state and CTA opens today's status picker.
- Settings loads without data present.

### Logging / Calendar

- Log a day as each status (in office, remote, PTO, holiday), relaunch app, confirm persistence.
- Clear a day and confirm the record is removed.
- Batch mode: select multiple days, apply status, confirm all updated.
- Month navigation: swipe months back/forward, verify no lag spikes.

### Dashboard Correctness

- Switch period Week/Month/Year and verify counts match what you logged.
- Monthly breakdown: current month highlight is correct and totals reflect logs.

### CSV Backup / Restore

- Log multiple days including:
  - Notes with commas, quotes, and a multi-line note.
  - Notes beginning with `=`, `+`, `-`, `@` (formula-injection mitigation).
- Export CSV, delete all attendance data, then import the CSV.
- Verify:
  - Exact same calendar days (no Monday->Sunday shifts).
  - Status values and notes are preserved.
  - Re-importing the same file twice does not create duplicates.

### Location / Workplace / Geofence

- Permission flows:
  - Not determined -> request
  - Denied/restricted messaging
- Set workplace from search and from current location.
- Change radius and verify geofence updates.
- Offline behavior:
  - Place search shows a friendly error state.

### Data Deletion Behavior

- Delete All Data removes attendance only.
- Workplace settings (address/coordinate/radius) remain intact.

### General Stability

- Rotate device and verify layouts in all tabs (iPhone and iPad).
- Background/foreground the app, ensure no crashes.
