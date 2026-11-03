package com.quicknotes.byhmnth

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CLEAR_CHANNEL = "com.quicknotes.byhmnth/deep_link_clear"
    private val WIDGET_PIN_CHANNEL = "com.quicknotes.byhmnth/widget_pin"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val currentIntent = intent
        if (currentIntent != null && currentIntent.action == Intent.ACTION_MAIN && currentIntent.hasCategory(Intent.CATEGORY_LAUNCHER)) {
            clearLaunchIntentData()
        }
        MidnightWidgetUpdateReceiver.scheduleMidnightAlarm(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLEAR_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "clearInitialIntent") {
                clearLaunchIntentData()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_PIN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isRequestPinWidgetSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        result.success(appWidgetManager.isRequestPinAppWidgetSupported)
                    } else {
                        result.success(false)
                    }
                }
                "requestPinNoteWidget" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val noteId = call.argument<String>("noteId") ?: ""
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString("pending_pin_note_id", noteId)
                            .putLong("pending_pin_note_timestamp", System.currentTimeMillis())
                            .apply()

                        val myProvider = ComponentName(this, SingleNoteWidget::class.java)
                        val successIntent = Intent(this, WidgetPinSuccessReceiver::class.java).apply {
                            putExtra("item_type", "note")
                            putExtra("item_id", noteId)
                        }
                        val successCallback = PendingIntent.getBroadcast(
                            this,
                            noteId.hashCode(),
                            successIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                        )

                        val success = appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                "requestPinTaskWidget" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val taskId = call.argument<String>("taskId") ?: ""
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString("pending_pin_task_id", taskId)
                            .putLong("pending_pin_task_timestamp", System.currentTimeMillis())
                            .apply()

                        val myProvider = ComponentName(this, SingleTaskWidget::class.java)
                        val successIntent = Intent(this, WidgetPinSuccessReceiver::class.java).apply {
                            putExtra("item_type", "task")
                            putExtra("item_id", taskId)
                        }
                        val successCallback = PendingIntent.getBroadcast(
                            this,
                            taskId.hashCode(),
                            successIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                        )

                        val success = appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_LAUNCHER)) {
            clearLaunchIntentData()
        }
    }

    private fun clearLaunchIntentData() {
        intent?.data = null
        val cleanIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            data = null
        }
        setIntent(cleanIntent)
    }
}
