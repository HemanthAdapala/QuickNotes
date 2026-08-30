package com.quicknotes.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.text.Html
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * MultiTaskWidget — Native Android AppWidget representing multiple tasks in a responsive vertical stack.
 *
 * **Phase T4 Architecture & Visual Contract:**
 * 1. Responsive Viewport Expansion: Vertical resizing reveals additional task cards without scaling typography or distorting geometry.
 * 2. Default 4x3 Footprint: Shows up to 2 task cards + Add Task action.
 * 3. 4x4 & 4x5 Expanded Footprints: Dynamically reveals 3 or 4 task cards + Add Task action.
 * 4. Dual Visual States: Renders Pending vs Completed states cleanly from [SingleTaskSnapshot].
 * 5. Exact Data Fidelity: Displays authentic title, date, time, priority, and recurrence.
 * 6. Empty State: Displays "All Caught Up!" card with Add Task action when zero tasks exist.
 * 7. RemoteViews Compliance: Strict usage of standard views (LinearLayout, TextView, ImageView).
 */
class MultiTaskWidget : HomeWidgetProvider() {

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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            val views = RemoteViews(context.packageName, R.layout.multi_task_widget_layout)

            // 1. Determine available widget height to calculate capacity
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0

            // Capacity threshold calculation:
            // Default 4x3 (~200dp): up to 2 task cards + Add Task
            // 4x4 (~260-310dp): up to 3 task cards + Add Task
            // 4x5+ (>= 320dp): up to 4 task cards + Add Task
            val maxVisibleTasks = when {
                minHeight >= 320 -> 4
                minHeight >= 240 -> 3
                else -> 2
            }

            // 2. Load Task Catalog & Map from HomeWidgetPreferences
            val taskList = mutableListOf<JSONObject>()
            val catalogRaw = widgetData.getString("quicknotes_tasks_catalog", null)
            val mapRaw = widgetData.getString("quicknotes_tasks_map", null)

            var tasksMap: JSONObject? = null
            if (!mapRaw.isNullOrEmpty()) {
                try {
                    tasksMap = JSONObject(mapRaw)
                } catch (_: Exception) {}
            }

