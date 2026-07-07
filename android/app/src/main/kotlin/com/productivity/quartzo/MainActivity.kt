package com.productivity.quartzo

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import android.app.KeyguardManager
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
            pendingPayload = intent.getStringExtra("payload")
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
                        if (Build.VERSION.SDK_INT >= 34) { // Android 14 (UPSIDE_DOWN_CAKE)
                            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
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
                            val appOpsManager = getSystemService(APP_OPS_SERVICE) as android.app.AppOpsManager
                            val mode = appOpsManager.unsafeCheckOpNoThrow("android:use_fullscreen_intent", android.os.Process.myUid(), packageName)
                            result.success(mode == android.app.AppOpsManager.MODE_ALLOWED)
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
    }
}
