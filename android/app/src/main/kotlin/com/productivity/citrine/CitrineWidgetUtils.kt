package com.productivity.citrine

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import org.json.JSONArray
import org.json.JSONObject

object CitrineWidgetUtils {
    const val accent = 0xFFFFB300.toInt()

    fun isDark(context: Context): Boolean {
        return (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    }

    fun bgColor(context: Context): Int = if (isDark(context)) 0xFF1F2024.toInt() else Color.WHITE
    fun textColor(context: Context): Int = if (isDark(context)) 0xFFF4F4F5.toInt() else 0xFF1F2430.toInt()
    fun mutedColor(context: Context): Int = if (isDark(context)) 0xFF9CA3AF.toInt() else 0xFF9AA0AA.toInt()
    fun chipColor(context: Context): Int = if (isDark(context)) 0xFF30323A.toInt() else 0xFFF0F1F3.toInt()
    fun softAccent(context: Context): Int = if (isDark(context)) 0xFF3A3020.toInt() else 0xFFFFF5E2.toInt()
    fun dividerColor(context: Context): Int = if (isDark(context)) 0xFF2C2E33.toInt() else 0xFFEEEEEE.toInt()

    fun json(raw: String?): JSONObject = try {
        if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
    } catch (_: Exception) {
        JSONObject()
    }

    fun array(obj: JSONObject, key: String): JSONArray = obj.optJSONArray(key) ?: JSONArray()

    /** Abre uma URI deep-link no MainActivity (citrine:///planner, citrine:///detail/xxx, etc.) */
    fun openUriIntent(context: Context, uri: String): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri), context, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            uri.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Abre o DayPopupActivity com a data selecionada */
    fun dayPopupIntent(context: Context, date: String): PendingIntent {
        val intent = Intent(context, DayPopupActivity::class.java)
        intent.putExtra("date", date)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            date.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Abre um item pelo seu linkUri (ex: "citrine:///detail/{id}").
     * Usa um requestCode único baseado no uri para evitar colisão de PendingIntents.
     */
    fun itemIntent(context: Context, linkUri: String): PendingIntent {
        return openUriIntent(context, linkUri)
    }

    fun backgroundIntent(context: Context, uri: String): PendingIntent {
        return HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uri))
    }

    fun backgroundTemplateIntent(context: Context): PendingIntent {
        val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java)
        intent.action = "es.antonborri.home_widget.action.BACKGROUND"

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 31) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        } else if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        return PendingIntent.getBroadcast(context, 0xC17A11, intent, flags)
    }

    /**
     * Configura um row de item no widget.
     * Se [item] for null, esconde o row. Caso contrário, mostra e conecta o deep link.
     */
    fun setRow(
        views: RemoteViews,
        rowId: Int,
        timeId: Int,
        titleId: Int,
        subtitleId: Int,
        item: JSONObject?,
        context: Context,
    ) {
        setRow(views, rowId, 0, timeId, titleId, subtitleId, item, context)
    }

    fun setRow(
        views: RemoteViews,
        rowId: Int,
        checkId: Int,
        timeId: Int,
        titleId: Int,
        subtitleId: Int,
        item: JSONObject?,
        context: Context,
    ) {
        if (item == null) {
            views.setViewVisibility(rowId, View.GONE)
            return
        }
        views.setViewVisibility(rowId, View.VISIBLE)
        val completed = item.optBoolean("completed", false)
        val type = item.optString("type", "")
        if (checkId != 0 && (type == "task" || type == "habit")) {
            views.setViewVisibility(checkId, View.VISIBLE)
            views.setTextViewText(checkId, if (completed) "✓" else "")
            views.setTextColor(checkId, if (completed) Color.WHITE else mutedColor(context))
            views.setInt(
                checkId,
                "setBackgroundResource",
                if (completed) R.drawable.widget_checkbox_checked else R.drawable.widget_checkbox_empty,
            )
            val toggleUri = item.optString("toggleUri", "")
            if (toggleUri.isNotBlank()) {
                views.setOnClickPendingIntent(
                    checkId,
                    backgroundIntent(context, toggleUri),
                )
            }
        } else if (checkId != 0) {
            views.setViewVisibility(checkId, View.INVISIBLE)
            views.setInt(checkId, "setBackgroundResource", 0)
        }
        if (timeId != 0) {
            views.setTextViewText(timeId, item.optString("time", ""))
            views.setTextColor(timeId, mutedColor(context))
        }
        views.setTextViewText(titleId, item.optString("title", ""))
        views.setTextViewText(subtitleId, item.optString("subtitle", ""))
        views.setTextColor(titleId, textColor(context))
        views.setTextColor(subtitleId, mutedColor(context))

        // Deep link para o detalhe do item ao clicar no row
        val linkUri = item.optString("linkUri", "").ifBlank {
            val id = item.optString("id", "")
            if (id.isNotBlank()) "citrine:///detail/$id" else "citrine:///planner"
        }
        views.setOnClickPendingIntent(rowId, itemIntent(context, linkUri))
    }

    fun setCollectionRow(
        views: RemoteViews,
        rowId: Int,
        checkId: Int,
        timeId: Int,
        titleId: Int,
        subtitleId: Int,
        item: JSONObject,
        context: Context,
    ) {
        views.setViewVisibility(rowId, View.VISIBLE)
        val completed = item.optBoolean("completed", false)
        val type = item.optString("type", "")
        if (type == "task" || type == "habit") {
            views.setViewVisibility(checkId, View.VISIBLE)
            views.setTextViewText(checkId, if (completed) "✓" else "")
            views.setTextColor(checkId, if (completed) Color.WHITE else mutedColor(context))
            views.setInt(
                checkId,
                "setBackgroundResource",
                if (completed) R.drawable.widget_checkbox_checked else R.drawable.widget_checkbox_empty,
            )
            val toggleUri = item.optString("toggleUri", "")
            if (toggleUri.isNotBlank()) {
                val fillInIntent = Intent()
                fillInIntent.data = Uri.parse(toggleUri)
                views.setOnClickFillInIntent(checkId, fillInIntent)
            }
        } else {
            views.setViewVisibility(checkId, View.INVISIBLE)
            views.setInt(checkId, "setBackgroundResource", 0)
        }
        views.setTextViewText(timeId, item.optString("time", ""))
        views.setTextColor(timeId, accent)
        views.setTextViewText(titleId, item.optString("title", ""))
        views.setTextViewText(subtitleId, item.optString("subtitle", ""))
        views.setTextColor(titleId, textColor(context))
        views.setTextColor(subtitleId, mutedColor(context))
    }

    /** Tipo de ícone de item baseado no campo "type" */
    fun typeEmoji(type: String): String = when (type) {
        "habit" -> "○"
        "reminder" -> "⏰"
        "google_calendar" -> "📅"
        else -> "•" // task
    }
}
