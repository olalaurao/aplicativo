package com.productivity.quartzo

import android.app.Activity
import android.app.DatePickerDialog
import android.content.Intent
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class QuickAddPopupActivity : Activity() {
    private lateinit var editText: EditText
    private lateinit var notesEditText: EditText
    private lateinit var detailsToggle: TextView
    private lateinit var detailsContainer: LinearLayout
    private lateinit var dueDateButton: TextView
    private lateinit var priorityRow: LinearLayout
    private lateinit var priorityButtons: Map<String, TextView>
    private lateinit var typeButtons: Map<String, TextView>
    private var selectedType: String = "task"
    private var detailsExpanded: Boolean = false
    private var selectedDueDateIso: String? = null
    private var selectedPriority: String = "none"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(44, 36, 44, 32)
            setBackgroundColor(QuartzoWidgetUtils.bgColor(this@QuickAddPopupActivity))
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        header.addView(TextView(this).apply {
            text = "Quick add"
            textSize = 20f
            setTextColor(QuartzoWidgetUtils.textColor(this@QuickAddPopupActivity))
            typeface = Typeface.DEFAULT_BOLD
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        header.addView(TextView(this).apply {
            text = "×"
            textSize = 26f
            gravity = Gravity.CENTER
            setTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setOnClickListener { finish() }
        }, LinearLayout.LayoutParams(56, 56))

        root.addView(header)

        val typeRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 20, 0, 16)
        }

        val buttons = linkedMapOf(
            "task" to typeButton("Task"),
            "event" to typeButton("Event"),
            "habit" to typeButton("Habit"),
            "goal" to typeButton("Goal"),
            "reminder" to typeButton("Reminder"),
        )
        typeButtons = buttons
        buttons.forEach { (type, view) ->
            view.setOnClickListener {
                selectedType = type
                updateTypeButtons()
                editText.hint = hintForType(type)
            }
            typeRow.addView(view)
        }
        root.addView(typeRow)
        updateTypeButtons()

        editText = EditText(this).apply {
            hint = hintForType(selectedType)
            setHintTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setTextColor(QuartzoWidgetUtils.textColor(this@QuickAddPopupActivity))
            setBackgroundColor(QuartzoWidgetUtils.chipColor(this@QuickAddPopupActivity))
            setPadding(24, 18, 24, 18)
            setSingleLine(true)
            setOnEditorActionListener { _, _, _ ->
                save()
                true
            }
        }

        root.addView(editText, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        detailsToggle = TextView(this).apply {
            text = "+ Add details"
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setPadding(0, 22, 0, 10)
            setOnClickListener {
                detailsExpanded = !detailsExpanded
                updateDetailsVisibility()
            }
        }
        root.addView(detailsToggle)

        detailsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
        }

        dueDateButton = TextView(this).apply {
            text = "Due date"
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setBackgroundColor(QuartzoWidgetUtils.chipColor(this@QuickAddPopupActivity))
            setPadding(24, 18, 24, 18)
            setOnClickListener { showDueDatePicker() }
        }
        detailsContainer.addView(dueDateButton, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 12
        })

        priorityRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 12)
        }
        priorityRow.addView(TextView(this).apply {
            text = "Priority"
            textSize = 15f
            setTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            typeface = Typeface.DEFAULT_BOLD
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        priorityButtons = linkedMapOf(
            "low" to priorityButton("Low"),
            "medium" to priorityButton("Med"),
            "high" to priorityButton("High"),
        )
        priorityButtons.forEach { (priority, view) ->
            view.setOnClickListener {
                selectedPriority = if (selectedPriority == priority) "none" else priority
                updatePriorityButtons()
            }
            priorityRow.addView(view)
        }
        detailsContainer.addView(priorityRow)
        updatePriorityButtons()

        notesEditText = EditText(this).apply {
            hint = "Notes (optional)"
            setHintTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setTextColor(QuartzoWidgetUtils.textColor(this@QuickAddPopupActivity))
            setBackgroundColor(QuartzoWidgetUtils.chipColor(this@QuickAddPopupActivity))
            setPadding(24, 18, 24, 18)
            minLines = 3
            maxLines = 5
            gravity = Gravity.TOP
        }
        detailsContainer.addView(notesEditText, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        root.addView(detailsContainer)
        updateDetailsVisibility()

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 24, 0, 0)
            gravity = Gravity.END
        }

        actions.addView(Button(this).apply {
            text = "Full editor"
            setTextColor(QuartzoWidgetUtils.accent(this@QuickAddPopupActivity))
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setOnClickListener { openFullEditor() }
        })

        actions.addView(Button(this).apply {
            text = "Cancel"
            setTextColor(QuartzoWidgetUtils.mutedColor(this@QuickAddPopupActivity))
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setOnClickListener { finish() }
        })

        actions.addView(Button(this).apply {
            text = "Save"
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(QuartzoWidgetUtils.accent(this@QuickAddPopupActivity))
            setPadding(32, 12, 32, 12)
            setOnClickListener { save() }
        })

        root.addView(actions)
        setContentView(ScrollView(this).apply { addView(root) })

        editText.post {
            editText.requestFocus()
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    private fun typeButton(label: String): TextView {
        return TextView(this).apply {
            text = label
            textSize = 14f
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(22, 12, 22, 12)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginEnd = 10
            }
        }
    }

    private fun priorityButton(label: String): TextView {
        return TextView(this).apply {
            text = label
            textSize = 13f
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(18, 10, 18, 10)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = 8
            }
        }
    }

    private fun updateTypeButtons() {
        typeButtons.forEach { (type, view) ->
            val selected = type == selectedType
            view.setTextColor(
                if (selected) android.graphics.Color.WHITE
                else QuartzoWidgetUtils.textColor(this)
            )
            view.setBackgroundColor(
                if (selected) QuartzoWidgetUtils.accent(this)
                else QuartzoWidgetUtils.chipColor(this)
            )
        }
        if (::priorityRow.isInitialized) {
            priorityRow.visibility = if (selectedType == "task") View.VISIBLE else View.GONE
        }
    }

    private fun updateDetailsVisibility() {
        detailsToggle.text = if (detailsExpanded) "- Hide details" else "+ Add details"
        detailsContainer.visibility = if (detailsExpanded) View.VISIBLE else View.GONE
    }

    private fun updatePriorityButtons() {
        priorityButtons.forEach { (priority, view) ->
            val selected = priority == selectedPriority
            view.setTextColor(
                if (selected) android.graphics.Color.WHITE
                else QuartzoWidgetUtils.textColor(this)
            )
            view.setBackgroundColor(
                if (selected) QuartzoWidgetUtils.accent(this)
                else QuartzoWidgetUtils.chipColor(this)
            )
        }
    }

    private fun showDueDatePicker() {
        val calendar = Calendar.getInstance()
        DatePickerDialog(
            this,
            { _, year, month, dayOfMonth ->
                calendar.set(year, month, dayOfMonth, 0, 0, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                selectedDueDateIso = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
                dueDateButton.text = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(calendar.time)
                dueDateButton.setTextColor(QuartzoWidgetUtils.accent(this))
            },
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH),
            calendar.get(Calendar.DAY_OF_MONTH),
        ).show()
    }

    private fun hintForType(type: String): String {
        return when (type) {
            "event" -> "Add an event..."
            "habit" -> "Add a habit..."
            "goal" -> "Add a goal..."
            "reminder" -> "Add a reminder..."
            else -> "Add a task..."
        }
    }

    private fun openFullEditor() {
        val title = editText.text.toString().trim()
        val notes = notesEditText.text.toString().trim()

        val uriBuilder = Uri.Builder()
            .scheme("quartzo")
            .authority("widget-toggle")
            .appendQueryParameter("type", "quick_add_open_editor")
            .appendQueryParameter("object_type", selectedType)

        if (title.isNotEmpty()) {
            uriBuilder.appendQueryParameter("title", title)
        }
        selectedDueDateIso?.let { uriBuilder.appendQueryParameter("due_date", it) }
        if (selectedType == "task" && selectedPriority != "none") {
            uriBuilder.appendQueryParameter("priority", selectedPriority)
        }
        if (notes.isNotEmpty()) {
            uriBuilder.appendQueryParameter("notes", notes)
        }

        val intent = Intent(Intent.ACTION_VIEW, uriBuilder.build(), this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(intent)
        finish()
    }

    private fun save() {
        val title = editText.text.toString().trim()
        if (title.isEmpty()) return
        val notes = notesEditText.text.toString().trim()

        val uriBuilder = Uri.Builder()
            .scheme("Quartzo")
            .authority("widget-toggle")
            .appendQueryParameter("type", "quick_add")
            .appendQueryParameter("object_type", selectedType)
            .appendQueryParameter("title", title)

        selectedDueDateIso?.let { uriBuilder.appendQueryParameter("due_date", it) }
        if (selectedType == "task" && selectedPriority != "none") {
            uriBuilder.appendQueryParameter("priority", selectedPriority)
        }
        if (notes.isNotEmpty()) {
            uriBuilder.appendQueryParameter("notes", notes)
        }

        val intent = Intent("es.antonborri.home_widget.action.BACKGROUND")
        intent.data = uriBuilder.build()
        sendBroadcast(intent)
        finish()
    }

    override fun finish() {
        if (::editText.isInitialized) {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(editText.windowToken, 0)
        }
        super.finish()
    }
}
