package com.productivity.quartzo

import android.content.Context
import android.content.Intent

class QuartzoCalendarWidgetReceiver : QuartzoCalendarWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        // Handle background widget refresh intents
        if (intent.action == "es.antonborri.home_widget.action.BACKGROUND") {
            val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, QuartzoCalendarWidgetReceiver::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
            return
        }
        super.onReceive(context, intent)
    }
}
