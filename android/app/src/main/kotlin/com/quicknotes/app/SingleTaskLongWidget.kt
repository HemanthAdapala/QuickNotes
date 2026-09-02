package com.quicknotes.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * SingleTaskLongWidget — Native Android AppWidget representing a single task (Long / horizontal 4x1).
 *
 * **Phase T3 Architecture & Visual Contract:**
 * 1. Horizontal Layout Flow: Badges (Priority/Recurrence) on left, natural-wrapping Title in center, Status pill on right.
 * 2. Dual Visual States: Renders Pending vs Completed states cleanly from [SingleTaskSnapshot].
 * 3. Exact Data Fidelity: Displays authentic title, date, time, priority, and recurrence without distortion.
 * 4. Multi-Instance Isolation: Configured independently per [appWidgetId] via `task_widget_id_<appWidgetId>`.
 * 5. Resilient Fallbacks: Safe fallback container when task is missing, deleted, or unconfigured.
 * 6. RemoteViews Compliance: Strict usage of standard views (LinearLayout, FrameLayout, TextView, ImageView).
 */
class SingleTaskLongWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (appWidgetId in appWidgetIds) {
            editor.remove("task_widget_id_$appWidgetId")
            editor.remove("task_widget_data_$appWidgetId")
        }
        editor.apply()
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            val views = RemoteViews(context.packageName, R.layout.single_task_long_widget_layout)

            // 1. Identify selected task ID for this specific widget instance
            val selectedTaskId = widgetData.getString("task_widget_id_$appWidgetId", null)

            // 2. Load latest task snapshot (checking live tasks map, then instance cache)
            var taskJson: JSONObject? = null
            if (!selectedTaskId.isNullOrEmpty()) {
                val tasksMapRaw = widgetData.getString("quicknotes_tasks_map", null)
                if (tasksMapRaw != null) {
                    try {
                        val tasksMap = JSONObject(tasksMapRaw)
                        if (tasksMap.has(selectedTaskId)) {
                            taskJson = tasksMap.getJSONObject(selectedTaskId)
                        }
                    } catch (_: Exception) {}
                } else {
                    // Fallback to instance cache only if tasks map was never written yet
                    val instanceDataRaw = widgetData.getString("task_widget_data_$appWidgetId", null)
                    if (!instanceDataRaw.isNullOrEmpty()) {
                        try {
                            taskJson = JSONObject(instanceDataRaw)
                        } catch (_: Exception) {}
                    }
                }
            }

            // 3. Render either Active Task Content or Safe Fallback State
            if (taskJson != null && !selectedTaskId.isNullOrEmpty()) {
                val resolvedState = TaskWidgetDateHelper.resolveTaskState(taskJson)
                val title = taskJson.optString("title", "Untitled Task")
                val formattedDate = resolvedState.formattedDate
                val formattedTime = resolvedState.formattedTime
                val priority = taskJson.optString("priority", "None")
                val hasPriority = taskJson.optBoolean("has_priority", false) && !priority.equals("None", ignoreCase = true)
                val hasRepeat = taskJson.optBoolean("has_repeat", false)
                val repeatLabel = taskJson.optString("repeat_label", "")
                val isCompleted = resolvedState.isCompleted

                views.setViewVisibility(R.id.widget_task_long_content_container, View.VISIBLE)
                views.setViewVisibility(R.id.widget_task_long_fallback_container, View.GONE)
                views.setViewVisibility(R.id.widget_task_long_header_container, View.VISIBLE)

                // Header Date & Time
                views.setTextViewText(R.id.widget_task_long_date_text, formattedDate)
                views.setTextViewText(R.id.widget_task_long_time_text, formattedTime)

                // Title
                views.setTextViewText(R.id.widget_task_long_title, title)

                // Priority Badge
                if (hasPriority) {
                    views.setViewVisibility(R.id.widget_task_long_priority_badge, View.VISIBLE)
                    views.setTextViewText(R.id.widget_task_long_priority_text, priority)

                    when {
                        priority.equals("High", ignoreCase = true) -> {
                            views.setInt(R.id.widget_task_long_priority_badge, "setBackgroundResource", R.drawable.widget_task_priority_high_bg)
                            views.setImageViewResource(R.id.widget_task_long_priority_icon, R.drawable.ic_task_flag_red)
                            views.setTextColor(R.id.widget_task_long_priority_text, Color.parseColor("#FF3B30"))
                        }
                        priority.equals("Medium", ignoreCase = true) -> {
                            views.setInt(R.id.widget_task_long_priority_badge, "setBackgroundResource", R.drawable.widget_task_priority_med_bg)
                            views.setImageViewResource(R.id.widget_task_long_priority_icon, R.drawable.ic_task_flag_yellow)
                            views.setTextColor(R.id.widget_task_long_priority_text, Color.parseColor("#FF9500"))
                        }
                        priority.equals("Low", ignoreCase = true) -> {
                            views.setInt(R.id.widget_task_long_priority_badge, "setBackgroundResource", R.drawable.widget_task_priority_low_bg)
                            views.setImageViewResource(R.id.widget_task_long_priority_icon, R.drawable.ic_task_flag_blue)
                            views.setTextColor(R.id.widget_task_long_priority_text, Color.parseColor("#0088FF"))
                        }
                        else -> {
                            views.setViewVisibility(R.id.widget_task_long_priority_badge, View.GONE)
                        }
                    }
                } else {
                    views.setViewVisibility(R.id.widget_task_long_priority_badge, View.GONE)
                }

                // Recurrence Badge
                if (hasRepeat && repeatLabel.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_task_long_repeat_badge, View.VISIBLE)
                    views.setTextViewText(R.id.widget_task_long_repeat_text, repeatLabel)
                } else {
                    views.setViewVisibility(R.id.widget_task_long_repeat_badge, View.GONE)
                }

                // Badges Container Visibility
                if (hasPriority || (hasRepeat && repeatLabel.isNotEmpty())) {
                    views.setViewVisibility(R.id.widget_task_long_badges_container, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_task_long_badges_container, View.GONE)
                }

                // Status Pill (Pending vs Completed)
                if (isCompleted) {
                    views.setImageViewResource(R.id.widget_task_long_status_icon, R.drawable.ic_task_check_completed)
                    views.setTextViewText(R.id.widget_task_long_status_text, "Completed")
                    views.setTextColor(R.id.widget_task_long_status_text, Color.parseColor("#222222"))
                } else {
                    views.setImageViewResource(R.id.widget_task_long_status_icon, R.drawable.ic_task_clock_pending)
                    views.setTextViewText(R.id.widget_task_long_status_text, "Pending")
                    views.setTextColor(R.id.widget_task_long_status_text, Color.parseColor("#222222"))
                }

                // Safe Task Deep Link Intent: quicknotes://task/<taskId>
                val taskId = taskJson.optString("id", selectedTaskId ?: "").trim()
                val launchIntent = if (taskId.isNotEmpty()) {
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("quicknotes://task/$taskId")
                    )
                } else {
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java
                    )
                }
                views.setOnClickPendingIntent(R.id.widget_single_task_long_root, launchIntent)

            } else {
                // Fallback / Missing Task State
                views.setViewVisibility(R.id.widget_task_long_content_container, View.GONE)
                views.setViewVisibility(R.id.widget_task_long_fallback_container, View.VISIBLE)
                views.setTextViewText(R.id.widget_task_long_fallback_title, "Quick Notes")
                views.setTextViewText(
                    R.id.widget_task_long_fallback_subtitle,
                    if (selectedTaskId.isNullOrEmpty()) "Tap to choose a task" else "Task unavailable"
                )

                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                views.setOnClickPendingIntent(R.id.widget_single_task_long_root, launchIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            MidnightWidgetUpdateReceiver.scheduleMidnightAlarm(context)
        }
    }
}
