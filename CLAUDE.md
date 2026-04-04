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

## UI Patterns

### Transient Confirmation Banner (Toast)
When an action succeeds and needs brief confirmation feedback, use this established pattern (first introduced in `AddEntryView`):

- **Placement:** `.overlay(alignment: .top)` on the view's root container
- **Style:** green gradient `Capsule` with white `.subheadline.weight(.medium)` text; `.padding(.horizontal, 16)`, `.padding(.vertical, 10)`, `.padding(.top, 8)`
- **Animation:** wrap show/hide in `withAnimation`; use `.transition(.move(edge: .top).combined(with: .opacity))`
- **Duration:** 1.5 seconds — `Task.sleep(nanoseconds: 1_500_000_000)`
- **State:** a `@State private var didSave: Bool = false` flag on the presenting view; a `showSaveConfirmation()` helper sets it `true`, spawns the reset `Task`
- **Accessibility:** set `.accessibilityLabel` on the banner `Text` (e.g., `"Fill-up saved successfully"`)

Always match this pattern exactly when adding new confirmation banners so the feedback style stays consistent across the app.

### Error & Outcome Alerts
For errors or operations with a meaningful outcome (e.g., import/export with counts or error detail), use a standard SwiftUI `.alert` — not a banner. Pattern established in `SettingsView`:

- **State:** three vars — `@State private var showAlert = false`, `alertTitle = ""`, `alertMessage = ""`
- **Modifier:** `.alert(alertTitle, isPresented: $showAlert) { Button(String(localized: "OK"), role: .cancel) {} } message: { Text(alertMessage) }`
- **Usage:** set `alertTitle` and `alertMessage`, then set `showAlert = true` — no helper function needed
- **Title format:** `"X Error"` for failures, `"X Successful"` for success outcomes with detail
- **Message format:** short plain-English sentence ending with a period (e.g., `"Export failed. Please try again."`)

**When to use alert vs. banner:**
- Banner (green capsule): simple "it worked" confirmation for quick actions (saving an entry, clean import with 0 skipped rows)
- Alert: errors, or successes that carry meaningful detail (e.g., partial import with skipped-row count)

### Inline Field Validation (Dirty-State)
For required fields where the Save button may be disabled, show an inline "Required" hint beneath the field after the user has touched and left it empty. Do not show hints on initial render — only after the field has lost focus at least once (dirty state). Pattern established in `AddEntryView` and `EditEntrySheetView`.

- **Trigger:** Only after the field has lost focus at least once while empty
- **State:** `@FocusState private var focusedField: FormField?` (private enum `FormField` with a case per required field) + per-field `@State private var xFieldTouched = false`
- **Dirty tracking:** `.onChange(of: focusedField) { oldValue, _ in ... }` — set a field's touched flag when `oldValue == .<thatField>`; attach the modifier to the `Form` or `NavigationStack`
- **Style:** `.font(.caption)` + `.foregroundStyle(.secondary)` (grey — passive hint, not an error)
- **Distinction:** Required hints are grey (`.secondary`); range/format errors are red. Use `else if` so they never show simultaneously for the same field
- **Accessibility:** Set `.accessibilityLabel` on the hint Text (e.g., `"Miles driven is required"`)
- **Reset:** Clear all touched flags on successful save (or on form reset)
- **Placement:** Immediately below the field, inside a `VStack(alignment: .leading, spacing: 4)` shared with range-error captions
- **Form row vs. inline caption:** In a SwiftUI `Form`/`List`, a conditional view appears as a separate row — it animates as a *row insertion*, which `List` manages outside the normal animation system. Wrapping the field and its caption in a `VStack` makes them one Form row; the caption is then a layout child, not a separate row, so `.transition` and `.animation` work as expected. Apply `.animation(.easeInOut(duration: 0.2), value: <condition>)` to the `VStack`, not the `Section`.

## Clean Code
- Follow Clean Code principles: meaningful names, single responsibility, DRY, and clear intent.
- Prefer clarity over cleverness.
- Delete dead code rather than commenting it out.

