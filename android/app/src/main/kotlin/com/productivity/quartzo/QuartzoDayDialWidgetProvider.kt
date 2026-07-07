package com.productivity.quartzo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class QuartzoDayDialWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = QuartzoWidgetUtils.json(
            HomeWidgetPlugin.getData(context).getString("quartzo_day_dial", null),
        )

        val now = Date()
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        val dateFormat = SimpleDateFormat("EEE, d MMM", Locale.getDefault())
        val timeStr = data.optString("currentTime", timeFormat.format(now))
        val dateStr = data.optString("currentDate", dateFormat.format(now))
        val summary = data.optString("summary", "")
        val progress = data.optDouble("dayProgress", 0.5)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_day_dial)

            views.setInt(R.id.day_dial_root, "setBackgroundColor", QuartzoWidgetUtils.bgColor(context))
            views.setTextViewText(R.id.day_dial_time, timeStr)
            views.setTextViewText(R.id.day_dial_date, dateStr)
            views.setTextColor(R.id.day_dial_time, QuartzoWidgetUtils.textColor(context))
            views.setTextColor(R.id.day_dial_date, QuartzoWidgetUtils.mutedColor(context))

            if (summary.isNotEmpty()) {
                views.setTextViewText(R.id.day_dial_summary, summary)
                views.setTextColor(R.id.day_dial_summary, QuartzoWidgetUtils.mutedColor(context))
            }

            views.setFloat(R.id.day_progress_bar, "setLayoutWeight", progress.toFloat().coerceIn(0f, 1f))

            val openIntent = QuartzoWidgetUtils.openUriIntent(context, "quartzo:///planner")
            views.setOnClickPendingIntent(R.id.day_dial_root, openIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
