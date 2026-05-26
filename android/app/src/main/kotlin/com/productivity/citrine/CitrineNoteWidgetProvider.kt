package com.productivity.citrine

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class CitrineNoteWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = CitrineWidgetUtils.json(
            HomeWidgetPlugin.getData(context).getString("citrine_note", null),
        )
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_citrine_note)
            views.setInt(R.id.note_root, "setBackgroundColor", CitrineWidgetUtils.bgColor(context))
            views.setTextViewText(R.id.note_title, data.optString("title", "Nota"))
            views.setTextViewText(R.id.note_content, data.optString("content", "Selecione uma nota no Citrine"))
            views.setTextColor(R.id.note_title, CitrineWidgetUtils.textColor(context))
            views.setTextColor(R.id.note_content, CitrineWidgetUtils.mutedColor(context))
            views.setOnClickPendingIntent(
                R.id.note_root,
                CitrineWidgetUtils.openUriIntent(context, data.optString("linkUri", "citrine:///notes")),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
