package com.productivity.citrine

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

class ShoppingAddPopupActivity : Activity() {
    private lateinit var editText: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(44, 36, 44, 32)
            setBackgroundColor(CitrineWidgetUtils.bgColor(this@ShoppingAddPopupActivity))
        }
        
        root.addView(TextView(this).apply {
            text = "Novo Item"
            textSize = 20f
            setTextColor(CitrineWidgetUtils.textColor(this@ShoppingAddPopupActivity))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })
        
        editText = EditText(this).apply {
            hint = "Digite o item..."
            setHintTextColor(CitrineWidgetUtils.mutedColor(this@ShoppingAddPopupActivity))
            setTextColor(CitrineWidgetUtils.textColor(this@ShoppingAddPopupActivity))
            setBackgroundColor(CitrineWidgetUtils.chipColor(this@ShoppingAddPopupActivity))
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
            setTextColor(CitrineWidgetUtils.mutedColor(this@ShoppingAddPopupActivity))
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setOnClickListener { finish() }
        }
        
        val addBtn = Button(this).apply {
            text = "Adicionar"
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(CitrineWidgetUtils.accent)
            setPadding(32, 12, 32, 12)
            setOnClickListener { 
                addShoppingItem()
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
    
    private fun addShoppingItem() {
        val itemName = editText.text.toString().trim()
        if (itemName.isNotEmpty()) {
            // Send intent to Flutter app to create shopping item in background
            val intent = Intent("es.antonborri.home_widget.action.BACKGROUND")
            intent.data = Uri.parse("citrine://widget-toggle?type=shopping_add&name=${Uri.encode(itemName)}")
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
