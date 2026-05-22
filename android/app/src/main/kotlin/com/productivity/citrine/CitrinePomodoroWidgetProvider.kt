package com.productivity.citrine

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.max

open class CitrinePomodoroWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = CitrineWidgetUtils.json(widgetData.getString("citrine_pomodoro", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    private fun buildViews(context: Context, data: org.json.JSONObject): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_citrine_pomodoro)
        val bars = CitrineWidgetUtils.array(data, "bars")
        var maxHours = 0.0
        for (i in 0 until bars.length()) {
            maxHours = max(maxHours, bars.optJSONObject(i)?.optDouble("hours") ?: 0.0)
        }

        views.setInt(R.id.pomodoro_root, "setBackgroundColor", CitrineWidgetUtils.bgColor(context))
        views.setTextViewText(R.id.pomodoro_total, data.optString("total", "0h"))
        views.setTextViewText(R.id.pomodoro_details, data.optString("details", "this week"))
        views.setTextViewText(R.id.pomodoro_average, data.optString("average", "~0h per day"))
        views.setTextColor(R.id.pomodoro_total, CitrineWidgetUtils.accent)
        views.setTextColor(R.id.pomodoro_details, CitrineWidgetUtils.mutedColor(context))
        views.setTextColor(R.id.pomodoro_average, CitrineWidgetUtils.mutedColor(context))
        views.setTextColor(R.id.pomodoro_start, 0xFFFFFFFF.toInt())
        views.setInt(R.id.pomodoro_start, "setBackgroundColor", CitrineWidgetUtils.accent)
        views.setOnClickPendingIntent(R.id.pomodoro_start, CitrineWidgetUtils.openUriIntent(context, "citrine:///pomodoro?action=start_with_picker"))

        val barIds = intArrayOf(
            R.id.pomo_bar_0, R.id.pomo_bar_1, R.id.pomo_bar_2, R.id.pomo_bar_3,
            R.id.pomo_bar_4, R.id.pomo_bar_5, R.id.pomo_bar_6,
        )
        val labelIds = intArrayOf(
            R.id.pomo_label_0, R.id.pomo_label_1, R.id.pomo_label_2, R.id.pomo_label_3,
            R.id.pomo_label_4, R.id.pomo_label_5, R.id.pomo_label_6,
        )
        for (i in barIds.indices) {
            val item = bars.optJSONObject(i)
            val hours = item?.optDouble("hours") ?: 0.0
            val heightDp = if (maxHours <= 0.0) 4 else (8 + (hours / maxHours * 54)).toInt()
            val heightPx = (heightDp * context.resources.displayMetrics.density).toInt()
            views.setInt(barIds[i], "setMinimumHeight", heightPx)
            views.setInt(barIds[i], "setBackgroundColor", if (hours > 0.0) CitrineWidgetUtils.accent else CitrineWidgetUtils.chipColor(context))
            views.setTextViewText(labelIds[i], item?.optString("label") ?: "")
            views.setTextColor(labelIds[i], CitrineWidgetUtils.mutedColor(context))
        }
        return views
    }
}
