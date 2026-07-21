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

class OverduePopupActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val data = QuartzoWidgetUtils.json(
            HomeWidgetPlugin.getData(this).getString("Quartzo_calendar", null),
        )
        val overdue = QuartzoWidgetUtils.array(data, "overdue")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(44, 36, 44, 32)
            setBackgroundColor(QuartzoWidgetUtils.bgColor(this@OverduePopupActivity))
        }
        
        val overdueCount = data.optInt("overdueCount", 0)
        root.addView(TextView(this).apply {
            text = "Atrasados ($overdueCount)"
            textSize = 20f
            setTextColor(0xFFEF4444.toInt())
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })

        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 24, 0, 0)
        }
        if (overdue.length() == 0) {
            list.addView(TextView(this).apply {
                text = "Nenhuma tarefa atrasada"
                textSize = 16f
                gravity = Gravity.CENTER
                setTextColor(QuartzoWidgetUtils.mutedColor(this@OverduePopupActivity))
                setPadding(0, 40, 0, 40)
            })
        } else {
            for (i in 0 until overdue.length()) {
                val item = overdue.optJSONObject(i) ?: continue
                list.addView(overdueRow(item))
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
            setTextColor(QuartzoWidgetUtils.accent(this@OverduePopupActivity))
            setPadding(0, 22, 0, 6)
            setOnClickListener { finish() }
        })
        setContentView(root)
    }

    private fun overdueRow(item: org.json.JSONObject): LinearLayout {
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
        
        val daysLate = item.optInt("daysLate", 0)
        val lateText = when {
            daysLate == 1 -> "1 dia"
            daysLate > 1 -> "$daysLate dias"
            else -> ""
        }
        
        row.addView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(TextView(this@OverduePopupActivity).apply {
                text = item.optString("title")
                textSize = 18f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setTextColor(QuartzoWidgetUtils.textColor(this@OverduePopupActivity))
            })
            addView(TextView(this@OverduePopupActivity).apply {
                text = if (lateText.isNotEmpty()) "Atrasado: $lateText" else ""
                textSize = 14f
                setTextColor(0xFFEF4444.toInt())
            })
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        
        return row
    }
}
