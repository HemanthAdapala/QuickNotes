package com.quicknotes.byhmnth

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

/**
 * WidgetPinSuccessReceiver — Handles system broadcast callbacks from Android Launcher
 * upon successful home-screen widget placement initiated via requestPinAppWidget.
 *
 * Automatically binds the newly assigned [appWidgetId] to the exact requested
 * note or task, updates instance storage in [HomeWidgetPreferences], and triggers
 * an immediate widget render so the placed widget reflects the authentic content.
 */
class WidgetPinSuccessReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val appWidgetManager = AppWidgetManager.getInstance(context)

        val itemType = intent.getStringExtra("item_type")
            ?: if (prefs.contains("pending_pin_note_id")) "note" else "task"
        val itemId = intent.getStringExtra("item_id")
            ?: prefs.getString("pending_pin_${itemType}_id", null)

        if (itemId.isNullOrEmpty()) return

        if (itemType == "note") {
            val notesMapRaw = prefs.getString("quicknotes_notes_map", null)
            var noteJsonStr: String? = null
            if (notesMapRaw != null) {
                try {
                    val notesMap = JSONObject(notesMapRaw)
                    if (notesMap.has(itemId)) {
                        noteJsonStr = notesMap.getJSONObject(itemId).toString()
                    }
                } catch (_: Exception) {}
            }

            val editor = prefs.edit().putString("note_widget_id_$appWidgetId", itemId)
            if (noteJsonStr != null) {
                editor.putString("note_widget_data_$appWidgetId", noteJsonStr)
            }
            editor.remove("pending_pin_note_id")
            editor.apply()

            SingleNoteWidget.updateAppWidget(context, appWidgetManager, appWidgetId, prefs)
        } else if (itemType == "task") {
            val tasksMapRaw = prefs.getString("quicknotes_tasks_map", null)
            var taskJsonStr: String? = null
            if (tasksMapRaw != null) {
                try {
                    val tasksMap = JSONObject(tasksMapRaw)
                    if (tasksMap.has(itemId)) {
                        taskJsonStr = tasksMap.getJSONObject(itemId).toString()
                    }
                } catch (_: Exception) {}
            }

            val editor = prefs.edit().putString("task_widget_id_$appWidgetId", itemId)
            if (taskJsonStr != null) {
                editor.putString("task_widget_data_$appWidgetId", taskJsonStr)
            }
            editor.remove("pending_pin_task_id")
            editor.apply()

            SingleTaskWidget.updateAppWidget(context, appWidgetManager, appWidgetId, prefs)
        }
    }
}

