# MPGTracker — Implementation Plan

## Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **Charts:** Swift Charts (built-in, iOS 16+)
- **Minimum deployment target:** iOS 17

## File Structure (target end state)
```
MPGTracker/
├── MPGTrackerApp.swift         # App entry point, ModelContainer setup
├── Models/
│   └── FillUpEntry.swift       # SwiftData model
├── Views/
│   ├── RootView.swift          # TabView shell
│   ├── Entry/
│   │   └── AddEntryView.swift  # Fill-up entry form
│   ├── History/
│   │   ├── HistoryView.swift   # Scrollable list of entries
│   │   └── EntryDetailView.swift
│   ├── Stats/
│   │   └── StatsView.swift     # Summary stats + charts
│   └── Settings/
│       └── SettingsView.swift  # Settings + About
└── Utilities/
    ├── MPGCalculator.swift     # Pure math functions
    └── DataTransfer.swift      # CSV/JSON import & export
```

---

## Step 1 — Data Model & Persistence ✅

**Goal:** Define the `FillUpEntry` SwiftData model and wire it into the app container. Delete the boilerplate `Item.swift` and `ContentView.swift`.

**Files to create/modify:**
- Delete `Item.swift` (boilerplate)
- Delete `ContentView.swift` (boilerplate — replaced in Step 2)
- Create `Models/FillUpEntry.swift`
- Modify `MPGTrackerApp.swift`

**`FillUpEntry` fields:**

| Property | Type | Required | Notes |
|---|---|---|---|
| `id` | `UUID` | yes | Auto-generated |
| `date` | `Date` | yes | Auto-captured at entry creation |
| `milesDriven` | `Double` | yes | From vehicle's trip odometer |
| `gallonsPumped` | `Double` | yes | From the pump |
| `calculatedMPG` | `Double` | yes | Derived: `milesDriven / gallonsPumped` |
| `totalPricePaid` | `Double?` | no | Total cost at the pump |
| `pricePerGallon` | `Double?` | no | Derived from total/gallons, or manually entered |
| `truckReportedMPG` | `Double?` | no | What the vehicle's computer showed |
| `notes` | `String?` | no | Optional free-text note |

**`MPGTrackerApp.swift` changes:**
- Replace `Item.self` with `FillUpEntry.self` in the schema.
- Root view will temporarily be a placeholder `Text("MPGTracker")` until Step 2.

**Acceptance criteria:**
- App builds and runs with no boilerplate content.
- SwiftData container initializes with `FillUpEntry` schema without crashing.

---

## Step 2 — App Shell (Tab Navigation) ✅

**Goal:** Create the top-level `TabView` that hosts all major screens. Each tab shows a placeholder view for now.

**Files to create/modify:**
- Create `Views/RootView.swift`
- Modify `MPGTrackerApp.swift` to use `RootView` as the root

**Tabs:**

| Tab | Icon | Label |
|---|---|---|
| History | `list.bullet` | "History" |
| Add Entry | `plus.circle.fill` | "Add Entry" |
| Stats | `chart.line.uptrend.xyaxis` | "Stats" |
| Settings | `gearshape` | "Settings" |

**Notes:**
- The Add Entry tab should stand out visually (larger icon, accent color) since it is the primary action.
- Each tab body is a `NavigationStack` wrapping a placeholder `Text` view. Real views are swapped in during later steps.

**Acceptance criteria:**
- App launches to a tab bar with four tabs.
- Each tab is tappable and displays its placeholder.

---

## Step 3 — Entry Screen ✅

**Goal:** Build the fill-up entry form. This is the most-used screen — keep it fast and minimal.

**Files to create/modify:**
- Create `Views/Entry/AddEntryView.swift`
- Create `Utilities/MPGCalculator.swift`
- Wire `AddEntryView` into `RootView`

**Form fields:**

| Field | Control | Required |
|---|---|---|
| Miles driven | `TextField` (decimal pad) | yes |
| Gallons pumped | `TextField` (decimal pad) | yes |
| Total price paid | `TextField` (decimal pad) | no |
| Price per gallon | Display (auto-calc) or `TextField` if overriding | no |
| Vehicle-reported MPG | `TextField` (decimal pad) | no |
| Notes | `TextField` (default keyboard) | no |

**Behavior:**
- Calculated MPG and price per gallon update live as the user types.
- Price per gallon: show auto-calculated value by default; allow the user to tap to override manually.
- "Save" button is disabled until miles driven and gallons pumped are valid (non-zero, parseable doubles).
- On save: create a `FillUpEntry`, insert into `modelContext`, dismiss the form.
- Date is captured automatically as `Date()` at save time — not exposed to the user.

**`MPGCalculator.swift`** — pure functions, no SwiftData imports:
- `calculateMPG(miles: Double, gallons: Double) -> Double`
- `calculatePricePerGallon(totalPrice: Double, gallons: Double) -> Double`

**Acceptance criteria:**
- User can enter required fields and save a `FillUpEntry`.
- Optional fields are skippable.
- Calculated values update live.
- Save is blocked on invalid input.

---

## Step 4 — History Screen ✅

**Goal:** Display all saved fill-up entries in reverse chronological order.

