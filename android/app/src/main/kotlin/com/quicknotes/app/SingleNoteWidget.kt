package com.quicknotes.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * SingleNoteWidget — Native Android AppWidget representing a single user-selected note.
 *
 * **Phase W6 Architecture & Semantic Fidelity:**
 * 1. Semantic Content Rendering: Preserves exact note structure (plain text, bulleted lists,
 *    numbered lists, checklists, and mixed content).
 * 2. Natural Text Wrapping: Continuous text naturally wraps using Android's native TextView width.
 * 3. Responsive Geometry: Revealing additional real content progressively as the widget expands.
 * 4. Multi-Instance Isolation: Configured independently per [appWidgetId].
 * 5. Safe Fallback: Clean state for locked, deleted, or unconfigured notes.
 * 6. Deep Link Security: Routes strictly via `quicknotes://note/<noteId>`.
 */
class SingleNoteWidget : HomeWidgetProvider() {

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
            editor.remove("note_widget_id_$appWidgetId")
            editor.remove("note_widget_data_$appWidgetId")
        }
        editor.apply()
    }

    companion object {
        private val LINE_IDS = intArrayOf(
            R.id.note_line_1,
            R.id.note_line_2,
            R.id.note_line_3,
            R.id.note_line_4,
            R.id.note_line_5,
            R.id.note_line_6,
            R.id.note_line_7,
            R.id.note_line_8,
            R.id.note_line_9,
            R.id.note_line_10
        )

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            val views = RemoteViews(context.packageName, R.layout.single_note_widget_layout)

            // 1. Identify selected note ID for this specific widget instance
            val selectedNoteId = widgetData.getString("note_widget_id_$appWidgetId", null)

            // 2. Load latest note snapshot (checking live catalog map, then instance cache)
            var noteJson: JSONObject? = null
            if (!selectedNoteId.isNullOrEmpty()) {
                val notesMapRaw = widgetData.getString("quicknotes_notes_map", null)
                if (notesMapRaw != null) {
                    try {
                        val notesMap = JSONObject(notesMapRaw)
                        if (notesMap.has(selectedNoteId)) {
                            noteJson = notesMap.getJSONObject(selectedNoteId)
                        }
                    } catch (_: Exception) {}
                } else {
                    // Fallback to instance cache only if notes map was never written yet
                    val instanceDataRaw = widgetData.getString("note_widget_data_$appWidgetId", null)
                    if (!instanceDataRaw.isNullOrEmpty()) {
                        try {
                            noteJson = JSONObject(instanceDataRaw)
                        } catch (_: Exception) {}
                    }
                }
            }

            // 3. Render either Active Note Content or Safe Fallback State
            if (noteJson != null && !selectedNoteId.isNullOrEmpty()) {
                val title = noteJson.optString("title", "Untitled Note")
                val formattedDate = noteJson.optString("formatted_date", "")
                val formattedTime = noteJson.optString("formatted_time", "")
                val semanticLines = noteJson.optJSONArray("semantic_lines")
                    ?: noteJson.optJSONArray("content_lines")
                val content = noteJson.optString("content", "")
                val previewLines = noteJson.optJSONArray("preview_lines")

                views.setViewVisibility(R.id.widget_content_container, View.VISIBLE)
                views.setViewVisibility(R.id.widget_fallback_container, View.GONE)
                views.setViewVisibility(R.id.widget_header_container, View.VISIBLE)

                views.setTextViewText(R.id.widget_date_text, formattedDate)
                views.setTextViewText(R.id.widget_time_text, formattedTime)
                views.setTextViewText(R.id.widget_note_title, title)

                // Bind semantic lines
                if (semanticLines != null && semanticLines.length() > 0) {
                    val totalLines = semanticLines.length()
                    for (i in 0 until 10) {
                        if (i < totalLines) {
                            val lineObj = semanticLines.optJSONObject(i)
                            if (lineObj != null) {
                                val text = lineObj.optString("text", "").trim()
                                val marker = lineObj.optString("marker", "").trim()
                                val displayText = if (marker.isNotEmpty()) "$marker  $text" else text

                                if (displayText.isNotEmpty()) {
                                    views.setViewVisibility(LINE_IDS[i], View.VISIBLE)
                                    views.setTextViewText(LINE_IDS[i], displayText)
                                } else {
                                    views.setViewVisibility(LINE_IDS[i], View.GONE)
                                }
                            } else {
                                views.setViewVisibility(LINE_IDS[i], View.GONE)
                            }
                        } else {
                            views.setViewVisibility(LINE_IDS[i], View.GONE)
                        }
                    }
                } else if (previewLines != null && previewLines.length() > 0) {
                    // Fallback from legacy preview strings
                    val totalLines = previewLines.length()
                    for (i in 0 until 10) {
                        if (i < totalLines) {
                            val text = previewLines.optString(i, "").trim()
                            if (text.isNotEmpty()) {
                                views.setViewVisibility(LINE_IDS[i], View.VISIBLE)
                                views.setTextViewText(LINE_IDS[i], text)
                            } else {
                                views.setViewVisibility(LINE_IDS[i], View.GONE)
                            }
                        } else {
                            views.setViewVisibility(LINE_IDS[i], View.GONE)
                        }
                    }
                } else if (content.isNotEmpty()) {
                    // Fallback from raw content string
                    val splitLines = content.split("\n")
                    for (i in 0 until 10) {
                        if (i < splitLines.size) {
                            val lineText = splitLines[i].trim()
                            if (lineText.isNotEmpty()) {
                                views.setViewVisibility(LINE_IDS[i], View.VISIBLE)
                                views.setTextViewText(LINE_IDS[i], lineText)
                            } else {
                                views.setViewVisibility(LINE_IDS[i], View.GONE)
                            }
                        } else {
                            views.setViewVisibility(LINE_IDS[i], View.GONE)
                        }
                    }
                } else {
                    for (i in 0 until 10) {
                        views.setViewVisibility(LINE_IDS[i], View.GONE)
                    }
                }

                // Attach Deep Link PendingIntent: quicknotes://note/<noteId>
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("quicknotes://note/$selectedNoteId")
                )
                views.setOnClickPendingIntent(R.id.widget_single_note_root, launchIntent)

            } else {
                // Unconfigured / Deleted / Locked note fallback state
                views.setViewVisibility(R.id.widget_content_container, View.GONE)
                views.setViewVisibility(R.id.widget_fallback_container, View.VISIBLE)
                views.setTextViewText(R.id.widget_fallback_title, "Quick Notes")
                views.setTextViewText(
                    R.id.widget_fallback_subtitle,
                    if (selectedNoteId.isNullOrEmpty()) "Tap to choose a note" else "Note unavailable"
                )

                // Tap launches configuration activity to choose a note
                val configIntent = Intent(context, NoteWidgetConfigureActivity::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingConfig = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    configIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_single_note_root, pendingConfig)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
