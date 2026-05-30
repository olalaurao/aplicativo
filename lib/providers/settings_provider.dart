// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/shared_types.dart';

/// Loaded once in main() before runApp and overridden into the ProviderContainer.
/// This ensures SettingsNotifier has real prefs from the very first build,
/// eliminating the async double-load that caused the vault to rebuild twice.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('Override sharedPreferencesProvider in main'),
);

class AutoCategoryRule {
  final String category;
  final String pattern;
  final String targetType;

  AutoCategoryRule({
    required this.category,
    required this.pattern,
    required this.targetType,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'pattern': pattern,
    'targetType': targetType,
  };
  factory AutoCategoryRule.fromMap(Map<String, dynamic> map) =>
      AutoCategoryRule(
        category: map['category'] ?? '',
        pattern: map['pattern'] ?? '',
        targetType: map['targetType'] ?? 'all',
      );
}

class AppSettings {
  final String vaultName;
  final String vaultPath;
  final bool autoSync;
  final bool conflictKeepNewest;
  final bool habitReminders;
  final bool pomodoroSounds;
  final String plannerColorMode;
  final int startOfWeek;
  final String defaultPlannerView;
  final Map<String, String> categoryColors;
  final List<AutoCategoryRule> autoCategoryRules;
  final bool biometricsEnabled;
  final String driveSyncFolder;
  final String driveSyncFolderId;
  final String driveSyncFolderPath;
  final Map<String, TypeSignature> typeSignatures;
  final bool sleepInTomorrow;
  final String sleepInUntil;
  final String sleepInDate;
  final String reviewDailyTemplateId;
  final bool nlpTaskParsingEnabled;
  final String dailyNoteIdentifier;
  final String dailyNoteDateFormat;
  final String dailyNoteFolder;
  final String socialViewMode;
  final Map<String, String> folderPaths;

  AppSettings({
    required this.vaultName,
    this.vaultPath = '',
    this.autoSync = true,
    this.conflictKeepNewest = false,
    this.habitReminders = true,
    this.pomodoroSounds = true,
    this.plannerColorMode = 'category',
    this.startOfWeek = 1,
    this.defaultPlannerView = 'day',
    this.categoryColors = const {},
    this.autoCategoryRules = const [],
    this.biometricsEnabled = false,
    this.driveSyncFolder = 'CitrineVault',
    this.driveSyncFolderId = '',
    this.driveSyncFolderPath = '',
    this.typeSignatures = const {},
    this.universalWidgetType = 'daily',
    this.universalWidgetOrganizer = '',
    this.universalWidgetSize = 'medium',
    this.universalWidgetObjectTypes = const ['task', 'goal'],
    this.visibleResourceFields = const ['author', 'rating', 'type'],
    this.resourceTypeFilters = const ['General'],
    this.sleepInTomorrow = false,
    this.sleepInUntil = '10:00',
    this.sleepInDate = '',
    this.reviewDailyTemplateId = '',
    this.nlpTaskParsingEnabled = true,
    this.dailyNoteIdentifier = 'filename_format',
    this.dailyNoteDateFormat = 'yyyy-MM-dd',
    this.dailyNoteFolder = 'daily',
    this.socialViewMode = 'grid',
    this.folderPaths = const {},
    this.quickAddWidgetButton1Label = 'Diário',
    this.quickAddWidgetButton1Target = 'journal',
    this.quickAddWidgetButton2Label = 'Tarefa',
    this.quickAddWidgetButton2Target = 'task',
    this.calendarWidgetType = 'week',
    this.calendarWidgetShowTasks = true,
    this.calendarWidgetShowHabits = true,
    this.calendarWidgetShowSessions = true,
    this.habitWidgetFilterType = 'all',
    this.habitWidgetOrganizer = '',
  });

  final String universalWidgetType;
  final String universalWidgetOrganizer;
  final String universalWidgetSize;
  final List<String> universalWidgetObjectTypes;
  final List<String> visibleResourceFields;
  final List<String> resourceTypeFilters;

  final String quickAddWidgetButton1Label;
  final String quickAddWidgetButton1Target;
  final String quickAddWidgetButton2Label;
  final String quickAddWidgetButton2Target;
  final String calendarWidgetType;
  final bool calendarWidgetShowTasks;
  final bool calendarWidgetShowHabits;
  final bool calendarWidgetShowSessions;
  final String habitWidgetFilterType;
  final String habitWidgetOrganizer;

