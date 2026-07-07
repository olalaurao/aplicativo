package com.productivity.quartzo

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.EditText
import android.widget.Button
import android.widget.TextView
import android.content.Intent
import android.net.Uri
import android.view.inputmethod.InputMethodManager
import es.antonborri.home_widget.HomeWidgetPlugin

class QuickAddPopupActivity : Activity() {
    private lateinit var editText: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(44, 36, 44, 32)
            setBackgroundColor(QuartzoWidgetUtils.bgColor(this@QuickAddPopupActivity))
        }
        
        root.addView(TextView(this).apply {
            text = "Nova Tarefa"
            textSize = 20f
            setTextColor(QuartzoWidgetUtils.textColor(this@QuickAddPopupActivity))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })
        
        editText = EditText(this).apply {
            hint = "Digite a tarefa..."
            setHintTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setTextColor(QuartzoWidgetUtils.textColor(this@QuickAddPopupActivity))
            setBackgroundColor(QuartzoWidgetUtils.chipColor(this@QuickAddPopupActivity))
            setPadding(20, 16, 20, 16)
            setSingleLine(true)
        }
        
        root.addView(editView(editText), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))
        
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 24, 0, 0)
            gravity = Gravity.END
        }
        
        val cancelBtn = Button(this).apply {
            text = "Cancelar"
            setTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setOnClickListener { finish() }
        }
        
        val addBtn = Button(this).apply {
            text = "Adicionar"
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(QuartzoWidgetUtils.accent)
            setPadding(32, 12, 32, 12)
            setOnClickListener { 
                addTask()
                finish()
            }
        }
        
        buttons.addView(cancelBtn)
        buttons.addView(addBtn)
        
        root.addView(buttons)
        setContentView(root)
        
        // Show keyboard
        editText.post {
            editText.requestFocus()
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
        }
    }
    
    private fun editView(editText: EditText): LinearLayout {
        val container = LinearLayout(this)
        container.addView(editText)
        return container
    }
    
    private fun addTask() {
        val taskTitle = editText.text.toString().trim()
        if (taskTitle.isNotEmpty()) {
            // Send intent to Flutter app to create task in background
            val intent = Intent("es.antonborri.home_widget.action.BACKGROUND")
            intent.data = Uri.parse("Quartzo://widget-toggle?type=quick_add&title=${Uri.encode(taskTitle)}")
            sendBroadcast(intent)
        }
    }
    
    override fun finish() {
        // Hide keyboard
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(editText.windowToken, 0)
        super.finish()
    }
}