            if (!catalogRaw.isNullOrEmpty()) {
                try {
                    val catalogArray = JSONArray(catalogRaw)
                    for (i in 0 until catalogArray.length()) {
                        val catalogItem = catalogArray.getJSONObject(i)
                        val taskId = catalogItem.optString("id", "")
                        // Prefer full snapshot from map if available, else catalog entry
                        val fullTask = if (tasksMap != null && tasksMap.has(taskId)) {
                            tasksMap.getJSONObject(taskId)
                        } else {
                            catalogItem
                        }
                        taskList.add(fullTask)
                    }
                } catch (_: Exception) {}
            } else if (tasksMap != null) {
                val keys = tasksMap.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    taskList.add(tasksMap.getJSONObject(key))
                }
            }

            // 3. Render Empty State or Stacked Task Cards
            if (taskList.isEmpty()) {
                // Empty State
                views.setViewVisibility(R.id.multi_task_empty_card, View.VISIBLE)
                views.setViewVisibility(R.id.multi_task_card_1, View.GONE)
                views.setViewVisibility(R.id.multi_task_card_2, View.GONE)
                views.setViewVisibility(R.id.multi_task_card_3, View.GONE)
                views.setViewVisibility(R.id.multi_task_card_4, View.GONE)
                views.setViewVisibility(R.id.multi_task_add_card, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.multi_task_empty_card, View.GONE)

                val countToRender = minOf(taskList.size, maxVisibleTasks)

                val cardIds = intArrayOf(
                    R.id.multi_task_card_1,
                    R.id.multi_task_card_2,
                    R.id.multi_task_card_3,
                    R.id.multi_task_card_4
                )
                val dateIds = intArrayOf(
                    R.id.multi_task_1_date,
                    R.id.multi_task_2_date,
                    R.id.multi_task_3_date,
                    R.id.multi_task_4_date
                )
                val timeIds = intArrayOf(
                    R.id.multi_task_1_time,
                    R.id.multi_task_2_time,
                    R.id.multi_task_3_time,
                    R.id.multi_task_4_time
                )
                val titleIds = intArrayOf(
                    R.id.multi_task_1_title,
                    R.id.multi_task_2_title,
                    R.id.multi_task_3_title,
                    R.id.multi_task_4_title
                )
                val badgesContainerIds = intArrayOf(
                    R.id.multi_task_1_badges_container,
                    R.id.multi_task_2_badges_container,
                    R.id.multi_task_3_badges_container,
                    R.id.multi_task_4_badges_container
                )
                val priorityBadgeIds = intArrayOf(
                    R.id.multi_task_1_priority_badge,
                    R.id.multi_task_2_priority_badge,
                    R.id.multi_task_3_priority_badge,
                    R.id.multi_task_4_priority_badge
                )
                val priorityIconIds = intArrayOf(
                    R.id.multi_task_1_priority_icon,
                    R.id.multi_task_2_priority_icon,
                    R.id.multi_task_3_priority_icon,
                    R.id.multi_task_4_priority_icon
                )
                val priorityTextIds = intArrayOf(
                    R.id.multi_task_1_priority_text,
                    R.id.multi_task_2_priority_text,
                    R.id.multi_task_3_priority_text,
                    R.id.multi_task_4_priority_text
                )
                val repeatBadgeIds = intArrayOf(
                    R.id.multi_task_1_repeat_badge,
                    R.id.multi_task_2_repeat_badge,
                    R.id.multi_task_3_repeat_badge,
                    R.id.multi_task_4_repeat_badge
                )
                val repeatTextIds = intArrayOf(
                    R.id.multi_task_1_repeat_text,
                    R.id.multi_task_2_repeat_text,
                    R.id.multi_task_3_repeat_text,
                    R.id.multi_task_4_repeat_text
                )
                val statusIconIds = intArrayOf(
                    R.id.multi_task_1_status_icon,
                    R.id.multi_task_2_status_icon,
                    R.id.multi_task_3_status_icon,
                    R.id.multi_task_4_status_icon
                )
                val statusTextIds = intArrayOf(
                    R.id.multi_task_1_status_text,
                    R.id.multi_task_2_status_text,
                    R.id.multi_task_3_status_text,
                    R.id.multi_task_4_status_text
                )

                for (i in 0..3) {
                    if (i < countToRender) {
                        val task = taskList[i]
                        val title = task.optString("title", "Untitled Task")
                        val formattedDate = task.optString("formatted_date", "")
                        val formattedTime = task.optString("formatted_time", "")
                        val priority = task.optString("priority", "None")
                        val hasPriority = task.optBoolean("has_priority", false) && !priority.equals("None", ignoreCase = true)
                        val hasRepeat = task.optBoolean("has_repeat", false)
                        val repeatLabel = task.optString("repeat_label", "")
                        val isCompleted = task.optBoolean("completed", false) ||
                                task.optBoolean("is_completed", false) ||
                                task.optString("status") == "completed"

                        views.setViewVisibility(cardIds[i], View.VISIBLE)
                        views.setTextViewText(dateIds[i], formattedDate)
                        views.setTextViewText(timeIds[i], formattedTime)

                        // Title (with strike-through for completed tasks)
                        if (isCompleted) {
                            views.setTextViewText(
                                titleIds[i],
                                Html.fromHtml("<s>${Html.escapeHtml(title)}</s>", Html.FROM_HTML_MODE_LEGACY)
                            )
                        } else {
                            views.setTextViewText(titleIds[i], title)
                        }

                        // Priority Badge
                        if (hasPriority) {
                            views.setViewVisibility(priorityBadgeIds[i], View.VISIBLE)
                            views.setTextViewText(priorityTextIds[i], priority)

                            when {
                                priority.equals("High", ignoreCase = true) -> {
                                    views.setInt(priorityBadgeIds[i], "setBackgroundResource", R.drawable.widget_task_priority_high_bg)
                                    views.setImageViewResource(priorityIconIds[i], R.drawable.ic_task_flag_red)
                                    views.setTextColor(priorityTextIds[i], Color.parseColor("#FF3B30"))
                                }
                                priority.equals("Medium", ignoreCase = true) -> {
                                    views.setInt(priorityBadgeIds[i], "setBackgroundResource", R.drawable.widget_task_priority_med_bg)
                                    views.setImageViewResource(priorityIconIds[i], R.drawable.ic_task_flag_yellow)
                                    views.setTextColor(priorityTextIds[i], Color.parseColor("#FF9500"))
                                }
                                priority.equals("Low", ignoreCase = true) -> {
                                    views.setInt(priorityBadgeIds[i], "setBackgroundResource", R.drawable.widget_task_priority_low_bg)
                                    views.setImageViewResource(priorityIconIds[i], R.drawable.ic_task_flag_blue)
                                    views.setTextColor(priorityTextIds[i], Color.parseColor("#0088FF"))
                                }
                                else -> {
                                    views.setViewVisibility(priorityBadgeIds[i], View.GONE)
                                }
                            }
                        } else {
                            views.setViewVisibility(priorityBadgeIds[i], View.GONE)
                        }

                        // Recurrence Badge
                        if (hasRepeat && repeatLabel.isNotEmpty()) {
                            views.setViewVisibility(repeatBadgeIds[i], View.VISIBLE)
                            views.setTextViewText(repeatTextIds[i], repeatLabel)
                        } else {
                            views.setViewVisibility(repeatBadgeIds[i], View.GONE)
                        }

                        // Badges Column Visibility
                        if (hasPriority || (hasRepeat && repeatLabel.isNotEmpty())) {
                            views.setViewVisibility(badgesContainerIds[i], View.VISIBLE)
                        } else {
                            views.setViewVisibility(badgesContainerIds[i], View.GONE)
                        }

                        // Status Pill (Pending vs Completed)
                        if (isCompleted) {
                            views.setImageViewResource(statusIconIds[i], R.drawable.ic_task_check_completed)
                            views.setTextViewText(statusTextIds[i], "Completed")
                            views.setTextColor(statusTextIds[i], Color.parseColor("#111111"))
                        } else {
                            views.setImageViewResource(statusIconIds[i], R.drawable.ic_task_clock_pending)
                            views.setTextViewText(statusTextIds[i], "Pending")
                            views.setTextColor(statusTextIds[i], Color.parseColor("#555555"))
                        }

                        // Per-Card Task Deep Link: quicknotes://task/<taskId>
                        val taskId = task.optString("id", "").trim()
                        val cardIntent = if (taskId.isNotEmpty()) {
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
                        views.setOnClickPendingIntent(cardIds[i], cardIntent)
                    } else {
                        views.setViewVisibility(cardIds[i], View.GONE)
                    }
                }

                views.setViewVisibility(R.id.multi_task_add_card, View.VISIBLE)
            }

            // 4. Safe App Launch Intent (Root, Empty Card, Add Card)
            val defaultLaunchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_multi_task_root, defaultLaunchIntent)
            views.setOnClickPendingIntent(R.id.multi_task_add_card, defaultLaunchIntent)
            views.setOnClickPendingIntent(R.id.multi_task_empty_card, defaultLaunchIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
