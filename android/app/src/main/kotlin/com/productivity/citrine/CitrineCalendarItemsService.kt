package com.productivity.citrine

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class CitrineCalendarItemsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CitrineCalendarItemsFactory(applicationContext)
    }
}

private class CitrineCalendarItemsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var items = JSONArray()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = CitrineWidgetUtils.json(widgetData.getString("citrine_calendar", null))
        val regularItems = CitrineWidgetUtils.array(data, "items")
        val overdueItems = CitrineWidgetUtils.array(data, "overdue")
        items = JSONArray()
        for (i in 0 until overdueItems.length()) {
            val overdue = overdueItems.optJSONObject(i) ?: continue
            val enriched = JSONObject(overdue.toString())
            enriched.put("isOverdue", true)
            enriched.put("time", "⚠")
            enriched.put(
                "subtitle",
                "${overdue.optInt("daysLate", 0)} dia(s) atrasado",
            )
            items.put(enriched)
        }
        for (i in 0 until regularItems.length()) {
            items.put(regularItems.optJSONObject(i))
        }
    }

    override fun onDestroy() {
        items = JSONArray()
    }

    override fun getCount(): Int = items.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_list_item)
        val item = items.optJSONObject(position)
        if (item != null) {
            CitrineWidgetUtils.setCollectionRow(
                views,
                R.id.calendar_item_row,
                R.id.calendar_item_checkbox,
                R.id.calendar_item_time,
                R.id.calendar_item_title,
                R.id.calendar_item_subtitle,
                item,
                context,
            )
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        return items.optJSONObject(position)?.optString("id", position.toString())?.hashCode()?.toLong()
            ?: position.toLong()
    }

    override fun hasStableIds(): Boolean = false
}
