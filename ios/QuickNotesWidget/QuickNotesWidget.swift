import WidgetKit
import SwiftUI

// MARK: - Snapshot Codable Model

/// Sanitized widget snapshot payload received from Flutter via App Group UserDefaults.
struct QuickNotesWidgetSnapshot: Codable {
    let version: Int?
    let updatedAt: String?
    let dateDayName: String?
    let dateFormatted: String?
    let pinnedNotesCount: Int?
    let pendingTasksCount: Int?
    let overdueTasksCount: Int?
    let hasActiveSession: Bool?

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case dateDayName = "date_day_name"
        case dateFormatted = "date_formatted"
        case pinnedNotesCount = "pinned_notes_count"
        case pendingTasksCount = "pending_tasks_count"
        case overdueTasksCount = "overdue_tasks_count"
        case hasActiveSession = "has_active_session"
    }

    /// Deterministic fallback values when snapshot is missing or malformed.
    static var fallback: QuickNotesWidgetSnapshot {
        let now = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"

        return QuickNotesWidgetSnapshot(
            version: 1,
            updatedAt: ISO8601DateFormatter().string(from: now),
            dateDayName: dayFormatter.string(from: now),
            dateFormatted: dateFormatter.string(from: now),
            pinnedNotesCount: 0,
            pendingTasksCount: 0,
            overdueTasksCount: 0,
            hasActiveSession: false
        )
    }
}

// MARK: - Timeline Entry

struct QuickNotesWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: QuickNotesWidgetSnapshot
}

// MARK: - Timeline Provider

struct QuickNotesTimelineProvider: TimelineProvider {
    private let appGroupId = "group.com.quicknotes.app"
    private let snapshotKey = "quicknotes_widget_snapshot"

    private func loadSnapshot() -> QuickNotesWidgetSnapshot {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let jsonString = userDefaults.string(forKey: snapshotKey),
              let data = jsonString.data(using: .utf8) else {
            return .fallback
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(QuickNotesWidgetSnapshot.self, data: data)
        } catch {
            return .fallback
        }
    }

    func placeholder(in context: Context) -> QuickNotesWidgetEntry {
        QuickNotesWidgetEntry(date: Date(), snapshot: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickNotesWidgetEntry) -> Void) {
        let entry = QuickNotesWidgetEntry(date: Date(), snapshot: loadSnapshot())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickNotesWidgetEntry>) -> Void) {
        let currentSnapshot = loadSnapshot()
        let currentDate = Date()
        let entry = QuickNotesWidgetEntry(date: currentDate, snapshot: currentSnapshot)

        // Calculate next calendar midnight for automatic day/date rollover
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)
        let timeline = Timeline(entries: [entry], policy: .after(startOfTomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Entry View

struct QuickNotesWidgetEntryView: View {
    var entry: QuickNotesTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let snapshot = entry.snapshot
        let hasSession = snapshot.hasActiveSession ?? false

        VStack(alignment: .leading, spacing: 10) {
            // Header Row: App Name + Date
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("QUICK NOTES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.51, green: 0.55, blue: 0.97)) // Indigo Accent
                        .tracking(0.8)
                    Text(snapshot.dateDayName ?? "Today")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(snapshot.dateFormatted ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.82))
            }

            // Metrics or Signed-out Banner
            if hasSession {
                HStack(spacing: 8) {
                    // Pinned Notes Pill
                    HStack(spacing: 4) {
                        Text("\(snapshot.pinnedNotesCount ?? 0)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.51, green: 0.55, blue: 0.97))
                        Text("Pinned")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.61))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.13, green: 0.13, blue: 0.17))
                    .cornerRadius(10)

                    // Due Today Tasks Pill
                    HStack(spacing: 4) {
                        Text("\(snapshot.pendingTasksCount ?? 0)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                        Text("Due Today")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.61))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.13, green: 0.13, blue: 0.17))
                    .cornerRadius(10)
                }
            } else {
                HStack {
                    Spacer()
                    Text("Sign in to Quick Notes")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.61))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(red: 0.13, green: 0.13, blue: 0.17))
                .cornerRadius(10)
            }

            Spacer(minLength: 0)

            // Action Buttons Row with Link Interactions
            HStack(spacing: 8) {
                Link(destination: URL(string: "quicknotes://note/new?homeWidget=true")!) {
                    HStack {
                        Spacer()
                        Text("+ New Note")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 36)
                    .background(Color(red: 0.16, green: 0.16, blue: 0.21))
                    .cornerRadius(10)
                }

                Link(destination: URL(string: "quicknotes://checklist/new?homeWidget=true")!) {
                    HStack {
                        Spacer()
                        Text("☑ Checklist")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 36)
                    .background(Color(red: 0.16, green: 0.16, blue: 0.21))
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "quicknotes://home?homeWidget=true"))
    }
}

// MARK: - Widget Configuration

@main
struct QuickNotesWidget: Widget {
    let kind: String = "QuickNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickNotesTimelineProvider()) { entry in
            QuickNotesWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.10, green: 0.10, blue: 0.13), for: .widget)
        }
        .configurationDisplayName("Quick Notes")
        .description("Quickly view pinned notes, today's tasks, and capture new ideas.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