**Files to create/modify:**
- Create `Views/History/HistoryView.swift`
- Create `Views/History/EntryDetailView.swift`
- Wire `HistoryView` into `RootView`

**`HistoryView`:**
- `@Query(sort: \FillUpEntry.date, order: .reverse)` for the list.
- Each row shows: date, calculated MPG, gallons pumped, and price per gallon (if available).
- Swipe-to-delete on rows.
- Tapping a row navigates to `EntryDetailView`.

**`EntryDetailView`:**
- Shows all fields for a single entry.
- Clearly labels which values are calculated vs. user-entered.
- Edit button to modify the entry (reuse the entry form in edit mode, or inline editing — keep it simple).
- Delete button.

**Acceptance criteria:**
- All saved entries appear in reverse date order.
- New entries added from the Entry tab appear immediately in the list.
- Swipe-to-delete and detail navigation both work.

---

## Step 5 — Stats Screen

**Goal:** Show summary statistics and charts derived from all saved entries.

**Files to create/modify:**
- Create `Views/Stats/StatsView.swift`
- Wire `StatsView` into `RootView`

**Summary statistics (top of screen):**
- Average MPG (all-time)
- Best session MPG
- Worst session MPG
- Total miles tracked
- Total gallons pumped
- Total fuel cost (if price data available)
- Number of fill-up sessions

**Charts (use Swift Charts):**
- MPG over time (line chart, x = date, y = calculated MPG).
- Optional overlay: vehicle-reported MPG on the same chart (only shown if any entries have that value).
- Fuel cost per gallon over time (line chart, only shown if price data available).

**Chart image export:**
- Each chart has a share button (`.toolbar` or icon below chart).
- Use `ImageRenderer` to render the chart view to a `UIImage`, then present a `ShareLink` or `UIActivityViewController`.

**Notes:**
- If fewer than 2 entries exist, show a prompt: "Add more fill-ups to see trends."
- Handle missing optional data gracefully — don't crash or show broken charts.

**Acceptance criteria:**
- Summary stats are accurate against saved data.
- Charts render correctly with 2+ entries.
- Chart share export produces a shareable image.

---

## Step 6 — Import & Export

**Goal:** Allow the user to export all data as CSV or JSON, import from CSV, and export chart images (chart image export is handled in Step 5).

**Files to create/modify:**
- Create `Utilities/DataTransfer.swift`
- Add Import/Export controls to `SettingsView` (created in Step 7, but stub the hooks here)

**`DataTransfer.swift`:**

Export functions:
- `exportCSV(entries: [FillUpEntry]) -> String` — serialize all entries to CSV.
- `exportJSON(entries: [FillUpEntry]) -> Data` — serialize all entries to JSON.

Import functions:
- `importCSV(_ csvString: String) -> [FillUpEntry]` — parse CSV rows into model objects. Skip malformed rows, don't crash.

CSV column order:
```
date, milesDriven, gallonsPumped, calculatedMPG, totalPricePaid, pricePerGallon, truckReportedMPG, notes
```

**UI (in Settings):**
- "Export as CSV" — generates file, presents share sheet.
- "Export as JSON" — generates file, presents share sheet.
- "Import from CSV" — presents file picker (`fileImporter`), parses, inserts new entries (no duplicates check needed for v1).

**Acceptance criteria:**
- CSV export contains all entries with correct columns.
- JSON export is valid and contains all entries.
- CSV import correctly parses a previously exported file back into entries.

---

## Step 7 — Settings & About

**Goal:** Build the Settings screen with import/export controls and an About section.

**Files to create/modify:**
- Create `Views/Settings/SettingsView.swift`
- Wire `SettingsView` into `RootView`

**Sections:**

**Units**
- Toggle between miles (MPG) and kilometers (L/100km or km/L — decide at implementation time).
- Preference stored in `UserDefaults`. All distance/efficiency labels and calculated values across Entry, History, and Stats screens must respect this setting.
- CSV/JSON export should include a column/field indicating the unit in use, or always export in a canonical unit (decide at implementation time).

**Data**
- Export as CSV
- Export as JSON
- Import from CSV

**About**
- App name: MPGTracker
- Version number (read from `Bundle.main`)
- Brief purpose: "A simple, private tool for tracking real-world fuel efficiency."
- Developer credit: "Made by Devin Kott"
- A short note on privacy: "No tracking. No ads. No subscriptions. Your data never leaves your device."

**Notes:**
- The About section should be clean and readable — not a wall of legal text.
- No links, no external calls, no third-party frameworks on this screen.

**Acceptance criteria:**
- Settings screen loads with Data and About sections.
- All import/export actions work end-to-end.
- Version number reflects the actual app bundle version.

---

## Implementation Order Summary

| Step | Description | Depends On |
|---|---|---|
| 1 | Data model & persistence | nothing |
| 2 | App shell (tab navigation) | Step 1 |
| 3 | Entry screen | Steps 1–2 |
| 4 | History screen | Steps 1–3 |
| 5 | Stats screen + chart export | Steps 1–4 |
| 6 | Import & export | Steps 1–2 |
| 7 | Settings & About | Steps 1–2, 6 |
