package com.productivity.quartzo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class QuartzoTasksWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = QuartzoWidgetUtils.json(widgetData.getString("Quartzo_tasks", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    private fun buildViews(context: Context, data: org.json.JSONObject): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_tasks)
        val items = QuartzoWidgetUtils.array(data, "items")

        views.setInt(R.id.tasks_root, "setBackgroundColor", QuartzoWidgetUtils.bgColor(context))
        views.setTextColor(R.id.tasks_title, QuartzoWidgetUtils.textColor(context))
        views.setTextColor(R.id.tasks_subtitle, QuartzoWidgetUtils.mutedColor(context))
        views.setTextColor(R.id.tasks_add_button, QuartzoWidgetUtils.textColor(context))

        views.setTextViewText(R.id.tasks_title, data.optString("title", "Tarefas"))
        views.setTextViewText(R.id.tasks_subtitle, data.optString("subtitle", "0 tarefas"))

        // Add button - open quick add popup
        views.setOnClickPendingIntent(
            R.id.tasks_add_button,
            QuartzoWidgetUtils.quickAddPopupIntent(context)
        )

        // Populate up to 8 task items
        for (i in 0 until minOf(items.length(), 8)) {
            val item = items.getJSONObject(i)
            val index = i + 1
            val itemContainerId = context.resources.getIdentifier("task_item_$index", "id", context.packageName)
            val checkboxId = context.resources.getIdentifier("task_checkbox_$index", "id", context.packageName)
            val titleId = context.resources.getIdentifier("task_title_$index", "id", context.packageName)
            val subtitleId = context.resources.getIdentifier("task_subtitle_$index", "id", context.packageName)

            views.setViewVisibility(itemContainerId, View.VISIBLE)
            views.setTextViewText(titleId, item.optString("title", ""))
            views.setTextColor(titleId, QuartzoWidgetUtils.textColor(context))
            
            val subtitle = item.optString("subtitle", "")
            if (subtitle.isNotEmpty()) {
                views.setViewVisibility(subtitleId, View.VISIBLE)
                views.setTextViewText(subtitleId, subtitle)
                views.setTextColor(subtitleId, QuartzoWidgetUtils.mutedColor(context))
            } else {
                views.setViewVisibility(subtitleId, View.GONE)
            }

            val completed = item.optBoolean("completed", false)
            views.setTextViewText(checkboxId, if (completed) "✓" else "○")
            views.setTextColor(checkboxId, if (completed) QuartzoWidgetUtils.accent(context) else QuartzoWidgetUtils.textColor(context))

            val toggleUri = item.optString("toggleUri", "")
            if (toggleUri.isNotEmpty()) {
                views.setOnClickPendingIntent(
                    checkboxId,
                    QuartzoWidgetUtils.backgroundIntent(context, toggleUri)
                )
            }
        }

        // Hide remaining items
        for (i in items.length() until 8) {
            val index = i + 1
            val itemContainerId = context.resources.getIdentifier("task_item_$index", "id", context.packageName)
            views.setViewVisibility(itemContainerId, View.GONE)
        }

        // Root click - open app
        views.setOnClickPendingIntent(
            R.id.tasks_root,
            QuartzoWidgetUtils.openUriIntent(context, "Quartzo:///planner")
        )

        return views
    }
}