## Current State
- Steps 1–6 complete: data model (`FillUpEntry`), tab shell (`RootView`), entry form (`AddEntryView`), history screen (`HistoryView`, `EntryDetailView`), stats screen (`StatsView`), and import/export (`DataTransfer`, `SettingsView`) are implemented.
- `MPGCalculator` (caseless enum in `Utilities/`) is the single source of truth for MPG and price-per-gallon math; `FillUpEntry` calls it directly.
- Price-per-gallon in `AddEntryView` is always auto-calculated from `totalPrice ÷ gallons` — there is no manual override. The PPG row is read-only; it shows "—" until both total price and gallons are entered. `EditEntrySheetView` follows the same pattern in `applyChanges()`.
- Numeric text fields use `String` state + `.onChange` filtering (digits and `.` only) rather than `value:format:`, to preserve the empty-vs-zero distinction needed for Save button validation.
- Range validation for `milesDriven` (max 1,000) and `gallonsPumped` (max 100) is enforced in both the form layer (`AddEntryView`, `EditEntrySheetView`) and the import layer (`DataTransfer.parseRow`). The form layer shows inline red captions and disables the Save button via `milesExceedsMax`/`gallonsExceedsMax`; the import layer silently counts out-of-range rows as skipped. `FillUpEntry` does **not** clamp values. Empty required fields show a grey "Required" hint after the field has been touched (dirty-state pattern); both forms use `@FocusState` + per-field touched flags for this.
- `truckReportedMPG` is the SwiftData property name (schema-stable); all user-facing strings say "vehicle-reported MPG".
- History list uses `@Query(sort: \FillUpEntry.date, order: .reverse)` and `NavigationLink(value:)` + `.navigationDestination(for: FillUpEntry.self)`.
- `EntryDetailView` uses `@Bindable var entry: FillUpEntry`; editing is done via `EditEntrySheetView` (private struct in `EntryDetailView.swift`) which writes back to the bindable entry directly — `applyChanges()` explicitly recalculates `calculatedMPG` and `pricePerGallon` because SwiftData `@Model` accessors do not reliably trigger `didSet` observers when properties are mutated externally. After a successful save, `EditEntrySheetView` calls an `onSaved: () -> Void` callback before dismissing; `EntryDetailView` uses this to show a "Changes saved" banner via `didSaveEdit` / `showSaveConfirmation()` (same pattern as `AddEntryView`).
- `HistoryView` supports swipe-to-delete (`onDelete`) and multi-select bulk delete via an Edit/Done toolbar toggle; `FillUpEntryRow` is a private struct in the same file that renders each list row.
- `FillUpEntry` has an optional `notes: String?` property; it is displayed in `EntryDetailView` and editable in `EditEntrySheetView`.
- `StatsView` uses a private `StatsSnapshot` struct to compute all aggregate values once per render; charts use Swift Charts with `chronologicalEntries` (ascending date sort); chart export uses `ImageRenderer` + `UIActivityViewController` (private `ActivityViewController` bridging struct inside `StatsView.swift`); VoiceOver support via `AXChartDescriptorRepresentable` (`MPGChartDescriptor`, `FuelCostChartDescriptor`).
- `DataTransfer` (caseless enum in `Utilities/`) has pure static functions: `exportCSV`, `exportJSON`, `importCSV`. Uses a private `FillUpEntryDTO: Codable` for JSON; CSV uses ISO 8601 dates and RFC 4180 quoting. `importCSV` now `throws` (`DataTransfer.ImportError.missingRequiredColumns`) — if the header row is missing any of `date`, `milesDriven`, or `gallonsPumped`, the entire import is rejected before any rows are processed. Column lookup is name-based (header row → `[String: Int]` map), not positional, so reordered columns are handled correctly. Malformed data rows and out-of-range values (miles > 1,000 or gallons > 100) are counted as skipped, not silently dropped.
- `SettingsView` (`Views/Settings/`) has a Data section (CSV export only, CSV import via `.fileImporter`) and a completed About section (app name + version from `Bundle.main`, purpose, privacy note, developer credit). JSON export code (`exportJSON`, `writeTempFile`) is kept in the file but not surfaced in the UI. Export uses a temp-file + `UIActivityViewController` (private `ActivityViewController` in the same file). Export failure shows an alert ("Export Error" / "Export failed. Please try again."). Import feedback: clean import (0 skipped) shows a green banner; partial import shows an alert with both imported and skipped counts; all import errors show an alert. `RootView` uses `SettingsView` in the settings tab.
- Units toggle (miles/km) is a planned TODO — not yet implemented.