  AppSettings copyWith({
    String? vaultName,
    String? vaultPath,
    bool? autoSync,
    bool? conflictKeepNewest,
    bool? habitReminders,
    bool? pomodoroSounds,
    String? plannerColorMode,
    int? startOfWeek,
    String? defaultPlannerView,
    Map<String, String>? categoryColors,
    List<AutoCategoryRule>? autoCategoryRules,
    bool? biometricsEnabled,
    String? driveSyncFolder,
    String? driveSyncFolderId,
    String? driveSyncFolderPath,
    Map<String, TypeSignature>? typeSignatures,
    String? universalWidgetType,
    String? universalWidgetOrganizer,
    String? universalWidgetSize,
    List<String>? universalWidgetObjectTypes,
    List<String>? visibleResourceFields,
    List<String>? resourceTypeFilters,
    bool? sleepInTomorrow,
    String? sleepInUntil,
    String? sleepInDate,
    String? reviewDailyTemplateId,
    bool? nlpTaskParsingEnabled,
    String? dailyNoteIdentifier,
    String? dailyNoteDateFormat,
    String? dailyNoteFolder,
    String? socialViewMode,
    Map<String, String>? folderPaths,
    String? quickAddWidgetButton1Label,
    String? quickAddWidgetButton1Target,
    String? quickAddWidgetButton2Label,
    String? quickAddWidgetButton2Target,
    String? calendarWidgetType,
    bool? calendarWidgetShowTasks,
    bool? calendarWidgetShowHabits,
    bool? calendarWidgetShowSessions,
    String? habitWidgetFilterType,
    String? habitWidgetOrganizer,
  }) {
    return AppSettings(
      vaultName: vaultName ?? this.vaultName,
      vaultPath: vaultPath ?? this.vaultPath,
      autoSync: autoSync ?? this.autoSync,
      conflictKeepNewest: conflictKeepNewest ?? this.conflictKeepNewest,
      habitReminders: habitReminders ?? this.habitReminders,
      pomodoroSounds: pomodoroSounds ?? this.pomodoroSounds,
      plannerColorMode: plannerColorMode ?? this.plannerColorMode,
      startOfWeek: startOfWeek ?? this.startOfWeek,
      defaultPlannerView: defaultPlannerView ?? this.defaultPlannerView,
      categoryColors: categoryColors ?? this.categoryColors,
      autoCategoryRules: autoCategoryRules ?? this.autoCategoryRules,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      driveSyncFolder: driveSyncFolder ?? this.driveSyncFolder,
      driveSyncFolderId: driveSyncFolderId ?? this.driveSyncFolderId,
      driveSyncFolderPath: driveSyncFolderPath ?? this.driveSyncFolderPath,
      typeSignatures: typeSignatures ?? this.typeSignatures,
      universalWidgetType: universalWidgetType ?? this.universalWidgetType,
      universalWidgetOrganizer:
          universalWidgetOrganizer ?? this.universalWidgetOrganizer,
      universalWidgetSize: universalWidgetSize ?? this.universalWidgetSize,
      universalWidgetObjectTypes:
          universalWidgetObjectTypes ?? this.universalWidgetObjectTypes,
      visibleResourceFields:
          visibleResourceFields ?? this.visibleResourceFields,
      resourceTypeFilters: resourceTypeFilters ?? this.resourceTypeFilters,
      sleepInTomorrow: sleepInTomorrow ?? this.sleepInTomorrow,
      sleepInUntil: sleepInUntil ?? this.sleepInUntil,
      sleepInDate: sleepInDate ?? this.sleepInDate,
      reviewDailyTemplateId:
          reviewDailyTemplateId ?? this.reviewDailyTemplateId,
      nlpTaskParsingEnabled:
          nlpTaskParsingEnabled ?? this.nlpTaskParsingEnabled,
      dailyNoteIdentifier: dailyNoteIdentifier ?? this.dailyNoteIdentifier,
      dailyNoteDateFormat: dailyNoteDateFormat ?? this.dailyNoteDateFormat,
      dailyNoteFolder: dailyNoteFolder ?? this.dailyNoteFolder,
      socialViewMode: socialViewMode ?? this.socialViewMode,
      folderPaths: folderPaths ?? this.folderPaths,
      quickAddWidgetButton1Label:
          quickAddWidgetButton1Label ?? this.quickAddWidgetButton1Label,
      quickAddWidgetButton1Target:
          quickAddWidgetButton1Target ?? this.quickAddWidgetButton1Target,
      quickAddWidgetButton2Label:
          quickAddWidgetButton2Label ?? this.quickAddWidgetButton2Label,
      quickAddWidgetButton2Target:
          quickAddWidgetButton2Target ?? this.quickAddWidgetButton2Target,
      calendarWidgetType: calendarWidgetType ?? this.calendarWidgetType,
      calendarWidgetShowTasks:
          calendarWidgetShowTasks ?? this.calendarWidgetShowTasks,
      calendarWidgetShowHabits:
          calendarWidgetShowHabits ?? this.calendarWidgetShowHabits,
      calendarWidgetShowSessions:
          calendarWidgetShowSessions ?? this.calendarWidgetShowSessions,
      habitWidgetFilterType:
          habitWidgetFilterType ?? this.habitWidgetFilterType,
      habitWidgetOrganizer: habitWidgetOrganizer ?? this.habitWidgetOrganizer,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(SharedPreferences prefs) : super(_buildFromPrefs(prefs));

  static AppSettings _buildFromPrefs(SharedPreferences prefs) {
    final rulesJson = prefs.getString('autoCategoryRules');
    List<AutoCategoryRule> rules = [];
    if (rulesJson != null) {
      rules = (json.decode(rulesJson) as List)
          .map((r) => AutoCategoryRule.fromMap(r))
          .toList();
    }

    final colorsJson = prefs.getString('categoryColors');
    Map<String, String> colors = {};
    if (colorsJson != null) {
      colors = Map<String, String>.from(json.decode(colorsJson));
    }

    final sigsJson = prefs.getString('typeSignatures');
    Map<String, TypeSignature> sigs = _defaultSignatures();
    if (sigsJson != null) {
      final Map<String, dynamic> decoded = json.decode(sigsJson);
      final loaded = decoded.map(
        (k, v) => MapEntry(k, TypeSignature.fromMap(v)),
      );
      sigs = _defaultSignatures()..addAll(loaded);
    }
    final folderPathsJson = prefs.getString('folderPaths');
    Map<String, String> folderPaths = {};
    if (folderPathsJson != null) {
      final decoded = json.decode(folderPathsJson);
      if (decoded is Map) {
        folderPaths = decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    }

    return AppSettings(
      vaultName: prefs.getString('vaultName') ?? 'Obsidian_Productivity_Vault',
      vaultPath: prefs.getString('vaultPath') ?? '',
      autoSync: prefs.getBool('autoSync') ?? true,
      conflictKeepNewest: prefs.getBool('conflictKeepNewest') ?? false,
      habitReminders: prefs.getBool('habitReminders') ?? true,
      pomodoroSounds: prefs.getBool('pomodoroSounds') ?? true,
      plannerColorMode: prefs.getString('plannerColorMode') ?? 'category',
      startOfWeek: prefs.getInt('startOfWeek') ?? 1,
      defaultPlannerView: prefs.getString('defaultPlannerView') ?? 'day',
      categoryColors: colors,
      autoCategoryRules: rules,
      biometricsEnabled: prefs.getBool('biometricsEnabled') ?? false,
      driveSyncFolder: prefs.getString('driveSyncFolder') ?? 'CitrineVault',
      driveSyncFolderId: prefs.getString('driveSyncFolderId') ?? '',
      driveSyncFolderPath: prefs.getString('driveSyncFolderPath') ?? '',
      typeSignatures: sigs,
      universalWidgetType: prefs.getString('universalWidgetType') ?? 'daily',
      universalWidgetOrganizer:
          prefs.getString('universalWidgetOrganizer') ?? '',
      universalWidgetSize: prefs.getString('universalWidgetSize') ?? 'medium',
      universalWidgetObjectTypes:
          prefs.getStringList('universalWidgetObjectTypes') ??
          const ['task', 'goal'],
      visibleResourceFields:
          prefs.getStringList('visibleResourceFields') ??
          const ['author', 'rating', 'type'],
      resourceTypeFilters:
          prefs.getStringList('resourceTypeFilters') ?? const ['General'],
      sleepInTomorrow: prefs.getBool('sleepInTomorrow') ?? false,
      sleepInUntil: prefs.getString('sleepInUntil') ?? '10:00',
      sleepInDate: prefs.getString('sleepInDate') ?? '',
      reviewDailyTemplateId: prefs.getString('reviewDailyTemplateId') ?? '',
      nlpTaskParsingEnabled: prefs.getBool('nlpTaskParsingEnabled') ?? true,
      dailyNoteIdentifier:
          prefs.getString('dailyNoteIdentifier') ?? 'filename_format',
      dailyNoteDateFormat:
          prefs.getString('dailyNoteDateFormat') ?? 'yyyy-MM-dd',
      dailyNoteFolder: prefs.getString('dailyNoteFolder') ?? 'daily',
      socialViewMode: prefs.getString('socialViewMode') ?? 'grid',
      folderPaths: folderPaths,
      quickAddWidgetButton1Label:
          prefs.getString('quickAddWidgetButton1Label') ?? 'Diário',
      quickAddWidgetButton1Target:
          prefs.getString('quickAddWidgetButton1Target') ?? 'journal',
      quickAddWidgetButton2Label:
          prefs.getString('quickAddWidgetButton2Label') ?? 'Tarefa',
      quickAddWidgetButton2Target:
          prefs.getString('quickAddWidgetButton2Target') ?? 'task',
      calendarWidgetType: prefs.getString('calendarWidgetType') ?? 'week',
      calendarWidgetShowTasks: prefs.getBool('calendarWidgetShowTasks') ?? true,
      calendarWidgetShowHabits:
          prefs.getBool('calendarWidgetShowHabits') ?? true,
      calendarWidgetShowSessions:
          prefs.getBool('calendarWidgetShowSessions') ?? true,
      habitWidgetFilterType: prefs.getString('habitWidgetFilterType') ?? 'all',
      habitWidgetOrganizer: prefs.getString('habitWidgetOrganizer') ?? '',
    );
  }

  static Map<String, TypeSignature> _defaultSignatures() {
    return {
      'task': TypeSignature(
        objectType: 'task',
        markerType: MarkerType.property,
        markerValue: 'type: task',
      ),
      'habit': TypeSignature(
        objectType: 'habit',
        markerType: MarkerType.property,
        markerValue: 'type: habit',
      ),
      'project': TypeSignature(
        objectType: 'project',
        markerType: MarkerType.property,
        markerValue: 'type: project',
      ),
      'goal': TypeSignature(
        objectType: 'goal',
        markerType: MarkerType.property,
        markerValue: 'type: goal',
      ),
      'note': TypeSignature(
        objectType: 'note',
        markerType: MarkerType.property,
        markerValue: 'type: note',
      ),
      'resource': TypeSignature(
        objectType: 'resource',
        markerType: MarkerType.property,
        markerValue: 'type: resource',
      ),
      'event': TypeSignature(
        objectType: 'event',
        markerType: MarkerType.property,
        markerValue: 'type: event',
      ),
      'person': TypeSignature(
        objectType: 'person',
        markerType: MarkerType.property,
        markerValue: 'type: person',
      ),
      'area': TypeSignature(
        objectType: 'area',
        markerType: MarkerType.folder,
        markerValue: 'organizers/areas/',
      ),
      'activity': TypeSignature(
        objectType: 'activity',
        markerType: MarkerType.folder,
        markerValue: 'organizers/activities/',
      ),
      'place': TypeSignature(
        objectType: 'place',
        markerType: MarkerType.folder,
        markerValue: 'organizers/places/',
      ),
      'label': TypeSignature(
        objectType: 'label',
        markerType: MarkerType.folder,
        markerValue: 'organizers/labels/',
      ),
      'organizer': TypeSignature(
        objectType: 'organizer',
        markerType: MarkerType.property,
        markerValue: 'type: organizer',
      ),
    };
  }

  Future<void> updateTypeSignature(String objectType, TypeSignature sig) async {
    final sigs = Map<String, TypeSignature>.from(state.typeSignatures);
    sigs[objectType] = sig;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'typeSignatures',
      json.encode(sigs.map((k, v) => MapEntry(k, v.toMap()))),
    );
    state = state.copyWith(typeSignatures: sigs);
  }

  Future<void> updateVaultName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vaultName', name);
    state = state.copyWith(vaultName: name);
  }

  Future<void> updateVaultPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vaultPath', path);
    state = state.copyWith(vaultPath: path);
  }

