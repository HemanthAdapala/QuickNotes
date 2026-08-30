package com.quicknotes.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

/**
 * TaskWidgetConfigureActivity — Native Android configuration Activity for SingleTaskWidget
 * and SingleTaskLongWidget.
 *
 * **Flow & Invariants:**
 * 1. Launches when user adds a SingleTaskWidget or SingleTaskLongWidget to their home screen.
 * 2. Loads active task items from [HomeWidgetPreferences] (`quicknotes_tasks_catalog`).
 * 3. Never touches SQLite directly.
 * 4. Preselects existing mapped task if re-configuring an active instance.
 * 5. Stores selected task ID per [appWidgetId] under key `task_widget_id_<appWidgetId>`.
 * 6. Immediately updates the target widget instance via [AppWidgetManager].
 * 7. Returns [Activity.RESULT_OK] with [AppWidgetManager.EXTRA_APPWIDGET_ID].
 */
class TaskWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val allTasks = mutableListOf<TaskCatalogItem>()
    private val filteredTasks = mutableListOf<TaskCatalogItem>()
    private var selectedTaskId: String? = null

    private lateinit var adapter: TasksAdapter
    private lateinit var emptyView: View
    private lateinit var listView: ListView
    private lateinit var selectButton: Button

    data class TaskCatalogItem(
        val id: String,
        val title: String,
        val priority: String,
        val hasPriority: Boolean,
        val formattedDate: String,
        val formattedTime: String,
        val isCompleted: Boolean,
        val statusLabel: String,
        val repeatLabel: String,
        val hasRepeat: Boolean,
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

        setContentView(R.layout.activity_task_widget_configure)

        listView = findViewById(R.id.tasks_list_view)
        emptyView = findViewById(R.id.empty_tasks_view)
        selectButton = findViewById(R.id.btn_select_task)
        val searchInput = findViewById<EditText>(R.id.search_tasks_input)

        adapter = TasksAdapter(this, filteredTasks)
        listView.adapter = adapter

        // 3. Load existing instance mapping if re-configuring
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        selectedTaskId = prefs.getString("task_widget_id_$appWidgetId", null)

        // 4. Load sanitized catalog from SharedPreferences
        loadTasksCatalog()

        // 5. Handle Item Selection
        listView.setOnItemClickListener { _, _, position, _ ->
            if (position in 0 until filteredTasks.size) {
                val item = filteredTasks[position]
                selectedTaskId = item.id
                updateSelectionState()
            }
        }

        // 6. Handle Confirm Selection
        selectButton.setOnClickListener {
            val currentSelectedId = selectedTaskId
            if (!currentSelectedId.isNullOrEmpty()) {
                val selectedTask = allTasks.find { it.id == currentSelectedId }
                if (selectedTask != null) {
                    confirmSelection(selectedTask)
                }
            }
        }

        // 7. Real-time Search Filtering
        searchInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                filterTasks(s?.toString() ?: "")
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        updateSelectionState()
    }

    private fun loadTasksCatalog() {
        allTasks.clear()
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val catalogRaw = prefs.getString("quicknotes_tasks_catalog", null)
        val mapRaw = prefs.getString("quicknotes_tasks_map", null)

        val tasksMap = if (!mapRaw.isNullOrEmpty()) {
            try { JSONObject(mapRaw) } catch (_: Exception) { JSONObject() }
        } else {
            JSONObject()
        }

        if (!catalogRaw.isNullOrEmpty()) {
            try {
                val array = JSONArray(catalogRaw)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val id = obj.optString("id", "").trim()
                    val title = obj.optString("title", "Untitled Task").trim()
                    val priority = obj.optString("priority", "None")
                    val hasPriority = obj.optBoolean("has_priority", false) && !priority.equals("None", ignoreCase = true)
                    val formattedDate = obj.optString("formatted_date", "")
                    val formattedTime = obj.optString("formatted_time", "")
                    val isCompleted = obj.optBoolean("completed", false) || obj.optBoolean("is_completed", false)
                    val statusLabel = obj.optString("status_label", if (isCompleted) "Completed" else "Pending")
                    val repeatLabel = obj.optString("repeat_label", "")
                    val hasRepeat = obj.optBoolean("has_repeat", false)

                    val fullJson = if (tasksMap.has(id)) {
                        tasksMap.getJSONObject(id)
                    } else {
                        obj
                    }

                    if (id.isNotEmpty()) {
                        allTasks.add(
                            TaskCatalogItem(
                                id = id,
                                title = title,
                                priority = priority,
                                hasPriority = hasPriority,
                                formattedDate = formattedDate,
                                formattedTime = formattedTime,
                                isCompleted = isCompleted,
                                statusLabel = statusLabel,
                                repeatLabel = repeatLabel,
                                hasRepeat = hasRepeat,
                                fullJson = fullJson
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // If the previously mapped task is no longer in the catalog, clear selection
        if (selectedTaskId != null && allTasks.none { it.id == selectedTaskId }) {
            selectedTaskId = null
        }

        filterTasks("")
    }

    private fun filterTasks(query: String) {
        filteredTasks.clear()
        val trimmed = query.trim().lowercase()
        if (trimmed.isEmpty()) {
            filteredTasks.addAll(allTasks)
        } else {
            for (item in allTasks) {
                if (item.title.lowercase().contains(trimmed) ||
                    item.formattedDate.lowercase().contains(trimmed) ||
                    item.priority.lowercase().contains(trimmed) ||
                    item.repeatLabel.lowercase().contains(trimmed)
                ) {
                    filteredTasks.add(item)
                }
            }
        }

        if (filteredTasks.isEmpty()) {
            emptyView.visibility = View.VISIBLE
            listView.visibility = View.GONE
        } else {
            emptyView.visibility = View.GONE
            listView.visibility = View.VISIBLE
        }

        adapter.notifyDataSetChanged()
        updateSelectionState()
    }

    private fun updateSelectionState() {
        val hasValidSelection = !selectedTaskId.isNullOrEmpty() && allTasks.any { it.id == selectedTaskId }
        selectButton.isEnabled = hasValidSelection
        adapter.notifyDataSetChanged()
    }

    private fun confirmSelection(task: TaskCatalogItem) {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("task_widget_id_$appWidgetId", task.id)
            .putString("task_widget_data_$appWidgetId", task.fullJson.toString())
            .apply()

        // Update widget instance immediately
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val appWidgetInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
        val providerClassName = appWidgetInfo?.provider?.className ?: ""

        if (providerClassName.contains("SingleTaskLongWidget")) {
            SingleTaskLongWidget.updateAppWidget(this, appWidgetManager, appWidgetId, prefs)
        } else if (providerClassName.contains("SingleTaskWidget")) {
            SingleTaskWidget.updateAppWidget(this, appWidgetManager, appWidgetId, prefs)
        } else {
            // Safe fallback to update both provider types
            SingleTaskWidget.updateAppWidget(this, appWidgetManager, appWidgetId, prefs)
            SingleTaskLongWidget.updateAppWidget(this, appWidgetManager, appWidgetId, prefs)
        }

        // Return SUCCESS to Android Launcher
        val resultValue = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        setResult(RESULT_OK, resultValue)
        finish()
    }

    private inner class TasksAdapter(
        private val context: Context,
        private val items: List<TaskCatalogItem>
    ) : BaseAdapter() {

        override fun getCount(): Int = items.size
        override fun getItem(position: Int): Any = items[position]
        override fun getItemId(position: Int): Long = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val view = convertView ?: LayoutInflater.from(context)
                .inflate(R.layout.item_task_select, parent, false)

            val item = items[position]
            val cardRoot = view.findViewById<View>(R.id.item_task_card_root)
            val radioIcon = view.findViewById<ImageView>(R.id.item_task_radio)
            val titleView = view.findViewById<TextView>(R.id.item_task_title)
            val datetimeView = view.findViewById<TextView>(R.id.item_task_datetime)
            val priorityBadge = view.findViewById<TextView>(R.id.item_task_priority_badge)
            val repeatBadge = view.findViewById<TextView>(R.id.item_task_repeat_badge)
            val statusBadge = view.findViewById<TextView>(R.id.item_task_status_badge)

            titleView.text = item.title

            val dateTimeText = when {
                item.formattedDate.isNotEmpty() && item.formattedTime.isNotEmpty() ->
                    "${item.formattedDate} • ${item.formattedTime}"
                item.formattedDate.isNotEmpty() -> item.formattedDate
                item.formattedTime.isNotEmpty() -> item.formattedTime
                else -> "No due date"
            }
            datetimeView.text = dateTimeText

            // Priority Badge
            if (item.hasPriority) {
                priorityBadge.visibility = View.VISIBLE
                priorityBadge.text = item.priority
                when {
                    item.priority.equals("High", ignoreCase = true) -> {
                        priorityBadge.setBackgroundResource(R.drawable.widget_task_priority_high_bg)
                        priorityBadge.setTextColor(Color.parseColor("#FF3B30"))
                    }
                    item.priority.equals("Medium", ignoreCase = true) -> {
                        priorityBadge.setBackgroundResource(R.drawable.widget_task_priority_med_bg)
                        priorityBadge.setTextColor(Color.parseColor("#FF9500"))
                    }
                    else -> {
                        priorityBadge.setBackgroundResource(R.drawable.widget_task_priority_low_bg)
                        priorityBadge.setTextColor(Color.parseColor("#0088FF"))
                    }
                }
            } else {
                priorityBadge.visibility = View.GONE
            }

            // Recurrence Badge
            if (item.hasRepeat && item.repeatLabel.isNotEmpty()) {
                repeatBadge.visibility = View.VISIBLE
                repeatBadge.text = item.repeatLabel
            } else {
                repeatBadge.visibility = View.GONE
            }

            // Status Badge
            if (item.isCompleted) {
                statusBadge.text = "Completed"
                statusBadge.setTextColor(Color.parseColor("#12B76A"))
            } else {
                statusBadge.text = "Pending"
                statusBadge.setTextColor(Color.parseColor("#0088FF"))
            }

            // Selected State Styling
            val isSelected = (item.id == selectedTaskId)
            cardRoot.isActivated = isSelected
            if (isSelected) {
                radioIcon.setImageResource(R.drawable.task_configure_radio_checked)
            } else {
                radioIcon.setImageResource(R.drawable.task_configure_radio_unchecked)
            }

            return view
        }
    }
}
