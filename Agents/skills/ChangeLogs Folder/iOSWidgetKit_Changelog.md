# iOSWidgetKit Changelog

## 2026-08-29 — iOS WidgetKit Implementation (Phase W4)

### Changes
- Created `QuickNotesWidget` native WidgetKit app extension target in Swift/SwiftUI (`ios/QuickNotesWidget/QuickNotesWidget.swift`).
- Implemented `QuickNotesWidgetSnapshot` Codable data model mapping snake_case payload fields from `quicknotes_widget_snapshot` (`version`, `updated_at`, `date_day_name`, `date_formatted`, `pinned_notes_count`, `pending_tasks_count`, `overdue_tasks_count`, `has_active_session`).
- Implemented `QuickNotesTimelineProvider` reading from `UserDefaults(suiteName: "group.com.quicknotes.app")` with calendar-based midnight rollover policy (`Timeline(entries: [entry], policy: .after(startOfTomorrow))`) and safe error fallback.
- Designed `systemMedium` SwiftUI widget view (`QuickNotesWidgetEntryView`) displaying app branding, local day/date, stat pills for pinned notes and due today tasks, and signed-out state banner when `has_active_session == false`.
- Wired deep-link interactions with mandatory `?homeWidget=true` query parameter for `HomeWidgetPlugin` interception:
  - Root widget area ➔ `quicknotes://home?homeWidget=true`
  - + New Note button ➔ `quicknotes://note/new?homeWidget=true`
  - ☑ Checklist button ➔ `quicknotes://checklist/new?homeWidget=true`
- Configured App Group `group.com.quicknotes.app` in `Runner.entitlements` and `QuickNotesWidget.entitlements`.
- Registered `quicknotes://` URL scheme under `CFBundleURLTypes` in `ios/Runner/Info.plist`.
- Bumped `IPHONEOS_DEPLOYMENT_TARGET` to `14.0` in `ios/Runner.xcodeproj/project.pbxproj` and registered `QuickNotesWidget` target, build phases, and configurations.
- Maintained zero SQLite/provider access from widget extension (pure SwiftUI renderer).
