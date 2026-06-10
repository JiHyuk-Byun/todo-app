# Planner — a macOS menu‑bar to‑do, goals & scripture app

A lightweight macOS menu‑bar app for daily focus: check off today's tasks, track weekly/monthly/yearly goals and a long‑term vision, and memorize a daily scripture (말씀) — with streaks, stats and achievement badges to keep you motivated. Built in SwiftUI/AppKit.

## Features

### Menu‑bar dropdown
- Click the menu‑bar icon (or a global hotkey) to open a dropdown showing **today's tasks**, grouped into two categories, each with its own quick‑add field.
- Check items off with satisfying feedback: **haptics, a bouncing checkmark, and a small confetti burst** per check; a **full confetti** celebration when a day is 100% complete.
- A pinned **"오늘의 말씀" (today's scripture)** banner and a **pinned‑goals** strip stay at the top.
- **🔥 streak chips** (tasks / scripture) in the header.

### Scheduler window — `[일정 | 목표 | 말씀 | 통계]`
- **일정 (Schedule):** a custom month calendar (per‑day completion shown as `done/total` + a mini progress bar, fully‑done days highlighted green) on the left with recurring rules below; the selected day's tasks on the right with inline edit, drag‑to‑reorder, swipe / right‑click actions, and notes.
- **목표 (Goals):** weekly / monthly / yearly / vision checklists, each split into two categories, with drag‑to‑reorder. Periods roll over automatically.
- **말씀 (Scripture memorization):** register the day's verse, then recite it from memory — the original is hidden while you type; on submit it's an **exact match** (every character and space) to earn a credit, otherwise nothing. Includes a peek button, edit, and a history of past verses.
- **통계 (Stats):** task & scripture streaks, weekly completion rate, totals, and a grid of **achievement badges**.

### Recurring rules
Daily or weekly (by weekday) rules with a start date and optional end date, an editable form, a category, "next occurrence" preview, "skip just this day", and a delete confirmation.

### Hashtags
Type `#keyword` and it renders as a **colored pill** — each keyword gets its own consistent color. Pills render live in input fields (atomic delete) and in displayed items.

### Global hotkeys & settings
- System‑wide hotkeys (Carbon, no accessibility permission needed) to toggle the dropdown / scheduler. Defaults: **⌥⌘T** (dropdown), **⌥⌘S** (scheduler).
- A Settings window lets you record custom shortcuts (persisted in `UserDefaults`).

### Achievements
28 badges across tasks completed, perfect days, streaks, goals, and scripture (credits, streaks, mastery). Unlocking one shows a banner + confetti.

## Data
All data is stored locally as JSON at `~/Library/Application Support/Planner/data.json`. The model uses backward‑compatible decoders, so updating the app never breaks existing data.

## Build & run
Requires Xcode / the matching Swift toolchain (macOS 14+).

```bash
./build.sh        # compiles Sources/Planner/**.swift into Planner.app (direct swiftc) and embeds the icon
open ./Planner.app # a checklist icon appears in the menu bar (no Dock icon — it's an accessory app)
```

Quit from the dropdown's **종료** button. To keep it always running, move `Planner.app` to `/Applications` and add it to **System Settings → General → Login Items**.

> `build.sh` is used instead of `swift build` because the project ships as a hand‑assembled `.app` bundle (with `Info.plist` `LSUIElement` and an icon) rather than a SwiftPM executable. It compiles every `*.swift` under `Sources/Planner`.

## App icon
`icon/make_icon.swift` generates `icon/AppIcon.icns` (purple‑gradient rounded square + checkmark); `build.sh` copies it into the bundle.

## Project layout
```
Sources/Planner/
  PlannerApp.swift            # @main; Settings scene only — AppDelegate owns the
                              # NSStatusItem + NSPopover (dropdown), scheduler NSWindow, hotkeys
  HotKey/HotKeyManager.swift  # Carbon global hotkeys
  Models/
    Models.swift              # TodoItem, RecurringRule, GoalItem, Verse, TodoCategory, PlannerData
    Store.swift               # persistence, queries, metrics, badge evaluation (Store.shared)
    Achievements.swift        # badge catalog
    ShortcutSettings.swift    # hotkey settings (UserDefaults)
    UIState.swift             # shared UI state (selected scheduler tab)
  Views/
    MenuBarView.swift         # dropdown
    SchedulerView.swift       # scheduler window + tab switcher
    MonthCalendarView.swift   # custom month calendar
    GoalsView.swift           # goals tab
    VerseView.swift           # scripture tab + today's‑verse banner
    StatsView.swift           # stats dashboard + badges
    PinnedGoals.swift         # pinned goals bar + horizon chips
    Components.swift          # shared checklist row, quick‑add field
    HashtagText.swift         # hashtag pills (display + live editable field)
    Celebration.swift         # confetti, haptics, badge‑unlock overlay
    MenuBarIcon.swift         # code‑drawn menu‑bar icon
    ShortcutRecorder.swift / SettingsView.swift
```
