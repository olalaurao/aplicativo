package com.productivity.citrine

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

open class CitrineCalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val data = CitrineWidgetUtils.json(widgetData.getString("citrine_calendar", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data, id))
            appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.items_list_view)
        }
    }

    private fun buildViews(
        context: Context,
        data: org.json.JSONObject,
        appWidgetId: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_citrine_calendar)

        val mode = "week"
        val isDark = CitrineWidgetUtils.isDark(context)
        val bgColor = if (isDark) 0xFF1F2024.toInt() else android.graphics.Color.WHITE
        val textColor = if (isDark) 0xFFF4F4F5.toInt() else 0xFF1F2430.toInt()
        val mutedColor = if (isDark) 0xFF9CA3AF.toInt() else 0xFF9AA0AA.toInt()
        // Root background
        views.setInt(R.id.calendar_root, "setBackgroundColor", bgColor)

        // Header Title
        views.setTextColor(R.id.calendar_title, textColor)

        // Nav Area
        views.setTextViewText(R.id.nav_title, data.optString("selectedTitle", "Hoje"))
        views.setTextViewText(R.id.nav_subtitle, data.optString("selectedSubtitle", ""))
        views.setTextColor(R.id.nav_title, textColor)
        views.setTextColor(R.id.nav_subtitle, mutedColor)
        
        // Arrows navigation
        views.setOnClickPendingIntent(
            R.id.nav_prev,
            CitrineWidgetUtils.openUriIntent(
                context,
                "citrine://widget-toggle?type=calendar_offset&offset=-1",
            )
        )
        views.setOnClickPendingIntent(
            R.id.nav_next,
            CitrineWidgetUtils.openUriIntent(
                context,
                "citrine://widget-toggle?type=calendar_offset&offset=1",
            )
        )

        // Header actions
        views.setTextColor(R.id.widget_sync_button, mutedColor)
        views.setTextColor(R.id.widget_add_button, textColor)
        views.setOnClickPendingIntent(
            R.id.widget_sync_button,
            CitrineWidgetUtils.openUriIntent(
                context,
                "citrine://widget-toggle?type=calendar_offset&offset=0",
            )
        )
        views.setOnClickPendingIntent(
            R.id.widget_add_button,
            CitrineWidgetUtils.openUriIntent(
                context,
                "citrine:///",
            )
        )

        if (mode == "month") {
            views.setViewVisibility(R.id.container_day_week, View.GONE)
            views.setViewVisibility(R.id.container_month, View.VISIBLE)
            applyMonthGrid(views, context, data, textColor, mutedColor)
        } else {
            views.setViewVisibility(R.id.container_day_week, View.VISIBLE)
            views.setViewVisibility(R.id.container_month, View.GONE)
            applyDayWeek(views, context, data, mode, appWidgetId, textColor, mutedColor)
        }

        return views
    }

    private fun applyDayWeek(
        views: RemoteViews, 
        context: Context, 
        data: org.json.JSONObject, 
        mode: String,
        appWidgetId: Int,
        textColor: Int,
        mutedColor: Int
    ) {
        val days = CitrineWidgetUtils.array(data, "days")
        if (mode == "day") {
            views.setViewVisibility(R.id.week_strip_container, View.GONE)
        } else {
            views.setViewVisibility(R.id.week_strip_container, View.VISIBLE)
            for (i in 0 until 7) {
                val dayObj = days.optJSONObject(i)
                val headerId = context.resources.getIdentifier("strip_header_$i", "id", context.packageName)
                val numId = context.resources.getIdentifier("strip_day_num_$i", "id", context.packageName)
                val dotsId = context.resources.getIdentifier("strip_dots_$i", "id", context.packageName)
                val containerId = context.resources.getIdentifier("strip_day_container_$i", "id", context.packageName)
                
                if (dayObj != null) {
                    views.setTextViewText(headerId, dayObj.optString("dayHeader", ""))
                    views.setTextViewText(numId, dayObj.optString("dayNum", ""))
                    val isSelected = dayObj.optBoolean("isSelected", false)
                    views.setTextColor(numId, if (isSelected) CitrineWidgetUtils.accent else textColor)
                    
                    val dotCount = dayObj.optInt(
                        "dotCount",
                        if (dayObj.optBoolean("hasDots", false)) 3 else 0,
                    )
                    views.setViewVisibility(dotsId, if (dotCount > 0) View.VISIBLE else View.GONE)
                    views.setTextViewText(dotsId, "•".repeat(dotCount.coerceIn(1, 3)))
                    
                    val dateStr = dayObj.optString("dateStr", "")
                    if (dateStr.isNotEmpty()) {
                        views.setOnClickPendingIntent(
                            containerId,
                            CitrineWidgetUtils.dayPopupIntent(context, dateStr)
                        )
                    }
                }
            }
        }
        
        views.setTextViewText(R.id.hoje_tarefas_text, data.optString("subtitle", ""))
        views.setTextColor(R.id.hoje_tarefas_text, mutedColor)

        val adapterIntent = Intent(context, CitrineCalendarItemsService::class.java)
        adapterIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        val adapterMode = data.optString("mode", mode)
        adapterIntent.data = Uri.parse("citrine://calendar-items/$appWidgetId/$adapterMode")
        views.setRemoteAdapter(R.id.items_list_view, adapterIntent)
        views.setPendingIntentTemplate(
            R.id.items_list_view,
            CitrineWidgetUtils.backgroundTemplateIntent(context),
        )
    }

    private fun applyMonthGrid(
        views: RemoteViews, 
        context: Context, 
        data: org.json.JSONObject,
        textColor: Int,
        mutedColor: Int
    ) {
        val days = CitrineWidgetUtils.array(data, "days") // The 7 day headers
        for (i in 0 until 7) {
            val dayObj = days.optJSONObject(i)
            val headerId = context.resources.getIdentifier("month_header_$i", "id", context.packageName)
            if (dayObj != null) {
                views.setTextViewText(headerId, dayObj.optString("dayHeader", ""))
            }
        }
        
        val monthGrid = CitrineWidgetUtils.array(data, "monthGrid")
        for (i in 0 until 42) {
            val cellId = context.resources.getIdentifier("month_cell_$i", "id", context.packageName)
            val numId = context.resources.getIdentifier("month_cell_num_$i", "id", context.packageName)
            val p1Id = context.resources.getIdentifier("month_cell_pill1_$i", "id", context.packageName)
            val p2Id = context.resources.getIdentifier("month_cell_pill2_$i", "id", context.packageName)
            val p3Id = context.resources.getIdentifier("month_cell_pill3_$i", "id", context.packageName)
            val moreId = context.resources.getIdentifier("month_cell_more_$i", "id", context.packageName)
            
            val cellObj = monthGrid.optJSONObject(i)
            if (cellObj != null) {
                views.setViewVisibility(cellId, View.VISIBLE)
                val dayNum = cellObj.optString("dayNum", "")
                views.setTextViewText(numId, dayNum)

                val isCurrentMonth = cellObj.optBoolean("isCurrentMonth", true)
                val isToday = cellObj.optBoolean("isToday", false)

                // Today: white text on orange circle; current month: normal text; other: muted
                if (isToday) {
                    views.setTextColor(numId, android.graphics.Color.WHITE)
                    views.setInt(numId, "setBackgroundResource", R.drawable.widget_today_circle)
                } else {
                    views.setTextColor(numId, if (isCurrentMonth) textColor else mutedColor)
                    views.setInt(numId, "setBackgroundResource", 0)
                }

                val pills = CitrineWidgetUtils.array(cellObj, "pills")

                fun applyPill(id: Int, idx: Int) {
                    val p = pills.optJSONObject(idx)
                    if (p != null) {
                        views.setViewVisibility(id, View.VISIBLE)
                        views.setTextViewText(id, p.optString("title", ""))
                        // Color is the BACKGROUND of the pill chip (pastel), text stays dark
                        val colorStr = p.optString("color", "")
                        if (colorStr.isNotEmpty()) {
                            try {
                                val bg = android.graphics.Color.parseColor(colorStr)
                                views.setInt(id, "setBackgroundColor", bg)
                                views.setTextColor(id, 0xFF333333.toInt())
                            } catch (e: Exception) {
                                views.setTextColor(id, textColor)
                            }
                        } else {
                            views.setTextColor(id, textColor)
                        }
                    } else {
                        views.setViewVisibility(id, View.GONE)
                    }
                }

                applyPill(p1Id, 0)
                applyPill(p2Id, 1)
                applyPill(p3Id, 2)

                val moreCount = cellObj.optInt("moreCount", 0)
                if (moreCount > 0) {
                    views.setViewVisibility(moreId, View.VISIBLE)
                    views.setTextViewText(moreId, "+$moreCount mais")
                } else {
                    views.setViewVisibility(moreId, View.GONE)
                }

                val dateStr = cellObj.optString("dateStr", "")
                if (dateStr.isNotEmpty()) {
                    views.setOnClickPendingIntent(
                        cellId,
                        CitrineWidgetUtils.dayPopupIntent(context, dateStr)
                    )
                }

            } else {
                views.setViewVisibility(cellId, View.INVISIBLE)
            }
        }
    }
}
