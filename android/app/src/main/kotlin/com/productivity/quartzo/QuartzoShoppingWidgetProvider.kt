package com.productivity.quartzo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

open class QuartzoShoppingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = QuartzoWidgetUtils.json(widgetData.getString("Quartzo_shopping", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    private fun buildViews(context: Context, data: org.json.JSONObject): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_quartzo_shopping)
        val items = QuartzoWidgetUtils.array(data, "items")

        views.setInt(R.id.shopping_root, "setBackgroundColor", QuartzoWidgetUtils.bgColor(context))
        views.setTextColor(R.id.shopping_title, QuartzoWidgetUtils.textColor(context))
        views.setTextColor(R.id.shopping_subtitle, QuartzoWidgetUtils.mutedColor(context))
        views.setTextColor(R.id.shopping_sync_btn, QuartzoWidgetUtils.mutedColor(context))
        views.setTextColor(R.id.shopping_add_btn, QuartzoWidgetUtils.textColor(context))

        views.setTextViewText(R.id.shopping_title, data.optString("title", "Lista de Mercado"))
        views.setTextViewText(R.id.shopping_subtitle, data.optString("subtitle", "0 pendentes"))

        // Sync button - refresh widget without opening app
        views.setOnClickPendingIntent(
            R.id.shopping_sync_btn,
            QuartzoWidgetUtils.backgroundIntent(
                context,
                "Quartzo://widget-toggle?type=refresh_widgets"
            )
        )

        // Add button - open shopping add popup
        views.setOnClickPendingIntent(
            R.id.shopping_add_btn,
            QuartzoWidgetUtils.shoppingAddPopupIntent(context)
        )

        val isDark = QuartzoWidgetUtils.isDark(context)

        views.removeAllViews(R.id.shopping_list)
        if (items.length() == 0) {
            val emptyView = RemoteViews(context.packageName, R.layout.widget_item_shopping_empty)
            emptyView.setTextViewText(R.id.empty_text, "Nenhum item pendente")
            emptyView.setTextColor(R.id.empty_text, QuartzoWidgetUtils.mutedColor(context))
            views.addView(R.id.shopping_list, emptyView)
        } else {
            // Limit to 5 items for better performance and memory efficiency
            for (i in 0 until minOf(items.length(), 5)) {
                val item = items.getJSONObject(i)
                val itemView = RemoteViews(context.packageName, R.layout.widget_item_shopping)
                
                itemView.setTextViewText(R.id.shopping_title, item.optString("title"))
                itemView.setTextColor(R.id.shopping_title, QuartzoWidgetUtils.textColor(context))
                
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
                        QuartzoWidgetUtils.backgroundIntent(context, toggleUri)
                    )
                }

                views.addView(R.id.shopping_list, itemView)
            }
        }

        views.setOnClickPendingIntent(
            R.id.shopping_root,
            QuartzoWidgetUtils.openUriIntent(context, "Quartzo:///shopping")
        )

        return views
    }
}
