package com.quicknotes.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * QuickCaptureWidget — Android Launcher AppWidget for Quick Notes.
 *
 * **Architecture & Privacy Guarantee:**
 * 1. Reads ONLY the sanitized snapshot from [HomeWidgetPreferences].
 * 2. Never accesses SQLite, VaultService, or note/task text content directly.
 * 3. Renders aggregate statistics and localized date strings.
 * 4. Hides user metrics when [has_active_session] is false.
 */
class QuickCaptureWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val rawJson = widgetData.getString("quicknotes_widget_snapshot", null)

        var dateDayName = ""
        var dateFormatted = ""
        var pinnedNotesCount = 0
        var pendingTasksCount = 0
        var hasActiveSession = true

        if (!rawJson.isNullOrBlank()) {
            try {
                val json = JSONObject(rawJson)
                dateDayName = json.optString("date_day_name", "")
                dateFormatted = json.optString("date_formatted", "")
                pinnedNotesCount = json.optInt("pinned_notes_count", 0)
                pendingTasksCount = json.optInt("pending_tasks_count", 0)
                hasActiveSession = json.optBoolean("has_active_session", true)
            } catch (e: Exception) {
                // Graceful fallback on corrupt JSON
                hasActiveSession = false
            }
        }

        // Deterministic local date fallback if date fields are not yet populated
        if (dateDayName.isEmpty() || dateFormatted.isEmpty()) {
            val now = Date()
            dateDayName = SimpleDateFormat("EEEE", Locale.getDefault()).format(now)
            dateFormatted = SimpleDateFormat("d MMM", Locale.getDefault()).format(now)
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // 1. Header & Date Display
            views.setTextViewText(R.id.widget_day_name, dateDayName)
            views.setTextViewText(R.id.widget_date_formatted, dateFormatted)

            // 2. Metrics or Signed-out State
            if (hasActiveSession) {
                views.setViewVisibility(R.id.widget_metrics_container, View.VISIBLE)
                views.setViewVisibility(R.id.widget_signed_out_container, View.GONE)

                views.setTextViewText(R.id.widget_pinned_count, pinnedNotesCount.toString())
                views.setTextViewText(R.id.widget_tasks_count, pendingTasksCount.toString())
            } else {
                views.setViewVisibility(R.id.widget_metrics_container, View.GONE)
                views.setViewVisibility(R.id.widget_signed_out_container, View.VISIBLE)
                views.setTextViewText(R.id.widget_signed_out_text, "Sign in to Quick Notes")
            }

            // 3. PendingIntents for Deep-Link Actions
            // Root card tap -> quicknotes://home
            val pendingHome = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("quicknotes://home")
            )
            views.setOnClickPendingIntent(R.id.widget_root_container, pendingHome)

            // Add text note tap -> quicknotes://note/new
            val pendingNewNote = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("quicknotes://note/new")
            )
            views.setOnClickPendingIntent(R.id.btn_add_note, pendingNewNote)

            // Add checklist note tap -> quicknotes://checklist/new
            val pendingNewChecklist = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("quicknotes://checklist/new")
            )
            views.setOnClickPendingIntent(R.id.btn_add_checklist, pendingNewChecklist)

            // Tasks due today stat pill tap -> quicknotes://tasks
            val pendingTasks = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("quicknotes://tasks")
            )
            views.setOnClickPendingIntent(R.id.widget_tasks_pill, pendingTasks)
            views.setOnClickPendingIntent(R.id.widget_tasks_count, pendingTasks)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
