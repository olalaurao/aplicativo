package com.productivity.quartzo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class QuartzoNoteWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = QuartzoWidgetUtils.json(
            HomeWidgetPlugin.getData(context).getString("Quartzo_note", null),
        )
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quartzo_note)
            views.setInt(R.id.note_root, "setBackgroundColor", QuartzoWidgetUtils.bgColor(context))
            views.setTextViewText(R.id.note_title, data.optString("title", "Nota"))
            views.setTextViewText(R.id.note_content, data.optString("content", "Selecione uma nota no Quartzo"))
            views.setTextColor(R.id.note_title, QuartzoWidgetUtils.textColor(context))
            views.setTextColor(R.id.note_content, QuartzoWidgetUtils.mutedColor(context))
            views.setOnClickPendingIntent(
                R.id.note_root,
                QuartzoWidgetUtils.openUriIntent(context, data.optString("linkUri", "Quartzo:///notes")),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
