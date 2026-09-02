package com.quicknotes.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * MidnightWidgetUpdateReceiver — Native Android BroadcastReceiver and exact alarm listener.
 *
 * Listens for date changes, time changes, timezone changes, system boot, and midnight alarm ticks.
 * Triggers full widget redrawing across all QuickNotes widget providers and reschedules the exact
 * midnight tick for 00:00:01 AM every night.
 */
class MidnightWidgetUpdateReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MIDNIGHT_TICK = "com.quicknotes.app.ACTION_MIDNIGHT_WIDGET_TICK"

        /**
         * Schedules the next exact midnight tick via AlarmManager.
         */
        fun scheduleMidnightAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, MidnightWidgetUpdateReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 1)
                set(Calendar.MILLISECOND, 0)
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        midnight.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        midnight.timeInMillis,
                        pendingIntent
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        // 1. Refresh SingleTaskWidget (2x2)
        val singleTaskComponent = ComponentName(context, SingleTaskWidget::class.java)
        val singleTaskIds = appWidgetManager.getAppWidgetIds(singleTaskComponent)
        for (id in singleTaskIds) {
            SingleTaskWidget.updateAppWidget(context, appWidgetManager, id, prefs)
        }

        // 2. Refresh SingleTaskLongWidget (4x1)
        val singleTaskLongComponent = ComponentName(context, SingleTaskLongWidget::class.java)
        val singleTaskLongIds = appWidgetManager.getAppWidgetIds(singleTaskLongComponent)
        for (id in singleTaskLongIds) {
            SingleTaskLongWidget.updateAppWidget(context, appWidgetManager, id, prefs)
        }

        // 3. Refresh MultiTaskWidget (4x3 / 4x4)
        val multiTaskComponent = ComponentName(context, MultiTaskWidget::class.java)
        val multiTaskIds = appWidgetManager.getAppWidgetIds(multiTaskComponent)
        for (id in multiTaskIds) {
            MultiTaskWidget.updateAppWidget(context, appWidgetManager, id, prefs)
        }

        // 4. Reschedule next exact midnight alarm
        scheduleMidnightAlarm(context)
    }
}
