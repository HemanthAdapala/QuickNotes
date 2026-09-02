package com.quicknotes.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CLEAR_CHANNEL = "com.quicknotes.app/deep_link_clear"

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
