package com.productivity.quartzo

import android.app.AlarmManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import android.app.KeyguardManager
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.productivity.Quartzo/settings"
    private var pendingPayload: String? = null
    private var pendingSharedText: String? = null
    private var pendingWidgetUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        enableLockScreenPresentation()
        
        // Check if opened via fullScreenIntent notification
        if (isNotificationLaunch(intent)) {
            // Make window translucent for overlay effect
            window.setBackgroundDrawableResource(android.R.color.transparent)
            window.setDimAmount(0f)
        }
    }
    
    private fun isNotificationLaunch(intent: Intent?): Boolean {
        if (intent == null) return false
        // Check for notification payload or fullScreenIntent flags
        return intent.hasExtra("payload") || 
               (intent.getBooleanExtra("from_notification", false))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        enableLockScreenPresentation()
        
        // Check if opened via fullScreenIntent notification
        if (isNotificationLaunch(intent)) {
            // Make window translucent for overlay effect
            window.setBackgroundDrawableResource(android.R.color.transparent)
            window.setDimAmount(0f)
        }
    }

    override fun onResume() {
        super.onResume()
        enableLockScreenPresentation()
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data
        if (data?.host == "widget-toggle") {
            pendingWidgetUri = data.toString()
        }
        if (intent != null && intent.hasExtra("payload")) {
            val payload = intent.getStringExtra("payload")
            if (tryOpenNativeNotification(payload, intent.getIntExtra("notification_id", 0))) {
                return
            }
            pendingPayload = payload
        }
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            pendingSharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
        }
    }

    private fun enableLockScreenPresentation() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestIgnoreBatteryOptimization" -> {
                    try {
                        val intent = Intent()
                        intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("ERROR", ex.message, null)
                        }
                    }
                }
                "requestScheduleExactAlarm" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent()
                            intent.action = Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (ex: Exception) {
                            result.error("ERROR", ex.message, null)
                        }
                    }
                }
                "checkScheduleExactAlarm" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(alarmManager.canScheduleExactAlarms())
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestFullScreenIntent" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 34) { // Android 14+
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
                            } catch (e: ActivityNotFoundException) {
                                // Fallback: open general notification settings
                                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                startActivity(intent)
                            }
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "checkFullScreenIntent" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 34) {
                            // Use the recommended API: NotificationManagerCompat.canUseFullScreenIntent()
                            val granted = NotificationManagerCompat.from(this).canUseFullScreenIntent()
                            result.success(granted)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "checkBatteryOptimizationIgnored" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    val ignored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignored)
                }
                "requestSystemAlertWindow" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.canDrawOverlays(this@MainActivity)) {
                                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                                startActivity(intent)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "checkSystemAlertWindow" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(Settings.canDrawOverlays(this@MainActivity))
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getAndClearPendingPayload" -> {
                    val payload = pendingPayload
                    pendingPayload = null
                    result.success(payload)
                }
                "getAndClearSharedText" -> {
                    val sharedText = pendingSharedText
                    pendingSharedText = null
                    result.success(sharedText)
                }
                "getAndClearPendingWidgetUri" -> {
                    val uri = pendingWidgetUri
                    pendingWidgetUri = null
                    result.success(uri)
                }
                "bringAppToForeground" -> {
                    try {
                        val intent = Intent(this@MainActivity, MainActivity::class.java)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startQuickAddPopup" -> {
                    try {
                        val intent = Intent(this@MainActivity, QuickAddPopupActivity::class.java)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startNativeNotificationPopup" -> {
                    try {
                        val payload = call.argument<String>("payload") ?: ""
                        val notificationId = call.argument<Int>("notification_id") ?: 0
                        val popupIntent = nativeNotificationIntent(payload, notificationId)
                        popupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(popupIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "sendBroadcast" -> {
                    try {
                        val action = call.argument<String>("action")
                        if (action.isNullOrBlank()) {
                            result.error("ERROR", "Missing broadcast action", null)
                        } else {
                            sendBroadcast(Intent(action))
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getDiagnosticReports" -> {
                    try {
                        val reportDir = java.io.File(filesDir, "app_flutter/diagnostics/crash_reports")
                        if (reportDir.exists()) {
                            val files = reportDir.listFiles()?.map { it.absolutePath } ?: emptyList()
                            result.success(files)
                        } else {
                            result.success(emptyList<String>())
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "clearDiagnosticReports" -> {
                    try {
                        val reportDir = java.io.File(filesDir, "app_flutter/diagnostics/crash_reports")
                        if (reportDir.exists()) {
                            reportDir.deleteRecursively()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.productivity.Quartzo/vibration").setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    try {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                        val pattern = call.argument<String>("pattern") ?: "normal"
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val timings = when (pattern) {
                                "gentle" -> longArrayOf(0, 100, 1000)
                                "normal" -> longArrayOf(0, 200, 800)
                                "strong" -> longArrayOf(0, 400, 600)
                                "pulsing" -> longArrayOf(0, 100, 50, 100, 500)
                                "urgent" -> longArrayOf(0, 200, 200, 200, 400)
                                else -> longArrayOf(0, 200, 800)
                            }
                            vibrator.vibrate(android.os.VibrationEffect.createWaveform(timings, -1))
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(500)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "cancelVibration" -> {
                    try {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                        vibrator.cancel()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun tryOpenNativeNotification(payload: String?, notificationId: Int): Boolean {
        if (payload.isNullOrBlank()) return false
        val type = extractPayloadField(payload, "ntype")
        if (type != "popup" && type != "alarm") return false
        val intent = nativeNotificationIntent(payload, notificationId)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    private fun nativeNotificationIntent(payload: String, notificationId: Int): Intent {
        val type = extractPayloadField(payload, "ntype")
        val target = if (type == "alarm") {
            NativeAlarmNotificationActivity::class.java
        } else {
            NativePopupNotificationActivity::class.java
        }
        return Intent(this@MainActivity, target).apply {
            putExtra(NativeNotificationActivity.EXTRA_PAYLOAD, payload)
            putExtra(NativeNotificationActivity.EXTRA_TITLE, extractPayloadField(payload, "title") ?: "Reminder")
            putExtra(NativeNotificationActivity.EXTRA_BODY, extractPayloadField(payload, "body") ?: "")
            putExtra(NativeNotificationActivity.EXTRA_NOTIFICATION_ID, notificationId)
        }
    }

    private fun extractPayloadField(payload: String, key: String): String? {
        val match = Regex("(^|[?&])$key=([^&]*)").find(payload)
        return match?.groupValues?.getOrNull(2)
    }
}
