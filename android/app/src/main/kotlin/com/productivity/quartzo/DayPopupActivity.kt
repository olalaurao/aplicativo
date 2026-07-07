package com.productivity.quartzo

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetPlugin

class DayPopupActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val date = intent.getStringExtra("date") ?: ""
        val data = QuartzoWidgetUtils.json(
            HomeWidgetPlugin.getData(this).getString("Quartzo_calendar", null),
        )
        val mode = data.optString("mode", "day")

        // Resolve items for the tapped date across all three modes
        val items: org.json.JSONArray = when (mode) {
            "month" -> {
                // In month mode, find the matching cell in monthGrid
                val grid = QuartzoWidgetUtils.array(data, "monthGrid")
                val cell = (0 until grid.length())
                    .map { grid.optJSONObject(it) }
                    .firstOrNull { it?.optString("dateStr") == date }
                cell?.optJSONArray("items") ?: org.json.JSONArray()
            }
            "week" -> {
                val days = QuartzoWidgetUtils.array(data, "days")
                val day = (0 until days.length())
                    .map { days.optJSONObject(it) }
                    .firstOrNull { it?.optString("dateStr") == date }
                day?.optJSONArray("items") ?: org.json.JSONArray()
            }
            else -> {
                // Day mode: items are always at the root level
                QuartzoWidgetUtils.array(data, "items")
            }
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(44, 36, 44, 32)
            setBackgroundColor(QuartzoWidgetUtils.bgColor(this@DayPopupActivity))
        }
        root.addView(TextView(this).apply {
            text = date.ifBlank { "Dia" }
            textSize = 20f
            setTextColor(QuartzoWidgetUtils.textColor(this@DayPopupActivity))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })

        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 24, 0, 0)
        }
        if (items.length() == 0) {
            list.addView(TextView(this).apply {
                text = "Nada agendado para este dia"
                textSize = 16f
                gravity = Gravity.CENTER
                setTextColor(QuartzoWidgetUtils.mutedColor(this@DayPopupActivity))
                setPadding(0, 40, 0, 40)
            })
        } else {
            for (i in 0 until items.length()) {
                val item = items.optJSONObject(i) ?: continue
                list.addView(dayRow(item))
            }
        }

        val scroll = ScrollView(this).apply {
            addView(list)
        }
        root.addView(
            scroll,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ),
        )
        root.addView(TextView(this).apply {
            text = "Fechar"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(QuartzoWidgetUtils.accent)
            setPadding(0, 22, 0, 6)
            setOnClickListener { finish() }
        })
        setContentView(root)
    }

    private fun dayRow(item: org.json.JSONObject): LinearLayout {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 24)
            val linkUri = item.optString("linkUri", "")
            if (linkUri.isNotBlank()) {
                setOnClickListener {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(linkUri)))
                    finish()
                }
            }
        }
        row.addView(TextView(this).apply {
            text = item.optString("time")
            textSize = 16f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setTextColor(QuartzoWidgetUtils.accent)
        }, LinearLayout.LayoutParams(104, ViewGroup.LayoutParams.WRAP_CONTENT))
        row.addView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(TextView(this@DayPopupActivity).apply {
                text = item.optString("title")
                textSize = 18f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setTextColor(QuartzoWidgetUtils.textColor(this@DayPopupActivity))
            })
            addView(TextView(this@DayPopupActivity).apply {
                text = item.optString("subtitle")
                textSize = 14f
                setTextColor(QuartzoWidgetUtils.mutedColor(this@DayPopupActivity))
            })
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        return row
    }
}
