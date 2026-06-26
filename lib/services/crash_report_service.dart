import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class CrashReportService {
  static final CrashReportService instance = CrashReportService._();
  CrashReportService._();

  // Circular buffer of recent events for context
  final Queue<String> _recentEvents = Queue<String>();
  static const int _maxEvents = 100;

  String? _appVersion;
  String? _vaultPath;

  // Current screen/route tracked externally
  String _currentRoute = 'unknown';

  // Tracks if an ANR is already in progress (to avoid duplicate reports)
  bool _anrInProgress = false;

  /// [appVersion] should be passed from main.dart (e.g. from pubspec or native channel).
  Future<void> init({String? vaultPath, String? appVersion}) async {
    _vaultPath = vaultPath;
    _appVersion = appVersion ?? 'unknown';

    logEvent('app_start version=$_appVersion');

    // Capture Flutter framework errors (widget build errors, etc.)
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final library = details.library ?? 'unknown';
      final context = details.context?.toDescription() ?? '';
      logEvent('flutter_error library=$library context=$context');
      final message = details.exception.toString();
      if (message.contains('A RenderFlex overflowed')) {
        unawaited(logOverflow(details: details.toString(), library: library));
      }
      _handleError(
        details.exception,
        details.stack ?? StackTrace.empty,
        'flutter_error',
        extra: {
          'library': library,
          'context': context,
          'silent': details.silent.toString(),
        },
      );
      if (originalOnError != null) {
        originalOnError(details);
      }
    };

    // Capture unhandled async Dart errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logEvent('dart_error ${error.runtimeType}: ${_shortMessage(error)}');
      _handleError(error, stack, 'dart_error');
      return true;
    };
  }

  /// Call this from GoRouter's observers or navigation callbacks
  void setCurrentRoute(String route) {
    if (_currentRoute != route) {
      logEvent('navigate → $route');
      _currentRoute = route;
    }
  }

  void setVaultPath(String path) {
    _vaultPath = path;
  }

  /// Log a notable app event. Keeps last [_maxEvents] entries in memory.
  void logEvent(String event) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final entry = '[$timestamp] $event';
    _recentEvents.addLast(entry);
    if (_recentEvents.length > _maxEvents) {
      _recentEvents.removeFirst();
    }
  }

  Future<void> _handleError(
    Object error,
    StackTrace stackTrace,
    String kind, {
    Map<String, String> extra = const {},
  }) async {
    try {
      final now = DateTime.now();
      final timestampStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      final filename = '${timestampStr}_$kind.md';
      final reportContent = await _buildReport(
        kind,
        now,
        error,
        stackTrace,
        extra: extra,
      );
      await _writeReport(filename, reportContent);
    } catch (e) {
      debugPrint('[CrashReport] Error writing crash report: $e');
    }
  }

  /// Called from Android side via MethodChannel when a native ANR is detected.
  /// [androidStackTrace] is the raw stack trace string from the native side.
  Future<void> handleAnrDetected({
    required String androidStackTrace,
    required int blockedForMs,
  }) async {
    if (_anrInProgress) return; // Already writing one
    _anrInProgress = true;

    try {
      final now = DateTime.now();
      final timestampStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      final filename = '${timestampStr}_suspected_anr.md';
      final error = 'ANR: Main thread blocked for >${blockedForMs}ms';
      final reportContent = await _buildReport(
        'suspected_anr',
        now,
        error,
        StackTrace.empty,
        extra: {
          'blocked_for_ms': blockedForMs.toString(),
          'android_stack_trace': androidStackTrace,
        },
      );
      await _writeReport(filename, reportContent);
    } catch (e) {
      debugPrint('[CrashReport] Error writing ANR report: $e');
    } finally {
      _anrInProgress = false;
    }
  }

  Future<void> logOverflow({
    required String details,
    required String library,
  }) async {
    try {
      final now = DateTime.now();
      final timestampStr = DateFormat('yyyy-MM-dd_HH-mm-ss_SSS').format(now);
      final filename = '${timestampStr}_overflow.md';
      final report =
          '''---
type: overflow
created_at: ${now.toIso8601String()}
library: $library
route: $_currentRoute
---

# RenderFlex Overflow

```text
$details
```
''';
      await _writeReport(filename, report);
    } catch (error) {
      debugPrint('[CrashReport] Error writing overflow report: $error');
    }
  }

  Future<String> _buildReport(
    String kind,
    DateTime createdAt,
    Object error,
    StackTrace stackTrace, {
    Map<String, String> extra = const {},
  }) async {
    final sb = StringBuffer();

    // --- YAML frontmatter ---
    sb.writeln('---');
    sb.writeln('type: crash_report');
    sb.writeln('kind: $kind');
    sb.writeln('created_at: ${createdAt.toIso8601String()}');
    sb.writeln('app_version: ${_appVersion ?? 'unknown'}');
    sb.writeln('platform: ${Platform.operatingSystem}');
    sb.writeln('route: $_currentRoute');
    sb.writeln('---');
    sb.writeln();

    sb.writeln('# Crash Report — $kind');
    sb.writeln();

    // --- Context ---
    sb.writeln('## Context');
    sb.writeln('| Field | Value |');
    sb.writeln('|---|---|');
    sb.writeln('| Kind | $kind |');
    sb.writeln('| Time | ${createdAt.toLocal()} |');
    sb.writeln('| App version | ${_appVersion ?? 'unknown'} |');
    sb.writeln(
      '| Platform | ${Platform.operatingSystem} ${Platform.operatingSystemVersion} |',
    );
    sb.writeln('| Dart version | ${Platform.version} |');
    sb.writeln('| Route | $_currentRoute |');
    for (final entry in extra.entries) {
      if (entry.key != 'android_stack_trace') {
        sb.writeln('| ${entry.key} | ${entry.value} |');
      }
    }
    sb.writeln();

    // --- Error ---
    sb.writeln('## Error');
    sb.writeln('**Type:** `${error.runtimeType}`');
    sb.writeln();
    sb.writeln('```');
    sb.writeln(error.toString());
    sb.writeln('```');
    sb.writeln();

    // --- Stack trace ---
    final stackStr = stackTrace.toString().trim();
    if (stackStr.isNotEmpty && stackStr != 'null') {
      sb.writeln('## Dart Stack Trace');
      sb.writeln('```');
      sb.writeln(stackStr);
      sb.writeln('```');
      sb.writeln();
    }

    // --- Android native stack (for ANRs) ---
    final androidStack = extra['android_stack_trace'];
    if (androidStack != null && androidStack.isNotEmpty) {
      sb.writeln('## Android Thread Dump');
      sb.writeln('```');
      sb.writeln(androidStack);
      sb.writeln('```');
      sb.writeln();
    }

    // --- Recent events ---
    sb.writeln('## Last App Events (most recent last)');
    if (_recentEvents.isEmpty) {
      sb.writeln('_No events recorded._');
    } else {
      sb.writeln('```');
      for (final event in _recentEvents) {
        sb.writeln(event);
      }
      sb.writeln('```');
    }
    sb.writeln();

    return sb.toString();
  }

  Future<void> _writeReport(String filename, String content) async {
    // 1. Internal storage (always)
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final internalDir = Directory('${docDir.path}/diagnostics/crash_reports');
      if (!await internalDir.exists()) {
        await internalDir.create(recursive: true);
      }
      await File('${internalDir.path}/$filename').writeAsString(content);
      debugPrint('[CrashReport] Written to internal: $filename');
    } catch (e) {
      debugPrint('[CrashReport] Failed to write to internal storage: $e');
    }

    // 2. Vault (if available)
    if (_vaultPath != null && _vaultPath!.isNotEmpty) {
      try {
        final vaultDir = Directory('$_vaultPath/_diagnostics/crash_reports');
        if (!await vaultDir.exists()) {
          await vaultDir.create(recursive: true);
        }
        await File('${vaultDir.path}/$filename').writeAsString(content);
        debugPrint('[CrashReport] Written to vault: $filename');
      } catch (e) {
        debugPrint('[CrashReport] Failed to write to vault: $e');
      }
    }
  }

  // --- Report management ---

  Future<List<File>> getInternalReports() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/diagnostics/crash_reports');
      if (!await dir.exists()) return [];
      final files = dir.listSync().whereType<File>().toList();
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<void> clearInternalReports() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/diagnostics/crash_reports');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('[CrashReport] Internal reports cleared.');
      }
    } catch (e) {
      debugPrint('[CrashReport] Error clearing reports: $e');
    }
  }

  // --- Helpers ---

  String _shortMessage(Object error) {
    final s = error.toString();
    return s.length > 120 ? '${s.substring(0, 120)}...' : s;
  }
}
