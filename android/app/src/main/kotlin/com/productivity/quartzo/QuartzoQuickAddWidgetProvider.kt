package com.productivity.quartzo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class QuartzoQuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = QuartzoWidgetUtils.json(
            HomeWidgetPlugin.getData(context).getString("Quartzo_quick_add", null),
        )
        val buttons = QuartzoWidgetUtils.array(data, "buttons")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quartzo_quick_add)
            views.setInt(R.id.quick_add_root, "setBackgroundColor", QuartzoWidgetUtils.bgColor(context))

            val first = buttons.optJSONObject(0)
            val second = buttons.optJSONObject(1)
            views.setTextViewText(R.id.quick_add_btn_1, first?.optString("label", "Entrada") ?: "Entrada")
            views.setTextViewText(R.id.quick_add_btn_2, second?.optString("label", "Tarefa") ?: "Tarefa")
            views.setTextColor(R.id.quick_add_btn_1, QuartzoWidgetUtils.textColor(context))
            views.setTextColor(R.id.quick_add_btn_2, QuartzoWidgetUtils.textColor(context))
            views.setOnClickPendingIntent(
                R.id.quick_add_btn_1,
                QuartzoWidgetUtils.openUriIntent(context, first?.optString("uri", "Quartzo:///create/entry") ?: "Quartzo:///create/entry"),
            )
            views.setOnClickPendingIntent(
                R.id.quick_add_btn_2,
                QuartzoWidgetUtils.openUriIntent(context, second?.optString("uri", "Quartzo:///create/task") ?: "Quartzo:///create/task"),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
