package com.productivity.citrine

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.app.FlutterApplication
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class CitrineApplication : FlutterApplication() {

    companion object {
        private const val TAG = "CitrineApplication"
        // Timeout before declaring ANR
        private const val ANR_TIMEOUT_MS = 30000L
        // Cooldown between consecutive ANR reports (avoid spam)
        private const val ANR_COOLDOWN_MS = 30_000L
    }

    override fun onCreate() {
        super.onCreate()
        setupUncaughtExceptionHandler()
        startAnrWatchdog()
    }

    // ─── Native crash handler ──────────────────────────────────────────────────

    private fun setupUncaughtExceptionHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                writeCrashReport("native_crash", throwable, thread)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write native crash report", e)
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    // ─── ANR watchdog ──────────────────────────────────────────────────────────

    private fun startAnrWatchdog() {
        val watchdog = Thread {
            val mainHandler = Handler(Looper.getMainLooper())
            val mainThread = Looper.getMainLooper().thread
            var lastReportTime = 0L

            while (!Thread.currentThread().isInterrupted) {
                var mainThreadResponded = false

                // Post a ping to the main thread
                mainHandler.post { mainThreadResponded = true }

                // Wait for the timeout
                try {
                    Thread.sleep(ANR_TIMEOUT_MS)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }

                if (!mainThreadResponded) {
                    val now = System.currentTimeMillis()
                    if (now - lastReportTime >= ANR_COOLDOWN_MS) {
                        lastReportTime = now
                        Log.w(TAG, "ANR detected: main thread did not respond in ${ANR_TIMEOUT_MS}ms")
                        writeAnrReport(mainThread)
                    } else {
                        Log.w(TAG, "ANR still ongoing (suppressing duplicate report)")
                    }

                    // Wait for the main thread to recover before next check
                    try {
                        Thread.sleep(ANR_COOLDOWN_MS)
                    } catch (e: InterruptedException) {
                        Thread.currentThread().interrupt()
                        break
                    }
                }
            }
        }
        watchdog.name = "ANR-Watchdog"
        watchdog.isDaemon = true
        watchdog.start()
    }

    // ─── Report writers ────────────────────────────────────────────────────────

    private fun writeAnrReport(mainThread: Thread) {
        try {
            val now = Date()
            val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(now)
            val filename = "${timestamp}_suspected_anr.md"

            // Capture stack traces of ALL threads for richer diagnostics
            val allThreadDumps = buildAllThreadDumps()

            val createdAt = utcFormatter().format(now)
            val appVersion = getAppVersion()

            val content = buildString {
                appendLine("---")
                appendLine("type: crash_report")
                appendLine("kind: suspected_anr")
                appendLine("created_at: $createdAt")
                appendLine("app_version: $appVersion")
                appendLine("platform: android")
                appendLine("---")
                appendLine()
                appendLine("# Crash Report — suspected_anr")
                appendLine()
                appendLine("## Context")
                appendLine("| Field | Value |")
                appendLine("|---|---|")
                appendLine("| Kind | suspected_anr |")
                appendLine("| Time | $createdAt |")
                appendLine("| App version | $appVersion |")
                appendLine("| Blocked for | >${ANR_TIMEOUT_MS}ms |")
                appendLine("| Main thread state | ${mainThread.state} |")
                appendLine()
                appendLine("## Error")
                appendLine("Main thread did not respond to a Handler.post() ping within ${ANR_TIMEOUT_MS}ms.")
                appendLine()
                appendLine("## Main Thread Stack Trace")
                appendLine("```")
                mainThread.stackTrace.forEach { appendLine("\tat $it") }
                appendLine("```")
                appendLine()
                appendLine("## All Thread Dumps")
                appendLine("```")
                append(allThreadDumps)
                appendLine("```")
            }

            writeToInternalStorage(filename, content)
            Log.i(TAG, "ANR report written: $filename")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write ANR report", e)
        }
    }

    private fun writeCrashReport(kind: String, throwable: Throwable, thread: Thread) {
        val now = Date()
        val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(now)
        val filename = "${timestamp}_$kind.md"
        val createdAt = utcFormatter().format(now)
        val appVersion = getAppVersion()
        val stackTrace = Log.getStackTraceString(throwable)
        val allThreadDumps = buildAllThreadDumps()

        val content = buildString {
            appendLine("---")
            appendLine("type: crash_report")
            appendLine("kind: $kind")
            appendLine("created_at: $createdAt")
            appendLine("app_version: $appVersion")
            appendLine("platform: android")
            appendLine("---")
            appendLine()
            appendLine("# Crash Report — $kind")
            appendLine()
            appendLine("## Context")
            appendLine("| Field | Value |")
            appendLine("|---|---|")
            appendLine("| Kind | $kind |")
            appendLine("| Time | $createdAt |")
            appendLine("| App version | $appVersion |")
            appendLine("| Thread | ${thread.name} (${thread.state}) |")
            appendLine()
            appendLine("## Error")
            appendLine("**Type:** `${throwable.javaClass.name}`")
            appendLine()
            appendLine("```")
            appendLine(throwable.toString())
            appendLine("```")
            appendLine()
            appendLine("## Stack Trace")
            appendLine("```")
            appendLine(stackTrace)
            appendLine("```")
            appendLine()
            appendLine("## All Thread Dumps")
            appendLine("```")
            append(allThreadDumps)
            appendLine("```")
        }

        writeToInternalStorage(filename, content)
        Log.i(TAG, "Crash report written: $filename ($kind)")
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    /** Dump stack traces of all live threads, grouped and labeled. */
    private fun buildAllThreadDumps(): String {
        return buildString {
            Thread.getAllStackTraces().entries
                .sortedBy { it.key.name }
                .forEach { (thread, frames) ->
                    appendLine("-- Thread: ${thread.name} [${thread.state}] daemon=${thread.isDaemon}")
                    if (frames.isEmpty()) {
                        appendLine("   (no stack)")
                    } else {
                        frames.forEach { frame -> appendLine("   at $frame") }
                    }
                    appendLine()
                }
        }
    }

    private fun writeToInternalStorage(filename: String, content: String) {
        val reportDir = File(filesDir, "app_flutter/diagnostics/crash_reports")
        if (!reportDir.exists()) reportDir.mkdirs()
        File(reportDir, filename).writeText(content)
    }

    private fun utcFormatter(): SimpleDateFormat {
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    private fun getAppVersion(): String {
        return try {
            val pInfo = packageManager.getPackageInfo(packageName, 0)
            "${pInfo.versionName}+${pInfo.longVersionCode}"
        } catch (e: Exception) {
            "unknown"
        }
    }
}
