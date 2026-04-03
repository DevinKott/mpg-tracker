# CLAUDE.md — Project Rules

## Meta
- After every coding session that modifies the codebase, update this file to reflect the latest changes.

## Code Complexity
- Keep generated code LOW in complexity.
- Break complex functions into smaller, readable sub-functions rather than nesting logic.
- Avoid complex control flow (deeply nested conditionals, multiple early returns mixed with side effects, etc.).
- Keep each function roughly ≤ 60 lines.

## Variable Scope
- Keep variables as local as possible.
- Avoid globals; pass data explicitly through function parameters or use dependency injection.

## Correctness
- Check all function return values — do not silently discard errors or optionals.
- Validate parameters at function boundaries; document assumptions with assertions where appropriate.

## Performance
- Prioritize performance in data processing, rendering, and I/O paths.
- Prefer lazy evaluation and efficient data structures.
- Avoid unnecessary work on the main thread.

## Accessibility & Localization
- All user-facing strings must use `NSLocalizedString` or `String(localized:)`.
- UI elements must have accessibility labels, hints, and traits set appropriately.
- Support Dynamic Type and VoiceOver by default.

## Documentation
- Document all types, properties, and functions with clear, concise doc comments (`///`).
- Focus on *why* and *what* — skip comments that just restate the code.
- Keep comments short; if a comment needs more than 2 lines, consider whether the code itself can be made clearer first.

## Clean Code
- Follow Clean Code principles: meaningful names, single responsibility, DRY, and clear intent.
- Prefer clarity over cleverness.
- Delete dead code rather than commenting it out.

## Current State
- Steps 1–6 complete: data model (`FillUpEntry`), tab shell (`RootView`), entry form (`AddEntryView`), history screen (`HistoryView`, `EntryDetailView`), stats screen (`StatsView`), and import/export (`DataTransfer`, `SettingsView`) are implemented.
- `MPGCalculator` (caseless enum in `Utilities/`) is the single source of truth for MPG and price-per-gallon math; `FillUpEntry` calls it directly.
- Numeric text fields use `String` state + `.onChange` filtering (digits and `.` only) rather than `value:format:`, to preserve the empty-vs-zero distinction needed for Save button validation.
- `truckReportedMPG` is the SwiftData property name (schema-stable); all user-facing strings say "vehicle-reported MPG".
- History list uses `@Query(sort: \FillUpEntry.date, order: .reverse)` and `NavigationLink(value:)` + `.navigationDestination(for: FillUpEntry.self)`.
- `EntryDetailView` uses `@Bindable var entry: FillUpEntry`; editing is done via `EditEntrySheetView` (private struct in `EntryDetailView.swift`) which writes back to the bindable entry directly — SwiftData `didSet` observers handle derived value recalculation automatically.
- `StatsView` uses a private `StatsSnapshot` struct to compute all aggregate values once per render; charts use Swift Charts with `chronologicalEntries` (ascending date sort); chart export uses `ImageRenderer` + `UIActivityViewController` (private `ActivityViewController` bridging struct inside `StatsView.swift`); VoiceOver support via `AXChartDescriptorRepresentable` (`MPGChartDescriptor`, `FuelCostChartDescriptor`).
- `DataTransfer` (caseless enum in `Utilities/`) has pure static functions: `exportCSV`, `exportJSON`, `importCSV`. Uses a private `FillUpEntryDTO: Codable` for JSON; CSV uses ISO 8601 dates and RFC 4180 quoting. `importCSV` skips malformed rows silently.
- `SettingsView` (`Views/Settings/`) has a Data section (CSV export, JSON export, CSV import via `.fileImporter`) and an About stub. Export uses a temp-file + `UIActivityViewController` (private `ActivityViewController` in the same file). Import shows an alert on failure. `RootView` now uses `SettingsView` in the settings tab (placeholder text removed).
