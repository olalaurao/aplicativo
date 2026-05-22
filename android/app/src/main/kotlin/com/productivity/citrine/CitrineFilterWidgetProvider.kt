package com.productivity.citrine

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

open class CitrineFilterWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = CitrineWidgetUtils.json(widgetData.getString("citrine_filter", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    private fun buildViews(context: Context, data: org.json.JSONObject): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_citrine_filter)
        val items = CitrineWidgetUtils.array(data, "items")
        val chips = CitrineWidgetUtils.array(data, "chips")
        val done = data.optInt("progressDone")
        val total = data.optInt("progressTotal")

        views.setInt(R.id.filter_root, "setBackgroundColor", CitrineWidgetUtils.bgColor(context))
        views.setTextColor(R.id.filter_title, CitrineWidgetUtils.textColor(context))
        views.setTextColor(R.id.filter_menu, CitrineWidgetUtils.mutedColor(context))
        views.setTextViewText(R.id.filter_organizer, data.optString("organizer", "Sem filtro"))
        views.setTextColor(R.id.filter_organizer, CitrineWidgetUtils.mutedColor(context))
        views.setInt(R.id.filter_progress_box, "setBackgroundColor", CitrineWidgetUtils.softAccent(context))
        views.setTextColor(R.id.filter_progress_label, CitrineWidgetUtils.textColor(context))
        views.setTextColor(R.id.filter_progress_value, CitrineWidgetUtils.textColor(context))
        views.setTextViewText(R.id.filter_progress_value, "$done/$total")

        val chipIds = intArrayOf(R.id.filter_chip_0, R.id.filter_chip_1, R.id.filter_chip_2)
        for (i in chipIds.indices) {
            val chip = chips.optJSONObject(i)
            if (chip == null) {
                views.setViewVisibility(chipIds[i], View.GONE)
            } else {
                views.setViewVisibility(chipIds[i], View.VISIBLE)
                views.setTextViewText(chipIds[i], "${chip.optString("label")} · ${chip.optInt("count")}")
                views.setTextColor(chipIds[i], CitrineWidgetUtils.mutedColor(context))
                views.setInt(chipIds[i], "setBackgroundColor", CitrineWidgetUtils.chipColor(context))
            }
        }

        val rows = arrayOf(
            intArrayOf(R.id.filter_row_0, R.id.filter_type_0, R.id.filter_item_0, R.id.filter_subtitle_0),
            intArrayOf(R.id.filter_row_1, R.id.filter_type_1, R.id.filter_item_1, R.id.filter_subtitle_1),
            intArrayOf(R.id.filter_row_2, R.id.filter_type_2, R.id.filter_item_2, R.id.filter_subtitle_2),
        )
        for (i in rows.indices) {
            val item = items.optJSONObject(i)
            if (item == null) {
                views.setViewVisibility(rows[i][0], View.GONE)
            } else {
                val row = org.json.JSONObject()
                    .put("id", item.optString("id"))
                    .put("type", item.optString("type"))
                    .put("title", item.optString("title"))
                    .put("subtitle", item.optString("subtitle"))
                    .put("completed", item.optBoolean("completed", false))
                    .put("linkUri", item.optString("linkUri"))
                    .put("toggleUri", item.optString("toggleUri"))
                CitrineWidgetUtils.setRow(
                    views,
                    rows[i][0],
                    rows[i][1],
                    0,
                    rows[i][2],
                    rows[i][3],
                    row,
                    context,
                )
            }
        }
        views.setViewVisibility(R.id.filter_empty, if (items.length() == 0) View.VISIBLE else View.GONE)
        views.setTextColor(R.id.filter_empty, CitrineWidgetUtils.mutedColor(context))
        views.setTextColor(R.id.filter_add_task, CitrineWidgetUtils.mutedColor(context))
        views.setOnClickPendingIntent(R.id.filter_add_task, CitrineWidgetUtils.openUriIntent(context, "citrine:///create/task"))
        views.setOnClickPendingIntent(R.id.filter_menu, CitrineWidgetUtils.openUriIntent(context, "citrine:///"))
        return views
    }
}
