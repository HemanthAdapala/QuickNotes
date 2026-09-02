package com.quicknotes.app

import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * TaskWidgetDateHelper — Central helper for dynamic day evaluation and live rollover.
 *
 * Guarantees that when a recurring task was completed on a previous day, Android widgets
 * dynamically evaluate it as "Pending" with today's date even if the Flutter app remained closed.
 */
object TaskWidgetDateHelper {

    data class ResolvedTaskState(
        val formattedDate: String,
        val formattedTime: String,
        val isCompleted: Boolean,
        val statusLabel: String
    )

    fun resolveTaskState(taskJson: JSONObject, now: Date = Date()): ResolvedTaskState {
        val originalDate = taskJson.optString("formatted_date", "")
        val originalTime = taskJson.optString("formatted_time", "")
        val rawCompleted = taskJson.optBoolean("completed", false) ||
                taskJson.optBoolean("is_completed", false) ||
                taskJson.optString("status") == "completed"
        val isRecurring = taskJson.optBoolean("is_recurring", false) ||
                taskJson.optBoolean("has_repeat", false) ||
                taskJson.optString("repeat_label").isNotEmpty()

        if (!isRecurring || !rawCompleted) {
            return ResolvedTaskState(
                formattedDate = originalDate,
                formattedTime = originalTime,
                isCompleted = rawCompleted,
                statusLabel = if (rawCompleted) "Completed" else "Pending"
            )
        }

        // Check task due date vs current local date
        val dueDateIso = taskJson.optString("due_date_iso", "")
        val taskDate: Date? = if (dueDateIso.isNotEmpty()) {
            try {
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                isoFormat.parse(dueDateIso)
            } catch (_: Exception) {
                try {
                    val fallbackIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }
                    fallbackIso.parse(dueDateIso)
                } catch (_: Exception) {
                    null
                }
            }
        } else {
            null
        }

        val todayCal = Calendar.getInstance().apply { time = now }
        val taskCal = Calendar.getInstance().apply {
            if (taskDate != null) {
                time = taskDate
            }
        }

        val isDifferentDay = taskDate != null && ((todayCal.get(Calendar.YEAR) > taskCal.get(Calendar.YEAR)) ||
                (todayCal.get(Calendar.YEAR) == taskCal.get(Calendar.YEAR) &&
                        todayCal.get(Calendar.DAY_OF_YEAR) > taskCal.get(Calendar.DAY_OF_YEAR)))

        if (isDifferentDay) {
            // New day has arrived: dynamically roll over to today's date & Pending status
            val displayFormat = SimpleDateFormat("EEE, d MMMM yyyy", Locale.getDefault())
            val newFormattedDate = displayFormat.format(now)

            return ResolvedTaskState(
                formattedDate = newFormattedDate,
                formattedTime = originalTime,
                isCompleted = false,
                statusLabel = "Pending"
            )
        }

        return ResolvedTaskState(
            formattedDate = originalDate,
            formattedTime = originalTime,
            isCompleted = rawCompleted,
            statusLabel = if (rawCompleted) "Completed" else "Pending"
        )
    }
}
