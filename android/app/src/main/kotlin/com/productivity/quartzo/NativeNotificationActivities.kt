package com.productivity.quartzo

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

open class NativeNotificationActivity : Activity() {
    protected open val alarmMode: Boolean = false

    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private lateinit var payload: String
    private var notificationId: Int = 0
    private var snoozeMinutes: Int = 10

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        payload = intent.getStringExtra(EXTRA_PAYLOAD).orEmpty()
        notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, extractInt(payload, "id") ?: 0)
        snoozeMinutes = extractInt(payload, "snooze") ?: 10

        if (alarmMode) {
            enableAlarmWindow()
            startAlarmFeedback()
        }

        val title = Uri.decode(intent.getStringExtra(EXTRA_TITLE) ?: extract(payload, "title") ?: "Reminder")
        val body = Uri.decode(intent.getStringExtra(EXTRA_BODY) ?: extract(payload, "body") ?: "")
        val subtype = extract(payload, "subtype") ?: "reminder"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(36, if (alarmMode) 64 else 36, 36, if (alarmMode) 64 else 32)
            setBackgroundColor(
                if (alarmMode) 0x66000000
                else QuartzoWidgetUtils.bgColor(this@NativeNotificationActivity)
            )
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(34, 30, 34, 28)
            setBackgroundColor(QuartzoWidgetUtils.bgColor(this@NativeNotificationActivity))
        }

        card.addView(TextView(this).apply {
            text = if (alarmMode) "Alarm" else labelForSubtype(subtype)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(QuartzoWidgetUtils.accent(this@NativeNotificationActivity))
        })

        card.addView(TextView(this).apply {
            text = title
            textSize = if (alarmMode) 24f else 20f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(QuartzoWidgetUtils.textColor(this@NativeNotificationActivity))
            setPadding(0, 10, 0, if (body.isBlank()) 18 else 6)
        })

        if (body.isNotBlank()) {
            card.addView(TextView(this).apply {
                text = body
                textSize = 15f
                setTextColor(QuartzoWidgetUtils.mutedColor(this@NativeNotificationActivity))
                setPadding(0, 0, 0, 18)
            })
        }

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        actions.addView(actionButton(if (alarmMode) "Ignore" else "OK") {
            sendAction("dismiss")
        })
        actions.addView(actionButton("Snooze ${snoozeMinutes}m") {
            sendAction("snooze")
        })
        actions.addView(actionButton("Done", filled = true) {
            sendAction("done")
        })

        card.addView(actions)
        root.addView(card, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        setContentView(root)
    }

    private fun actionButton(label: String, filled: Boolean = false, onClick: () -> Unit): Button {
        return Button(this).apply {
            text = label
            textSize = 13f
            setTextColor(
                if (filled) android.graphics.Color.WHITE
                else QuartzoWidgetUtils.textColor(this@NativeNotificationActivity)
            )
            setBackgroundColor(
                if (filled) QuartzoWidgetUtils.accent(this@NativeNotificationActivity)
                else QuartzoWidgetUtils.chipColor(this@NativeNotificationActivity)
            )
            setOnClickListener { onClick() }
        }
    }

    private fun sendAction(action: String) {
        val uri = Uri.Builder()
            .scheme("Quartzo")
            .authority("widget-toggle")
            .appendQueryParameter("type", "notification_action")
            .appendQueryParameter("action", action)
            .appendQueryParameter("payload", payload)
            .appendQueryParameter("notification_id", notificationId.toString())
            .build()

        val intent = Intent("es.antonborri.home_widget.action.BACKGROUND")
        intent.data = uri
        sendBroadcast(intent)
        finish()
    }

    private fun enableAlarmWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
    }

    private fun startAlarmFeedback() {
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        ringtone = RingtoneManager.getRingtone(this, alarmUri)?.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            play()
        }

        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 700, 250, 700, 250)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    override fun finish() {
        ringtone?.stop()
        vibrator?.cancel()
        super.finish()
    }

    private fun labelForSubtype(subtype: String): String {
        return when (subtype) {
            "task" -> "Task reminder"
            "event" -> "Event reminder"
            "habit" -> "Habit reminder"
            else -> "Reminder"
        }
    }

    companion object {
        const val EXTRA_PAYLOAD = "payload"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_NOTIFICATION_ID = "notification_id"

        fun extract(payload: String, key: String): String? {
            val match = Regex("(^|[?&])$key=([^&]*)").find(payload)
            return match?.groupValues?.getOrNull(2)
        }

        fun extractInt(payload: String, key: String): Int? {
            return extract(payload, key)?.toIntOrNull()
        }
    }
}

class NativePopupNotificationActivity : NativeNotificationActivity() {
    override val alarmMode: Boolean = false
}

class NativeAlarmNotificationActivity : NativeNotificationActivity() {
    override val alarmMode: Boolean = true
}
