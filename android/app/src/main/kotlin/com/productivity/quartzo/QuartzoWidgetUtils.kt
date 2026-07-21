package com.productivity.quartzo

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

object QuartzoWidgetUtils {
    fun isDark(context: Context): Boolean {
        return (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    }

    fun accent(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        context.getColor(R.color.quartzo_accent)
    } else {
        @Suppress("DEPRECATION")
        context.resources.getColor(R.color.quartzo_accent)
    }

    fun bgColor(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        if (isDark(context)) context.getColor(R.color.quartzo_dark_background) else context.getColor(R.color.quartzo_background)
    } else {
        @Suppress("DEPRECATION")
        if (isDark(context)) context.resources.getColor(R.color.quartzo_dark_background) else context.resources.getColor(R.color.quartzo_background)
    }

    fun textColor(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        if (isDark(context)) context.getColor(R.color.quartzo_dark_text_primary) else context.getColor(R.color.quartzo_text_primary)
    } else {
        @Suppress("DEPRECATION")
        if (isDark(context)) context.resources.getColor(R.color.quartzo_dark_text_primary) else context.resources.getColor(R.color.quartzo_text_primary)
    }

    fun mutedColor(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        if (isDark(context)) context.getColor(R.color.quartzo_dark_text_secondary) else context.getColor(R.color.quartzo_text_secondary)
    } else {
        @Suppress("DEPRECATION")
        if (isDark(context)) context.resources.getColor(R.color.quartzo_dark_text_secondary) else context.resources.getColor(R.color.quartzo_text_secondary)
    }

    fun chipColor(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        if (isDark(context)) context.getColor(R.color.quartzo_dark_card_fill) else context.getColor(R.color.quartzo_surface_variant)
    } else {
        @Suppress("DEPRECATION")
        if (isDark(context)) context.resources.getColor(R.color.quartzo_dark_card_fill) else context.resources.getColor(R.color.quartzo_surface_variant)
    }

    fun softAccent(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        if (isDark(context)) context.getColor(R.color.quartzo_dark_card_fill) else context.getColor(R.color.quartzo_surface_variant)
    } else {
        @Suppress("DEPRECATION")
        if (isDark(context)) context.resources.getColor(R.color.quartzo_dark_card_fill) else context.resources.getColor(R.color.quartzo_surface_variant)
    }

    fun dividerColor(context: Context): Int = if (Build.VERSION.SDK_INT >= 23) {
        if (isDark(context)) context.getColor(R.color.quartzo_dark_divider) else context.getColor(R.color.quartzo_divider)
    } else {
        @Suppress("DEPRECATION")
        if (isDark(context)) context.resources.getColor(R.color.quartzo_dark_divider) else context.resources.getColor(R.color.quartzo_divider)
    }

    fun json(raw: String?): JSONObject = try {
        if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
    } catch (_: Exception) {
        JSONObject()
    }

    fun array(obj: JSONObject, key: String): JSONArray = obj.optJSONArray(key) ?: JSONArray()

    fun displayText(item: JSONObject, vararg keys: String, fallback: String = "Sem tÃ­tulo"): String {
        for (key in keys) {
            val value = item.optString(key, "").trim()
            if (value.isNotBlank() && !looksLikeTechnicalId(value)) return value
        }
        return fallback
    }

    private fun looksLikeTechnicalId(value: String): Boolean {
        return Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").matches(value) ||
            Regex("^\\d{10,}$").matches(value)
    }

    /** Abre uma URI deep-link no MainActivity (Quartzo:///planner, Quartzo:///detail/xxx, etc.) */
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

    /** Abre o Planner no dia selecionado via deep link */
    fun dayPopupIntent(context: Context, date: String): PendingIntent {
        return openUriIntent(context, "Quartzo:///planner/day/$date")
    }

    /** Abre popup de tarefas atrasadas */
    fun overduePopupIntent(context: Context): PendingIntent {
        val intent = Intent(context, OverduePopupActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Abre popup de adiÃ§Ã£o rÃ¡pida de tarefa */
    fun quickAddPopupIntent(context: Context): PendingIntent {
        val intent = Intent(context, QuickAddPopupActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            1002,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Abre popup de adiÃ§Ã£o de item de shopping */
    fun shoppingAddPopupIntent(context: Context): PendingIntent {
        val intent = Intent(context, ShoppingAddPopupActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            1003,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Abre um item pelo seu linkUri (ex: "Quartzo:///detail/{id}").
     * Usa um requestCode Ãºnico baseado no uri para evitar colisÃ£o de PendingIntents.
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
     * Se [item] for null, esconde o row. Caso contrÃ¡rio, mostra e conecta o deep link.
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
            views.setTextViewText(checkId, if (completed) "âœ“" else "")
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
        views.setTextViewText(titleId, displayText(item, "title", "label"))
        views.setTextViewText(subtitleId, displayText(item, "subtitle", fallback = ""))
        views.setTextColor(titleId, textColor(context))
        views.setTextColor(subtitleId, mutedColor(context))

        // Deep link para o detalhe do item ao clicar no row
        val linkUri = item.optString("linkUri", "").ifBlank {
            "Quartzo:///planner"
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
            views.setTextViewText(checkId, if (completed) "âœ“" else "")
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
        views.setTextColor(timeId, accent(context))
        views.setTextViewText(titleId, displayText(item, "title", "label"))
        views.setTextViewText(subtitleId, displayText(item, "subtitle", fallback = ""))
        views.setTextColor(titleId, textColor(context))
        views.setTextColor(subtitleId, mutedColor(context))
    }

    /** Tipo de Ã­cone de item baseado no campo "type" */
    fun typeEmoji(type: String): String = when (type) {
        "habit" -> "â—‹"
        "reminder" -> "â°"
        "google_calendar" -> "ðŸ“…"
        else -> "â€¢" // task
    }
}
