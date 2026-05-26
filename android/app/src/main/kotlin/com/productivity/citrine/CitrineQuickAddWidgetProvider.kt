package com.productivity.citrine

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class CitrineQuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = CitrineWidgetUtils.json(
            HomeWidgetPlugin.getData(context).getString("citrine_quick_add", null),
        )
        val buttons = CitrineWidgetUtils.array(data, "buttons")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_citrine_quick_add)
            views.setInt(R.id.quick_add_root, "setBackgroundColor", CitrineWidgetUtils.bgColor(context))

            val first = buttons.optJSONObject(0)
            val second = buttons.optJSONObject(1)
            views.setTextViewText(R.id.quick_add_btn_1, first?.optString("label", "Entrada") ?: "Entrada")
            views.setTextViewText(R.id.quick_add_btn_2, second?.optString("label", "Tarefa") ?: "Tarefa")
            views.setTextColor(R.id.quick_add_btn_1, CitrineWidgetUtils.textColor(context))
            views.setTextColor(R.id.quick_add_btn_2, CitrineWidgetUtils.textColor(context))
            views.setOnClickPendingIntent(
                R.id.quick_add_btn_1,
                CitrineWidgetUtils.openUriIntent(context, first?.optString("uri", "citrine:///create/entry") ?: "citrine:///create/entry"),
            )
            views.setOnClickPendingIntent(
                R.id.quick_add_btn_2,
                CitrineWidgetUtils.openUriIntent(context, second?.optString("uri", "citrine:///create/task") ?: "citrine:///create/task"),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
