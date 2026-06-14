package com.productivity.citrine

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

open class CitrineShoppingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = CitrineWidgetUtils.json(widgetData.getString("citrine_shopping", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    private fun buildViews(context: Context, data: org.json.JSONObject): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_citrine_shopping)
        val items = CitrineWidgetUtils.array(data, "items")

        views.setInt(R.id.shopping_root, "setBackgroundColor", CitrineWidgetUtils.bgColor(context))
        views.setTextColor(R.id.shopping_title, CitrineWidgetUtils.textColor(context))
        views.setTextColor(R.id.shopping_subtitle, CitrineWidgetUtils.mutedColor(context))

        views.setTextViewText(R.id.shopping_title, data.optString("title", "Lista de Mercado"))
        views.setTextViewText(R.id.shopping_subtitle, data.optString("subtitle", "0 pendentes"))

        val isDark = CitrineWidgetUtils.isDark(context)

        views.removeAllViews(R.id.shopping_list)
        if (items.length() == 0) {
            val emptyView = RemoteViews(context.packageName, R.layout.widget_item_shopping_empty)
            emptyView.setTextViewText(R.id.empty_text, "Nenhum item pendente")
            emptyView.setTextColor(R.id.empty_text, CitrineWidgetUtils.mutedColor(context))
            views.addView(R.id.shopping_list, emptyView)
        } else {
            for (i in 0 until minOf(items.length(), 6)) {
                val item = items.getJSONObject(i)
                val itemView = RemoteViews(context.packageName, R.layout.widget_item_shopping)
                
                itemView.setTextViewText(R.id.shopping_title, item.optString("title"))
                itemView.setTextColor(R.id.shopping_title, CitrineWidgetUtils.textColor(context))
                
                val completed = item.optBoolean("completed", false)
                if (completed) {
                    itemView.setImageViewResource(R.id.shopping_checkbox, R.drawable.widget_checkbox_checked)
                } else {
                    itemView.setImageViewResource(R.id.shopping_checkbox, R.drawable.widget_checkbox_empty)
                }

                val toggleUri = item.optString("toggleUri", "")
                if (toggleUri.isNotEmpty()) {
                    itemView.setOnClickPendingIntent(
                        R.id.shopping_checkbox,
                        CitrineWidgetUtils.backgroundIntent(context, toggleUri)
                    )
                }

                views.addView(R.id.shopping_list, itemView)
            }
        }

        views.setOnClickPendingIntent(
            R.id.shopping_root,
            CitrineWidgetUtils.openUriIntent(context, "citrine:///shopping")
        )

        views.setOnClickPendingIntent(
            R.id.shopping_add_btn,
            CitrineWidgetUtils.openUriIntent(context, "citrine:///shopping")
        )

        return views
    }
}