  Future<void> updatePlannerSettings({
    int? startOfWeek,
    String? defaultView,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (startOfWeek != null) await prefs.setInt('startOfWeek', startOfWeek);
    if (defaultView != null) {
      await prefs.setString('defaultPlannerView', defaultView);
    }
    state = state.copyWith(
      startOfWeek: startOfWeek,
      defaultPlannerView: defaultView,
    );
  }

  Future<void> updateCategoryColor(String category, String colorHex) async {
    final colors = Map<String, String>.from(state.categoryColors);
    colors[category] = colorHex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categoryColors', json.encode(colors));
    state = state.copyWith(categoryColors: colors);
  }

  Future<void> addAutoCategoryRule(AutoCategoryRule rule) async {
    final rules = [...state.autoCategoryRules, rule];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'autoCategoryRules',
      json.encode(rules.map((r) => r.toMap()).toList()),
    );
    state = state.copyWith(autoCategoryRules: rules);
  }

  Future<void> updateAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSync', value);
    state = state.copyWith(autoSync: value);
  }

  Future<void> updateConflictResolution(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('conflictKeepNewest', value);
    state = state.copyWith(conflictKeepNewest: value);
  }

  Future<void> updateHabitReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('habitReminders', value);
    state = state.copyWith(habitReminders: value);
  }

  Future<void> updatePomodoroSounds(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pomodoroSounds', value);
    state = state.copyWith(pomodoroSounds: value);
  }

  Future<void> updatePlannerColorMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plannerColorMode', mode);
    state = state.copyWith(plannerColorMode: mode);
  }

  Future<void> updateBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricsEnabled', value);
    state = state.copyWith(biometricsEnabled: value);
  }

  Future<void> updateDriveSyncFolder(String folder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driveSyncFolder', folder);
    await prefs.remove('driveSyncFolderId');
    await prefs.remove('driveSyncFolderPath');
    state = state.copyWith(
      driveSyncFolder: folder,
      driveSyncFolderId: '',
      driveSyncFolderPath: '',
    );
  }

  Future<void> updateDriveSyncFolderSelection({
    required String id,
    required String name,
    required String path,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driveSyncFolder', name);
    await prefs.setString('driveSyncFolderId', id);
    await prefs.setString('driveSyncFolderPath', path);
    state = state.copyWith(
      driveSyncFolder: name,
      driveSyncFolderId: id,
      driveSyncFolderPath: path,
    );
  }

  Future<void> updateUniversalWidgetSettings({
    String? type,
    String? organizer,
    String? size,
    List<String>? objectTypes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (type != null) await prefs.setString('universalWidgetType', type);
    if (organizer != null) {
      await prefs.setString('universalWidgetOrganizer', organizer);
    }
    if (size != null) await prefs.setString('universalWidgetSize', size);
    if (objectTypes != null) {
      await prefs.setStringList('universalWidgetObjectTypes', objectTypes);
    }
    state = state.copyWith(
      universalWidgetType: type,
      universalWidgetOrganizer: organizer,
      universalWidgetSize: size,
      universalWidgetObjectTypes: objectTypes,
    );
  }

  Future<void> updateVisibleResourceFields(List<String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visibleResourceFields', fields);
    state = state.copyWith(visibleResourceFields: fields);
  }

  Future<void> updateResourceTypeFilters(List<String> filters) async {
    final cleaned =
        filters
            .map((filter) => filter.trim())
            .where((filter) => filter.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('resourceTypeFilters', cleaned);
    state = state.copyWith(resourceTypeFilters: cleaned);
  }

  Future<void> updateSleepInTomorrow(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sleepInTomorrow', value);
    if (value) {
      final tomorrowStr = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      await prefs.setString('sleepInDate', tomorrowStr);
      state = state.copyWith(sleepInTomorrow: true, sleepInDate: tomorrowStr);
    } else {
      await prefs.setString('sleepInDate', '');
      state = state.copyWith(sleepInTomorrow: false, sleepInDate: '');
    }
  }

  Future<void> updateSleepInUntil(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sleepInUntil', value);
    state = state.copyWith(sleepInUntil: value);
  }

  Future<void> updateSleepInDate(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sleepInDate', value);
    state = state.copyWith(sleepInDate: value);
  }

  Future<void> updateReviewDailyTemplateId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reviewDailyTemplateId', value);
    state = state.copyWith(reviewDailyTemplateId: value);
  }

  Future<void> updateWidgetQuickAddSettings({
    String? btn1Label,
    String? btn1Target,
    String? btn2Label,
    String? btn2Target,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (btn1Label != null) {
      await prefs.setString('quickAddWidgetButton1Label', btn1Label);
    }
    if (btn1Target != null) {
      await prefs.setString('quickAddWidgetButton1Target', btn1Target);
    }
    if (btn2Label != null) {
      await prefs.setString('quickAddWidgetButton2Label', btn2Label);
    }
    if (btn2Target != null) {
      await prefs.setString('quickAddWidgetButton2Target', btn2Target);
    }
    state = state.copyWith(
      quickAddWidgetButton1Label: btn1Label,
      quickAddWidgetButton1Target: btn1Target,
      quickAddWidgetButton2Label: btn2Label,
      quickAddWidgetButton2Target: btn2Target,
    );
  }

  Future<void> updateWidgetCalendarSettings({
    String? type,
    bool? showTasks,
    bool? showHabits,
    bool? showSessions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (type != null) await prefs.setString('calendarWidgetType', type);
    if (showTasks != null) {
      await prefs.setBool('calendarWidgetShowTasks', showTasks);
    }
    if (showHabits != null) {
      await prefs.setBool('calendarWidgetShowHabits', showHabits);
    }
    if (showSessions != null) {
      await prefs.setBool('calendarWidgetShowSessions', showSessions);
    }
    state = state.copyWith(
      calendarWidgetType: type,
      calendarWidgetShowTasks: showTasks,
      calendarWidgetShowHabits: showHabits,
      calendarWidgetShowSessions: showSessions,
    );
  }

  Future<void> updateWidgetHabitSettings({
    String? filterType,
    String? organizer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (filterType != null) {
      await prefs.setString('habitWidgetFilterType', filterType);
    }
    if (organizer != null) {
      await prefs.setString('habitWidgetOrganizer', organizer);
    }
    state = state.copyWith(
      habitWidgetFilterType: filterType,
      habitWidgetOrganizer: organizer,
    );
  }

  Future<void> updateNlpTaskParsingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nlpTaskParsingEnabled', value);
    state = state.copyWith(nlpTaskParsingEnabled: value);
  }

  Future<void> updateDailyNoteSettings({
    String? identifier,
    String? dateFormat,
    String? folder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (identifier != null) {
      await prefs.setString('dailyNoteIdentifier', identifier);
    }
    if (dateFormat != null) {
      await prefs.setString('dailyNoteDateFormat', dateFormat);
    }
    if (folder != null) {
      await prefs.setString('dailyNoteFolder', folder);
    }
    state = state.copyWith(
      dailyNoteIdentifier: identifier,
      dailyNoteDateFormat: dateFormat,
      dailyNoteFolder: folder,
    );
  }

  Future<void> updateSocialViewMode(String mode) async {
    final normalized = mode == 'timeline' ? 'timeline' : 'grid';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('socialViewMode', normalized);
    state = state.copyWith(socialViewMode: normalized);
  }

  Future<void> updateFolderPath(String objectType, String folder) async {
    final key = objectType.trim();
    final value = folder.trim().replaceAll('\\', '/').replaceAll(
      RegExp(r'^/+|/+$'),
      '',
    );
    if (key.isEmpty || value.isEmpty) return;
    final next = Map<String, String>.from(state.folderPaths)..[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folderPaths', json.encode(next));
    state = state.copyWith(folderPaths: next);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
