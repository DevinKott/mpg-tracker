# MPGTracker — Project Overview

## Purpose

MPGTracker is a personal iOS app for tracking real-world fuel efficiency across fill-up sessions. The goal is to replace manual note-taking at the gas pump with a clean, purpose-built tool that surfaces useful insights over time.

---

## Core Workflow

Each fill-up session follows a simple loop:

1. Drive until the next fill-up.
2. At the pump, note the miles driven since the last reset (from the vehicle's trip odometer).
3. Note the exact gallons pumped.
4. Enter both into the app — it calculates MPG automatically.
5. Reset the trip odometer. Repeat.

---

## Data Captured Per Fill-Up

| Field | Source | Notes |
|---|---|---|
| Miles driven | User input | Read from vehicle's trip odometer |
| Gallons pumped | User input | Read from the pump |
| MPG (calculated) | App-derived | `miles ÷ gallons` |
| Total price paid | User input (optional) | Total cost at the pump |
| Price per gallon | App-derived | Calculated from total price ÷ gallons |
| Vehicle-reported MPG | User input (optional) | What the vehicle's computer displayed — for comparison |
| Notes | User input (optional) | Free-text note about the fill-up |
| Date | Auto-captured | Timestamp of the entry |

---

## Features

### Entry
- Fast, minimal input screen optimized for use at a gas pump.
- Required fields: miles driven (max 1,000) and gallons pumped (max 100). Out-of-range values show an inline red error and block saving.
- After the user touches a required field and leaves it empty, a grey "Required" hint appears beneath it (dirty-state inline validation). Hints are grey; range errors are red.
- Optional fields: total price paid, vehicle-reported MPG.
- App auto-calculates: MPG and price per gallon (from total price ÷ gallons).

### History
- Scrollable log of all past fill-up sessions.
- Display calculated MPG, date, gallons, and cost per entry.

### Stats & Trends
- Summary statistics: average MPG, best/worst session, total miles tracked, total fuel cost.
- Simple charts showing MPG over time.
- Optional overlay: calculated MPG vs. vehicle-reported MPG for comparison.
- Fuel cost trends over time.

### Confirmation Feedback
- Transient success banners appear at the top of the screen after user actions (e.g., saving a fill-up).
- Style: green gradient capsule, white medium-weight text, slides in from the top and fades out after ~1.5 seconds.
- All new confirmation banners must follow this pattern for visual consistency.
- Errors and outcomes with meaningful detail (e.g., import counts, export failures) use a standard system alert with an OK button — not a banner. Title format: "X Error" / "X Successful". Message: short plain-English sentence.
- **Rule of thumb:** banner for simple "it worked", alert for errors or results that need explanation.

### Settings & About
- Settings page with an About section.
- About content: app name, brief purpose statement, and a note crediting the developer.
- No unnecessary settings — only expose controls that are genuinely useful.

### Import & Export
- Export data to CSV or JSON for use in other tools.
- Import from CSV to restore or migrate data.
- Export charts as PNG/JPEG images the user can share from their own device.

---

## Design Principles

- **Speed at the pump.** Entry should be fast — the user is standing outside at a gas station. Minimize taps and typing.
- **Clarity over features.** Show the most useful numbers prominently. Don't clutter the UI.
- **Accurate math.** The app's derived values (MPG, cost per gallon) must be precise and clearly labeled as calculated.
- **Personal, not social.** This is a private tracking tool. No accounts, no cloud sync, no tracking, no analytics. User data stays on-device and is never transmitted anywhere.
- **No monetization traps.** No ads. No subscriptions. No paywalled features. The app is a one-time tool that does its job and gets out of the way.
- **Sharing is opt-in and user-initiated.** The only sharing surface is the user explicitly exporting a chart image from their own device. Nothing is shared automatically or silently.
