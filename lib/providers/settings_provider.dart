// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/shared_types.dart';
import '../models/saved_filter.dart';
import '../models/app_theme_config.dart';

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
  final String driveSyncFolder;
  final String driveSyncFolderId;
  final String driveSyncFolderPath;
  final Map<String, TypeSignature> typeSignatures;
  final bool sleepInTomorrow;
  final String sleepInUntil;
  final String sleepInDate;
  final String reviewDailyTemplateId;
  final String accentColor;
  final String themeMode;
  final String activeThemeId;
  final String? backgroundColor;
  final String? darkBackgroundColor;
  final String? fontFamily;
  final bool nlpTaskParsingEnabled;
  final bool showOverdueSection;
  final String dailyNoteIdentifier;
  final String dailyNoteDateFormat;
  final String dailyNoteFolder;
  final String socialViewMode;
  final String tiktokResolverEndpoint;
  final String tiktokResolverApiKey;
  final Map<String, String> folderPaths;
  // ── Idea capture settings ──
  final String ideaStrategy; // 'tag' | 'folder' | 'any_note'
  final String ideaTag; // default: 'idea'
  final String ideaFolder; // default: 'notes/ideas'

  // ── User identity ──
  final String? userName; // displayed in greeting on Home screen

  // ── Saved filters ──
  final List<Map<String, dynamic>> savedFiltersRaw; // persisted as JSON list

  // ── Integrations ──
  final String? huggingFaceToken; // Whisper / HuggingFace API token (E11)
  final String googleBooksApiKey;
  final String omdbApiKey;

  // ── Conflict suppression ──
  final Map<String, DateTime>
  suppressedConflicts; // slug → suppressed date (E2)

  // ── Recent Searches ──
  final List<String> recentSearches;

  // ── Timeline settings (RA-P2-2) ──
  final int dayStartHour; // Hour when the day starts (0-23), default 0 (midnight)

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
    this.driveSyncFolder = 'QuartzoVault',
    this.driveSyncFolderId = '',
    this.driveSyncFolderPath = '',
    this.typeSignatures = const {},
    this.universalWidgetType = 'daily',
    this.universalWidgetOrganizer = '',
    this.universalWidgetSize = 'medium',
    this.universalWidgetObjectTypes = const ['task', 'goal'],
    this.visibleResourceFields = const ['author', 'rating', 'type'],
    this.resourceTypeFilters = const ['Book', 'Movie', 'Show', 'General'],
    this.sleepInTomorrow = false,
    this.sleepInUntil = '10:00',
    this.sleepInDate = '',
    this.reviewDailyTemplateId = '',
    this.accentColor = '#F97316',
    this.themeMode = 'system',
    this.activeThemeId = 'Quartzo',
    this.backgroundColor,
    this.darkBackgroundColor,
    this.fontFamily,
    this.nlpTaskParsingEnabled = true,
    this.showOverdueSection = true,
    this.dailyNoteIdentifier = 'filename_format',
    this.dailyNoteDateFormat = 'yyyy-MM-dd',
    this.dailyNoteFolder = 'daily',
    this.socialViewMode = 'grid',
    this.tiktokResolverEndpoint = '',
    this.tiktokResolverApiKey = '',
    this.folderPaths = const {},
    this.quickAddWidgetButton1Label = 'Journal',
    this.quickAddWidgetButton1Target = 'journal',
    this.quickAddWidgetButton2Label = 'Task',
    this.quickAddWidgetButton2Target = 'task',
    this.calendarWidgetType = 'week',
    this.calendarWidgetShowTasks = true,
    this.calendarWidgetShowHabits = true,
    this.calendarWidgetShowSessions = true,
    this.habitWidgetFilterType = 'all',
    this.habitWidgetOrganizer = '',
    this.ideaStrategy = 'tag',
    this.ideaTag = 'idea',
    this.ideaFolder = 'notes/ideas',
    this.userName,
    this.savedFiltersRaw = const [],
    this.huggingFaceToken,
    this.googleBooksApiKey = '',
    this.omdbApiKey = '55335ca0',
    this.suppressedConflicts = const {},
    this.recentSearches = const [],
    this.dayStartHour = 0,
  });

  /// All saved filters deserialized.
  List<SavedFilter> get savedFilters =>
      savedFiltersRaw.map((j) => SavedFilter.fromJson(j)).toList();

  /// Filters that target this type (or the wildcard '*').
  List<SavedFilter> filtersFor(String targetType) => savedFilters
      .where((f) => f.targetType == targetType || f.targetType == '*')
      .toList();

  /// V5: mediaTypeFilters alias for resourceTypeFilters
  List<String> get mediaTypeFilters => resourceTypeFilters;

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
    String? accentColor,
    String? themeMode,
    String? activeThemeId,
    String? backgroundColor,
    String? darkBackgroundColor,
    String? fontFamily,
    bool? nlpTaskParsingEnabled,
    bool? showOverdueSection,
    String? dailyNoteIdentifier,
    String? dailyNoteDateFormat,
    String? dailyNoteFolder,
    String? socialViewMode,
    String? tiktokResolverEndpoint,
    String? tiktokResolverApiKey,
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
    String? ideaStrategy,
    String? ideaTag,
    String? ideaFolder,
    String? userName,
    List<Map<String, dynamic>>? savedFiltersRaw,
    String? huggingFaceToken,
    String? googleBooksApiKey,
    String? omdbApiKey,
    Map<String, DateTime>? suppressedConflicts,
    List<String>? recentSearches,
    int? dayStartHour,
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
      accentColor: accentColor ?? this.accentColor,
      themeMode: themeMode ?? this.themeMode,
      activeThemeId: activeThemeId ?? this.activeThemeId,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      darkBackgroundColor: darkBackgroundColor ?? this.darkBackgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      nlpTaskParsingEnabled:
          nlpTaskParsingEnabled ?? this.nlpTaskParsingEnabled,
      showOverdueSection: showOverdueSection ?? this.showOverdueSection,
      dailyNoteIdentifier: dailyNoteIdentifier ?? this.dailyNoteIdentifier,
      dailyNoteDateFormat: dailyNoteDateFormat ?? this.dailyNoteDateFormat,
      dailyNoteFolder: dailyNoteFolder ?? this.dailyNoteFolder,
      socialViewMode: socialViewMode ?? this.socialViewMode,
      tiktokResolverEndpoint:
          tiktokResolverEndpoint ?? this.tiktokResolverEndpoint,
      tiktokResolverApiKey: tiktokResolverApiKey ?? this.tiktokResolverApiKey,
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
      ideaStrategy: ideaStrategy ?? this.ideaStrategy,
      ideaTag: ideaTag ?? this.ideaTag,
      ideaFolder: ideaFolder ?? this.ideaFolder,
      userName: userName ?? this.userName,
      savedFiltersRaw: savedFiltersRaw ?? this.savedFiltersRaw,
      huggingFaceToken: huggingFaceToken ?? this.huggingFaceToken,
      googleBooksApiKey: googleBooksApiKey ?? this.googleBooksApiKey,
      omdbApiKey: omdbApiKey ?? this.omdbApiKey,
      suppressedConflicts: suppressedConflicts ?? this.suppressedConflicts,
      recentSearches: recentSearches ?? this.recentSearches,
      dayStartHour: dayStartHour ?? this.dayStartHour,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;
  SettingsNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(_buildFromPrefs(prefs));

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
      driveSyncFolder: prefs.getString('driveSyncFolder') ?? 'QuartzoVault',
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
          prefs.getStringList('resourceTypeFilters') ?? const ['Book', 'Movie', 'Show', 'General'],
      sleepInTomorrow: prefs.getBool('sleepInTomorrow') ?? false,
      sleepInUntil: prefs.getString('sleepInUntil') ?? '10:00',
      sleepInDate: prefs.getString('sleepInDate') ?? '',
      reviewDailyTemplateId: prefs.getString('reviewDailyTemplateId') ?? '',
      accentColor: prefs.getString('accentColor') ?? '#F97316',
      themeMode: prefs.getString('themeMode') ?? 'system',
      activeThemeId: prefs.getString('activeThemeId') ?? 'Quartzo',
      backgroundColor: prefs.getString('backgroundColor'),
      darkBackgroundColor: prefs.getString('darkBackgroundColor'),
      fontFamily: prefs.getString('fontFamily'),
      nlpTaskParsingEnabled: prefs.getBool('nlpTaskParsingEnabled') ?? true,
      showOverdueSection: prefs.getBool('showOverdueSection') ?? true,
      dailyNoteIdentifier:
          prefs.getString('dailyNoteIdentifier') ?? 'filename_format',
      dailyNoteDateFormat:
          prefs.getString('dailyNoteDateFormat') ?? 'yyyy-MM-dd',
      dailyNoteFolder: prefs.getString('dailyNoteFolder') ?? 'daily',
      socialViewMode: prefs.getString('socialViewMode') ?? 'grid',
      tiktokResolverEndpoint: prefs.getString('tiktokResolverEndpoint') ?? '',
      tiktokResolverApiKey: prefs.getString('tiktokResolverApiKey') ?? '',
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
      ideaStrategy: prefs.getString('ideaStrategy') ?? 'tag',
      ideaTag: prefs.getString('ideaTag') ?? 'idea',
      ideaFolder: prefs.getString('ideaFolder') ?? 'notes/ideas',
      userName: prefs.getString('userName'),
      savedFiltersRaw: () {
        final raw = prefs.getString('savedFiltersRaw');
        if (raw == null) return const <Map<String, dynamic>>[];
        try {
          return (json.decode(raw) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      }(),
      huggingFaceToken: prefs.getString('huggingFaceToken'),
      googleBooksApiKey: prefs.getString('google_books_api_key') ?? '',
      omdbApiKey: prefs.getString('omdb_api_key') ?? '',
      suppressedConflicts: () {
        final raw = prefs.getString('suppressedConflicts');
        if (raw == null) return const <String, DateTime>{};
        try {
          return (json.decode(raw) as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, DateTime.parse(v as String)),
          );
        } catch (_) {
          return const <String, DateTime>{};
        }
      }(),
      recentSearches: prefs.getStringList('recentSearches') ?? const [],
      dayStartHour: prefs.getInt('dayStartHour') ?? 0,
    );
  }

  static Map<String, TypeSignature> _defaultSignatures() {
    return {
      'shopping_list': TypeSignature(
        objectType: 'shopping_list',
        markerType: MarkerType.property,
        markerValue: 'type: shopping_list',
        emoji: '🛒',
      ),
      'task': TypeSignature(
        objectType: 'task',
        markerType: MarkerType.property,
        markerValue: 'type: task',
        emoji: '✅',
      ),
      'idea': TypeSignature(
        objectType: 'idea',
        markerType: MarkerType.tag,
        markerValue: 'ideia',
        emoji: '💡',
      ),
      'habit': TypeSignature(
        objectType: 'habit',
        markerType: MarkerType.property,
        markerValue: 'type: habit',
        emoji: '🔄',
      ),
      'project': TypeSignature(
        objectType: 'project',
        markerType: MarkerType.property,
        markerValue: 'type: project',
        emoji: '🚀',
      ),
      'goal': TypeSignature(
        objectType: 'goal',
        markerType: MarkerType.property,
        markerValue: 'type: goal',
        emoji: '🎯',
      ),
      'note': TypeSignature(
        objectType: 'note',
        markerType: MarkerType.property,
        markerValue: 'type: note',
        emoji: '📄',
      ),
      'resource': TypeSignature(
        objectType: 'resource',
        markerType: MarkerType.property,
        markerValue: 'type: resource',
        emoji: '📚',
      ),
      'event': TypeSignature(
        objectType: 'event',
        markerType: MarkerType.property,
        markerValue: 'type: event',
        emoji: '📅',
      ),
      'person': TypeSignature(
        objectType: 'person',
        markerType: MarkerType.property,
        markerValue: 'type: person',
        emoji: '👤',
      ),
      'area': TypeSignature(
        objectType: 'area',
        markerType: MarkerType.folder,
        markerValue: 'organizers/areas/',
        emoji: '🗺️',
      ),
      'activity': TypeSignature(
        objectType: 'activity',
        markerType: MarkerType.folder,
        markerValue: 'organizers/activities/',
        emoji: '⚡',
      ),
      'label': TypeSignature(
        objectType: 'label',
        markerType: MarkerType.folder,
        markerValue: 'organizers/labels/',
        emoji: '🏷️',
      ),
      'organizer': TypeSignature(
        objectType: 'organizer',
        markerType: MarkerType.property,
        markerValue: 'type: organizer',
        emoji: '📋',
      ),
      'day_theme': TypeSignature(
        objectType: 'day_theme',
        markerType: MarkerType.property,
        markerValue: 'type: day_theme',
        emoji: '🌅',
      ),
      'time_block': TypeSignature(
        objectType: 'time_block',
        markerType: MarkerType.property,
        markerValue: 'type: time_block',
        emoji: '⏱️',
      ),
      'tracker': TypeSignature(
        objectType: 'tracker',
        markerType: MarkerType.property,
        markerValue: 'type: tracker',
        emoji: '📊',
      ),
      'reminder': TypeSignature(
        objectType: 'reminder',
        markerType: MarkerType.property,
        markerValue: 'type: reminder',
        emoji: '⏰',
      ),
      'social_post': TypeSignature(
        objectType: 'social_post',
        markerType: MarkerType.property,
        markerValue: 'type: social_post',
        emoji: '📱',
      ),
      'mood_definition': TypeSignature(
        objectType: 'mood_definition',
        markerType: MarkerType.property,
        markerValue: 'type: mood_definition',
        emoji: '😊',
      ),
      'system': TypeSignature(
        objectType: 'system',
        markerType: MarkerType.property,
        markerValue: 'type: system',
        emoji: '⚙️',
      ),
      'analysis': TypeSignature(
        objectType: 'analysis',
        markerType: MarkerType.property,
        markerValue: 'type: analysis',
        emoji: '📈',
      ),
      'wellbeing_indicator': TypeSignature(
        objectType: 'wellbeing_indicator',
        markerType: MarkerType.property,
        markerValue: 'type: wellbeing_indicator',
        emoji: '❤️',
      ),
      'template': TypeSignature(
        objectType: 'template',
        markerType: MarkerType.property,
        markerValue: 'type: template',
        emoji: '📝',
      ),
      'inbox': TypeSignature(
        objectType: 'inbox',
        markerType: MarkerType.property,
        markerValue: 'type: inbox',
        emoji: '📥',
      ),
    };
  }

  Future<void> updateTypeSignature(String objectType, TypeSignature sig) async {
    final sigs = Map<String, TypeSignature>.from(state.typeSignatures);
    sigs[objectType] = sig;
    await _prefs.setString(
      'typeSignatures',
      json.encode(sigs.map((k, v) => MapEntry(k, v.toMap()))),
    );
    state = state.copyWith(typeSignatures: sigs);
  }

  Future<void> updateVaultName(String name) async {
    await _prefs.setString('vaultName', name);
    state = state.copyWith(vaultName: name);
  }

  Future<void> updateVaultPath(String path) async {
    await _prefs.setString('vaultPath', path);
    state = state.copyWith(vaultPath: path);
  }

  Future<void> updatePlannerSettings({
    int? startOfWeek,
    String? defaultView,
  }) async {
    if (startOfWeek != null) await _prefs.setInt('startOfWeek', startOfWeek);
    if (defaultView != null) {
      await _prefs.setString('defaultPlannerView', defaultView);
    }
    state = state.copyWith(
      startOfWeek: startOfWeek,
      defaultPlannerView: defaultView,
    );
  }

  Future<void> updateCategoryColor(String category, String colorHex) async {
    final colors = Map<String, String>.from(state.categoryColors);
    colors[category] = colorHex;
    await _prefs.setString('categoryColors', json.encode(colors));
    state = state.copyWith(categoryColors: colors);
  }

  Future<void> addAutoCategoryRule(AutoCategoryRule rule) async {
    final rules = [...state.autoCategoryRules, rule];
    await _prefs.setString(
      'autoCategoryRules',
      json.encode(rules.map((r) => r.toMap()).toList()),
    );
    state = state.copyWith(autoCategoryRules: rules);
  }

  Future<void> updateAccentColor(String value) async {
    await _prefs.setString('accentColor', value);
    state = state.copyWith(accentColor: value);
  }

  Future<void> updateThemeMode(String value) async {
    final normalized = switch (value) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
    await _prefs.setString('themeMode', normalized);
    state = state.copyWith(themeMode: normalized);
  }

  Future<void> updateActiveTheme({
    required String themeId,
    required String accentColor,
  }) async {
    await _prefs.setString('activeThemeId', themeId);
    await _prefs.setString('accentColor', accentColor);
    state = state.copyWith(activeThemeId: themeId, accentColor: accentColor);
  }

  Future<void> updateCustomTheme(AppThemeConfig theme) async {
    await _prefs.setString('activeThemeId', theme.id);
    await _prefs.setString('accentColor', theme.accentHex);
    if (theme.backgroundColor != null) {
      final hex = '#${theme.backgroundColor!.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      await _prefs.setString('backgroundColor', hex);
    }
    if (theme.darkBackgroundColor != null) {
      final darkHex = '#${theme.darkBackgroundColor!.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      await _prefs.setString('darkBackgroundColor', darkHex);
    }
    if (theme.fontFamily != null) {
      await _prefs.setString('fontFamily', theme.fontFamily!);
    }
    state = state.copyWith(
      activeThemeId: theme.id,
      accentColor: theme.accentHex,
      backgroundColor: theme.backgroundColor != null
          ? '#${theme.backgroundColor!.toARGB32().toRadixString(16).substring(2).toUpperCase()}'
          : null,
      darkBackgroundColor: theme.darkBackgroundColor != null
          ? '#${theme.darkBackgroundColor!.toARGB32().toRadixString(16).substring(2).toUpperCase()}'
          : null,
      fontFamily: theme.fontFamily,
    );
  }

  Future<void> updateLightBackgroundColor(String hex) async {
    await _prefs.setString('backgroundColor', hex);
    state = state.copyWith(backgroundColor: hex);
  }

  Future<void> updateDarkBackgroundColor(String hex) async {
    await _prefs.setString('darkBackgroundColor', hex);
    state = state.copyWith(darkBackgroundColor: hex);
  }

  Future<void> updateFontFamily(String? family) async {
    if (family != null) {
      await _prefs.setString('fontFamily', family);
    } else {
      await _prefs.remove('fontFamily');
    }
    state = state.copyWith(fontFamily: family);
  }

  Future<void> updateAutoSync(bool value) async {
    await _prefs.setBool('autoSync', value);
    state = state.copyWith(autoSync: value);
  }

  Future<void> updateConflictResolution(bool value) async {
    await _prefs.setBool('conflictKeepNewest', value);
    state = state.copyWith(conflictKeepNewest: value);
  }

  Future<void> updateHabitReminders(bool value) async {
    await _prefs.setBool('habitReminders', value);
    state = state.copyWith(habitReminders: value);
  }

  Future<void> updatePomodoroSounds(bool value) async {
    await _prefs.setBool('pomodoroSounds', value);
    state = state.copyWith(pomodoroSounds: value);
  }

  Future<void> updatePlannerColorMode(String mode) async {
    await _prefs.setString('plannerColorMode', mode);
    state = state.copyWith(plannerColorMode: mode);
  }

  Future<void> updateDriveSyncFolder(String folder) async {
    await _prefs.setString('driveSyncFolder', folder);
    await _prefs.remove('driveSyncFolderId');
    await _prefs.remove('driveSyncFolderPath');
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
    await _prefs.setString('driveSyncFolder', name);
    await _prefs.setString('driveSyncFolderId', id);
    await _prefs.setString('driveSyncFolderPath', path);
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
    if (type != null) await _prefs.setString('universalWidgetType', type);
    if (organizer != null) {
      await _prefs.setString('universalWidgetOrganizer', organizer);
    }
    if (size != null) await _prefs.setString('universalWidgetSize', size);
    if (objectTypes != null) {
      await _prefs.setStringList('universalWidgetObjectTypes', objectTypes);
    }
    state = state.copyWith(
      universalWidgetType: type,
      universalWidgetOrganizer: organizer,
      universalWidgetSize: size,
      universalWidgetObjectTypes: objectTypes,
    );
  }

  Future<void> updateVisibleResourceFields(List<String> fields) async {
    await _prefs.setStringList('visibleResourceFields', fields);
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
    await _prefs.setStringList('resourceTypeFilters', cleaned);
    state = state.copyWith(resourceTypeFilters: cleaned);
  }

  Future<void> updateSleepInTomorrow(bool value) async {
    await _prefs.setBool('sleepInTomorrow', value);
    if (value) {
      final tomorrowStr = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      await _prefs.setString('sleepInDate', tomorrowStr);
      state = state.copyWith(sleepInTomorrow: true, sleepInDate: tomorrowStr);
    } else {
      await _prefs.setString('sleepInDate', '');
      state = state.copyWith(sleepInTomorrow: false, sleepInDate: '');
    }
  }

  Future<void> updateSleepInUntil(String value) async {
    await _prefs.setString('sleepInUntil', value);
    state = state.copyWith(sleepInUntil: value);
  }

  Future<void> updateSleepInDate(String value) async {
    await _prefs.setString('sleepInDate', value);
    state = state.copyWith(sleepInDate: value);
  }

  Future<void> updateReviewDailyTemplateId(String value) async {
    await _prefs.setString('reviewDailyTemplateId', value);
    state = state.copyWith(reviewDailyTemplateId: value);
  }

  Future<void> updateWidgetQuickAddSettings({
    String? btn1Label,
    String? btn1Target,
    String? btn2Label,
    String? btn2Target,
  }) async {
    if (btn1Label != null) {
      await _prefs.setString('quickAddWidgetButton1Label', btn1Label);
    }
    if (btn1Target != null) {
      await _prefs.setString('quickAddWidgetButton1Target', btn1Target);
    }
    if (btn2Label != null) {
      await _prefs.setString('quickAddWidgetButton2Label', btn2Label);
    }
    if (btn2Target != null) {
      await _prefs.setString('quickAddWidgetButton2Target', btn2Target);
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
    if (type != null) await _prefs.setString('calendarWidgetType', type);
    if (showTasks != null) {
      await _prefs.setBool('calendarWidgetShowTasks', showTasks);
    }
    if (showHabits != null) {
      await _prefs.setBool('calendarWidgetShowHabits', showHabits);
    }
    if (showSessions != null) {
      await _prefs.setBool('calendarWidgetShowSessions', showSessions);
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
    if (filterType != null) {
      await _prefs.setString('habitWidgetFilterType', filterType);
    }
    if (organizer != null) {
      await _prefs.setString('habitWidgetOrganizer', organizer);
    }
    state = state.copyWith(
      habitWidgetFilterType: filterType,
      habitWidgetOrganizer: organizer,
    );
  }

  Future<void> updateNlpTaskParsingEnabled(bool value) async {
    await _prefs.setBool('nlpTaskParsingEnabled', value);
    state = state.copyWith(nlpTaskParsingEnabled: value);
  }

  Future<void> updateShowOverdueSection(bool value) async {
    await _prefs.setBool('showOverdueSection', value);
    state = state.copyWith(showOverdueSection: value);
  }

  Future<void> updateDailyNoteSettings({
    String? identifier,
    String? dateFormat,
    String? folder,
  }) async {
    if (identifier != null) {
      await _prefs.setString('dailyNoteIdentifier', identifier);
    }
    if (dateFormat != null) {
      await _prefs.setString('dailyNoteDateFormat', dateFormat);
    }
    if (folder != null) {
      await _prefs.setString('dailyNoteFolder', folder);
    }
    state = state.copyWith(
      dailyNoteIdentifier: identifier,
      dailyNoteDateFormat: dateFormat,
      dailyNoteFolder: folder,
    );
  }

  Future<void> updateSocialViewMode(String mode) async {
    final normalized = mode == 'timeline' ? 'timeline' : 'grid';
    await _prefs.setString('socialViewMode', normalized);
    state = state.copyWith(socialViewMode: normalized);
  }

  Future<void> updateTikTokResolverSettings({
    String? endpoint,
    String? apiKey,
  }) async {
    if (endpoint != null) {
      await _prefs.setString('tiktokResolverEndpoint', endpoint.trim());
    }
    if (apiKey != null) {
      await _prefs.setString('tiktokResolverApiKey', apiKey.trim());
    }
    state = state.copyWith(
      tiktokResolverEndpoint: endpoint,
      tiktokResolverApiKey: apiKey,
    );
  }

  Future<void> updateGoogleBooksApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    await _prefs.setString('google_books_api_key', trimmed);
    state = state.copyWith(googleBooksApiKey: trimmed);
  }

  Future<void> updateOmdbApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    await _prefs.setString('omdb_api_key', trimmed);
    state = state.copyWith(omdbApiKey: trimmed);
  }

  Future<void> updateFolderPath(String objectType, String folder) async {
    final key = objectType.trim();
    final value = folder
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    if (key.isEmpty || value.isEmpty) return;
    final next = Map<String, String>.from(state.folderPaths)..[key] = value;
    await _prefs.setString('folderPaths', json.encode(next));
    state = state.copyWith(folderPaths: next);
  }

  // ── A2: User identity ──
  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    await _prefs.setString('userName', trimmed);
    state = state.copyWith(userName: trimmed);
  }

  // ── A2: Saved filters ──
  Future<void> upsertSavedFilter(SavedFilter filter) async {
    final list = state.savedFilters.toList();
    final idx = list.indexWhere((f) => f.id == filter.id);
    if (idx >= 0) {
      list[idx] = filter;
    } else {
      list.add(filter);
    }
    final raw = list.map((f) => f.toJson()).toList();
    await _prefs.setString('savedFiltersRaw', json.encode(raw));
    state = state.copyWith(savedFiltersRaw: raw);
  }

  Future<void> deleteSavedFilter(String filterId) async {
    final list = state.savedFilters.where((f) => f.id != filterId).toList();
    final raw = list.map((f) => f.toJson()).toList();
    await _prefs.setString('savedFiltersRaw', json.encode(raw));
    state = state.copyWith(savedFiltersRaw: raw);
  }

  // ── E11: HuggingFace token ──
  Future<void> setHuggingFaceToken(String token) async {
    await _prefs.setString('huggingFaceToken', token.trim());
    state = state.copyWith(huggingFaceToken: token.trim());
  }

  // ── E2: Suppress conflict warnings ──
  Future<void> suppressConflict(String slug) async {
    final next = Map<String, DateTime>.from(state.suppressedConflicts)
      ..[slug] = DateTime.now();
    final encoded = json.encode(
      next.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await _prefs.setString('suppressedConflicts', encoded);
    state = state.copyWith(suppressedConflicts: next);
  }

  Future<void> setIdeaStrategy({
    required String strategy,
    String? tag,
    String? folder,
  }) async {
    await _prefs.setString('ideaStrategy', strategy);
    if (tag != null) await _prefs.setString('ideaTag', tag);
    if (folder != null) await _prefs.setString('ideaFolder', folder);
    state = state.copyWith(
      ideaStrategy: strategy,
      ideaTag: tag ?? state.ideaTag,
      ideaFolder: folder ?? state.ideaFolder,
    );

    // Sincronizar com typeSignatures para que a identificação de ideas
    // no vault reflita imediatamente a estratégia escolhida.
    final effectiveTag = tag ?? state.ideaTag;
    final effectiveFolder = folder ?? state.ideaFolder;
    final TypeSignature updatedSig;
    switch (strategy) {
      case 'folder':
        updatedSig = TypeSignature(
          objectType: 'idea',
          markerType: MarkerType.folder,
          markerValue: effectiveFolder,
        );
        break;
      case 'any_note':
        updatedSig = TypeSignature(
          objectType: 'idea',
          markerType: MarkerType.property,
          markerValue: 'type: idea',
        );
        break;
      default: // 'tag'
        updatedSig = TypeSignature(
          objectType: 'idea',
          markerType: MarkerType.tag,
          markerValue: effectiveTag,
        );
    }
    await updateTypeSignature('idea', updatedSig);
  }

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    var next = List<String>.from(state.recentSearches);
    next.remove(trimmed);
    next.insert(0, trimmed);
    if (next.length > 5) next = next.sublist(0, 5);
    await _prefs.setStringList('recentSearches', next);
    state = state.copyWith(recentSearches: next);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove('recentSearches');
    state = state.copyWith(recentSearches: const []);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

final googleBooksApiKeyProvider = StateProvider<String>((ref) {
  return ref.watch(settingsProvider.select((s) => s.googleBooksApiKey));
});
