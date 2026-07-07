package com.productivity.quartzo

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class QuartzoCalendarItemsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return QuartzoCalendarItemsFactory(applicationContext)
    }
}

private class QuartzoCalendarItemsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var items = JSONArray()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = QuartzoWidgetUtils.json(widgetData.getString("Quartzo_calendar", null))
        val regularItems = QuartzoWidgetUtils.array(data, "items")
        val overdueItems = QuartzoWidgetUtils.array(data, "overdue")
        items = JSONArray()
        for (i in 0 until overdueItems.length()) {
            val overdue = overdueItems.optJSONObject(i) ?: continue
            val enriched = JSONObject(overdue.toString())
            enriched.put("isOverdue", true)
            enriched.put("time", "âš ")
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
            QuartzoWidgetUtils.setCollectionRow(
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
