package com.quicknotes.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

/**
 * NoteWidgetConfigureActivity — Native Android configuration Activity for SingleNoteWidget.
 *
 * **Flow & Invariants:**
 * 1. Launches when user adds a SingleNoteWidget to their home screen.
 * 2. Loads active, unlocked note items from [HomeWidgetPreferences] (`quicknotes_notes_catalog`).
 * 3. Never touches SQLite directly.
 * 4. Stores note selection per [appWidgetId] upon user tap.
 * 5. Returns [Activity.RESULT_OK] with the [AppWidgetManager.EXTRA_APPWIDGET_ID].
 */
class NoteWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val allNotes = mutableListOf<NoteItem>()
    private val filteredNotes = mutableListOf<NoteItem>()
    private lateinit var adapter: NotesAdapter
    private lateinit var emptyView: View
    private lateinit var listView: ListView

    data class NoteItem(
        val id: String,
        val title: String,
        val preview: String,
        val noteType: String,
        val date: String,
        val fullJson: JSONObject
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Set RESULT_CANCELED by default. If user backs out, widget creation is aborted.
        setResult(RESULT_CANCELED)

        // 2. Extract appWidgetId from Launch Intent
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_note_widget_configure)

        listView = findViewById(R.id.notes_list_view)
        emptyView = findViewById(R.id.empty_notes_view)
        val searchInput = findViewById<EditText>(R.id.search_notes_input)

        adapter = NotesAdapter(this, filteredNotes)
        listView.adapter = adapter

        // 3. Load sanitized catalog from SharedPreferences
        loadNotesCatalog()

        // 4. Handle Item Selection
        listView.setOnItemClickListener { _, _, position, _ ->
            if (position in 0 until filteredNotes.size) {
                selectNote(filteredNotes[position])
            }
        }

        // 5. Real-time Search Filtering
        searchInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                filterNotes(s?.toString() ?: "")
            }
            override fun afterTextChanged(s: Editable?) {}
        })
    }

    private fun loadNotesCatalog() {
        allNotes.clear()
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val catalogRaw = prefs.getString("quicknotes_notes_catalog", null)
        val mapRaw = prefs.getString("quicknotes_notes_map", null)

        val notesMap = if (!mapRaw.isNullOrEmpty()) {
            try { JSONObject(mapRaw) } catch (_: Exception) { JSONObject() }
        } else {
            JSONObject()
        }

        if (!catalogRaw.isNullOrEmpty()) {
            try {
                val array = JSONArray(catalogRaw)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val id = obj.optString("id", "")
                    val title = obj.optString("title", "Untitled Note")
                    val preview = obj.optString("preview", "")
                    val noteType = obj.optString("note_type", "text")
                    val date = obj.optString("formatted_date", "")

                    val fullJson = if (notesMap.has(id)) {
                        notesMap.getJSONObject(id)
                    } else {
                        obj
                    }

                    if (id.isNotEmpty()) {
                        allNotes.add(NoteItem(id, title, preview, noteType, date, fullJson))
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        filterNotes("")
    }

    private fun filterNotes(query: String) {
        filteredNotes.clear()
        val trimmed = query.trim().lowercase()
        if (trimmed.isEmpty()) {
            filteredNotes.addAll(allNotes)
        } else {
            for (item in allNotes) {
                if (item.title.lowercase().contains(trimmed) ||
                    item.preview.lowercase().contains(trimmed)
                ) {
                    filteredNotes.add(item)
                }
            }
        }

        if (filteredNotes.isEmpty()) {
            emptyView.visibility = View.VISIBLE
            listView.visibility = View.GONE
        } else {
            emptyView.visibility = View.GONE
            listView.visibility = View.VISIBLE
        }

        adapter.notifyDataSetChanged()
    }

    private fun selectNote(note: NoteItem) {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("note_widget_id_$appWidgetId", note.id)
            .putString("note_widget_data_$appWidgetId", note.fullJson.toString())
            .apply()

        // Update widget instance immediately
        val appWidgetManager = AppWidgetManager.getInstance(this)
        SingleNoteWidget.updateAppWidget(this, appWidgetManager, appWidgetId, prefs)

        // Return SUCCESS to Android Launcher
        val resultValue = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        setResult(RESULT_OK, resultValue)
        finish()
    }

    private class NotesAdapter(
        private val context: Context,
        private val items: List<NoteItem>
    ) : BaseAdapter() {

        override fun getCount(): Int = items.size
        override fun getItem(position: Int): Any = items[position]
        override fun getItemId(position: Int): Long = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val view = convertView ?: LayoutInflater.from(context)
                .inflate(R.layout.item_note_select, parent, false)

            val item = items[position]
            val titleView = view.findViewById<TextView>(R.id.item_note_title)
            val previewView = view.findViewById<TextView>(R.id.item_note_preview)
            val typeView = view.findViewById<TextView>(R.id.item_note_type)
            val dateView = view.findViewById<TextView>(R.id.item_note_date)

            titleView.text = item.title
            previewView.text = if (item.preview.isNotEmpty()) item.preview else "No additional text"
            typeView.text = if (item.noteType.equals("checklist", ignoreCase = true)) "CHECKLIST" else "NOTE"
            dateView.text = if (item.date.isNotEmpty()) "Updated ${item.date}" else "Recent"

            return view
        }
    }
}
