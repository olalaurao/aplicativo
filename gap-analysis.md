CITRINE — ESPECIFICAÇÕES TÉCNICAS COMPLETAS
> Documento único de referência para implementação.
> Cobre gaps do código atual + 4 features novas.
> Cada seção explica O QUÊ é, POR QUÊ existe, COMO funciona e COMO implementar.
> Código atual lido diretamente do repositório em junho/2026.
---
TOKENS DE DESIGN
```
primary     = #FFB000  (AppColors.primary)
info        = #3B82F6  (AppColors.info)
success     = #22C55E  (AppColors.habitGreen)
purple      = #8B5CF6  (AppColors.habitPurple)
warning     = #F59E0B  (AppColors.warning)
error       = #EF4444  (AppColors.error)
textMuted   = #9CA3AF  (AppColors.textMuted)
darkCard    = #22252F  (AppColors.darkCardFill)
divider     = #E5E7EB  (AppColors.divider)

cardDecoration → AppTheme.cardDecoration(context)    r=20, shadow suave
surfaceVariant → AppTheme.surfaceVariantColor(context)
textMuted      → AppTheme.textMutedColor(context)

Chips:         r=20, padding h:14 v:7
Badges inline: r=4,  padding h:6 v:2
Section label: 10px w700 letterSpacing:0.1em uppercase muted
Body text:     12–13px lineHeight:1.7
```
---
BLOCO A — INFRA E MODELOS
---
A1 — Sistema de Filtros Reutilizável (`saved_filter.dart`)
O que é: Um modelo de dados compartilhado que representa um filtro salvo pelo usuário. Usado por Notes, Resources, Habits, Tasks, Goals, People, Journal e Trackers. Hoje cada tela tem sua lógica de filtro hardcoded e incompatível com as demais — chips de "All/Text/Outline" em Notes, popups de sort em Resources, etc. Isso cria UX inconsistente e código duplicado.
Como funciona: Um `SavedFilter` contém uma lista de regras (`FilterRule`), configuração de sort, agrupamento e view mode. O usuário cria filtros via `FilterSortSheet` (ver B1), nomeia e salva. Os filtros salvos aparecem como chips horizontais em cada tela. Tocar num chip aplica todas as regras + sort + groupBy de uma vez.
Arquivos: `lib/models/saved_filter.dart` — CRIAR NOVO
```dart
enum SortField {
  manual, title, created, modified,
  rating, status, type, priority,
  deadline, streak, lastContact,
}

enum GroupField { none, type, status, organizer, tag, date }

enum FilterOperator { equals, contains, notEquals, greaterThan, lessThan, isEmpty }

enum ViewMode { grid, list, grouped, matrix }

class FilterRule {
  final String property;
  final FilterOperator op;
  final dynamic value;
  const FilterRule({required this.property, required this.op, required this.value});

  Map<String, dynamic> toJson() => {'property': property, 'op': op.name, 'value': value};
  factory FilterRule.fromJson(Map<String, dynamic> j) => FilterRule(
    property: j['property'], op: FilterOperator.values.byName(j['op']), value: j['value']);
}

class SavedFilter {
  final String id;
  final String name;
  final String targetType; // 'note'|'resource'|'habit'|'task'|'goal'|'person'|'journal_entry'|'tracker'|'*'
  final List<FilterRule> rules;
  final SortField sortBy;
  final bool sortAscending;
  final GroupField groupBy;
  final ViewMode viewMode;

  const SavedFilter({
    required this.id, required this.name, required this.targetType,
    this.rules = const [], this.sortBy = SortField.modified,
    this.sortAscending = false, this.groupBy = GroupField.none,
    this.viewMode = ViewMode.grid,
  });

  List<T> apply<T>(List<T> items) =>
    items.where((item) => rules.every((rule) => _matchesRule(item, rule))).toList();

  bool _matchesRule(dynamic item, FilterRule rule) {
    final val = _getProperty(item, rule.property);
    return switch (rule.op) {
      FilterOperator.equals      => val?.toString() == rule.value?.toString(),
      FilterOperator.notEquals   => val?.toString() != rule.value?.toString(),
      FilterOperator.contains    => val is List
          ? (rule.value is List
              ? (rule.value as List).any((v) => val.contains(v))
              : val.contains(rule.value))
          : val?.toString().toLowerCase().contains(rule.value?.toString().toLowerCase() ?? '') == true,
      FilterOperator.greaterThan => (val is num && rule.value is num) && val > rule.value,
      FilterOperator.lessThan    => (val is num && rule.value is num) && val < rule.value,
      FilterOperator.isEmpty     => val == null || (val is List && val.isEmpty) || (val is String && val.isEmpty),
    };
  }

  dynamic _getProperty(dynamic item, String prop) => switch (prop) {
    'noteType'        => item.noteType,
    'status'          => item.status?.name ?? item.stage?.name ?? item.state?.name,
    'tags'            => item.tags,
    'organizers'      => item.organizers?.map((o) => o.slug).toList(),
    'rating'          => item.rating,
    'resourceType'    => item.resourceType,
    'priority'        => item.priority?.name,
    'pinned'          => item.pinned,
    'archived'        => item.archived,
    'author'          => item.author,
    'category'        => item.category,
    'goalType'        => item.goalType?.name,
    'state'           => item.state?.name,
    'contactPriority' => item.contactPriority?.name,
    'moodSlug'        => item.moodSlug,
    _                 => null,
  };

  SavedFilter copyWith({
    String? name, List<FilterRule>? rules, SortField? sortBy,
    bool? sortAscending, GroupField? groupBy, ViewMode? viewMode,
  }) => SavedFilter(
    id: id, name: name ?? this.name, targetType: targetType,
    rules: rules ?? this.rules, sortBy: sortBy ?? this.sortBy,
    sortAscending: sortAscending ?? this.sortAscending,
    groupBy: groupBy ?? this.groupBy, viewMode: viewMode ?? this.viewMode,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'targetType': targetType,
    'rules': rules.map((r) => r.toJson()).toList(),
    'sortBy': sortBy.name, 'sortAscending': sortAscending,
    'groupBy': groupBy.name, 'viewMode': viewMode.name,
  };

  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
    id: j['id'], name: j['name'], targetType: j['targetType'],
    rules: (j['rules'] as List? ?? []).map((r) => FilterRule.fromJson(r as Map<String, dynamic>)).toList(),
    sortBy: SortField.values.byName(j['sortBy'] ?? 'modified'),
    sortAscending: j['sortAscending'] ?? false,
    groupBy: GroupField.values.byName(j['groupBy'] ?? 'none'),
    viewMode: ViewMode.values.byName(j['viewMode'] ?? 'grid'),
  );
}

class FilterProperty {
  final String key;
  final String label;
  final List<String>? allowedValues;
  const FilterProperty({required this.key, required this.label, this.allowedValues});
}

// Propriedades disponíveis por tela:
class NoteFilterProperties {
  static const all = [
    FilterProperty(key: 'noteType', label: 'Tipo', allowedValues: ['text', 'outline', 'collection']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'pinned', label: 'Fixado', allowedValues: ['true', 'false']),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}

class ResourceFilterProperties {
  static const all = [
    FilterProperty(key: 'resourceType', label: 'Tipo', allowedValues: ['Book', 'Podcast', 'Movie', 'Article', 'Course']),
    FilterProperty(key: 'status', label: 'Status', allowedValues: ['toConsume', 'inProgress', 'completed', 'dropped']),
    FilterProperty(key: 'author', label: 'Autor'),
    FilterProperty(key: 'category', label: 'Categoria'),
    FilterProperty(key: 'rating', label: 'Rating'),
    FilterProperty(key: 'tags', label: 'Tags'),
  ];
}

class HabitFilterProperties {
  static const all = [
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TaskFilterProperties {
  static const all = [
    FilterProperty(key: 'status', label: 'Status', allowedValues: ['idea','todo','inProgress','pending','finalized']),
    FilterProperty(key: 'priority', label: 'Prioridade', allowedValues: ['low','medium','high','critical']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}

class GoalFilterProperties {
  static const all = [
    FilterProperty(key: 'state', label: 'Estado', allowedValues: ['active','completed','onHold','cancelled']),
    FilterProperty(key: 'goalType', label: 'Tipo', allowedValues: ['repeating','oneTime']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class PersonFilterProperties {
  static const all = [
    FilterProperty(key: 'contactPriority', label: 'Prioridade', allowedValues: ['low','medium','high','critical']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class JournalFilterProperties {
  static const all = [
    FilterProperty(key: 'moodSlug', label: 'Mood'),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TrackerFilterProperties {
  static const all = [
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}
```
---
A2 — Settings Provider: novos campos
O que é: Os campos `userName`, `accentColor` e `savedFiltersRaw` ainda não existem em `AppSettings`. São necessários para saudação personalizada no Home, cor de destaque editável e persistência de filtros salvos.
Arquivo: `lib/providers/settings_provider.dart` — EDITAR
Adicionar ao modelo `AppSettings`:
```dart
final String? userName;
final String accentColor;               // hex '#FFB000'
final List<Map<String, dynamic>> savedFiltersRaw; // serializado como JSON list

// No construtor:
this.userName,
this.accentColor = '#FFB000',
this.savedFiltersRaw = const [],

// No copyWith:
String? userName, String? accentColor, List<Map<String, dynamic>>? savedFiltersRaw,
userName: userName ?? this.userName,
accentColor: accentColor ?? this.accentColor,
savedFiltersRaw: savedFiltersRaw ?? this.savedFiltersRaw,

// Helpers derivados (não persistidos, calculados):
List<SavedFilter> get savedFilters =>
    savedFiltersRaw.map((j) => SavedFilter.fromJson(j)).toList();

List<SavedFilter> filtersFor(String targetType) =>
    savedFilters.where((f) => f.targetType == targetType || f.targetType == '*').toList();
```
Adicionar ao `SettingsNotifier`:
```dart
Future<void> setUserName(String name) async {
  state = state.copyWith(userName: name.trim());
  await _persist();
}

Future<void> setAccentColor(String hex) async {
  state = state.copyWith(accentColor: hex);
  await _persist();
}

Future<void> upsertSavedFilter(SavedFilter filter) async {
  final list = state.savedFilters.toList();
  final idx = list.indexWhere((f) => f.id == filter.id);
  if (idx >= 0) list[idx] = filter; else list.add(filter);
  state = state.copyWith(savedFiltersRaw: list.map((f) => f.toJson()).toList());
  await _persist();
}

Future<void> deleteSavedFilter(String filterId) async {
  final list = state.savedFilters.where((f) => f.id != filterId).toList();
  state = state.copyWith(savedFiltersRaw: list.map((f) => f.toJson()).toList());
  await _persist();
}
```
Incluir `userName`, `accentColor`, `savedFiltersRaw` na leitura/escrita do SharedPreferences (JSON encode/decode da lista para `savedFiltersRaw`).
---
A3 — `extractHighlights` no MarkdownParser
O que é: Método estático que extrai citações/destaques (blockquotes `>`) de um body markdown ou Quill Delta. Necessário para a Resources Screen mostrar highlights do synopsis e para o Home mostrar a quote do dia. Hoje não existe — o campo `synopsis` é tratado como texto livre sem extração de highlights.
Arquivo: `lib/services/markdown_parser.dart` — EDITAR
```dart
class HighlightItem {
  final String text;
  final String? tag;   // extraído de '#palavra' no final da linha
  final String? date;  // extraído de 'YYYY-MM-DD' se presente
  const HighlightItem({required this.text, this.tag, this.date});
}

// Dentro de MarkdownParser:
static List<HighlightItem> extractHighlights(String markdown) {
  if (markdown.isEmpty) return [];
  final highlights = <HighlightItem>[];

  // Tentar Quill Delta primeiro
  final ops = tryParseDeltaOps(markdown);
  if (ops != null) {
    for (final op in ops) {
      final insert = op['insert'];
      final attrs  = op['attributes'];
      if (insert is String && attrs is Map &&
          (attrs['blockquote'] == true || attrs['quote'] == true)) {
        final text = insert.trim();
        if (text.isNotEmpty) highlights.add(HighlightItem(text: text));
      }
    }
    return highlights;
  }

  // Markdown plano: linhas que começam com '>'
  final lines = markdown.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('>')) continue;

    var text = line.replaceFirst(RegExp(r'^>\s*(\[!\w+\]\s*)?'), '').trim();
    if (text.isEmpty) continue;

    // Extrair tag inline: '…texto #tag' → tag separada
    String? tag;
    final tagMatch = RegExp(r'#(\w+)\s*$').firstMatch(text);
    if (tagMatch != null) {
      tag  = tagMatch.group(1);
      text = text.substring(0, tagMatch.start).trim();
    }

    // Extrair data YYYY-MM-DD se presente
    String? date;
    final dateMatch = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text);
    if (dateMatch != null) date = dateMatch.group(0);

    // Continuação multi-linha
    while (i + 1 < lines.length && lines[i + 1].trim().startsWith('>')) {
      i++;
      final cont = lines[i].trim().replaceFirst(RegExp(r'^>\s*'), '').trim();
      if (cont.isNotEmpty) text += ' $cont';
    }

    if (text.length > 5) highlights.add(HighlightItem(text: text, tag: tag, date: date));
  }
  return highlights;
}
```
---
A4 — Encoding UTF-8 nos serviços de arquivo
O que é: Bug crítico de dados. Os serviços `obsidian_service.dart`, `google_drive_sync_service.dart` e `backup_service.dart` não especificam encoding ao ler/escrever arquivos, então o Dart usa o encoding padrão do sistema. Em alguns dispositivos/ambientes isso resulta em caracteres portugueses corrompidos: `ç` vira `Ã§`, `ã` vira `Ã£`, `é` vira `Ã©`. Isso aparece visível no código-fonte do próprio `home_screen.dart` em comentários corrompidos.
Como resolver:
Em `obsidian_service.dart`:
```dart
import 'dart:convert' show utf8;

// ANTES:
await file.writeAsString(content);
final content = await file.readAsString();

// DEPOIS:
await file.writeAsString(content, encoding: utf8);
final content = await file.readAsString(encoding: utf8);
```
Em `google_drive_sync_service.dart`:
```dart
// Upload de conteúdo markdown:
final bytes = utf8.encode(markdownContent);
// Download:
final content = utf8.decode(responseBodyBytes);
```
Em `backup_service.dart`:
```dart
final jsonStr = jsonEncode(data);
await file.writeAsString(jsonStr, encoding: utf8);
// Leitura:
final raw = await file.readAsString(encoding: utf8);
```
Adicionar: Varrer o projeto por strings com `Ã§`, `Ã£`, `Ã©`, `Ã¢` e substituir pelos caracteres UTF-8 corretos. Ex: `'Descartar alteraÃ§Ãµes?'` → `'Descartar alterações?'`.
---
A5 — Badge Counts Provider
O que é: Provider derivado que calcula contagens de pendências para exibir como badges na bottom navigation. Hoje a nav não mostra nenhum indicador de urgência — o usuário não sabe que tem tasks vencidas ou inbox cheio sem abrir cada tela.
Arquivo: `lib/providers/badge_counts_provider.dart` — CRIAR NOVO
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vault_provider.dart';

final badgeCountsProvider = Provider<Map<String, int>>((ref) {
  final tasks      = ref.watch(tasksProvider);
  final people     = ref.watch(peopleProvider);
  final inboxItems = ref.watch(inboxProvider).valueOrNull ?? [];
  final now        = DateTime.now();

  final overdueTasks = tasks.where((t) =>
    t.stage?.name != 'finalized' &&
    t.deadline != null &&
    t.deadline!.isBefore(now)).length;

  final pendingContacts = people.where((p) => p.isDueForContact).length;
  final pendingInbox    = inboxItems.where((i) => !(i.isArchived ?? false)).length;

  return {
    'planner': overdueTasks,
    'people':  pendingContacts,
    'inbox':   pendingInbox,
    'total':   overdueTasks + pendingContacts + pendingInbox,
  };
});
```
---
A6 — Modelos de novas features
A6.1 — `Habit.isQuitting`
O que é: Campo booleano que marca um hábito como "de parar" — o objetivo é NÃO fazer, não fazer. Ex: parar de fumar, parar de roer unhas. Hoje esses hábitos são tratados igual a qualquer outro, aparecem no Planner e CalendarWidget com checkbox de marcar, o que é semanticamente errado.
Arquivo: `lib/models/habit_model.dart` — EDITAR
```dart
final bool isQuitting; // default: false

// No construtor, copyWith, toJson/fromJson:
'is_quitting': isQuitting,
isQuitting: j['is_quitting'] ?? false,
```
A6.2 — `TrackerField`: campos de alerta de saúde
O que é: Extensão do `TrackerField` existente para suportar alertas automáticos por campo. Necessário para o tracker de saúde (sono, cabelo, comida, cocô) mostrar indicadores visuais sem o usuário precisar interpretar os dados manualmente.
Arquivo: `lib/models/tracker_model.dart` — EDITAR
```dart
enum FieldAlertLevel { none, info, warning, critical }

// Em TrackerField, adicionar:
final FieldAlertLevel alertLevel;
final double? alertThreshold; // aciona alerta quando valor <= threshold
final String? alertNote;      // contexto explicativo (ex: "depende dos remédios")
final bool alwaysAlert;       // true = qualquer registro acende alerta (ex: buraco no cabelo)

// Serialização:
'alert_level':     alertLevel.name,
'alert_threshold': alertThreshold,
'alert_note':      alertNote,
'always_alert':    alwaysAlert,

// Deserialização:
alertLevel:     FieldAlertLevel.values.byName(j['alert_level'] ?? 'none'),
alertThreshold: (j['alert_threshold'] as num?)?.toDouble(),
alertNote:      j['alert_note'],
alwaysAlert:    j['always_alert'] ?? false,
```
A6.3 — `Tracker.isHealthTracker`
Arquivo: `lib/models/tracker_model.dart` — EDITAR
```dart
final bool isHealthTracker; // default: false

// Serialização:
'is_health_tracker': isHealthTracker,
isHealthTracker: j['is_health_tracker'] ?? false,
```
A6.4 — `Idea` (tipo novo)
O que é: Um tipo de objeto de primeiro nível para capturar ideias brutas antes de saber o que fazer com elas. Mais leve que uma Task (sem stage pipeline), mais estruturado que uma Note (tem horizonte de tempo, prioridade, conversão). Quando a ideia amadurece, é convertida em Task/Projeto/Goal/Note mantendo suas propriedades.
Arquivo: `lib/models/idea_model.dart` — CRIAR NOVO
```dart
enum IdeaStatus  { raw, developing, readyToAct, converted, dropped }
enum IdeaHorizon { now, soon, someday, noDeadline }

class Idea implements ContentObject {
  @override final String id;
  @override final String title;
  @override final DateTime? createdAt;
  @override final DateTime? updatedAt;
  @override final bool archived;
  @override final List<OrganizerReference> organizers;
  @override final List<String> tags;
  @override final String? color;
  @override final String? emoji;

  final String?       body;
  final IdeaStatus    status;
  final IdeaHorizon   horizon;
  final TaskPriority? priority;
  final DateTime?     targetDate;
  final String?       convertedToType; // 'task'|'project'|'goal'|'note'
  final String?       convertedToId;
  final List<String>  linkedSlugs;     // [[wiki-links]]

  const Idea({
    required this.id, required this.title,
    this.createdAt, this.updatedAt, this.archived = false,
    this.organizers = const [], this.tags = const [],
    this.color, this.emoji,
    this.body, this.status = IdeaStatus.raw,
    this.horizon = IdeaHorizon.someday,
    this.priority, this.targetDate,
    this.convertedToType, this.convertedToId,
    this.linkedSlugs = const [],
  });

  bool get isConverted => convertedToType != null;

  @override String get obsidianFileName => title;
  @override String get slug => id;

  Idea copyWith({
    String? title, String? body, IdeaStatus? status, IdeaHorizon? horizon,
    TaskPriority? priority, DateTime? targetDate, bool? archived,
    List<OrganizerReference>? organizers, List<String>? tags,
    String? color, String? emoji, List<String>? linkedSlugs,
    String? convertedToType, String? convertedToId, DateTime? updatedAt,
  }) => Idea(
    id: id, title: title ?? this.title,
    createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    organizers: organizers ?? this.organizers, tags: tags ?? this.tags,
    color: color ?? this.color, emoji: emoji ?? this.emoji,
    body: body ?? this.body, status: status ?? this.status,
    horizon: horizon ?? this.horizon, priority: priority ?? this.priority,
    targetDate: targetDate ?? this.targetDate,
    convertedToType: convertedToType ?? this.convertedToType,
    convertedToId: convertedToId ?? this.convertedToId,
    linkedSlugs: linkedSlugs ?? this.linkedSlugs,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body,
    'status': status.name, 'horizon': horizon.name,
    'priority': priority?.name, 'target_date': targetDate?.toIso8601String(),
    'archived': archived,
    'organizers': organizers.map((o) => o.toJson()).toList(),
    'tags': tags, 'color': color, 'emoji': emoji,
    'linked_slugs': linkedSlugs,
    'converted_to_type': convertedToType, 'converted_to_id': convertedToId,
    'created_at': createdAt?.toIso8601String(), 'updated_at': updatedAt?.toIso8601String(),
  };

  factory Idea.fromJson(Map<String, dynamic> j) => Idea(
    id: j['id'], title: j['title'] ?? '',
    body: j['body'], status: IdeaStatus.values.byName(j['status'] ?? 'raw'),
    horizon: IdeaHorizon.values.byName(j['horizon'] ?? 'someday'),
    priority: j['priority'] != null ? TaskPriority.values.byName(j['priority']) : null,
    targetDate: j['target_date'] != null ? DateTime.parse(j['target_date']) : null,
    archived: j['archived'] ?? false,
    organizers: (j['organizers'] as List? ?? [])
      .map((o) => OrganizerReference.fromJson(o as Map<String, dynamic>)).toList(),
    tags: List<String>.from(j['tags'] ?? []),
    color: j['color'], emoji: j['emoji'],
    linkedSlugs: List<String>.from(j['linked_slugs'] ?? []),
    convertedToType: j['converted_to_type'], convertedToId: j['converted_to_id'],
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
    updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
  );
}
```
A6.5 — `ShoppingList` e `ShoppingItem` (tipo novo)
O que é: Tipo de objeto dedicado para listas de compras. Separado de Note e Task porque tem requisitos únicos: captura ultra-rápida (Enter = próximo item), widget nativo Android com checkbox, agrupamento por categoria, marcação que "some" o item. Usar Note/collection ou Task para isso seria inferior em UX.
Arquivo: `lib/models/shopping_list_model.dart` — CRIAR NOVO
```dart
enum ShoppingItemStatus { active, checked, archived }

class ShoppingItem {
  final String id;
  final String name;
  final String? quantity;   // "2 kg", "1 caixa"
  final String? category;  // "Hortifruti", "Limpeza"
  final String? note;
  final ShoppingItemStatus status;
  final int order;

  const ShoppingItem({
    required this.id, required this.name,
    this.quantity, this.category, this.note,
    this.status = ShoppingItemStatus.active, this.order = 0,
  });

  bool get isChecked => status == ShoppingItemStatus.checked;

  ShoppingItem copyWith({
    String? name, String? quantity, String? category,
    String? note, ShoppingItemStatus? status, int? order,
  }) => ShoppingItem(
    id: id, name: name ?? this.name, quantity: quantity ?? this.quantity,
    category: category ?? this.category, note: note ?? this.note,
    status: status ?? this.status, order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'quantity': quantity,
    'category': category, 'note': note, 'status': status.name, 'order': order,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id: j['id'], name: j['name'], quantity: j['quantity'],
    category: j['category'], note: j['note'],
    status: ShoppingItemStatus.values.byName(j['status'] ?? 'active'),
    order: j['order'] ?? 0,
  );
}

class ShoppingList implements ContentObject {
  @override final String id;
  @override final String title;
  @override final DateTime? createdAt;
  @override final DateTime? updatedAt;
  @override final bool archived;
  @override final List<OrganizerReference> organizers;
  @override final List<String> tags;
  @override final String? color;
  @override final String? emoji;

  final List<ShoppingItem> items;
  final bool hideChecked;

  @override String get obsidianFileName => title;
  @override String get slug => id;

  const ShoppingList({
    required this.id, required this.title,
    this.createdAt, this.updatedAt, this.archived = false,
    this.organizers = const [], this.tags = const [],
    this.color, this.emoji = '🛒',
    this.items = const [], this.hideChecked = true,
  });

  List<ShoppingItem> get activeItems =>
    items.where((i) => i.status == ShoppingItemStatus.active).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

  List<ShoppingItem> get checkedItems =>
    items.where((i) => i.status == ShoppingItemStatus.checked).toList();

  int get activeCount  => activeItems.length;
  int get checkedCount => checkedItems.length;
  int get totalCount   => items.where((i) => i.status != ShoppingItemStatus.archived).length;

  ShoppingList copyWith({
    String? title, List<ShoppingItem>? items, bool? hideChecked,
    bool? archived, List<OrganizerReference>? organizers,
    List<String>? tags, String? color, String? emoji, DateTime? updatedAt,
  }) => ShoppingList(
    id: id, title: title ?? this.title,
    createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    organizers: organizers ?? this.organizers, tags: tags ?? this.tags,
    color: color ?? this.color, emoji: emoji ?? this.emoji,
    items: items ?? this.items, hideChecked: hideChecked ?? this.hideChecked,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title,
    'items': items.map((i) => i.toJson()).toList(),
    'hide_checked': hideChecked, 'archived': archived,
    'organizers': organizers.map((o) => o.toJson()).toList(),
    'tags': tags, 'color': color, 'emoji': emoji,
    'created_at': createdAt?.toIso8601String(), 'updated_at': updatedAt?.toIso8601String(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
    id: j['id'], title: j['title'],
    items: (j['items'] as List? ?? [])
      .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>)).toList(),
    hideChecked: j['hide_checked'] ?? true,
    archived: j['archived'] ?? false,
    organizers: (j['organizers'] as List? ?? [])
      .map((o) => OrganizerReference.fromJson(o as Map<String, dynamic>)).toList(),
    tags: List<String>.from(j['tags'] ?? []),
    color: j['color'], emoji: j['emoji'],
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
    updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
  );
}
```
---
A7 — Providers de novas features (`vault_provider.dart`)
O que é: Os novos tipos `Idea` e `ShoppingList` precisam de providers StateNotifier para CRUD e persistência, seguindo o mesmo padrão dos providers existentes.
Arquivo: `lib/providers/vault_provider.dart` — EDITAR
```dart
// ── Ideas ──────────────────────────────────────────────────────────────────
final ideasProvider = StateNotifierProvider<IdeasNotifier, List<Idea>>(
  (ref) => IdeasNotifier(ref));

class IdeasNotifier extends StateNotifier<List<Idea>> {
  IdeasNotifier(this._ref) : super([]) { _load(); }
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('ideas');
    if (raw != null) {
      state = (jsonDecode(raw) as List)
        .map((j) => Idea.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ideas', jsonEncode(state.map((i) => i.toJson()).toList()));
  }

  Future<void> addIdea(Idea idea)    async { state = [...state, idea]; await _persist(); }
  Future<void> updateIdea(Idea idea) async {
    state = state.map((i) => i.id == idea.id ? idea : i).toList();
    await _persist();
  }
  Future<void> deleteIdea(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _persist();
  }
  Future<void> archiveIdea(String id) async =>
    updateIdea(state.firstWhere((i) => i.id == id).copyWith(archived: true));
}

// ── Shopping Lists ──────────────────────────────────────────────────────────
final shoppingListsProvider = StateNotifierProvider<ShoppingListsNotifier, List<ShoppingList>>(
  (ref) => ShoppingListsNotifier(ref));

class ShoppingListsNotifier extends StateNotifier<List<ShoppingList>> {
  ShoppingListsNotifier(this._ref) : super([]) { _load(); }
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('shopping_lists');
    if (raw != null) {
      state = (jsonDecode(raw) as List)
        .map((j) => ShoppingList.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_lists',
      jsonEncode(state.map((l) => l.toJson()).toList()));
  }

  Future<void> addList(ShoppingList list)    async { state = [...state, list]; await _persist(); }
  Future<void> updateList(ShoppingList list) async {
    state = state.map((l) => l.id == list.id ? list : l).toList();
    await _persist();
    // Notificar widget nativo Android
    await _ref.read(widgetServiceProvider).updateShoppingWidget(list);
  }

  Future<void> addItem(String listId, ShoppingItem item) async {
    final list    = state.firstWhere((l) => l.id == listId);
    final updated = list.copyWith(
      items: [...list.items, item], updatedAt: DateTime.now());
    await updateList(updated);
  }

  Future<void> toggleItem(String listId, String itemId) async {
    final list  = state.firstWhere((l) => l.id == listId);
    final items = list.items.map((i) {
      if (i.id != itemId) return i;
      return i.copyWith(
        status: i.isChecked ? ShoppingItemStatus.active : ShoppingItemStatus.checked);
    }).toList();
    await updateList(list.copyWith(items: items, updatedAt: DateTime.now()));
  }

  Future<void> clearChecked(String listId) async {
    final list  = state.firstWhere((l) => l.id == listId);
    final items = list.items
      .where((i) => i.status != ShoppingItemStatus.checked).toList();
    await updateList(list.copyWith(items: items, updatedAt: DateTime.now()));
  }
}
```
Registrar `ideasProvider` no `allObjectsProvider` para que busca global e wiki-links funcionem.
---
A8 — Health Alerts Provider
O que é: Provider derivado que calcula automaticamente quais campos do tracker de saúde estão em estado de alerta. Não requer ação do usuário — é reativo e se atualiza quando novos registros são salvos.
Arquivo: `lib/providers/health_alerts_provider.dart` — CRIAR NOVO
```dart
class HealthAlert {
  final Tracker tracker;
  final TrackerField field;
  final double? lastValue;
  final DateTime? lastRecordDate;
  final int daysSinceLastRecord;
  final FieldAlertLevel level;
  final String message;

  const HealthAlert({
    required this.tracker, required this.field,
    required this.lastValue, required this.lastRecordDate,
    required this.daysSinceLastRecord, required this.level, required this.message,
  });
}

final healthAlertsProvider = Provider<List<HealthAlert>>((ref) {
  final trackers   = ref.watch(trackersProvider);
  final allRecords = ref.watch(trackingRecordsProvider);
  final now        = DateTime.now();
  final alerts     = <HealthAlert>[];

  for (final tracker in trackers.where((t) => t.isHealthTracker)) {
    for (final field in tracker.fields) {
      if (field.alertLevel == FieldAlertLevel.none && !field.alwaysAlert) continue;

      final fieldRecords = allRecords
        .where((r) => r.trackerId == tracker.id && r.fieldValues.containsKey(field.name))
        .toList()..sort((a, b) => b.date.compareTo(a.date));

      final last     = fieldRecords.isNotEmpty ? fieldRecords.first : null;
      final lastDate = last?.date;
      final lastVal  = last != null ? (last.fieldValues[field.name] as num?)?.toDouble() : null;
      final daysSince = lastDate != null
        ? now.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays
        : 999;

      FieldAlertLevel level = FieldAlertLevel.none;
      String message = '';

      if (field.alwaysAlert && last != null) {
        level   = FieldAlertLevel.critical;
        message = field.alertNote ?? 'Verificar ${field.name}';
      } else if (field.alertThreshold != null && lastVal != null && lastVal <= field.alertThreshold!) {
        level   = field.alertLevel;
        message = field.alertNote ?? '${field.name}: $lastVal (abaixo de ${field.alertThreshold})';
      } else if (daysSince >= 3 && field.alertLevel != FieldAlertLevel.none) {
        level   = FieldAlertLevel.warning;
        message = '${field.name}: sem registro há $daysSince dias';
      }

      if (level != FieldAlertLevel.none) {
        alerts.add(HealthAlert(
          tracker: tracker, field: field, lastValue: lastVal,
          lastRecordDate: lastDate, daysSinceLastRecord: daysSince,
          level: level, message: message));
      }
    }
  }

  alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
  return alerts;
});
```

---
BLOCO B — WIDGETS REUTILIZÁVEIS
---
B1 — FilterSortSheet
O que é: Bottom sheet unificado de filtros, ordenação, agrupamento e modo de visualização. Hoje cada tela tem sua própria lógica de filtro (chips hardcoded em Notes, popup de sort em Resources, etc.). O `FilterSortSheet` substitui tudo isso com uma interface consistente e filtros que o usuário pode nomear e reutilizar.
UX: Abre via botão `Icons.tune_rounded` na AppBar de qualquer tela. Altura inicial 75% da tela, expansível até 95%. Tem 5 seções: Meus Filtros (chips dos filtros salvos), Filtrar Por (regras dinâmicas), Ordenar, Agrupar e Visualização. Footer com Limpar e Aplicar. Long-press num filtro salvo → deletar.
Arquivo: `lib/ui/widgets/filter_sort_sheet.dart` — CRIAR NOVO
```dart
class FilterSortSheet extends ConsumerStatefulWidget {
  final String targetType;
  final SavedFilter? currentFilter;
  final List<FilterProperty> availableProperties;
  final ValueChanged<SavedFilter?> onApply;

  const FilterSortSheet({
    super.key, required this.targetType, required this.currentFilter,
    required this.availableProperties, required this.onApply,
  });

  static Future<void> show({
    required BuildContext context, required WidgetRef ref,
    required String targetType, required SavedFilter? currentFilter,
    required List<FilterProperty> availableProperties,
    required ValueChanged<SavedFilter?> onApply,
  }) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => FilterSortSheet(
            targetType: targetType, currentFilter: currentFilter,
            availableProperties: availableProperties,
            onApply: (f) { Navigator.pop(ctx); onApply(f); }))));
  }

  @override
  ConsumerState<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends ConsumerState<FilterSortSheet> {
  late SavedFilter _draft;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter ?? SavedFilter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Novo filtro', targetType: widget.targetType);
    _nameController.text = _draft.name;
  }

  @override void dispose() { _nameController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(settingsProvider).filtersFor(widget.targetType);
    return Column(children: [
      // Handle bar
      Container(margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36, height: 4,
        decoration: BoxDecoration(color: AppTheme.dividerColor(context),
          borderRadius: BorderRadius.circular(2))),
      // Header
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          const Text('Filtrar & Ordenar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context)),
        ])),
      const Divider(),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        // ── Filtros salvos ──
        _section('MEUS FILTROS', child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ...saved.map(_savedChip),
            _addSavedChip(),
          ]))),
        // ── Regras ──
        _section('FILTRAR POR', child: Column(children: [
          ..._draft.rules.asMap().entries.map((e) => _ruleRow(e.key, e.value)),
          ListTile(
            leading: Icon(Icons.add_circle_outline_rounded, color: AppColors.info, size: 18),
            title: Text('Adicionar filtro', style: TextStyle(
              fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600)),
            onTap: _addRule, dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4)),
        ])),
        // ── Ordenar ──
        _section('ORDENAR POR', child: Column(children: [
          _dropdownRow(SortField.values.map((f) => f.name).toList(),
            _draft.sortBy.name, (val) => setState(() =>
              _draft = _draft.copyWith(sortBy: SortField.values.byName(val)))),
          const SizedBox(height: 8),
          Row(children: [
            _directionBtn('↓ Mais recente', false),
            const SizedBox(width: 8),
            _directionBtn('↑ Mais antigo', true),
          ]),
        ])),
        // ── Agrupar ──
        _section('AGRUPAR POR', child: _dropdownRow(
          GroupField.values.map((f) => f.name).toList(), _draft.groupBy.name,
          (val) => setState(() =>
            _draft = _draft.copyWith(groupBy: GroupField.values.byName(val))))),
        // ── Visualização ──
        _section('VISUALIZAÇÃO', child: Row(children: [
          _viewBtn('⊞ Grade', ViewMode.grid),
          const SizedBox(width: 8),
          _viewBtn('☰ Lista', ViewMode.list),
          const SizedBox(width: 8),
          _viewBtn('§ Grupos', ViewMode.grouped),
        ])),
      ]))),
      // Footer
      const Divider(height: 1),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16,
          10 + MediaQuery.of(context).viewInsets.bottom),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: _clear, child: const Text('Limpar'))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: FilledButton(onPressed: _apply, child: const Text('Aplicar'))),
        ])),
    ]);
  }

  Widget _section(String label, {required Widget child}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
      const SizedBox(height: 8), child, const SizedBox(height: 4),
    ]));

  Widget _savedChip(SavedFilter f) {
    final isActive = _draft.id == f.id;
    return GestureDetector(
      onTap: () => setState(() => _draft = f),
      onLongPress: () => _deleteFilter(f),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : AppTheme.surfaceVariantColor(context),
          border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          borderRadius: BorderRadius.circular(20)),
        child: Text(f.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: isActive ? AppColors.primary : AppTheme.textSecondaryColor(context)))));
  }

  Widget _addSavedChip() => GestureDetector(
    onTap: _promptSaveCurrent,
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20)),
      child: Text('＋ Salvar atual',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info))));

  Widget _ruleRow(int index, FilterRule rule) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: DropdownButtonFormField<String>(
        value: widget.availableProperties.any((p) => p.key == rule.property) ? rule.property : null,
        decoration: _inputDec('Propriedade'),
        items: widget.availableProperties.map((p) => DropdownMenuItem(
          value: p.key, child: Text(p.label, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(property: val, op: rules[index].op, value: '');
          setState(() => _draft = _draft.copyWith(rules: rules));
        })),
      const SizedBox(width: 6),
      SizedBox(width: 80, child: DropdownButtonFormField<FilterOperator>(
        value: rule.op, decoration: _inputDec('Op.'),
        items: [FilterOperator.equals, FilterOperator.notEquals,
                FilterOperator.contains, FilterOperator.isEmpty]
          .map((op) => DropdownMenuItem(value: op,
            child: Text(_opLabel(op), style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(property: rule.property, op: val, value: rule.value);
          setState(() => _draft = _draft.copyWith(rules: rules));
        })),
      const SizedBox(width: 6),
      if (rule.op != FilterOperator.isEmpty)
        Expanded(child: _valueField(rule, index))
      else const Expanded(child: SizedBox.shrink()),
      GestureDetector(
        onTap: () {
          final rules = _draft.rules.toList()..removeAt(index);
          setState(() => _draft = _draft.copyWith(rules: rules));
        },
        child: Padding(padding: const EdgeInsets.all(8),
          child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error))),
    ]));

  Widget _valueField(FilterRule rule, int index) {
    final prop = widget.availableProperties.firstWhere(
      (p) => p.key == rule.property,
      orElse: () => FilterProperty(key: rule.property, label: rule.property));
    if (prop.allowedValues != null) {
      return DropdownButtonFormField<String>(
        value: prop.allowedValues!.contains(rule.value) ? rule.value as String : null,
        decoration: _inputDec('Valor'),
        items: prop.allowedValues!.map((v) => DropdownMenuItem(
          value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(property: rule.property, op: rule.op, value: val);
          setState(() => _draft = _draft.copyWith(rules: rules));
        });
    }
    return TextFormField(
      initialValue: rule.value?.toString() ?? '',
      decoration: _inputDec('Valor'),
      style: const TextStyle(fontSize: 12),
      onChanged: (val) {
        final rules = _draft.rules.toList();
        rules[index] = FilterRule(property: rule.property, op: rule.op, value: val);
        setState(() => _draft = _draft.copyWith(rules: rules));
      });
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    isDense: true);

  Widget _dropdownRow(List<String> options, String current, ValueChanged<String> onChange) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: current, isExpanded: true,
        items: options.map((o) => DropdownMenuItem(
          value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (val) { if (val != null) onChange(val); })));

  Widget _directionBtn(String label, bool ascending) {
    final active = _draft.sortAscending == ascending;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(sortAscending: ascending)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : AppTheme.surfaceVariantColor(context),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.primary : AppTheme.textSecondaryColor(context)))))));
  }

  Widget _viewBtn(String label, ViewMode mode) {
    final active = _draft.viewMode == mode;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(viewMode: mode)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : AppTheme.surfaceVariantColor(context),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.primary : AppTheme.textSecondaryColor(context)))))));
  }

  void _addRule() {
    final prop = widget.availableProperties.first;
    setState(() => _draft = _draft.copyWith(
      rules: [..._draft.rules, FilterRule(property: prop.key, op: FilterOperator.equals, value: '')]));
  }

  void _clear() => setState(() => _draft = SavedFilter(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: 'Todos', targetType: widget.targetType));

  void _apply() {
    final isBlank = _draft.rules.isEmpty &&
      _draft.groupBy == GroupField.none && _draft.sortBy == SortField.modified;
    widget.onApply(isBlank ? null : _draft);
  }

  void _promptSaveCurrent() async {
    _nameController.text = _draft.name;
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar filtro'),
        content: TextField(controller: _nameController, autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome do filtro')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ]));
    if (confirmed != true) return;
    final toSave = _draft.copyWith(name: _nameController.text.trim());
    await ref.read(settingsProvider.notifier).upsertSavedFilter(toSave);
    setState(() => _draft = toSave);
  }

  void _deleteFilter(SavedFilter f) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${f.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir')),
        ]));
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).deleteSavedFilter(f.id);
      if (_draft.id == f.id) _clear();
    }
  }

  String _opLabel(FilterOperator op) => switch (op) {
    FilterOperator.equals      => '=',
    FilterOperator.notEquals   => '≠',
    FilterOperator.contains    => 'contém',
    FilterOperator.greaterThan => '>',
    FilterOperator.lessThan    => '<',
    FilterOperator.isEmpty     => 'vazio',
  };
}
```
Padrão de uso em qualquer tela:
```dart
// Estado:
SavedFilter? _activeFilter;
List<SavedFilter> _savedFilters = [];

// initState:
WidgetsBinding.instance.addPostFrameCallback((_) {
  setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('TIPO'));
});

// Abrir painel:
void _openFilterSheet() => FilterSortSheet.show(
  context: context, ref: ref,
  targetType: 'TIPO',
  currentFilter: _activeFilter,
  availableProperties: TIPOFilterProperties.all,
  onApply: (f) => setState(() {
    _activeFilter = f;
    _savedFilters = ref.read(settingsProvider).filtersFor('TIPO');
  }));

// Chips dinâmicos (substituem qualquer chip hardcoded):
Widget _buildFilterChips() => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(children: [
    _chip('Todos', _activeFilter == null, () => setState(() => _activeFilter = null)),
    ..._savedFilters.map((f) => _chip(f.name, _activeFilter?.id == f.id,
      () => setState(() => _activeFilter = f))),
    GestureDetector(
      onTap: _openFilterSheet,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20)),
        child: Text('+ filtro', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info)))),
  ]));

Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? AppColors.primary : AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: selected ? Colors.black : AppTheme.textSecondaryColor(context)))));

// Filtragem + sort unificados:
List<T> _applyFilterAndSort<T>(List<T> all) {
  var result = (_activeFilter?.apply(all) ?? all).where((item) =>
    _searchQuery.isEmpty ||
    (item as dynamic).title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  final sort = _activeFilter?.sortBy ?? SortField.modified;
  final asc  = _activeFilter?.sortAscending ?? false;
  result.sort((a, b) {
    final cmp = switch (sort) {
      SortField.title    => (a as dynamic).title.compareTo((b as dynamic).title),
      SortField.created  => ((a as dynamic).createdAt ?? DateTime(0))
                              .compareTo((b as dynamic).createdAt ?? DateTime(0)),
      SortField.modified => ((a as dynamic).updatedAt ?? DateTime(0))
                              .compareTo((b as dynamic).updatedAt ?? DateTime(0)),
      SortField.manual   => ((a as dynamic).order ?? 0).compareTo((b as dynamic).order ?? 0),
      SortField.priority => ((a as dynamic).priority?.index ?? 0)
                              .compareTo((b as dynamic).priority?.index ?? 0),
      SortField.rating   => ((a as dynamic).rating ?? 0).compareTo((b as dynamic).rating ?? 0),
      _ => 0,
    };
    return asc ? cmp : -cmp;
  });
  return result;
}
```
---
B2 — SkeletonList
O que é: Widget de loading animado (shimmer) para substituir telas em branco enquanto os providers carregam dados. Hoje só o Dashboard tem skeleton — as demais telas mostram branco ou nada.
UX: Exibe N cards cinza com animação de fade (opacity 0.35→0.85 em loop de 1.2s). Quando o provider retorna dados, substitui automaticamente pela lista real sem layout shift perceptível.
Arquivo: `lib/ui/widgets/skeleton_list.dart` — CRIAR NOVO
```dart
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const SkeletonList({
    super.key, this.itemCount = 5, this.itemHeight = 72,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 100),
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding, itemCount: itemCount,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (ctx, i) => _SkeletonCard(height: itemHeight));
}

class _SkeletonCard extends StatefulWidget {
  final double height;
  const _SkeletonCard({required this.height});
  @override State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween(begin: 0.35, end: 0.85)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: widget.height,
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Opacity(opacity: _anim.value,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _line(context, 140, 13), const SizedBox(height: 12),
          _line(context, double.infinity, 11), const SizedBox(height: 8),
          _line(context, 180, 11),
        ]))));

  Widget _line(BuildContext context, double width, double height) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(6)));
}
```
Uso: Em telas com `AsyncValue`:
```dart
return notesAsync.when(
  data:    (notes)  => _buildList(notes),
  loading: ()       => const SkeletonList(),
  error:   (e, _)   => Center(child: Text('Erro: $e')));
```
---
B3 — HealthAlertsStrip
O que é: Widget reutilizável que exibe alertas do tracker de saúde. Versão compacta (scroll horizontal) para o dashboard. Versão expandida (lista vertical) para a aba Hoje dos hábitos. Aparece apenas quando há alertas — se tudo estiver bem, não ocupa espaço.
UX: Cada card de alerta tem cor semafórica (🚨 vermelho crítico, ⚠️ amarelo aviso, ℹ️ azul info), nome do campo, mensagem e botão "Registrar" que abre `CreateRecordForm` pré-selecionado. O campo `alertNote` (ex: "cabelo = alerta vermelho sempre") aparece em itálico abaixo da mensagem como contexto.
Arquivo: `lib/ui/widgets/health_alerts_strip.dart` — CRIAR NOVO
```dart
class HealthAlertsStrip extends ConsumerWidget {
  final bool compact;
  const HealthAlertsStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(healthAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    if (compact) {
      // Versão horizontal para dashboard
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => _AlertCard(alert: alerts[i], compact: true)));
    }

    // Versão expandida para HabitsScreen
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('SAÚDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
          const Spacer(),
          Text('${alerts.length} alerta${alerts.length == 1 ? "" : "s"}',
            style: const TextStyle(fontSize: 11, color: AppColors.warning)),
        ])),
      ...alerts.map((a) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _AlertCard(alert: a, compact: false))),
    ]);
  }
}

class _AlertCard extends ConsumerWidget {
  final HealthAlert alert;
  final bool compact;
  const _AlertCard({required this.alert, required this.compact});

  Color get _color => switch (alert.level) {
    FieldAlertLevel.critical => AppColors.error,
    FieldAlertLevel.warning  => AppColors.warning,
    FieldAlertLevel.info     => AppColors.info,
    FieldAlertLevel.none     => AppColors.textMuted,
  };

  String get _icon => switch (alert.level) {
    FieldAlertLevel.critical => '🚨',
    FieldAlertLevel.warning  => '⚠️',
    FieldAlertLevel.info     => 'ℹ️',
    FieldAlertLevel.none     => '•',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Expanded(child: Text(alert.field.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color))),
          ]),
          const SizedBox(height: 4),
          Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor(context))),
        ]));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.25))),
      child: Row(children: [
        Text(_icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${alert.tracker.title} · ${alert.field.name}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
          const SizedBox(height: 2),
          Text(alert.message,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
          if (alert.field.alertNote != null) ...[
            const SizedBox(height: 3),
            Text(alert.field.alertNote!, style: TextStyle(fontSize: 10,
              color: AppTheme.textMutedColor(context), fontStyle: FontStyle.italic)),
          ],
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateRecordForm(preselectedTracker: alert.tracker)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
            child: Text('Registrar', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _color)))),
      ]));
  }
}
```

---
BLOCO C — TELAS EXISTENTES: BUGS E MELHORIAS
---
C1 — Notes Screen
O que é: Tela de listagem de notas. Hoje usa filtros hardcoded (`['All','Text','Outline','Collection']`), modo de visualização único (lista reordenável) e a expansão de notas Outline/Collection não funciona — ao tocar no ícone de expandir, nada acontece.
Bugs a corrigir:
Expandir nota tipo Outline ou Collection não exibe nada. O código atual só renderiza editor para `noteType == 'text'`.
`_formatDate()` exibe hora sem zero-pad: "9:05" em vez de "09:05".
Chips de filtro hardcoded, sem possibilidade de salvar filtros personalizados.
UX nova:
AppBar: botão de toggle view (⊞ grid / ☰ lista) + botão `Icons.tune_rounded` abre FilterSortSheet
Chips dinâmicos (ver padrão B1) substituem `['All','Text','Outline','Collection']`
View Grid: `SliverGrid` 2 colunas, cards com emoji do tipo (📝 text, 🌿 outline, 🔮 collection), badge colorido de tipo (azul=text, verde=outline, roxo=collection), data modificada
View Grouped: seções por `groupBy` do filtro ativo, cada seção com header colapsável e pin lateral colorido
Arquivo: `lib/ui/screens/notes_screen.dart`
```dart
// Estado adicional:
enum NoteViewMode { grid, grouped }
NoteViewMode _viewMode = NoteViewMode.grid;
SavedFilter? _activeFilter;
List<SavedFilter> _savedFilters = [];

// Fix _formatDate:
String _formatDate(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
  }
  return '${date.day}/${date.month}';
}

// Fix expandir Outline/Collection — no _buildNoteItem existente,
// APÓS: if (isExpanded && note.noteType == 'text') RichTextEditor(...)
// ADICIONAR:
else if (isExpanded && note.noteType == 'outline')
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: OutlineEditor(
      items: note.outlineItems ?? [],
      onChanged: (items) {
        final updated = note.copyWith(outlineItems: items, updatedAt: DateTime.now());
        ref.read(vaultProvider.notifier).updateObject(updated);
      }))
else if (isExpanded && note.noteType == 'collection')
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: CollectionView(note: note))

// Grid view — substituir SliverReorderableList quando _viewMode == NoteViewMode.grid:
SliverPadding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  sliver: SliverGrid(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 10,
      mainAxisSpacing: 10, childAspectRatio: 1.05),
    delegate: SliverChildBuilderDelegate(
      (ctx, i) => _buildGridCard(ctx, filtered[i]),
      childCount: filtered.length)))

// _buildGridCard:
Widget _buildGridCard(BuildContext context, dynamic note) {
  final (_, color, label) = _noteTypeAssets(note);
  return ObjectActionWrapper(object: note,
    child: InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: note))),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_noteEmoji(note), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Row(children: [
            _typeBadge(label, color),
            const Spacer(),
            Text(_formatDate(note.updatedAt ?? note.createdAt),
              style: TextStyle(fontSize: 9, color: AppTheme.textMutedColor(context))),
          ]),
        ]))));
}

String _noteEmoji(dynamic note) => switch (note.noteType) {
  'outline' => '🌿', 'collection' => '🔮', _ => '📝' };

(IconData, Color, String) _noteTypeAssets(dynamic note) => switch (note.noteType) {
  'outline'    => (Icons.account_tree_outlined, AppColors.habitGreen, 'Outline'),
  'collection' => (Icons.grid_view_rounded, AppColors.habitPurple, 'Collection'),
  _            => (Icons.description_outlined, AppColors.info, 'Text'),
};

Widget _typeBadge(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
  child: Text(label, style: TextStyle(
    fontSize: 9, fontWeight: FontWeight.w700, color: color)));
```
---
C2 — Resources Screen
O que é: Tela de listagem de recursos (livros, podcasts, filmes, artigos). Hoje é um grid simples sem nenhuma visualização de highlights. O `synopsis` de cada resource pode conter blockquotes com citações, mas elas nunca são exibidas.
UX nova:
View A — Shelf + Highlights (padrão): prateleira horizontal de capas no topo (últimos 8) + feed de highlights extraídos do `synopsis` via `extractHighlights`
View B — Lista: lista compacta com capa pequena e primeiro highlight inline
Chips dinâmicos + FilterSortSheet substituem botões de display/sort separados
Arquivo: `lib/ui/screens/resources_screen.dart`
```dart
enum ResourceViewMode { shelfHighlights, listHighlights }
ResourceViewMode _resourceViewMode = ResourceViewMode.shelfHighlights;

// Layout principal quando shelfHighlights:
SliverToBoxAdapter(child: _buildShelf(filtered)),
SliverToBoxAdapter(child: _buildHighlightsFeed(filtered)),

Widget _buildShelf(List<Resource> resources) => Column(
  crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,6),
      child: Text('RECENTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.10, color: AppTheme.textMutedColor(context)))),
    SizedBox(height: 108, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: resources.take(8).length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (ctx, i) => _buildShelfItem(ctx, resources.take(8).toList()[i]))),
  ]);

Widget _buildShelfItem(BuildContext context, Resource resource) =>
  GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => UniversalDetailView(object: resource))),
    child: SizedBox(width: 72, child: Column(children: [
      Container(
        width: 72, height: 72, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: AppColors.surfaceVariant),
        child: resource.coverImage?.isNotEmpty == true
          ? Image.network(resource.coverImage!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(resource))
          : _fallbackIcon(resource)),
      const SizedBox(height: 4),
      Text(resource.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
      Text(resource.author ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 8, color: AppTheme.textMutedColor(context))),
    ])));

Widget _fallbackIcon(Resource r) {
  final emoji = switch (r.resourceType.toLowerCase()) {
    'book' || 'livro' => '📗', 'podcast' => '🎙️',
    'movie' || 'filme' => '🎬', 'article' => '📄', _ => '📚',
  };
  return Container(color: AppColors.surfaceVariant,
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))));
}

Widget _buildHighlightsFeed(List<Resource> resources) {
  final highlights = <({Resource r, String text, String? tag})>[];
  for (final r in resources) {
    if (r.synopsis == null || r.synopsis!.isEmpty) continue;
    final hls = MarkdownParser.extractHighlights(r.synopsis!);
    highlights.addAll(hls.take(2).map((h) => (r: r, text: h.text, tag: h.tag)));
  }
  if (highlights.isEmpty) return const SizedBox.shrink();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8),
      child: Text('✨ HIGHLIGHTS RECENTES', style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: 0.10,
        color: AppTheme.textMutedColor(context)))),
    ...highlights.map((hl) => Padding(
      padding: const EdgeInsets.fromLTRB(16,0,16,8),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => UniversalDetailView(object: hl.r))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _resourceColor(hl.r).withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: _resourceColor(hl.r), width: 2)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_resourceEmoji(hl.r)} ${hl.r.title}${hl.tag != null ? " · #${hl.tag}" : ""}',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: _resourceColor(hl.r))),
            const SizedBox(height: 3),
            Text('"${hl.text}"', style: TextStyle(fontSize: 10,
              color: AppTheme.textSecondaryColor(context),
              height: 1.55, fontStyle: FontStyle.italic)),
          ])))),
  ]);
}

Color _resourceColor(Resource r) => switch (r.resourceType.toLowerCase()) {
  'podcast' => AppColors.info, 'book' || 'livro' => AppColors.primary,
  _ => AppColors.habitPurple };
```
---
C3 — Home Screen
O que é: Dashboard principal. Hoje o header é só botões de sync e edição sem contexto — nenhuma saudação, nenhuma data. A quote do dia é hardcoded ("Peter Drucker"). O pull-to-search dispara com -80px e não tem debounce, causando abertura acidental frequente.
Melhorias:
3a. Saudação contextual: Adicionar antes dos botões de ação no header:
```dart
Widget _buildGreeting(BuildContext context, WidgetRef ref) {
  final hour     = DateTime.now().hour;
  final greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
  final name     = ref.watch(settingsProvider).userName ?? '';
  final dateStr  = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('$greeting${name.isNotEmpty ? ", $name" : ""}',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
        color: AppTheme.textPrimaryColor(context))),
    const SizedBox(height: 2),
    Text(dateStr, style: TextStyle(fontSize: 13,
      color: AppTheme.textMutedColor(context), fontWeight: FontWeight.w500)),
  ]);
}

// Header reorganizado:
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Expanded(child: _buildGreeting(context, ref)),
  Row(mainAxisSize: MainAxisSize.min, children: [
    _buildSyncIndicator(ref),
    if (_isEditMode) IconButton(icon: const Icon(Icons.add_box_rounded, color: AppColors.primary), ...),
    IconButton(icon: Icon(_isEditMode ? Icons.check_rounded : Icons.tune_rounded, ...), ...),
  ]),
])
```
3b. Quote do dia com highlights reais: Substituir hardcoded:
```dart
Widget _buildQuoteBlock(BuildContext context, WidgetRef ref) {
  final resources = ref.watch(resourcesProvider);
  final allHighlights = <({String text, String source})>[];
  for (final r in resources) {
    final hls = MarkdownParser.extractHighlights(r.synopsis ?? '');
    allHighlights.addAll(hls.map((h) => (text: h.text, source: r.title)));
  }
  final today    = DateTime.now();
  final dayIndex = today.day + today.month * 31;
  final quote    = allHighlights.isEmpty
    ? (text: '"The best way to predict the future is to create it."', source: 'Peter Drucker')
    : allHighlights[dayIndex % allHighlights.length];

  return _buildCard(title: 'Destaque do dia', icon: Icons.format_quote_rounded,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('"${quote.text}"', style: const TextStyle(
        fontSize: 15, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, height: 1.5)),
      const SizedBox(height: 8),
      Text('— ${quote.source}',
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
    ]));
}
```
3c. Fix pull-to-search (debounce):
```dart
// Estado adicional:
bool _searchOpenedInThisScroll = false;

// No NotificationListener:
onNotification: (notification) {
  if (notification.metrics.pixels >= 0) _searchOpenedInThisScroll = false;
  if (notification.metrics.pixels < -140 &&    // threshold: -140 em vez de -80
      notification.dragDetails != null &&
      !_searchOpenedInThisScroll &&
      ModalRoute.of(context)?.isCurrent == true) {
    _searchOpenedInThisScroll = true;
    showCommandCenter(context);
  }
  return false;
},
```
---
C4 — Planner Screen
O que é: Tela de planejamento diário com timeline, lista de tarefas, hábitos e eventos. Tem vários bugs confirmados no código.
Bugs a corrigir:
4a. `timeBlocks:` não passado ao `TimeLineDayView` — bug de 1 linha que faz as faixas coloridas de bloco de tempo nunca aparecerem:
```dart
// Localizar a construção de TimeLineDayView e adicionar:
TimeLineDayView(
  // ...parâmetros existentes...
  timeBlocks: timeBlocks,  // ← ADICIONAR
)
```
4b. Toggle timeline/lista ausente na AppBar:
```dart
IconButton(
  icon: Icon(_isTimeline ? Icons.view_list_rounded : Icons.view_timeline_rounded,
    size: 22, color: AppTheme.textMutedColor(context)),
  tooltip: _isTimeline ? 'Ver como lista' : 'Ver como timeline',
  onPressed: () => setState(() => _isTimeline = !_isTimeline)),
```
4c. Setas de navegação entre dias — substituir widget de data:
```dart
Row(children: [
  IconButton(
    icon: const Icon(Icons.chevron_left_rounded),
    onPressed: () => setState(() =>
      _selectedDate = _selectedDate.subtract(const Duration(days: 1)))),
  Expanded(child: GestureDetector(
    onTap: _pickCustomDate,
    child: Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDate),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
  IconButton(
    icon: const Icon(Icons.chevron_right_rounded),
    onPressed: () => setState(() =>
      _selectedDate = _selectedDate.add(const Duration(days: 1)))),
  if (!_isToday(_selectedDate))
    TextButton(
      onPressed: () => setState(() => _selectedDate = DateTime.now()),
      child: const Text('Hoje', style: TextStyle(
        color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
])
```
4d. Fix moodSlug bruto em `_buildJournalEntryItem`:
```dart
// ANTES: Text('Mood: ${entry.moodSlug}')
// DEPOIS:
Consumer(builder: (ctx, ref, _) {
  final moods = ref.watch(moodsProvider);
  final mood  = moods.cast<MoodDefinition?>().firstWhere(
    (m) => m?.id == entry.moodSlug || m?.slug == entry.moodSlug,
    orElse: () => null);
  if (mood == null) return const SizedBox.shrink();
  return Text('${mood.emoji} ${mood.title}',
    style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)));
})
```
4e. Fix `_buildTrackingRecordItem` sem nome do tracker:
```dart
// ANTES: Text('Tracker Record')
// DEPOIS:
Consumer(builder: (ctx, ref, _) {
  final trackers = ref.watch(trackersProvider);
  final tracker  = trackers.cast<dynamic>().firstWhere(
    (t) => t.id == record.trackerId, orElse: () => null);
  return Text(tracker?.title ?? 'Registro',
    maxLines: 1, overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
})
```
---
C5 — Goals Screen
O que é: Tela de metas. É `ConsumerWidget` (stateless), o que impede filtros dinâmicos e estado local. Tem crash potencial em cores inválidas (`int.parse` sem try-catch) e usa `IntrinsicHeight` em listas longas, causando lentidão.
Bugs a corrigir + melhorias:
5a. Converter para ConsumerStatefulWidget:
```dart
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});
  @override ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('goal'));
    });
  }
}
```
5b. Barra de progresso global no header — adicionar como primeiro SliverToBoxAdapter:
```dart
SliverToBoxAdapter(child: Padding(
  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Text('Metas',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
      Text('${completedGoals.length}/${goals.length}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.primary)),
    ]),
    const SizedBox(height: 10),
    ClipRRect(borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: goals.isEmpty ? 0 : completedGoals.length / goals.length,
        minHeight: 6,
        backgroundColor: AppTheme.surfaceVariantColor(context),
        valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
    const SizedBox(height: 4),
    Text('${activeGoals.length} em andamento · ${onHoldGoals.length} pausadas',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
  ])))
```
5c. Botão +10% inline — após a barra de progresso de cada `_GoalCard`:
```dart
if (!isCompleted)
  GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      final newP = (liveProgress + 0.1).clamp(0.0, 1.0);
      ref.read(goalsProvider.notifier).updateGoal(goal.copyWith(progress: newP));
      if (newP >= 1.0 && context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Meta concluída!')));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20)),
      child: const Text('+10%', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)))),
```
5d. Fix IntrinsicHeight — substituir por `ConstrainedBox`:
```dart
// ANTES: IntrinsicHeight(child: Row(children: [Container(width:6, color:color), ...]))
// DEPOIS:
ConstrainedBox(
  constraints: const BoxConstraints(minHeight: 80),
  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(width: 6, decoration: BoxDecoration(
      color: isCompleted ? AppColors.textMuted : color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)))),
    Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Column(...))),
  ]))
```
5e. Fix color parse sem try-catch:
```dart
Color _parseGoalColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
  catch (_) { return AppColors.primary; }
}
```
---
C6 — Habits Screen
O que é: Tela de hábitos com abas Hoje/Semana/Mês. Tem bug de locale: a semana começa no domingo americano em vez de segunda-feira.
Bugs + melhorias:
6a. Fix semana começando na segunda-feira:
```dart
// ANTES:
final weekStart = now.subtract(Duration(days: now.weekday % 7));
// DEPOIS:
final weekStart = now.subtract(Duration(days: now.weekday - 1));
```
6b. Seção "Sem agendamento" na aba Hoje — adicionar após a lista de hábitos agendados:
```dart
Builder(builder: (context) {
  final unscheduled = ref.watch(habitsProvider).where((h) =>
    h.status == HabitStatus.active && !h.archived && h.schedulers.isEmpty).toList();
  if (unscheduled.isEmpty) return const SizedBox.shrink();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(width: 3, height: 14,
          decoration: BoxDecoration(color: AppColors.textMuted,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('Sem agendamento', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, color: AppTheme.textMutedColor(context),
          letterSpacing: 0.08)),
      ])),
    const SizedBox(height: 8),
    ...unscheduled.map((h) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Opacity(opacity: 0.65, child: _TodayHabitCard(habit: h, date: DateTime.now())))),
  ]);
})
```
6c. Quitting Habits — ver seção D1. A `HabitsScreen` precisa separar habits normais de quitting e renderizar cada grupo com card diferente.
6d. HealthAlertsStrip — adicionar no topo da aba Hoje (antes dos hábitos):
```dart
const HealthAlertsStrip(compact: false),
```
6e. Fix _SummaryChip Row sem Flexible:
```dart
// ANTES: Row(children: [_SummaryChip(...), SizedBox(width:8), _SummaryChip(...)])
// DEPOIS:
Row(children: [
  Flexible(child: _SummaryChip(...)),
  const SizedBox(width: 8),
  Flexible(child: _SummaryChip(...)),
])
```
---
C7 — Inbox Screen
O que é: Tela de captura GTD. Hoje o campo de captura só aparece depois de tocar num botão "Capturar" na AppBar — o usuário tem que fazer 2 toques para começar a digitar. O campo some depois de usar.
UX nova: Campo sempre visível no topo da tela com borda dourada, auto-focus ao abrir, Enter submete e limpa o campo imediatamente (sem fechar o teclado) para a próxima captura. Swipe → direita arquiva, swipe ← esquerda abre tela de triagem.
```dart
// AppBar: remover botão 'Capturar'

// Campo fixo no topo do body:
Container(
  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
  decoration: BoxDecoration(
    color: AppTheme.cardFillColor(context),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.primary, width: 1.5),
    boxShadow: [BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.10), blurRadius: 12)]),
  child: Row(children: [
    Expanded(child: TextField(
      controller: _captureController,
      focusNode: _captureFocus,
      decoration: const InputDecoration(
        hintText: 'O que está na sua cabeça?',
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      style: const TextStyle(fontSize: 16),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _capture())),
    IconButton(onPressed: _capture,
      icon: const Icon(Icons.send_rounded, color: AppColors.primary)),
  ]))

// Auto-focus em initState:
WidgetsBinding.instance.addPostFrameCallback((_) => _captureFocus.requestFocus());

// Swipe nos itens:
Dismissible(
  key: ValueKey(item.id),
  background: Container(
    alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20),
    color: AppColors.habitGreen,
    child: const Icon(Icons.archive_rounded, color: Colors.white)),
  secondaryBackground: Container(
    alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
    color: AppColors.info,
    child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white)),
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.startToEnd) {
      await ref.read(inboxProvider.notifier).archiveItem(item.id);
      return true;
    } else {
      _showTriageSheet(context, item);
      return false;
    }
  },
  child: _buildInboxItemTile(item))
```
---
C8 — Settings Screen
O que é: Tela de configurações. Hoje é uma lista plana sem hierarquia visual — todos os itens no mesmo nível, difícil de navegar. Campo de nome do usuário não existe.
UX nova: 4 grupos em cards com divisórias internas (Perfil / Preferências / Integrações / Avançado). Seção Avançado colapsada por padrão.
```dart
// Helpers:
Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 0.10, color: AppTheme.textMutedColor(context))));

Widget _buildSettingsCard(List<Widget> tiles) => Container(
  decoration: AppTheme.cardDecoration(context),
  margin: const EdgeInsets.only(bottom: 16),
  child: Column(children: tiles.asMap().entries.expand((e) => [
    e.value,
    if (e.key < tiles.length - 1) const Divider(height: 1, indent: 56),
  ]).toList()));

Widget _settingsTile(String title, IconData icon,
    {String? subtitle, VoidCallback? onTap}) => ListTile(
  leading: Container(width: 34, height: 34,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, size: 18, color: AppColors.primary)),
  title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
  subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
  trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
  onTap: onTap);

// Editar nome inline:
void _editUserName() async {
  final ctrl   = TextEditingController(text: ref.read(settingsProvider).userName ?? '');
  final result = await showDialog<String>(context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Seu nome'),
      content: TextField(controller: ctrl, autofocus: true,
        decoration: const InputDecoration(hintText: 'Como posso te chamar?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Salvar')),
      ]));
  if (result != null) await ref.read(settingsProvider.notifier).setUserName(result);
}
```
---
C9 — Appearance Screen
O que é: Tela de aparência. Os swatches de cor existem visualmente mas não são interativos — tocar não faz nada. A cor de destaque do app é hardcoded em `AppColors.primary`.
Como implementar:
```dart
// Swatches interativos:
static const _presets = [
  Color(0xFFFFB000), Color(0xFF3B82F6), Color(0xFF22C55E),
  Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899),
  Color(0xFF8B5CF6), Color(0xFF0EA5E9), Color(0xFFF97316),
];

// Em build():
Wrap(spacing: 10, runSpacing: 10, children: _presets.map((color) {
  final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  final isSelected = settings.accentColor.toUpperCase() == hex;
  return GestureDetector(
    onTap: () => ref.read(settingsProvider.notifier).setAccentColor(hex),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: isSelected
          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
          : null),
      child: isSelected
        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null));
}).toList())
```
---
C10 — Journal Screen
O que é: Tela do diário. Quando há filtros ativos (por mood, por foto, por data), o usuário não tem feedback visual de que está filtrando — a lista simplesmente mostra menos itens sem explicação. O campo de busca existe no estado mas nunca é exibido na UI.
10a. Banner de filtros ativos:
```dart
// Logo antes do ListView, condicional:
if (_filterMood != null || _filterHasPhoto || _onlySelectedDate)
  Container(
    color: AppColors.primary.withValues(alpha: 0.06),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(children: [
      const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.primary),
      const SizedBox(width: 6),
      if (_filterMood != null) ...[
        _activeChip(_resolveMoodLabel(ref, _filterMood!),
          () => setState(() => _filterMood = null)),
        const SizedBox(width: 6),
      ],
      if (_filterHasPhoto) ...[
        _activeChip('📷 Com foto', () => setState(() => _filterHasPhoto = false)),
        const SizedBox(width: 6),
      ],
      if (_onlySelectedDate)
        _activeChip(DateFormat('d MMM', 'pt_BR').format(_selectedDate),
          () => setState(() => _onlySelectedDate = false)),
      const Spacer(),
      GestureDetector(
        onTap: () => setState(() {
          _filterMood = null; _filterHasPhoto = false; _onlySelectedDate = false;
        }),
        child: const Text('Limpar', style: TextStyle(
          fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600))),
    ])),

Widget _activeChip(String label, VoidCallback onRemove) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20)),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: const TextStyle(
      fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
    const SizedBox(width: 4),
    GestureDetector(onTap: onRemove,
      child: const Icon(Icons.close_rounded, size: 12, color: AppColors.primary)),
  ]));
```
10b. Busca expansível na AppBar:
```dart
// Estado: bool _searchExpanded = false;

// Na AppBar actions:
IconButton(
  icon: Icon(_searchExpanded ? Icons.close_rounded : Icons.search_rounded,
    color: _searchExpanded ? AppColors.primary : AppTheme.textMutedColor(context)),
  onPressed: () => setState(() {
    _searchExpanded = !_searchExpanded;
    if (!_searchExpanded) { _searchQuery = ''; _searchController.clear(); }
  })),

// Abaixo da AppBar:
AnimatedContainer(
  duration: const Duration(milliseconds: 220),
  height: _searchExpanded ? 52 : 0,
  child: _searchExpanded ? Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: TextField(
      controller: _searchController, autofocus: true,
      decoration: InputDecoration(
        hintText: 'Buscar entradas…',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.zero, isDense: true),
      onChanged: (v) => setState(() => _searchQuery = v)))
  : const SizedBox.shrink()),
```
---
C11 — People Screen
O que é: Tela de pessoas/contatos. Hoje não tem campo de busca e os botões de ligar/SMS não fazem nada (callbacks vazios `() {}`).
11a. Converter para ConsumerStatefulWidget + busca + toggle grid/lista — mesmo padrão do C5a. Adicionar:
```dart
bool _isListView = false;
String _searchQuery = '';

// Campo de busca sempre visível abaixo da AppBar
// Toggle grid/lista na AppBar
// Filtrar por _searchQuery ao exibir
```
11b. Ações de contato funcionais:
```dart
// Adicionar url_launcher ao pubspec.yaml se ausente.
enum _ContactType { sms, call }

Widget _contactAction(Person p, IconData icon, Color color, _ContactType type) =>
  GestureDetector(
    onTap: () async {
      if (p.phone == null || p.phone!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum telefone cadastrado')));
        return;
      }
      final uri = type == _ContactType.sms
        ? Uri.parse('sms:${p.phone}') : Uri.parse('tel:${p.phone}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    },
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)));
```
11c. Badge de contato pendente:
```dart
// Envolver card em Stack e adicionar ponto vermelho se isDueForContact:
if (person.isDueForContact)
  Positioned(top: 8, right: 8,
    child: Container(width: 10, height: 10,
      decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5))))
```
---
C12 — Trackers Screen
O que é: Tela de trackers. Os cards não mostram o último valor registrado, forçando o usuário a abrir cada tracker para ver o dado mais recente. Não tem atalho de registro rápido.
12a. Último valor no card:
```dart
Consumer(builder: (ctx, ref, _) {
  final records = ref.watch(trackingRecordsProvider)
    .where((r) => r.trackerId == tracker.id).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final last       = records.isNotEmpty ? records.first : null;
  final firstField = last?.fieldValues.entries.firstOrNull;

  if (firstField == null) return Text('Sem registros',
    style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(ctx)));

  return Column(children: [
    const Divider(height: 16),
    Row(children: [
      Expanded(child: Text(firstField.key, style: TextStyle(
        fontSize: 10, color: AppTheme.textMutedColor(ctx)), maxLines: 1,
        overflow: TextOverflow.ellipsis)),
      Text(firstField.value.toString(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
          color: AppColors.primary)),
      const SizedBox(width: 6),
      Text(DateFormat('d/M').format(last!.date),
        style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(ctx))),
    ]),
  ]);
})
```
12b. Botão + direto no card:
```dart
// Envolver conteúdo em Stack:
Positioned(bottom: 10, right: 10,
  child: GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRecordForm(preselectedTracker: tracker)),
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 8, offset: const Offset(0, 3))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 18))))
```
12c. Remover botão duplicado de Analysis — localizar `IconButton` com `Icons.auto_graph_rounded` ou similar no header e deletar.
---
C13 — Timeline Screen
O que é: Tela de histórico cronológico de todos os eventos. Hoje o título ainda está como "Journal" (ou equivalente). Sem paginação, o que pode travar com muitos itens.
13a. Fix título: `AppBar(title: const Text('Timeline'), centerTitle: true)`
13b. Paginação por scroll infinito:
```dart
int _currentPage = 1;
static const _pageSize = 50;
final _scrollController = ScrollController();

@override
void initState() {
  super.initState();
  _scrollController.addListener(() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_currentPage * _pageSize < _filteredItems.length)
        setState(() => _currentPage++);
    }
  });
}

// No build — usar paginatedItems:
final paginatedItems = _filteredItems.take(_pageSize * _currentPage).toList();
```
---
C14 — Organizer Detail Screen
O que é: Tela de detalhe de um Organizer. As tabs (Tarefas/Notas/Outros) não mostram contagem de itens. O único botão de ação abre o `UniversalDetailView` mas não o form de edição diretamente.
14a. Contagem nas tabs:
```dart
final allItems   = associatedItemsAsync.valueOrNull ?? [];
final taskCount  = allItems.whereType<Task>().length;
final noteCount  = allItems.whereType<Note>().length;
final otherCount = allItems.length - taskCount - noteCount;

TabBar(controller: _tabController, tabs: [
  Tab(text: 'Tarefas${taskCount > 0 ? " ($taskCount)" : ""}'),
  Tab(text: 'Notas${noteCount > 0 ? " ($noteCount)" : ""}'),
  Tab(text: 'Outros${otherCount > 0 ? " ($otherCount)" : ""}'),
])
```
14b. Botões separados editar/detalhes:
```dart
// Em SliverAppBar actions — substituir botão único por dois:
IconButton(
  tooltip: 'Editar', icon: const Icon(Icons.edit_outlined, size: 20),
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => CreateOrganizerForm(existingOrganizer: widget.organizer)))),
IconButton(
  tooltip: 'Ver detalhes', icon: const Icon(Icons.info_outline_rounded, size: 20),
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => UniversalDetailView(object: widget.organizer)))),
```
---
C15 — Day Theme Screen
O que é: Tela de configuração de blocos de tempo e temas do dia. Hoje a única forma de criar é via `PopupMenuButton` na AppBar — não óbvio. Os tiles de bloco de tempo não têm preview visual do horário.
15a. Botões explícitos no final de cada seção:
```dart
// Após a lista de blocos:
SizedBox(width: double.infinity, child: OutlinedButton.icon(
  icon: const Icon(Icons.add_rounded, size: 16),
  label: const Text('Novo Bloco de Tempo'),
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
    foregroundColor: AppColors.primary),
  onPressed: () => _showBlockDialog(context, ref))),

// Após a lista de temas:
SizedBox(width: double.infinity, child: OutlinedButton.icon(
  icon: const Icon(Icons.add_rounded, size: 16),
  label: const Text('Novo Tema do Dia'),
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
    foregroundColor: AppColors.primary),
  onPressed: () => _showThemeDialog(context, ref))),
```
15b. Preview visual de bloco com barra proporcional de horário:
```dart
Widget _buildBlockTile(TimeBlock block, int reorderIndex) {
  final color = _parseBlockColor(block.color);
  return Container(
    key: ValueKey(block.id),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: AppTheme.cardDecoration(context),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
      leading: Container(width: 4, height: 48,
        decoration: BoxDecoration(color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)))),
      title: Text(block.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${block.startTime} → ${block.endTime}',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildTimeBar(block, color),
        const SizedBox(width: 8),
        ReorderableDragStartListener(index: reorderIndex,
          child: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted)),
      ]),
      onTap: () => _showBlockDialog(context, ref, existing: block)));
}

// Barra proporcional 60px representando 24h:
Widget _buildTimeBar(TimeBlock block, Color color) {
  int toMin(String t) {
    final p = t.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }
  final start = toMin(block.startTime) / 1440.0;
  final end   = toMin(block.endTime)   / 1440.0;
  final barW  = ((end - start) * 60).clamp(4.0, 56.0);
  final leftW = (start * 60).clamp(0.0, 60.0 - barW);
  return SizedBox(width: 60, height: 8, child: Stack(children: [
    Container(decoration: BoxDecoration(
      color: AppTheme.textMutedColor(context).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4))),
    Positioned(left: leftW, width: barW, top: 0, bottom: 0,
      child: Container(decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(4)))),
  ]));
}

Color _parseBlockColor(String? hex) {
  try { return hex != null ? Color(int.parse(hex.replaceFirst('#', '0xFF'))) : AppColors.primary; }
  catch (_) { return AppColors.primary; }
}
```
---
C16 — Search Screen
O que é: Tela de busca global. Buscas recentes são hardcoded ou não persistidas. Quando o usuário filtra por tipo, não há feedback visual de que o filtro está ativo. As actions contextuais são fixas e não levam em conta o texto digitado.
16a. Buscas recentes persistidas:
```dart
List<String> _recentSearches = [];

@override
void initState() {
  super.initState();
  _loadRecents();
}

Future<void> _loadRecents() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() => _recentSearches = prefs.getStringList('recent_searches') ?? []);
}

Future<void> _persistSearch(String query) async {
  if (query.trim().length < 2) return;
  final prefs  = await SharedPreferences.getInstance();
  final list   = prefs.getStringList('recent_searches') ?? [];
  list.remove(query); list.insert(0, query);
  if (list.length > 10) list.removeLast();
  await prefs.setStringList('recent_searches', list);
  if (mounted) setState(() => _recentSearches = list);
}
// Chamar _persistSearch no onSubmitted do campo de busca.
```
16b. Chip de tipo ativo nos resultados:
```dart
if (_searchQuery.isNotEmpty && _selectedType != null)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_typeLabels[_selectedType] ?? _selectedType!,
            style: const TextStyle(fontSize: 12,
              color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() { _selectedType = null; _onSearchChanged(_searchController.text); }),
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary)),
        ])),
      const Spacer(),
      Text('${_results.length} resultado${_results.length == 1 ? "" : "s"}',
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
    ])),
```
16c. Actions contextuais por query:
```dart
List<SearchAction> _getActions(String query) {
  final q    = query.trim();
  final base = <SearchAction>[
    SearchAction(label: 'Nova Nota', icon: Icons.note_add_outlined, color: AppColors.info,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => CreateNoteForm(initialTitle: q.isNotEmpty ? q : null)))),
    SearchAction(label: 'Iniciar Pomodoro', icon: Icons.timer_rounded, color: AppColors.error,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PomodoroScreen()))),
    SearchAction(label: 'Configurações', icon: Icons.settings_rounded, color: AppColors.info,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
  ];
  if (q.length > 2) {
    base.insert(0, SearchAction(
      label: 'Nova Task: "$q"', icon: Icons.add_circle_outline_rounded, color: AppColors.primary,
      onExecute: (ctx) => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => CreateTaskForm(initialTitle: q)))));
  }
  return base;
}
```
---
C17 — App Shell
O que é: Shell principal com bottom navigation. Hoje mostra labels em todos os itens (ocupa espaço), não tem badges de pendências e o FAB não tem tooltip.
17a. Labels só no item ativo:
```dart
// NavigationBar (M3):
NavigationBar(
  labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
  ...)
// BottomNavigationBar (M2):
BottomNavigationBar(showUnselectedLabels: false, ...)
```
17b. Badges na bottom nav:
```dart
final badgeCounts = ref.watch(badgeCountsProvider);
// Envolver ícone do Planner:
Badge(
  isLabelVisible: (badgeCounts['planner'] ?? 0) > 0,
  label: Text('${badgeCounts['planner']}', style: const TextStyle(fontSize: 9)),
  child: Icon(_navIcon('planner')))
// Mesma coisa para 'inbox' e 'people'
```
17c. Tooltip no FAB:
```dart
Tooltip(message: 'Criar novo',
  child: FloatingActionButton(
    onPressed: () => showCreateMenu(context),
    backgroundColor: AppColors.primary,
    child: const Icon(Icons.add_rounded, color: Colors.black)))
```
---
C18 — Social Screen
O que é: Tela de posts salvos. Usa string para modo de ordenação em vez de enum. O overlay de seleção múltipla não é visualmente forte o suficiente. O popup de ações pode fazer overflow com muitas opções.
18a. SortMode como enum:
```dart
enum SocialSortMode { savedDesc, savedAsc, platformAsc, unwatchedFirst }
SocialSortMode _sortMode = SocialSortMode.savedDesc;
// Atualizar switch de ordenação para usar enum.
```
18b. Overlay de seleção mais evidente:
```dart
// Em SocialPostGridCard, quando isSelected && isMultiSelectMode:
Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
  color: AppColors.primary.withValues(alpha: 0.30),
  border: Border.all(color: AppColors.primary, width: 2.5),
  borderRadius: BorderRadius.circular(12)))),
const Positioned(top: 6, right: 6,
  child: CircleAvatar(radius: 10, backgroundColor: AppColors.primary,
    child: Icon(Icons.check_rounded, size: 12, color: Colors.black))),
```
18c. Arquivar em multi-select com undo:
```dart
IconButton(
  tooltip: 'Arquivar selecionados',
  icon: const Icon(Icons.archive_outlined),
  onPressed: _selectedIds.isEmpty ? null : () async {
    final toArchive = posts.where((p) => _selectedIds.contains(p.id)).toList();
    for (final p in toArchive)
      await ref.read(socialPostsProvider.notifier).updatePost(p.copyWith(archived: true));
    _clearSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${toArchive.length} post(s) arquivados'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () async {
        for (final p in toArchive)
          await ref.read(socialPostsProvider.notifier).updatePost(p.copyWith(archived: false));
      })));
  }),
```
18d. Fix overflow no popup de ações (`object_action_wrapper.dart`):
```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,        // ADICIONAR
  ...
  builder: (sheetContext) => SafeArea(
    child: ConstrainedBox(          // ADICIONAR
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: SingleChildScrollView( // ADICIONAR
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min,
            children: [/* conteúdo existente */]))))))
```
---
C19 — Create Social Post Form
O que é: Formulário de criação de post social. Não detecta posts duplicados (mesmo URL salvo antes). O campo de título vem do fetch de metadata mas não é editável — o usuário não consegue renomear o arquivo que será salvo no vault.
19a. Detecção de duplicata:
```dart
enum _DuplicateAction { edit, doNothing, saveAnyway }

Future<void> _save() async {
  if (widget.existingPost == null) {
    final url      = _urlController.text.trim();
    final existing = ref.read(socialPostsProvider).where((p) => p.url.trim() == url).toList();
    if (existing.isNotEmpty) {
      final action = await _showDuplicateDialog(existing.first);
      if (!mounted) return;
      switch (action) {
        case _DuplicateAction.edit:
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CreateSocialPostForm(existingPost: existing.first)));
          return;
        case _DuplicateAction.doNothing:
          Navigator.pop(context); return;
        case _DuplicateAction.saveAnyway: break;
        case null: return;
      }
    }
  }
  // lógica de save existente
}

Future<_DuplicateAction?> _showDuplicateDialog(SocialPost dup) => showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Row(children: [
      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
      const SizedBox(width: 8),
      const Expanded(child: Text('Post já salvo',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dup.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text('Salvo em ${_fmtDate(dup.createdAt)}',
            style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
        ])),
      const SizedBox(height: 12),
      const Text('Este link já foi salvo. O que deseja fazer?'),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, _DuplicateAction.doNothing),
        child: const Text('Não fazer nada')),
      OutlinedButton(onPressed: () => Navigator.pop(ctx, _DuplicateAction.edit),
        child: const Text('Editar existente')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.warning.withValues(alpha:0.9)),
        onPressed: () => Navigator.pop(ctx, _DuplicateAction.saveAnyway),
        child: const Text('Salvar mesmo assim')),
    ]));

String _fmtDate(DateTime d) =>
  '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'
  ' às ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
```
19b. Campo de título editável com preview de slug:
```dart
// Logo após o campo de URL:
const SizedBox(height: 12),
Text('Título / nome do arquivo', style: TextStyle(fontSize: 11,
  fontWeight: FontWeight.w700, letterSpacing: 0.08,
  color: AppTheme.textMutedColor(context))),
const SizedBox(height: 6),
TextField(
  controller: _titleController,
  decoration: InputDecoration(
    hintText: 'Nome que aparece no vault…',
    filled: true, fillColor: AppTheme.surfaceVariantColor(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    suffixIcon: _titleController.text.isNotEmpty
      ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16),
          onPressed: () => setState(() => _titleController.clear()))
      : null),
  onChanged: (_) => setState(() {})),
if (_titleController.text.trim().isNotEmpty) ...[
  const SizedBox(height: 4),
  Text('Arquivo: ${_slugPreview(_titleController.text)}',
    style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context),
      fontFamily: 'monospace')),
],

String _slugPreview(String title) {
  var s = title.toLowerCase().trim()
    .replaceAll(RegExp(r'\s+'), '-')
    .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
    .replaceAll(RegExp(r'-+'), '-');
  if (s.length > 40) s = s.substring(0, 40);
  return '$s.md';
}
```
---
C20 — Fixes Globais de Overflow
O que é: Bugs de layout que fazem widgets ultrapassarem seus bounds, causando exceções ou texto cortado sem ellipsis.
20a. Goals — badge "VENCIDA" sem Flexible:
```dart
Row(children: [
  const Icon(Icons.calendar_today_rounded, size: 12),
  const SizedBox(width: 4),
  Flexible(child: Text('Prazo: ${_formatDate(goal.deadline)}',
    maxLines: 1, overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)))),
  const SizedBox(width: 6),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4)),
    child: const Text('VENCIDA', style: TextStyle(
      fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.error))),
])
```
20b. Home — `_buildEditModeHint` sem maxLines:
```dart
Text('Arraste para reordenar ou toque ⋯ para configurar',
  maxLines: 2, overflow: TextOverflow.ellipsis,
  style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context)))
```
20c. Habits — `_SummaryChip` Row sem Flexible:
```dart
Row(children: [
  Flexible(child: _SummaryChip(...)),
  const SizedBox(width: 8),
  Flexible(child: _SummaryChip(...)),
])
```
20d. Timeline `resize handle` área de toque 8dp:
```dart
// Substituir Container(height: isTiny ? 8 : 16) por:
GestureDetector(
  onVerticalDragUpdate: _onResizeDrag,
  child: SizedBox(height: 24,  // área de toque mínima 24dp
    child: Align(alignment: Alignment.bottomCenter,
      child: Container(width: 32, height: isTiny ? 3 : 4,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2))))))
```

---
BLOCO D — FEATURES NOVAS
---
D1 — Quitting Habits (Hábitos de Parar)
O que é: Hábitos cujo objetivo é NÃO fazer algo — parar de fumar, parar de roer unhas, parar de comer açúcar. Hoje esses hábitos são tratados igual a qualquer outro: aparecem no Planner com checkbox de "marcar como feito", aparecem no CalendarWidget, e marcar é semanticamente errado (marcar = falhar, não ter sucesso). O usuário quer ver quantos dias ficou sem fazer, não quantas vezes fez.
Como funciona:
Hábito com `isQuitting: true` aparece em seção separada "Evitando" na aba Hoje — nunca junto com os hábitos normais
Card visual diferente: sem checkbox, com contador de dias limpos com cor semafórica
Verde ✨ = 3+ dias limpos | Amarelo ⚠️ = 1–2 dias | Vermelho 💥 = recaída hoje
Botão "Recaída" com confirmação — registra que o usuário fez o que estava evitando
NÃO aparece no Planner, NÃO aparece no CalendarWidget
Na aba Semana/Mês aparece em seção separada com streak de dias limpos
Formulário — `lib/ui/forms/create_habit_form.dart`:
```dart
// Estado:
bool _isQuitting = false;

// UI — após o campo de nome, antes de frequência:
Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: _isQuitting
      ? AppColors.error.withValues(alpha: 0.08)
      : AppTheme.surfaceVariantColor(context),
    borderRadius: BorderRadius.circular(12),
    border: _isQuitting
      ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
      : null),
  child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Hábito de parar',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: _isQuitting ? AppColors.error : AppTheme.textPrimaryColor(context))),
      const SizedBox(height: 2),
      Text('O objetivo é NÃO fazer. Não aparece no Planner.',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _isQuitting, activeColor: AppColors.error,
      onChanged: (v) => setState(() => _isQuitting = v)),
  ]))
```
Card de quitting na HabitsScreen — novo widget `_QuittingHabitCard`:
```dart
class _QuittingHabitCard extends ConsumerWidget {
  final Habit habit;
  const _QuittingHabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calcular dias limpos: dias desde a última entrada done==true no completionHistory
    final history = habit.completionHistory ?? {};
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    int cleanDays = 0;
    for (int i = 0; i < 365; i++) {
      final d   = today.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final e   = history[key];
      if (e == true || (e is Map && e['done'] == true)) break;
      cleanDays++;
    }

    final statusColor = cleanDays == 0 ? AppColors.error
      : cleanDays < 3 ? AppColors.warning : AppColors.habitGreen;
    final statusEmoji = cleanDays == 0 ? '💥' : cleanDays < 3 ? '⚠️' : '✨';

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.2))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Text(statusEmoji, style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(cleanDays == 0 ? 'Recaída hoje'
            : cleanDays == 1 ? '1 dia limpo' : '$cleanDays dias limpos',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
        ])),
        GestureDetector(
          onTap: () => _confirmRelapse(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20)),
            child: const Text('Recaída', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)))),
      ]));
  }

  void _confirmRelapse(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar recaída?'),
        content: Text(
          'Isso vai zerar o contador de dias limpos de "${habit.title}". '
          'Tudo bem, recomeços fazem parte do processo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar')),
        ]));
    if (confirmed != true) return;
    await ref.read(habitsProvider.notifier).toggleHabit(habit, DateTime.now(), slotIndex: 0);
  }
}
```
Integração na `_TodayView` da HabitsScreen:
```dart
// Separar antes de renderizar:
final normalHabits   = todayHabits.where((h) => !h.isQuitting).toList();
final quittingHabits = todayHabits.where((h) =>  h.isQuitting).toList();

// Renderizar normalHabits com _TodayHabitCard existente.

// Adicionar ao final, após os normais:
if (quittingHabits.isNotEmpty) ...[
  const SizedBox(height: 20),
  Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text('Evitando', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.error, letterSpacing: 0.08)),
    ])),
  const SizedBox(height: 8),
  ...quittingHabits.map((h) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: _QuittingHabitCard(habit: h))),
]
```
Excluir do Planner e CalendarWidget:
```dart
// planner_screen.dart — em qualquer filtro de todayHabits:
.where((h) => _shouldShowToday(h) && !h.isQuitting)

// calendar_widget.dart:
habits.where((h) => h.status == HabitStatus.active && !h.isQuitting).take(4)
```
---
D2 — Tracker de Saúde com Alertas Automáticos
O que é: Sistema de monitoramento de métricas de saúde com alertas visuais automáticos. A Laura quer acompanhar sono, buraco no cabelo, comida e cocô — mas cada um tem uma lógica diferente: sono tem threshold numérico (abaixo de 6h = aviso), cabelo é sempre alerta crítico independente do valor, comida e cocô variam muito e servem mais para observar padrão do que alertar.
O problema dos lembretes: Lembretes comuns são ignorados depois de um tempo. A solução é escalonamento: lembrete inicial no horário configurado, follow-up 2h depois se não registrado, lembrete crítico às 21h para campos críticos.
Formulário de campo no tracker — `lib/ui/forms/create_tracker_form.dart`:
Após o picker de tipo de campo, adicionar seção de alerta:
```dart
// Switch "sempre alerta" (para buraco no cabelo):
Row(children: [
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Sempre é alerta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    Text('Qualquer registro acende alerta vermelho',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
  ])),
  Switch(value: _alwaysAlert, activeColor: AppColors.error,
    onChanged: (v) => setState(() => _alwaysAlert = v)),
]),

// Se não for alwaysAlert, mostrar threshold e nível:
if (!_alwaysAlert) ...[
  const SizedBox(height: 12),
  Text('Nível de alerta', style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
  const SizedBox(height: 6),
  Row(children: [
    _alertBtn(FieldAlertLevel.none,    '—',      AppTheme.textMutedColor(context)),
    const SizedBox(width: 6),
    _alertBtn(FieldAlertLevel.info,    'Info',   AppColors.info),
    const SizedBox(width: 6),
    _alertBtn(FieldAlertLevel.warning, 'Aviso',  AppColors.warning),
    const SizedBox(width: 6),
    _alertBtn(FieldAlertLevel.critical,'Crítico',AppColors.error),
  ]),
  if (_alertLevel != FieldAlertLevel.none) ...[
    const SizedBox(height: 10),
    TextField(
      controller: _thresholdController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Acionar alerta quando valor ≤',
        hintText: 'ex: 6 (para horas de sono)',
        filled: true, fillColor: AppTheme.surfaceVariantColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none))),
    const SizedBox(height: 8),
    TextField(
      controller: _alertNoteController,
      decoration: InputDecoration(
        labelText: 'Contexto do alerta (opcional)',
        hintText: 'ex: "sono depende dos remédios, considerar isso"',
        filled: true, fillColor: AppTheme.surfaceVariantColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none))),
  ],
],

Widget _alertBtn(FieldAlertLevel level, String label, Color color) {
  final sel = _alertLevel == level;
  return Expanded(child: GestureDetector(
    onTap: () => setState(() => _alertLevel = level),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: sel ? color.withValues(alpha: 0.15) : AppTheme.surfaceVariantColor(context),
        border: sel ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: sel ? color : AppTheme.textMutedColor(context)))))));
}
```
Toggle isHealthTracker no formulário do tracker:
```dart
Row(children: [
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Tracker de saúde', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    Text('Mostra alertas na tela de hábitos e no dashboard',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
  ])),
  Switch(value: _isHealthTracker, activeColor: AppColors.primary,
    onChanged: (v) => setState(() => _isHealthTracker = v)),
]),
```
Template pré-configurado "Saúde" — botão no topo do formulário:
```dart
OutlinedButton.icon(
  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
  label: const Text('Usar template: Saúde'),
  onPressed: () => setState(() {
    _titleController.text = 'Saúde';
    _isHealthTracker = true;
    _fields = [
      TrackerField(name: 'Sono', type: FieldType.number, unit: 'h',
        alertLevel: FieldAlertLevel.warning, alertThreshold: 6.0,
        alertNote: 'Depende dos remédios — contexto importa'),
      TrackerField(name: 'Comida', type: FieldType.boolean,
        alertLevel: FieldAlertLevel.info,
        alertNote: 'Varia com o dia — observar padrão'),
      TrackerField(name: 'Cocô', type: FieldType.boolean,
        alertLevel: FieldAlertLevel.info,
        alertNote: 'Varia — observar frequência'),
      TrackerField(name: 'Buraco no cabelo', type: FieldType.boolean,
        alwaysAlert: true, alertLevel: FieldAlertLevel.critical,
        alertNote: 'ALERTA VERMELHO — verificar imediatamente'),
    ];
  })),
```
Lembretes escalonados — `lib/services/notification_service.dart`:
```dart
Future<void> scheduleHealthReminders(Tracker tracker, TrackerField field) async {
  final baseTime = field.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);

  // Lembrete primário
  await _scheduleLocal(
    id: _hId(tracker.id, field.name, 0),
    title: '${tracker.title}: registrar ${field.name}',
    body: field.alertNote ?? 'Não esqueça de registrar',
    scheduledTime: _todayAt(baseTime),
    payload: 'tracker:${tracker.id}');

  // Follow-up 2h depois para campos com alerta
  if (field.alertLevel != FieldAlertLevel.none) {
    await _scheduleLocal(
      id: _hId(tracker.id, field.name, 1),
      title: '⚠️ ${field.name} ainda não registrado',
      body: 'Verifique ${tracker.title}',
      scheduledTime: _todayAt(baseTime).add(const Duration(hours: 2)),
      payload: 'tracker:${tracker.id}');
  }

  // Alerta crítico à noite para campos críticos
  if (field.alertLevel == FieldAlertLevel.critical || field.alwaysAlert) {
    await _scheduleLocal(
      id: _hId(tracker.id, field.name, 2),
      title: '🚨 ${field.name} — verificação final do dia',
      body: field.alertNote ?? 'Registro obrigatório',
      scheduledTime: _todayAt(const TimeOfDay(hour: 21, minute: 0)),
      payload: 'tracker:${tracker.id}');
  }
}

Future<void> cancelHealthReminders(String trackerId, String fieldName) async {
  for (int i = 0; i <= 2; i++) await _cancelLocal(_hId(trackerId, fieldName, i));
}

int _hId(String tid, String fname, int variant) =>
  'health_${tid}_${fname}_$variant'.hashCode.abs();
DateTime _todayAt(TimeOfDay t) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, t.hour, t.minute);
}
```
Chamar `cancelHealthReminders` no notifier de tracking records ao salvar um record.
---
D3 — Ideias como Tipo de Objeto
O que é: Um tipo de objeto de primeiro nível chamado "Ideia". É mais leve que uma Task (sem stage pipeline de to-do → in progress → done) e mais estruturado que uma Note (tem horizonte de tempo, prioridade, pode ser convertida). O fluxo é: capturar ideia rápida → amadurecer → converter em Task/Projeto/Goal/Nota quando estiver pronta. Ao converter, todas as propriedades (organizers, tags, notas) são transferidas para o novo objeto.
UX:
Captura em bottom sheet rápido (abre direto no campo de título com autofocus)
Emoji editável (padrão 💡)
Campo de notas expansível sem limite de linhas
Horizonte de tempo em chips: 🔥 Agora / ⚡ Em breve / ☁️ Um dia / ∞ Sem prazo
Data alvo opcional (só aparece quando horizonte é Agora ou Em breve)
Prioridade em chips compactos
Organizers via `OrganizerSelectorField` existente
Botão "Converter →" no card → sheet com opções Task/Projeto/Goal/Nota
Ideia convertida fica marcada com "→ task" e fica visível só se `_showConverted = true`
Formulário — `lib/ui/forms/create_idea_form.dart` — CRIAR NOVO:
```dart
class CreateIdeaForm extends ConsumerStatefulWidget {
  final Idea? existingIdea;
  final String? initialTitle;
  const CreateIdeaForm({super.key, this.existingIdea, this.initialTitle});
  @override ConsumerState<CreateIdeaForm> createState() => _CreateIdeaFormState();
}

class _CreateIdeaFormState extends ConsumerState<CreateIdeaForm> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  IdeaHorizon   _horizon   = IdeaHorizon.someday;
  TaskPriority? _priority;
  DateTime?     _targetDate;
  List<OrganizerReference> _organizers = [];
  String _emoji = '💡';

  @override
  void initState() {
    super.initState();
    final e     = widget.existingIdea;
    _titleCtrl  = TextEditingController(text: e?.title ?? widget.initialTitle ?? '');
    _bodyCtrl   = TextEditingController(text: e?.body ?? '');
    _horizon    = e?.horizon    ?? IdeaHorizon.someday;
    _priority   = e?.priority;
    _targetDate = e?.targetDate;
    _organizers = e?.organizers.toList() ?? [];
    _emoji      = e?.emoji ?? '💡';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.dividerColor(context),
              borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Emoji + Título
              Row(children: [
                GestureDetector(
                  onTap: _pickEmoji,
                  child: Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(_emoji,
                      style: const TextStyle(fontSize: 22))))),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _titleCtrl,
                  autofocus: widget.existingIdea == null,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'A ideia é…', border: InputBorder.none),
                  textInputAction: TextInputAction.next)),
              ]),
              const SizedBox(height: 12),

              // Notas
              TextField(
                controller: _bodyCtrl, maxLines: null, minLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Contexto, referências, por que isso importa…',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context)),
                  border: InputBorder.none)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Horizonte
              Text('Quando?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppTheme.textMutedColor(context), letterSpacing: 0.08)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: IdeaHorizon.values.map((h) {
                  final sel = _horizon == h;
                  return Padding(padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _horizon = h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(_horizonLabel(h), style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
                }).toList())),

              // Data alvo (só se horizonte for now/soon)
              if (_horizon == IdeaHorizon.now || _horizon == IdeaHorizon.soon) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantColor(context),
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_targetDate != null
                        ? DateFormat('d MMM y', 'pt_BR').format(_targetDate!)
                        : 'Escolher data',
                        style: TextStyle(fontSize: 12,
                          color: _targetDate != null
                            ? AppTheme.textPrimaryColor(context)
                            : AppTheme.textMutedColor(context))),
                    ]))),
              ],
              const SizedBox(height: 12),

              // Prioridade
              Row(children: [
                Text('Prioridade:', style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedColor(context))),
                const SizedBox(width: 8),
                ...TaskPriority.values.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = _priority == p ? null : p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priority == p
                          ? _priorityColor(p).withValues(alpha: 0.15)
                          : AppTheme.surfaceVariantColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: _priority == p
                          ? Border.all(color: _priorityColor(p).withValues(alpha: 0.4)) : null),
                      child: Text(_priorityLabel(p), style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _priority == p
                          ? _priorityColor(p) : AppTheme.textMutedColor(context)))))),
              ]),
              const SizedBox(height: 12),

              // Organizers
              OrganizerSelectorField(
                selected: _organizers,
                onChanged: (list) => setState(() => _organizers = list)),
              const SizedBox(height: 16),

              // Salvar
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(widget.existingIdea == null ? 'Salvar ideia' : 'Atualizar',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)))),
            ])),
        ]));
  }

  String _horizonLabel(IdeaHorizon h) => switch (h) {
    IdeaHorizon.now        => '🔥 Agora',
    IdeaHorizon.soon       => '⚡ Em breve',
    IdeaHorizon.someday    => '☁️ Um dia',
    IdeaHorizon.noDeadline => '∞ Sem prazo',
  };

  Color _priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.critical => AppColors.error, TaskPriority.high => AppColors.warning,
    TaskPriority.medium   => AppColors.info,  TaskPriority.low  => AppColors.textMuted,
  };

  String _priorityLabel(TaskPriority p) => switch (p) {
    TaskPriority.critical => 'Crítica', TaskPriority.high => 'Alta',
    TaskPriority.medium   => 'Média',   TaskPriority.low  => 'Baixa',
  };

  void _pickDate() async {
    final picked = await showDatePicker(context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)));
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _pickEmoji() => showModalBottomSheet(context: context,
    builder: (_) => _EmojiGrid(onPick: (e) { setState(() => _emoji = e); Navigator.pop(context); }));

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final idea = Idea(
      id: widget.existingIdea?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      horizon: _horizon, priority: _priority, targetDate: _targetDate,
      organizers: _organizers, emoji: _emoji,
      createdAt: widget.existingIdea?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now());
    if (widget.existingIdea == null) {
      await ref.read(ideasProvider.notifier).addIdea(idea);
    } else {
      await ref.read(ideasProvider.notifier).updateIdea(idea);
    }
    if (mounted) Navigator.pop(context);
  }
}
```
Tela de Ideias — `lib/ui/screens/ideas_screen.dart` — CRIAR NOVO:
Layout: busca sempre visível, chips de horizonte, lista com card que tem botão "Converter →".
```dart
class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key});
  @override ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
  String       _searchQuery    = '';
  IdeaHorizon? _filterHorizon;
  bool         _showConverted  = false;

  @override
  Widget build(BuildContext context) {
    final ideas   = ref.watch(ideasProvider);
    var   filtered = ideas.where((i) =>
      !i.archived &&
      (_showConverted || !i.isConverted) &&
      (_filterHorizon == null || i.horizon == _filterHorizon) &&
      (_searchQuery.isEmpty ||
        i.title.toLowerCase().contains(_searchQuery.toLowerCase()))).toList()
      ..sort((a, b) {
        final hc = a.horizon.index.compareTo(b.horizon.index);
        if (hc != 0) return hc;
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Ideias'), centerTitle: true),
      body: CustomScrollView(slivers: [
        // Busca
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Buscar ideias…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true, fillColor: AppTheme.surfaceVariantColor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero, isDense: true)))),

        // Chips de horizonte
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _hChip(null, 'Todas'),
              ...IdeaHorizon.values.map((h) => _hChip(h, _horizonLabel(h))),
            ])))),

        // Lista ou empty state
        filtered.isEmpty
          ? SliverFillRemaining(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                const Text('💡', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Nenhuma ideia ainda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Toque em + para capturar uma',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
              ])))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildIdeaCard(ctx, filtered[i]),
                childCount: filtered.length))),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context,
          isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => const CreateIdeaForm()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black)));
  }

  Widget _hChip(IdeaHorizon? h, String label) {
    final sel = _filterHorizon == h;
    return Padding(padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterHorizon = h),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
  }

  String _horizonLabel(IdeaHorizon h) => switch (h) {
    IdeaHorizon.now        => '🔥 Agora',
    IdeaHorizon.soon       => '⚡ Em breve',
    IdeaHorizon.someday    => '☁️ Um dia',
    IdeaHorizon.noDeadline => '∞ Sem prazo',
  };

  Widget _buildIdeaCard(BuildContext context, Idea idea) {
    return ObjectActionWrapper(object: idea,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => UniversalDetailView(object: idea))),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(idea.emoji ?? '💡', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(idea.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              if (idea.body != null && idea.body!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(idea.body!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _horizonBadge(idea.horizon),
                if (idea.priority != null) ...[
                  const SizedBox(width: 6),
                  _priorityDot(idea.priority!),
                ],
                const Spacer(),
                if (!idea.isConverted)
                  GestureDetector(
                    onTap: () => _showConvertSheet(context, idea),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20)),
                      child: const Text('Converter →', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.info))))
                else
                  Text('→ ${idea.convertedToType}',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context))),
              ]),
            ])),
          ]))));
  }

  Widget _horizonBadge(IdeaHorizon h) {
    final (label, color) = switch (h) {
      IdeaHorizon.now        => ('🔥 Agora',    AppColors.error),
      IdeaHorizon.soon       => ('⚡ Em breve', AppColors.warning),
      IdeaHorizon.someday    => ('☁️ Um dia',   AppColors.info),
      IdeaHorizon.noDeadline => ('∞ Sem prazo', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)));
  }

  Widget _priorityDot(TaskPriority p) {
    final color = switch (p) {
      TaskPriority.critical => AppColors.error,   TaskPriority.high => AppColors.warning,
      TaskPriority.medium   => AppColors.info,     TaskPriority.low  => AppColors.textMuted,
    };
    return Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  void _showConvertSheet(BuildContext context, Idea idea) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Converter "${idea.title}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Notas e organizers serão mantidos.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 16),
          _convertTile(ctx, idea, 'Task',    Icons.check_circle_outline_rounded, AppColors.primary,
            'Cria tarefa com título e prioridade',
            () => CreateTaskForm(initialTitle: idea.title, initialNotes: idea.body,
              initialPriority: idea.priority, initialOrganizers: idea.organizers)),
          _convertTile(ctx, idea, 'Projeto', Icons.folder_outlined, AppColors.habitPurple,
            'Cria projeto no Organize',
            () => CreateProjectForm(initialTitle: idea.title, initialDescription: idea.body,
              initialOrganizers: idea.organizers)),
          _convertTile(ctx, idea, 'Meta',    Icons.flag_outlined, AppColors.habitGreen,
            'Cria uma goal',
            () => CreateGoalForm(initialTitle: idea.title, initialNotes: idea.body,
              initialOrganizers: idea.organizers)),
          _convertTile(ctx, idea, 'Nota',    Icons.description_outlined, AppColors.info,
            'Cria nota com o conteúdo da ideia',
            () => CreateNoteForm(initialTitle: idea.title, initialBody: idea.body,
              initialOrganizers: idea.organizers, initialTags: idea.tags)),
        ])));
  }

  Widget _convertTile(BuildContext ctx, Idea idea, String label,
      IconData icon, Color color, String sub, Widget Function() formBuilder) {
    return ListTile(
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
      onTap: () async {
        Navigator.pop(ctx);
        final result = await Navigator.push<dynamic>(context,
          MaterialPageRoute(builder: (_) => formBuilder()));
        if (result != null && mounted) {
          await ref.read(ideasProvider.notifier).updateIdea(
            idea.copyWith(convertedToType: label.toLowerCase(), convertedToId: result.id));
        }
      });
  }
}
```
Integração com CreateMenu:
```dart
// Em create_menu_sheet.dart, na aba Capture:
_captureItem(icon: '💡', label: 'Ideia', subtitle: 'Captura rápida, converte depois',
  onTap: () {
    Navigator.pop(context);
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateIdeaForm());
  }),
```
---
D4 — Mercado (Lista de Compras)
O que é: Tipo de objeto dedicado para listas de compras. A Laura precisa de algo ultra-rápido: abrir, digitar, Enter, próximo item. E funcionar como widget nativo no Android onde dá para marcar itens sem abrir o app.
Por que não usar Note/Collection ou Task: Note/collection não tem widget nativo de checklist com sync, não tem agrupamento por categoria. Task seria pesado demais (deadline, priority, stage). Shopping precisa de UX própria: Enter = novo item, marcar = tachar e sumir, categorias para organizar na loja.
Tela de lista individual — `lib/ui/screens/shopping_list_screen.dart` — CRIAR NOVO:
```dart
class ShoppingListScreen extends ConsumerStatefulWidget {
  final ShoppingList list;
  final bool autoFocus;
  const ShoppingListScreen({super.key, required this.list, this.autoFocus = false});
  @override ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _inputController = TextEditingController();
  final _inputFocus      = FocusNode();
  bool    _showChecked     = false;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _inputFocus.requestFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListsProvider);
    final list  = lists.firstWhere((l) => l.id == widget.list.id, orElse: () => widget.list);
    final activeItems  = list.activeItems;
    final checkedItems = list.checkedItems;

    // Agrupar por categoria
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in activeItems) {
      (grouped[item.category ?? 'Outros'] ??= []).add(item);
    }
    final displayGroups = _filterCategory != null
      ? {_filterCategory!: grouped[_filterCategory!] ?? []}
      : grouped;

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(list.emoji ?? '🛒', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(list.title),
        ]),
        actions: [
          if (checkedItems.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.cleaning_services_rounded, size: 16),
              label: Text('Limpar (${checkedItems.length})'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              onPressed: () => _clearChecked(list)),
        ]),
      body: Column(children: [
        // Campo de captura sempre visível
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: AppTheme.cardFillColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)),
          child: Row(children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('🛒', style: TextStyle(fontSize: 18))),
            Expanded(child: TextField(
              controller: _inputController, focusNode: _inputFocus,
              decoration: const InputDecoration(
                hintText: 'Adicionar item…', border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14)),
              textInputAction: TextInputAction.done,
              onSubmitted: (val) => _addItem(list, val))),
            IconButton(icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () => _addItem(list, _inputController.text)),
          ])),

        // Chips de categoria (só se há mais de 1)
        if (grouped.keys.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _catChip(null, 'Todos'),
                ...grouped.keys.map((cat) => _catChip(cat, cat)),
              ]))),

        const SizedBox(height: 4),

        // Lista de itens
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            // Itens ativos por categoria
            ...displayGroups.entries.expand((entry) => [
              if (displayGroups.length > 1)
                Padding(padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(entry.key, style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.10,
                    color: AppTheme.textMutedColor(context)))),
              ...entry.value.map((item) => _buildItemTile(list, item, checked: false)),
            ]),

            // Itens marcados (colapsável)
            if (checkedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _showChecked = !_showChecked),
                child: Row(children: [
                  Icon(_showChecked ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AppTheme.textMutedColor(context)),
                  const SizedBox(width: 4),
                  Text('${checkedItems.length} marcados',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
                ])),
              if (_showChecked)
                ...checkedItems.map((item) => _buildItemTile(list, item, checked: true)),
            ],
          ])),
      ]));
  }

  Widget _catChip(String? cat, String label) {
    final sel = _filterCategory == cat;
    return Padding(padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterCategory = cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
  }

  Widget _buildItemTile(ShoppingList list, ShoppingItem item, {required bool checked}) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_rounded, color: AppColors.error)),
      onDismissed: (_) => _deleteItem(list, item),
      child: InkWell(
        onTap: () => ref.read(shoppingListsProvider.notifier).toggleItem(list.id, item.id),
        borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Container(width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: checked ? AppColors.primary : AppTheme.dividerColor(context), width: 2),
                color: checked ? AppColors.primary : Colors.transparent),
              child: checked ? const Icon(Icons.check_rounded, size: 14, color: Colors.black) : null),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                decoration: checked ? TextDecoration.lineThrough : null,
                color: checked ? AppTheme.textMutedColor(context) : AppTheme.textPrimaryColor(context))),
              if (item.quantity != null)
                Text(item.quantity!,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
            ])),
          ]))));
  }

  void _addItem(ShoppingList list, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;
    // Detectar quantidade: "2 kg de arroz" → qty: "2 kg", name: "arroz"
    final qtyMatch = RegExp(
      r'^(\d+[\s,.]?\d*\s*(?:kg|g|l|ml|un|caixa|pote|cx|und)?\s+)(.+)',
      caseSensitive: false).firstMatch(trimmed);
    final name     = qtyMatch?.group(2)?.trim() ?? trimmed;
    final quantity = qtyMatch?.group(1)?.trim();
    ref.read(shoppingListsProvider.notifier).addItem(list.id,
      ShoppingItem(id: const Uuid().v4(), name: name, quantity: quantity, order: list.items.length));
    _inputController.clear();
    _inputFocus.requestFocus(); // mantém foco para próximo item
  }

  void _deleteItem(ShoppingList list, ShoppingItem item) {
    final updated = list.copyWith(
      items: list.items.where((i) => i.id != item.id).toList(), updatedAt: DateTime.now());
    ref.read(shoppingListsProvider.notifier).updateList(updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${item.name}" removido'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () {
        ref.read(shoppingListsProvider.notifier).addItem(list.id, item);
      })));
  }

  void _clearChecked(ShoppingList list) async {
    final toRestore = list.checkedItems.toList();
    await ref.read(shoppingListsProvider.notifier).clearChecked(list.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${toRestore.length} item(s) removidos'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () async {
        final curr = ref.read(shoppingListsProvider).firstWhere((l) => l.id == list.id);
        await ref.read(shoppingListsProvider.notifier)
          .updateList(curr.copyWith(items: [...curr.items, ...toRestore]));
      })));
  }
}
```
Tela de todas as listas — `lib/ui/screens/shopping_screen.dart` — CRIAR NOVO:
```dart
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(shoppingListsProvider).where((l) => !l.archived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mercado'), centerTitle: true),
      body: lists.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛒', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Nenhuma lista ainda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            FilledButton.icon(icon: const Icon(Icons.add_rounded),
              label: const Text('Criar lista'),
              onPressed: () => _createList(context, ref)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: lists.length,
            itemBuilder: (ctx, i) => _buildListCard(ctx, ref, lists[i])),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createList(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black)));
  }

  Widget _buildListCard(BuildContext context, WidgetRef ref, ShoppingList list) {
    final total   = list.totalCount;
    final checked = list.checkedCount;
    final pct     = total > 0 ? checked / total : 0.0;

    return InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ShoppingListScreen(list: list))),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(list.emoji ?? '🛒', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(list.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('$checked/$total', style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700,
              color: pct >= 1.0 ? AppColors.habitGreen : AppColors.primary)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: AppTheme.surfaceVariantColor(context),
              valueColor: AlwaysStoppedAnimation(
                pct >= 1.0 ? AppColors.habitGreen : AppColors.primary))),
          if (list.activeItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              list.activeItems.take(3).map((i) => i.name).join(', ')
              + (list.activeItems.length > 3 ? '…' : ''),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
          ],
        ])));
  }

  void _createList(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova lista'),
        content: TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ex: Mercado semana, Feira, Farmácia')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Criar')),
        ]));
    if (name == null || name.isEmpty) return;
    final list = ShoppingList(id: const Uuid().v4(), title: name,
      createdAt: DateTime.now(), updatedAt: DateTime.now());
    await ref.read(shoppingListsProvider.notifier).addList(list);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ShoppingListScreen(list: list, autoFocus: true)));
    }
  }
}
```
Widget nativo Android — `lib/services/widget_service.dart`:
```dart
static const _shoppingProvider = 'CitrineShoppingWidgetProvider';

static Future<void> updateShoppingWidget(ShoppingList list) async {
  await _saveJson('citrine_shopping_${list.id}', {
    'listId':   list.id, 'title': list.title, 'emoji': list.emoji ?? '🛒',
    'items': list.activeItems.take(10).map((i) => {
      'id': i.id, 'name': i.name, 'qty': i.quantity, 'checked': i.isChecked,
    }).toList(),
    'checkedCount': list.checkedCount, 'totalCount': list.totalCount,
    'linkUri':  'citrine:///shopping/${list.id}',
    'addUri':   'citrine:///shopping/${list.id}/add',
    'checkUri': 'citrine:///shopping/${list.id}/check/',
  });
  await _update(_shoppingProvider);
}
```
Widget nativo (Kotlin) deve: mostrar emoji + título, lista de até 8 itens com checkbox tapável, item marcado some após 2s com animação de tachado, botão + no canto, barra de progresso X/Y no rodapé.
Deep links — adicionar ao router:
```dart
'/shopping/:listId'              → ShoppingListScreen(listId)
'/shopping/:listId/add'          → ShoppingListScreen(listId, autoFocus: true)
'/shopping/:listId/check/:itemId' → toggleItem sem abrir tela, confirmar com vibração
```
Integração no CreateMenu:
```dart
_captureItem(icon: '🛒', label: 'Mercado', subtitle: 'Adicionar à lista de compras',
  onTap: () {
    Navigator.pop(context);
    final lists = ref.read(shoppingListsProvider).where((l) => !l.archived).toList();
    if (lists.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ShoppingListScreen(list: lists.first, autoFocus: true)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingScreen()));
    }
  }),
```

---
CHECKLIST COMPLETO DE IMPLEMENTAÇÃO
---
🔴 CRÍTICO — quebra dados ou funcionalidade central
[ ] `obsidian_service.dart` — `encoding: utf8` em read/write (A4)
[ ] `google_drive_sync_service.dart` — encoding utf8 (A4)
[ ] `backup_service.dart` — encoding utf8 (A4)
[ ] Strings `Ã§`, `Ã£`, `Ã©` em todo codebase → corrigir para UTF-8 real (A4)
[ ] `planner_screen.dart` — passar `timeBlocks:` ao `TimeLineDayView` — 1 linha (C4a)
[ ] `notes_screen.dart` — expandir Outline/Collection mostra editor correto (C1)
[ ] `goals_screen.dart` — `_parseGoalColor` com try-catch (C5e)
[ ] `universal_detail_view.dart` — callback de vincular objeto em Resource salva de volta ao resource
---
🟠 ALTA — base compartilhada (desbloqueia várias telas)
[ ] `lib/models/saved_filter.dart` — criar arquivo novo (A1)
[ ] `lib/providers/settings_provider.dart` — `userName`, `accentColor`, `savedFiltersRaw`, métodos (A2)
[ ] `lib/services/markdown_parser.dart` — `HighlightItem` + `extractHighlights` (A3)
[ ] `lib/ui/widgets/filter_sort_sheet.dart` — criar arquivo novo (B1)
---
🟡 ALTA — telas principais com bugs ou UX quebrada
[ ] `notes_screen.dart` — grid view, chips dinâmicos, fix `_formatDate` zero-pad (C1)
[ ] `resources_screen.dart` — shelf + highlights feed (C2)
[ ] `home_screen.dart` — saudação, quote com highlights, fix pull-to-search debounce (C3)
[ ] `planner_screen.dart` — toggle timeline/lista, setas de navegação, fix moodSlug, fix tracker (C4)
[ ] `goals_screen.dart` — ConsumerStatefulWidget, barra global, +10% inline, sem IntrinsicHeight (C5)
[ ] `habits_screen.dart` — fix semana na segunda, seção sem agendamento, fix _SummaryChip (C6)
[ ] `inbox_screen.dart` — campo sempre visível, swipe triagem (C7)
[ ] `settings_screen.dart` — grupos visuais, campo de nome (C8)
[ ] `social_screen.dart` — SortMode enum, overlay multi-select, arquivar com undo (C18)
[ ] `object_action_wrapper.dart` — fix overflow popup (C18d)
[ ] `create_social_post_form.dart` — detecção duplicata, título editável (C19)
---
🟢 MÉDIA — qualidade de vida e features novas
[ ] `appearance_screen.dart` — swatches interativos + persistência (C9)
[ ] `journal_screen.dart` — banner filtros ativos, busca expansível (C10)
[ ] `people_screen.dart` — busca, toggle lista/grid, ações contato, badge pendente (C11)
[ ] `trackers_screen.dart` — último valor no card, botão +, remover Analysis duplicado (C12)
[ ] `timeline_screen.dart` — fix título, paginação (C13)
[ ] `organizer_detail_screen.dart` — contagem nas tabs, botões separados (C14)
[ ] `day_theme_screen.dart` — botões explícitos, preview visual de blocos (C15)
[ ] `search_screen.dart` — recentes persistidos, chip de tipo ativo, actions contextuais (C16)
[ ] Fixes globais de overflow: VENCIDA badge, editModeHint, SummaryChip, resize handle (C20)
[ ] Feature Quitting Habits — modelo, formulário, card, integração (D1)
[ ] Feature Tracker de Saúde — `lib/models/tracker_model.dart`, `create_tracker_form.dart`, `health_alerts_provider.dart`, `health_alerts_strip.dart`, `notification_service.dart` (D2)
---
⚪ BAIXA — polimento e features novas complexas
[ ] `app_shell.dart` — labels onlyShowSelected, badges na nav, tooltip FAB (C17)
[ ] `lib/providers/badge_counts_provider.dart` — criar (A5)
[ ] `lib/ui/widgets/skeleton_list.dart` — criar (B2)
[ ] Feature Ideias — `idea_model.dart`, `ideasProvider`, `create_idea_form.dart`, `ideas_screen.dart`, integração CreateMenu + busca (D3)
[ ] Feature Mercado — `shopping_list_model.dart`, `shoppingListsProvider`, `shopping_list_screen.dart`, `shopping_screen.dart`, widget nativo Android, deep links (D4)
---
Dependências entre itens
```
A1 saved_filter.dart
  └── A2 settings_provider (filtersFor, upsertSavedFilter)
        └── B1 FilterSortSheet
              ├── C1 notes_screen (chips dinâmicos)
              ├── C2 resources_screen (chips dinâmicos)
              ├── C5 goals_screen (filtros)
              ├── C11 people_screen (filtros)
              └── C13 timeline_screen (filtros)

A3 extractHighlights
  ├── C2 resources_screen (highlights feed)
  └── C3 home_screen (quote do dia)

A5 badge_counts_provider
  └── C17 app_shell (badges na nav)

D2 TrackerField alerta
  ├── A8 health_alerts_provider
  └── B3 health_alerts_strip
        └── C6 habits_screen (HealthAlertsStrip no topo)

D3 Ideias
  └── A6.4 idea_model + A7 ideasProvider
        └── D3 create_idea_form + ideas_screen

D4 Mercado
  └── A6.5 shopping_list_model + A7 shoppingListsProvider
        └── D4 shopping screens + widget nativo
```

---
BLOCO E — COMPLEMENTOS E VERIFICAÇÕES
> Specs adicionais para os pedidos de 04–13/06 que não estavam cobertos no Bloco A–D.
VERIFICAÇÃO E COMPLEMENTO — Pedidos de 04–13/06
> Para cada pedido: status (✅ coberto / ⚠️ parcial / ❌ ausente), onde encontrar no doc principal, e o complemento necessário.
---
PEDIDO 1 — Tracker: dias sem dado não aparecem como zero no gráfico
Mensagem: "quando eu nao colocar nada no dia no tracker e pedir uma analise, ao inves de aparecer como se fosse 0 no grafico, nao ter a bolinha e interromper a linha, aí voltar quando tiver dado de novo"
Status: ❌ ausente no doc principal — a seção de TrackerDetailScreen menciona "gráficos por campo" mas não especifica o comportamento de dados ausentes.
Viável agora: Sim, com o `citrine_chart.dart` existente ou usando `fl_chart`/`recharts`. É uma mudança de lógica de dados, não requer novo modelo.
Spec complementar — E1: Gaps em gráficos de tracker
O problema: Quando o usuário não registra um campo num dia, o dado é `null`. Hoje o gráfico provavelmente interpola para zero ou conecta pontos distantes, fazendo parecer que o valor foi zero — o que é falso e distorce a análise.
Comportamento correto:
Dia com registro → ponto no gráfico
Dia sem registro → sem ponto, sem bolinha, linha interrompida
Quando os dados voltarem → linha recomeça daquele ponto
Como implementar — na construção do dataset do gráfico:
```dart
// Em TrackerDetailScreen ou no widget de gráfico, ao montar os dados:

/// Converte registros em série de pontos com gaps explícitos.
/// Retorna lista de [FlSpot] onde dias sem dado ficam de fora da série,
/// e uma lista separada de spans (segmentos contínuos) para desenhar
/// linhas que se interrompem nos gaps.
List<List<FlSpot>> buildSparseLineSeries({
  required List<TrackingRecord> records,
  required String fieldName,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  // Mapear data → valor
  final Map<String, double> byDate = {};
  for (final r in records) {
    final key = _dateKey(r.date);
    final val = (r.fieldValues[fieldName] as num?)?.toDouble();
    if (val != null) byDate[key] = val;
  }

  // Iterar dia a dia e criar segmentos contínuos
  final segments = <List<FlSpot>>[];
  var currentSegment = <FlSpot>[];

  for (var d = rangeStart;
       !d.isAfter(rangeEnd);
       d = d.add(const Duration(days: 1))) {
    final key = _dateKey(d);
    final val = byDate[key];
    final x   = d.difference(rangeStart).inDays.toDouble();

    if (val != null) {
      currentSegment.add(FlSpot(x, val));
    } else {
      // Gap: finalizar segmento atual se tiver pontos
      if (currentSegment.isNotEmpty) {
        segments.add(List.from(currentSegment));
        currentSegment = [];
      }
    }
  }
  if (currentSegment.isNotEmpty) segments.add(currentSegment);
  return segments; // cada segmento vira uma LineChartBarData separada
}

String _dateKey(DateTime d) =>
  '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
```
No widget de gráfico (fl_chart):
```dart
// Cada segmento vira uma LineChartBarData independente com a mesma cor/estilo:
final segments = buildSparseLineSeries(
  records: fieldRecords, fieldName: field.name,
  rangeStart: rangeStart, rangeEnd: rangeEnd);

LineChart(LineChartData(
  lineBarsData: segments.map((segment) => LineChartBarData(
    spots: segment,
    isCurved: true,
    color: AppColors.primary,
    barWidth: 2,
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
        radius: 4, color: AppColors.primary,
        strokeWidth: 2, strokeColor: Colors.white)),
    belowBarData: BarAreaData(
      show: true,
      color: AppColors.primary.withValues(alpha: 0.08)),
  )).toList(),
  // ... restante das configs
))
```
Se o app usa `citrine_chart.dart` próprio em vez de fl_chart, aplicar a mesma lógica: construir `segments` como acima e passar como lista de séries separadas ao `CitrineChart`, que deve iterar e desenhar cada uma independentemente.
Regra adicional: No tooltip do ponto, mostrar a data real e o valor. Para dias sem dado (quando o usuário toca na área vazia), não mostrar tooltip — ou mostrar "sem registro neste dia".
Onde adicionar: `lib/ui/screens/trackers_screen.dart` ou (preferencialmente) em `lib/ui/screens/universal_detail_view.dart` no bloco de Tracker, e em qualquer widget de gráfico dentro de `lib/ui/widgets/citrine_chart.dart`.
---
PEDIDO 2 — Hierarquia de Organizers: arquivo nota+área, aviso de conflito
Mensagem: "definir hierarquia de organizer. quando um mesmo arquivo se encaixa no que faz uma nota e uma área, vira o que? como isso é definido? tem um aviso dessa confusao? pede pra eu definir o que acontece?"
Status: ❌ ausente no doc principal — mencionado superficialmente nos docs anteriores de gap analysis mas não foi incluído no `citrine_specs_completo.md`.
Viável: Sim, após implementação do vault provider e parser de markdown.
Spec complementar — E2: Resolução de conflito Nota/Organizer
E2.1 — Regras de resolução de tipo
Ao parsear um arquivo `.md` do vault, o `MarkdownParser` / `VaultProvider` aplica estas regras em ordem:
Prioridade	Condição	Resultado
1	`type: organizer` no frontmatter	→ Organizer
2	`type: note` no frontmatter	→ Note
3	Tem `organizer_type` no frontmatter	→ Organizer
4	Tem `note_subtype` no frontmatter	→ Note
5	Body tem >50 chars que não são só links	→ Note (com body descritivo)
6	Outros objetos têm `organizers: [[este-arquivo]]`	→ Organizer
7	Nenhum critério	→ Organizer label (fallback)
Conflito é detectado quando:
`type: organizer` E body tem >50 chars de texto corrido (não só links)
`type: note` E outros objetos referenciam este arquivo em `organizers:`
Tem `organizer_type` E `note_subtype` simultaneamente
Tem `organizer_type` E body substantivo (não só links)
E2.2 — Provider de conflitos
Arquivo: `lib/providers/vault_provider.dart` — adicionar:
```dart
/// Um arquivo que satisfaz critérios de Nota E de Organizer ao mesmo tempo.
class ObjectConflict {
  final String fileSlug;
  final String title;
  final String currentType;      // 'note' | 'organizer'
  final List<String> reasons;   // por que é ambíguo
  const ObjectConflict({
    required this.fileSlug, required this.title,
    required this.currentType, required this.reasons,
  });
}

final conflictingObjectsProvider = Provider<List<ObjectConflict>>((ref) {
  final allObjects = ref.watch(allObjectsProvider);
  final conflicts  = <ObjectConflict>[];

  for (final obj in allObjects) {
    final reasons = <String>[];

    if (obj is Note) {
      // Note sendo referenciada como organizer por outros objetos
      final referencedAsOrganizer = allObjects.any((o) =>
        o != obj &&
        (o as dynamic).organizers?.any((org) => org.slug == obj.slug) == true);
      if (referencedAsOrganizer) {
        reasons.add('Esta nota é usada como organizer por outros objetos');
      }
      // Note com organizer_type no frontmatter (caso de import do Obsidian)
      if ((obj as dynamic).rawFrontmatter?['organizer_type'] != null) {
        reasons.add('Tem organizer_type no frontmatter mas é tratada como nota');
      }
    }

    if (obj is Organizer) {
      // Organizer com body substantivo
      final body = (obj as dynamic).description ?? '';
      final nonLinkContent = body.replaceAll(RegExp(r'\[\[.*?\]\]'), '').trim();
      if (nonLinkContent.length > 80) {
        reasons.add('Tem conteúdo textual substancial além de links');
      }
      // Organizer com note_subtype
      if ((obj as dynamic).rawFrontmatter?['note_subtype'] != null) {
        reasons.add('Tem note_subtype no frontmatter mas é tratado como organizer');
      }
    }

    if (reasons.isNotEmpty) {
      conflicts.add(ObjectConflict(
        fileSlug: obj.slug, title: obj.title,
        currentType: obj is Note ? 'note' : 'organizer',
        reasons: reasons));
    }
  }

  return conflicts;
});
```
E2.3 — Banner de conflito no UniversalDetailView
Arquivo: `lib/ui/screens/universal_detail_view.dart`
Adicionar no início do body (após o SliverAppBar, antes das propriedades):
```dart
// Verificar se este objeto tem conflito:
final conflicts  = ref.watch(conflictingObjectsProvider);
final myConflict = conflicts.cast<ObjectConflict?>()
  .firstWhere((c) => c?.fileSlug == object.slug, orElse: () => null);

if (myConflict != null)
  SliverToBoxAdapter(child: _buildConflictBanner(myConflict)),

Widget _buildConflictBanner(ObjectConflict conflict) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.35))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Arquivo ambíguo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.warning))),
      ]),
      const SizedBox(height: 6),
      ...conflict.reasons.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: AppColors.warning)),
          Expanded(child: Text(r, style: TextStyle(
            fontSize: 12, color: AppTheme.textSecondaryColor(context)))),
        ]))),
      const SizedBox(height: 10),
      Text('Este arquivo se comporta como ${conflict.currentType == "note" ? "nota" : "organizer"}. '
        'Deseja manter assim ou converter?',
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () {/* manter como está — descartar aviso por 30 dias */},
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5))),
          child: Text('Manter como ${conflict.currentType == "note" ? "nota" : "organizer"}'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(
          onPressed: () => _showConversionSheet(conflict),
          style: FilledButton.styleFrom(backgroundColor: AppColors.warning.withValues(alpha: 0.9)),
          child: Text('Converter para ${conflict.currentType == "note" ? "organizer" : "nota"}'))),
      ]),
    ]));
}
```
E2.4 — Sheet de conversão
```dart
void _showConversionSheet(ObjectConflict conflict) {
  showModalBottomSheet(context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Converter arquivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (conflict.currentType == 'note') ...[
          // Nota → Organizer
          Text('O corpo da nota virará o campo "descrição" do organizer. '
            'Os links wiki [[...]] continuarão funcionando.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 12),
          Text('Tipo de organizer:', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 8),
          // Chips de tipo de organizer (area, project, label, etc.)
          Wrap(spacing: 8, children: ['area', 'project', 'label', 'activity', 'family']
            .map((t) => _orgTypeChip(t)).toList()),
        ] else ...[
          // Organizer → Nota
          Text('A descrição do organizer virará o corpo da nota. '
            'Objetos que usam este arquivo como organizer continuarão vinculados.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 12),
          // Aviso de impacto
          Consumer(builder: (ctx, ref, _) {
            final affected = ref.watch(allObjectsProvider).where((o) =>
              (o as dynamic).organizers?.any((org) => org.slug == conflict.fileSlug) == true
            ).toList();
            if (affected.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Text('${affected.length} objeto(s) têm este arquivo como organizer. '
                'Eles continuarão vinculados mas o arquivo passará a ser exibido como nota.',
                style: TextStyle(fontSize: 12, color: AppColors.info)));
          }),
        ],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            _performConversion(conflict);
          },
          child: const Text('Confirmar conversão'))),
      ])));
}

Future<void> _performConversion(ObjectConflict conflict) async {
  // Reescrever o frontmatter do arquivo .md via ObsidianService
  // Atualizar o type: 'note' ou 'organizer'
  // Se Nota→Organizer: mover body para description, limpar body
  // Se Organizer→Nota: mover description para body
  // Recarregar o vault (forçar re-parse)
  await ref.read(obsidianServiceProvider).convertObjectType(
    slug: conflict.fileSlug,
    targetType: conflict.currentType == 'note' ? 'organizer' : 'note',
  );
  if (mounted) Navigator.pop(context);
}
```
Suprimir aviso por 30 dias — salvar em `AppSettings.suppressedConflicts: Map<String, DateTime>`:
```dart
// Em settingsProvider, adicionar:
final Map<String, DateTime> suppressedConflicts; // slug → data de supressão

// Ao verificar conflito:
final suppressed = settings.suppressedConflicts[obj.slug];
final isSuppressed = suppressed != null &&
  DateTime.now().difference(suppressed).inDays < 30;
if (!isSuppressed) { /* mostrar banner */ }
```
---
PEDIDO 3 — Arquitetura de informação: organizer lê propriedades e corpo
Mensagem: "quando um arquivo é um organizer, o app precisa ler oq está nas propriedades e no corpo da nota, e mostrar. exemplo: o que significa quando uma área tem vários links? quando esses links são notas, elas precisam aparecer em items. quando são tarefas, eventos, hábitos, etc com checks, momentos que ocorrem, precisam aparecer na timeline dessa área. quando são outros organizers, precisam aparecer em children/suborganizers."
Status: ❌ ausente no doc principal. Mencionado vagamente no gap analysis original mas não foi especificado com detalhe suficiente.
Viável: Sim, após implementação do wiki-link resolver.
Spec complementar — E3: Arquitetura de informação por tipo de objeto
E3.1 — Wiki-link resolver (base necessária)
Antes de tudo, o app precisa de um resolver que converte `[[slug]]` em `ContentObject`:
```dart
// Adicionar em lib/services/markdown_parser.dart:
static List<String> extractWikiLinks(String text) {
  final matches = RegExp(r'\[\[([^\]]+)\]\]').allMatches(text);
  return matches.map((m) => m.group(1)!.trim()).toList();
}

// Provider derivado — resolve slugs para objetos reais:
// lib/providers/wiki_link_resolver_provider.dart (NOVO)
final wikiLinkResolverProvider = Provider<Map<String, ContentObject>>((ref) {
  final all = ref.watch(allObjectsProvider);
  return {for (final obj in all) obj.slug: obj};
});

// Uso:
final resolver = ref.watch(wikiLinkResolverProvider);
final linkedObj = resolver['nome-da-nota']; // → ContentObject ou null
```
E3.2 — Regras de exibição por tipo de link no body
Quando um `Organizer` tem wiki-links `[[...]]` no body/description, o app classifica cada link resolvido e o exibe na aba correta:
Tipo do objeto linkado	Aparece em
`Note`	Aba Items
`Task`	Aba Timeline (com data base = `deadline` ou `createdAt`) + Aba Items
`Habit`	Aba Timeline (por data de completion)
`JournalEntry`	Aba Timeline (por `date`)
`TrackingRecord`	Aba Timeline (por `date`)
`Organizer`	Aba Children/Sub-organizers
`Resource`	Aba Items
`SocialPost`	Aba Items
`Goal`	Aba Items + progresso inline
`Project`	Aba Children
`Person`	Aba Items (com último contato)
`Reminder`	Aba Items
`Idea`	Aba Items
`ShoppingList`	Aba Items
E3.3 — OrganizerDetailScreen: leitura completa
Arquivo: `lib/ui/screens/organizer_detail_screen.dart` — REFATORAR significativamente
Estado atual: O `associatedItemsProvider` busca objetos que têm `organizers: [[este-slug]]` no frontmatter. Ele não lê os wiki-links do body do próprio organizer.
Estado novo: Dois tipos de itens associados:
Incoming: objetos que têm `organizers: [[este-slug]]` → já existe
Outgoing (novo): objetos linkados via `[[wiki-link]]` no body/description do organizer
```dart
// Provider expandido:
final organizerAssociatedProvider = FutureProvider.family<_OrganizerItems, String>((ref, slug) async {
  final resolver = ref.watch(wikiLinkResolverProvider);
  final all      = ref.watch(allObjectsProvider);

  // 1. Incoming: objetos que referenciam este organizer
  final incoming = all.where((o) =>
    (o as dynamic).organizers?.any((org) => org.slug == slug) == true
  ).toList();

  // 2. Outgoing: objetos linkados no body deste organizer
  final organizer = all.firstWhere((o) => o.slug == slug);
  final body      = (organizer as dynamic).description ?? '';
  final slugsInBody = MarkdownParser.extractWikiLinks(body);
  final outgoing  = slugsInBody
    .map((s) => resolver[s])
    .whereType<ContentObject>()
    .where((o) => !incoming.contains(o)) // evitar duplicatas
    .toList();

  final combined = [...incoming, ...outgoing];

  // Classificar por tipo
  return _OrganizerItems(
    timelineItems: combined.where((o) =>
      o is Task || o is JournalEntry || o is TrackingRecord ||
      o is Habit || o is PomodoroSession
    ).toList()
      ..sort((a, b) => _baseTime(a).compareTo(_baseTime(b))),
    noteItems: combined.whereType<Note>().toList(),
    resourceItems: combined.whereType<Resource>().toList(),
    socialItems: combined.whereType<SocialPost>().toList(),
    goalItems: combined.whereType<Goal>().toList(),
    ideaItems: combined.whereType<Idea>().toList(),
    childOrganizers: combined.where((o) => o is Organizer || o is Project).toList(),
    people: combined.whereType<Person>().toList(),
  );
});

class _OrganizerItems {
  final List<ContentObject> timelineItems;
  final List<ContentObject> noteItems;
  final List<ContentObject> resourceItems;
  final List<ContentObject> socialItems;
  final List<ContentObject> goalItems;
  final List<ContentObject> ideaItems;
  final List<ContentObject> childOrganizers;
  final List<ContentObject> people;
  // ...
}

DateTime _baseTime(ContentObject o) {
  if (o is Task)         return o.deadline ?? o.createdAt ?? DateTime(0);
  if (o is JournalEntry) return o.date;
  if (o is TrackingRecord) return o.date;
  return (o as dynamic).createdAt ?? DateTime(0);
}
```
Tabs da OrganizerDetailScreen reformuladas:
```
Tab 1: TIMELINE
  → Items com data: tasks, journal entries, records, habit completions
  → Agrupado por data (hoje, ontem, esta semana, mais antigos)
  → Ordenado por baseTime desc

Tab 2: ITENS
  → Notes, Resources, SocialPosts, Goals, Ideas, Pessoas, Reminders
  → Sub-seções por tipo com headers

Tab 3: SUB-ORGANIZERS
  → Organizers e Projects filhos (parentId == este slug OU linkados no body)
  → Cards compactos com contagem de itens próprios

Tab 4: DESCRIÇÃO (nova, aparece só se description não vazia)
  → Markdown renderizado do body/description do organizer
  → Wiki-links clicáveis inline
```
Tab DESCRIÇÃO — renderização com links clicáveis:
```dart
// Na aba Descrição:
MarkdownBodyView(
  content: organizer.description ?? '',
  onWikiLinkTap: (slug) {
    final resolver = ref.read(wikiLinkResolverProvider);
    final target   = resolver[slug];
    if (target != null && context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => UniversalDetailView(object: target)));
    }
  })
```
O `MarkdownBodyView` existente precisa aceitar um callback `onWikiLinkTap`. Se não aceita, adicionar o parâmetro.
E3.4 — Regras por tipo de organizer
Área (type: area):
Description = propósito da área ("Por que esta área existe na minha vida?")
Timeline = tudo que acontece dentro dessa área ordenado por data
Items = notas, recursos, metas relacionadas
Children = projetos e sub-áreas
Projeto (type: project):
Description = objetivo e contexto
Timeline = tasks com deadline, marcos concluídos
Items = notas de contexto, recursos de referência
Children = sub-projetos
Extra: barra de progresso de tasks (`finalized / total`)
Label/Tag (type: label):
Items = tudo que tem essa label, qualquer tipo
Sem timeline, sem children
People/Person:
Timeline = histórico de contatos (`ContactEvent`), tasks com participant, journal entries que mencionam
Items = notas sobre a pessoa, recursos compartilhados
Sem children
Activity (type: activity):
Timeline = todas as vezes que a atividade foi feita (habit completions, pomodoro sessions, tracking records)
Items = notas, recursos relacionados
E3.5 — BacklinksProvider expandido
O `backlinksProvider` atual só busca no frontmatter. Expandir para incluir menções no body:
```dart
// lib/providers/backlinks_provider.dart — EDITAR
final backlinksProvider = Provider.family<List<ContentObject>, String>((ref, slug) {
  final all      = ref.watch(allObjectsProvider);
  final resolver = ref.watch(wikiLinkResolverProvider);

  return all.where((obj) {
    // 1. Referenciado no frontmatter organizers:
    final inFrontmatter = (obj as dynamic).organizers
      ?.any((org) => org.slug == slug) ?? false;

    // 2. Mencionado no body/description via [[wiki-link]]:
    final body  = (obj as dynamic).body ?? (obj as dynamic).description ?? '';
    final links = MarkdownParser.extractWikiLinks(body);
    final inBody = links.contains(slug);

    return inFrontmatter || inBody;
  }).toList();
});
```
---
PEDIDO 4 — Social: duplicata ao salvar (banner + opções)
Mensagem: "no social tem uns que duplicam, ao salvar, identificar se é um link que ja existe, se sim ter um banner em cima dizendo que ja foi salvo no dia e horario X, e com a opção de editar ou nao fazer nada"
Status: ✅ Completamente coberto no doc principal — seção C19 (`create_social_post_form.dart`), subseção 19a "Detecção de duplicata". Implementação completa com enum `_DuplicateAction`, dialog de confirmação com 3 opções (não fazer nada / editar existente / salvar mesmo assim) e formatação de data.
Nada a complementar.
---
PEDIDO 5 — Como anotar ideias relacionadas a qualquer coisa no vault
Mensagem: "como anotar ideias? q podem ta relacionada a qqr coisa no vault"
Status: ✅ Completamente coberto no doc principal — seção D3 (Ideias como Tipo de Objeto). Inclui modelo `Idea`, formulário de captura rápida com `linkedSlugs` para vincular qualquer objeto do vault via wiki-links, tela de listagem, e conversão para Task/Projeto/Goal/Nota.
Nada a complementar.
---
PEDIDO 6 — Busca/link picker: aba para Social Posts, filtrar por plataforma e criador
Mensagem: "quando eu for pesquisar algo pra linkar ao que eu to criando/editando, tem q ter os posts do social, uma aba pra filtrar eles ordenado pela ultima modificação pra ficar mais facil de achar" + "mas tb preciso achar por plataforma, criador"
Status: ❌ ausente no doc principal — o `universal_search_picker.dart` não foi especificado com aba de Social.
Viável: Sim, após implementar os filtros base.
Spec complementar — E6: Social Posts no UniversalSearchPicker
Arquivo: `lib/ui/widgets/universal_search_picker.dart` — EDITAR
O que é: O picker que abre quando o usuário toca em "Vincular objeto" em qualquer form. Hoje provavelmente tem abas por tipo (Tudo, Tasks, Notes, Resources...) mas sem Social Posts.
Adicionar aba "Social":
```dart
// Na TabBar do picker, adicionar:
Tab(text: 'Social'),

// Na TabBarView correspondente:
_buildSocialTab(),

Widget _buildSocialTab() {
  final posts = ref.watch(socialPostsProvider);

  // Sub-filtros no topo da aba
  return Column(children: [
    // Barra de busca por título/handle/caption
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        onChanged: (v) => setState(() => _socialSearch = v),
        decoration: InputDecoration(
          hintText: 'Título, @handle, legenda…',
          prefixIcon: const Icon(Icons.search_rounded, size: 16),
          filled: true, fillColor: AppTheme.surfaceVariantColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero, isDense: true))),

    // Chips de plataforma
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _platformChip(null, 'Todas'),
          ...SocialPlatform.values.map((p) => _platformChip(p, p.name.toUpperCase())),
        ]))),

    // Chips de criador (extraídos dos posts disponíveis)
    if (_uniqueCreators(posts).isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _creatorChip(null, 'Todos'),
            ..._uniqueCreators(posts).map((h) => _creatorChip(h, '@$h')),
          ]))),

    const Divider(height: 1),

    // Lista ordenada por updatedAt desc
    Expanded(child: Builder(builder: (ctx) {
      var filtered = posts
        .where((p) => !p.archived)
        .where((p) => _socialPlatformFilter == null || p.platform == _socialPlatformFilter)
        .where((p) => _socialCreatorFilter == null || p.authorHandle == _socialCreatorFilter)
        .where((p) => _socialSearch.isEmpty ||
          p.title.toLowerCase().contains(_socialSearch.toLowerCase()) ||
          (p.authorHandle?.toLowerCase().contains(_socialSearch.toLowerCase()) ?? false) ||
          (p.caption?.toLowerCase().contains(_socialSearch.toLowerCase()) ?? false))
        .toList()
        ..sort((a, b) =>
          (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0)));

      if (filtered.isEmpty) return Center(child: Text('Nenhum post encontrado',
        style: TextStyle(color: AppTheme.textMutedColor(context))));

      return ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final post = filtered[i];
          return ListTile(
            leading: _platformIcon(post.platform),
            title: Text(post.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${post.authorHandle != null ? "@${post.authorHandle}" : post.platform.name}'
              ' · ${_relativeDate(post.updatedAt ?? post.createdAt)}',
              style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
            onTap: () => Navigator.pop(context, post));
        });
    })),
  ]);
}

List<String> _uniqueCreators(List<SocialPost> posts) =>
  posts.map((p) => p.authorHandle).whereType<String>().toSet().toList()..sort();

Widget _platformChip(SocialPlatform? p, String label) {
  final sel = _socialPlatformFilter == p;
  return Padding(padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: () => setState(() => _socialPlatformFilter = p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: sel ? Colors.black : AppTheme.textSecondaryColor(context))))));
}

Widget _creatorChip(String? handle, String label) {
  final sel = _socialCreatorFilter == handle;
  return Padding(padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: () => setState(() => _socialCreatorFilter = handle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AppColors.info.withValues(alpha: 0.15) : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: sel ? AppColors.info : AppTheme.textSecondaryColor(context))))));
}

// Estado adicional no picker:
SocialPlatform? _socialPlatformFilter;
String?         _socialCreatorFilter;
String          _socialSearch = '';
```
Onde o picker é chamado: Sempre que o usuário toca em "Vincular" em qualquer form (Task, Note, Resource, Idea, SocialPost próprio). A aba Social deve aparecer em todos esses contextos.
---
PEDIDO 7 — Resources: vincular e criar objeto não funciona
Mensagem: "nos resources quando vou em vincular e crio um objeto, nao acontece nada"
Status: ✅ Mencionado e especificado no doc principal — seção C (referenciado como bug crítico): "universal_detail_view.dart — callback de vincular objeto em Resource salva de volta ao resource". Está no checklist de CRÍTICO.
O código exato do fix está implícito mas não explicitado. Complementar:
Spec complementar — E7: Fix vincular objeto em Resource
Arquivo: `lib/ui/screens/universal_detail_view.dart`
No bloco de `_buildTypeSpecificContent` para `Resource`, localizar onde o `UniversalSearchPicker` (ou equivalente) é chamado e corrigir o callback:
```dart
// ANTES (provável — não salva):
onObjectSelected: (obj) {
  // vazio ou sem persistência
},

// DEPOIS:
onObjectSelected: (obj) async {
  if (obj == null || obj is! ContentObject) return;
  final resource = object as Resource;
  final updated  = resource.copyWith(
    linkedObjects: [
      ...(resource.linkedObjects ?? []),
      OrganizerReference(id: obj.id, title: obj.title, slug: obj.slug),
    ],
    updatedAt: DateTime.now());
  await ref.read(resourcesProvider.notifier).updateResource(updated);
  // Forçar rebuild mostrando o novo vínculo
  if (mounted) setState(() {});
},

// Se o picker permite criar novo objeto inline (CreateTaskForm, CreateNoteForm, etc.),
// garantir que ao retornar o objeto criado seja passado de volta:
final newObj = await Navigator.push<ContentObject>(context,
  MaterialPageRoute(builder: (_) => CreateTaskForm()));
if (newObj != null && mounted) {
  onObjectSelected(newObj);
}
```
---
PEDIDO 8 — Caracteres especiais bugados (ç, acentos)
Mensagem: "os caracteres especiais tao tudo bugado (coisa com acento, ç etc"
Status: ✅ Completamente coberto no doc principal — seção A4 (Encoding UTF-8 nos serviços de arquivo). Especifica exatamente onde e como adicionar `encoding: utf8` nos três serviços, e como varrer o codebase por strings corrompidas `Ã§`, `Ã£`.
Nada a complementar.
---
PEDIDO 9 — Diminuir overflow adaptando tamanho de caixas/botões/cards
Mensagem: "tem como diminuir o overflow das coisas adaptando o tamanho das coisas? caixas de texto, botoes, cards etc?"
Status: ✅ Parcialmente coberto no doc principal — seção C20 cobre fixes pontuais de overflow (badge VENCIDA, editModeHint, SummaryChip, resize handle). O `AdaptiveLayout` helper foi mencionado nos docs anteriores mas não foi incluído no `citrine_specs_completo.md`.
Spec complementar — E9: AdaptiveLayout helper global
Arquivo: `lib/ui/utils/adaptive_layout.dart` — CRIAR NOVO
```dart
// lib/ui/utils/adaptive_layout.dart

/// Helper para adaptar tamanhos de UI a telas pequenas.
/// Telas < 380px (alguns Androids entry-level) precisam de ajustes.
class AdaptiveLayout {
  /// Retorna fontSize reduzido em telas < 380px de largura.
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.82;
    if (w < 380) return base * 0.91;
    return base;
  }

  /// Retorna padding horizontal reduzido em telas pequenas.
  static EdgeInsets hPadding(BuildContext context, {double normal = 16}) {
    final w = MediaQuery.of(context).size.width;
    final p = w < 360 ? normal * 0.75 : normal;
    return EdgeInsets.symmetric(horizontal: p);
  }

  /// True se a tela é estreita (< 380px).
  static bool isNarrow(BuildContext context) =>
    MediaQuery.of(context).size.width < 380;

  /// Padding de campo de texto adaptativo.
  static EdgeInsets fieldPadding(BuildContext context) =>
    isNarrow(context)
      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
      : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  /// Padding horizontal de botão adaptativo.
  static EdgeInsets buttonPadding(BuildContext context) =>
    isNarrow(context)
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
      : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
}
```
Uso nos forms (onde o overflow é mais frequente):
```dart
// Em campos de texto:
InputDecoration(
  contentPadding: AdaptiveLayout.fieldPadding(context),
  ...)

// Em botões primários:
ElevatedButton(
  style: ElevatedButton.styleFrom(padding: AdaptiveLayout.buttonPadding(context)),
  ...)

// Em títulos de card com texto longo:
Text(title,
  style: TextStyle(fontSize: AdaptiveLayout.fontSize(context, 14), fontWeight: FontWeight.w700),
  maxLines: 2, overflow: TextOverflow.ellipsis)
```
Regra geral para todo o codebase: Qualquer `Text` dentro de um `Row` que não esteja dentro de `Expanded` ou `Flexible` é um overflow em potencial. Aplicar `Expanded(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis))` sistematicamente.
---
PEDIDO 10 — Rotinas: linkar objetos e trechos, go-to page, scheduler e bloco de tempo
Mensagem: "preciso q tenha tipo um jeito de eu linkar objetos e trechos de objetos a uma pagina (acho q seria uma rotina)... qq eu faço quando to com meltdown? quais sao todas as coisas q preciso fazer antes de sair de casa?... pode ter rotina automatica (com scheduler) ou que eu coloco manualmente como um bloco de tempo no planner (tem que ter essa opção)"
Status: ❌ ausente no doc principal. Mencionado brevemente nos docs anteriores como "Rotinas como Note outline" mas sem spec completa.
Viável: Sim, usando `Note` tipo `outline` com extensões. Não requer novo tipo de objeto.
Spec complementar — E10: Rotinas
E10.1 — O que é uma Rotina
Uma Rotina é uma `Note` com `noteType: 'routine'` (novo subtipo). É uma página de referência pessoal — um "go-to" para lembrar o que fazer numa situação específica. Não é uma checklist de tarefas (não tem stage pipeline), é um documento vivo que pode ter:
Texto livre com contexto
Wiki-links para outros objetos (`[[nome-nota]]`, `[[titulo-habito]]`)
Trechos citados de outros objetos (highlight de um resource, um bloco de uma nota)
Passos numerados
Checkboxes contextuais (não salvos como tarefas — são lembretes visuais)
Exemplos de uso da Laura:
"O que fazer num meltdown?" → links para habits de regulação, trecho do livro sobre isso, checklist simples
"Sair de casa" → passos, links para objetos que ela precisa verificar
"Receita de carne do TikTok" → link para o SocialPost, notas pessoais, trechos de outros posts
E10.2 — Modelo — extensão de Note
Arquivo: `lib/models/note_model.dart` — EDITAR
```dart
// Adicionar ao enum NoteType (ou noteType String):
// 'routine' — além de 'text', 'outline', 'collection'

// Adicionar ao modelo Note:
final String? schedulerSlug;    // se tem scheduler automático vinculado
final bool showInPlanner;       // se deve aparecer como bloco de tempo no planner
final TimeOfDay? plannerTime;   // horário padrão no planner
```
E10.3 — Formulário de criação rápida — `lib/ui/forms/create_note_form.dart`
Quando `noteType == 'routine'`, mostrar campos adicionais:
```dart
// Após os campos básicos (título, organizers, tags):
if (_noteType == 'routine') ...[
  const Divider(),
  // Opção de scheduler automático
  Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rotina agendada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('Aparece automaticamente no planner no horário definido',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _hasScheduler, onChanged: (v) => setState(() => _hasScheduler = v)),
  ]),
  if (_hasScheduler) ...[
    const SizedBox(height: 8),
    // Reutilizar SchedulerPicker existente
    SchedulerPicker(onChanged: (s) => setState(() => _scheduler = s)),
  ],
  const SizedBox(height: 8),
  // Opção de adicionar manualmente ao planner
  Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mostrar no Planner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('Aparece como bloco de tempo quando arrastado para o planner',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _showInPlanner, onChanged: (v) => setState(() => _showInPlanner = v)),
  ]),
],
```
E10.4 — Editor de Rotina
A rotina usa o `OutlineEditor` existente mas com capacidade de inserir dois novos tipos de item:
Tipo A: Link para objeto — `[[wiki-link]]`
Ao tocar em "+ Adicionar" dentro do outline editor → menu de opções
"Linkar objeto" → abre `UniversalSearchPicker` → insere `[[slug-do-objeto]]`
Renderizado como card compacto com ícone do tipo + título clicável
Tipo B: Trecho de objeto — `> "texto citado" — [[fonte]]`
"Citar trecho" → abre picker de objeto → depois picker de highlight desse objeto
Insere blockquote com atribuição: `> "texto do highlight" — [[titulo-resource]]`
Renderizado como blockquote com borda colorida (igual ao feed de highlights do Resources)
```dart
// Em OutlineEditor ou no editor de Routine,
// botão de inserção rápida no toolbar:
Row(children: [
  _toolbarBtn(Icons.link_rounded, 'Linkar objeto', () => _insertWikiLink()),
  _toolbarBtn(Icons.format_quote_rounded, 'Citar trecho', () => _insertHighlight()),
  _toolbarBtn(Icons.check_box_outlined, 'Checkbox', () => _insertCheckbox()),
  _toolbarBtn(Icons.format_list_numbered_rounded, 'Passo numerado', () => _insertStep()),
]),

Future<void> _insertWikiLink() async {
  final obj = await Navigator.push<ContentObject>(context,
    MaterialPageRoute(builder: (_) => const UniversalSearchPickerScreen()));
  if (obj == null) return;
  _insertAtCursor('[[${obj.slug}]]');
}

Future<void> _insertHighlight() async {
  // 1. Picker de objeto (qualquer tipo com body/synopsis)
  final obj = await Navigator.push<ContentObject>(context,
    MaterialPageRoute(builder: (_) => const UniversalSearchPickerScreen()));
  if (obj == null) return;

  // 2. Picker de highlight desse objeto
  final body = (obj as dynamic).body ?? (obj as dynamic).synopsis ?? '';
  final highlights = MarkdownParser.extractHighlights(body);
  if (highlights.isEmpty) {
    // Sem highlights detectados → inserir link simples
    _insertAtCursor('[[${obj.slug}]]');
    return;
  }

  final selected = await showModalBottomSheet<HighlightItem>(
    context: context,
    builder: (ctx) => _HighlightPickerSheet(
      objectTitle: obj.title, highlights: highlights));
  if (selected == null) return;

  _insertAtCursor('> "${selected.text}" — [[${obj.slug}]]');
}
```
`_HighlightPickerSheet` — bottom sheet que lista os highlights de um objeto:
```dart
class _HighlightPickerSheet extends StatelessWidget {
  final String objectTitle;
  final List<HighlightItem> highlights;
  const _HighlightPickerSheet({required this.objectTitle, required this.highlights});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Trechos de "$objectTitle"',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        const Divider(),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: highlights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final hl = highlights[i];
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, hl),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  border: Border(left: BorderSide(color: AppColors.primary, width: 2)),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (hl.tag != null)
                    Text('#${hl.tag}', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  Text('"${hl.text}"', style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryColor(context),
                    fontStyle: FontStyle.italic, height: 1.5)),
                ])));
          })),
      ]));
  }
}
```
E10.5 — Integração com Planner
Quando `note.showInPlanner == true`, a rotina pode ser arrastada para o Planner como bloco de tempo.
Em `planner_screen.dart`: Adicionar seção "Rotinas" no backlog (lista de itens sem horário definido):
```dart
// No _buildBacklogSection, após tasks sem data:
final routines = ref.watch(notesProvider)
  .where((n) => n.noteType == 'routine' && n.showInPlanner).toList();

if (routines.isNotEmpty) ...[
  const SizedBox(height: 16),
  Text('ROTINAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
  const SizedBox(height: 8),
  ...routines.map((r) => Draggable<Note>(
    data: r,
    feedback: Material(child: _buildRoutineBacklogCard(r, dragging: true)),
    child: _buildRoutineBacklogCard(r))),
]
```
O `DragTarget` na timeline aceita `Note` com `noteType == 'routine'` e cria um bloco de tempo com duração padrão de 30min e o título da rotina.
Rotina com scheduler automático: Quando `note.schedulerSlug != null`, o `SchedulerService.shouldFire(scheduler, date)` inclui essa rotina nos itens do dia. Aparece na timeline como bloco de tipo "routine" (ícone 📋, cor roxa).
E10.6 — CreateMenu: atalho para nova rotina
```dart
// Em create_menu_sheet.dart:
_createItem(
  icon: '📋',
  label: 'Rotina',
  subtitle: 'Página go-to para uma situação',
  onTap: () {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreateNoteForm(initialNoteType: 'routine')));
  }),
```
---
PEDIDO 11 — TikTok: transcrição automática e embed sem UI
Mensagem: "quando eu salvo um video no TikTok tem como ir carregando e colocar a transcrição do video (ptbr ou ingles)? e fazer isso de graça?" + "geralmente uso o whisper pra puxar a transcrição... e tb da pra ficar embed só o video sem a ui do tiktok? talvez com aquele yt dlp"
Status: ⚠️ Parcialmente coberto — mencionado nos docs anteriores com esboço de código para Whisper via HuggingFace, mas não incluído no `citrine_specs_completo.md`.
Viável: Transcrição via HuggingFace Inference API = gratuito com rate limit. Embed sem UI do TikTok via yt-dlp = requer backend/servidor — não é 100% automático e gratuito no cliente Flutter puro. Ver análise abaixo.
Spec complementar — E11: Transcrição e embed TikTok
E11.1 — Transcrição via HuggingFace Whisper (gratuito)
Campo no modelo — `lib/models/social_post.dart`:
```dart
final String? transcription;      // texto transcrito
final String? transcriptionLang;  // 'pt' | 'en' | 'auto'
final bool    isTranscribing;     // loading state
```
Serviço — `lib/services/transcription_service.dart` — CRIAR NOVO:
```dart
class TranscriptionService {
  static const _apiUrl =
    'https://api-inference.huggingface.co/models/openai/whisper-large-v3';

  /// Transcreve um vídeo a partir de sua URL de áudio/vídeo.
  /// Requer: HuggingFace token gratuito (configurado em Settings > Integrações).
  ///
  /// LIMITAÇÃO: HuggingFace Inference API aceita arquivos de até ~25MB.
  /// Para vídeos maiores, retorna erro e orienta o usuário.
  ///
  /// ALTERNATIVA GRATUITA ADICIONAL: Groq API tem Whisper gratuito com
  /// limite de 7200 segundos/dia — mais generoso que HuggingFace.
  /// Endpoint: https://api.groq.com/openai/v1/audio/transcriptions
  static Future<String?> transcribeFromUrl({
    required String videoUrl,
    required String hfToken,     // token do HuggingFace salvo em Settings
    String language = 'pt',
  }) async {
    try {
      // 1. Baixar o áudio do vídeo (via URL direta se disponível)
      //    TikTok: a URL de oEmbed pode não dar acesso direto ao arquivo
      //    Fallback: usar videoUrl diretamente se for .mp4 acessível
      final audioResponse = await http.get(Uri.parse(videoUrl));
      if (audioResponse.statusCode != 200) return null;

      final bytes = audioResponse.bodyBytes;
      if (bytes.lengthInBytes > 25 * 1024 * 1024) {
        throw Exception('Arquivo muito grande para transcrição automática (>25MB)');
      }

      // 2. Enviar para HuggingFace Whisper
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $hfToken',
          'Content-Type': 'application/octet-stream',
          'X-Wait-For-Model': 'true',   // aguarda o modelo carregar se necessário
        },
        body: bytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] as String?;
      }

      // Modelo ainda carregando (503) → aguardar e tentar novamente
      if (response.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 20));
        return transcribeFromUrl(
          videoUrl: videoUrl, hfToken: hfToken, language: language);
      }

      return null;
    } catch (e) {
      debugPrint('Transcription error: $e');
      return null;
    }
  }
}
```
UI no form de Social Post — botão de transcrição no formulário:
```dart
// Em create_social_post_form.dart, seção de vídeo (quando plataforma é TikTok/YouTube):
if (_isVideoPost) ...[
  const SizedBox(height: 12),
  ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.subtitles_outlined, color: AppColors.info, size: 18)),
    title: Text(_draft?.transcription != null
      ? 'Transcrição disponível (${_draft!.transcription!.length} chars)'
      : 'Transcrever vídeo automaticamente'),
    subtitle: Text(_draft?.transcription != null
      ? 'Toque para ver ou editar'
      : 'Usa Whisper via HuggingFace (gratuito)',
      style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    trailing: _isTranscribing
      ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Icon(Icons.chevron_right_rounded, size: 16),
    onTap: _isTranscribing ? null : () => _transcribe()),
],

Future<void> _transcribe() async {
  final settings = ref.read(settingsProvider);
  if (settings.huggingFaceToken?.isEmpty != false) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
        'Configure seu token HuggingFace em Configurações > Integrações')));
    return;
  }

  setState(() => _isTranscribing = true);
  try {
    final videoUrl = _draft?.videoUrl ?? _urlController.text.trim();
    final text = await TranscriptionService.transcribeFromUrl(
      videoUrl: videoUrl,
      hfToken: settings.huggingFaceToken!);
    if (text != null && mounted) {
      setState(() => _draft = _draft?.copyWith(transcription: text));
      // Mostrar resultado em sheet expansível
      _showTranscriptionSheet(text);
    }
  } finally {
    if (mounted) setState(() => _isTranscribing = false);
  }
}

void _showTranscriptionSheet(String text) => showModalBottomSheet(
  context: context, isScrollControlled: true,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.6, maxChildSize: 0.95, expand: false,
    builder: (_, ctrl) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text('Transcrição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(controller: ctrl,
          child: SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.6)))),
      ]))));
```
Campo HuggingFace token em Settings:
```dart
// Em settings_screen.dart, dentro do card "Integrações":
_settingsTile('Whisper (HuggingFace)', Icons.mic_rounded,
  subtitle: settings.huggingFaceToken?.isNotEmpty == true
    ? 'Token configurado' : 'Não configurado',
  onTap: () => _editHfToken()),

void _editHfToken() async {
  final ctrl = TextEditingController(text: ref.read(settingsProvider).huggingFaceToken ?? '');
  final result = await showDialog<String>(context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Token HuggingFace'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'hf_...')),
        const SizedBox(height: 8),
        Text('Obtenha gratuitamente em huggingface.co/settings/tokens',
          style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Salvar')),
      ]));
  if (result != null) {
    await ref.read(settingsProvider.notifier).setHuggingFaceToken(result);
  }
}
```
Adicionar `huggingFaceToken: String?` ao `AppSettings` e `setHuggingFaceToken()` ao notifier.
E11.2 — Embed sem UI do TikTok
Análise de viabilidade:
Abordagem	Gratuito	Automático	Sem UI TikTok
oEmbed padrão do TikTok	✅	✅	❌ tem UI
WebView com JS injection	✅	✅	⚠️ frágil
yt-dlp no dispositivo	✅	❌ manual	✅
yt-dlp em servidor próprio	✅*	✅	✅
Terceiros (cobram)	❌	✅	✅
*servidor próprio requer hospedagem (Railway free tier funciona)
Recomendação: WebView com JS injection (melhor custo-benefício no Flutter):
```dart
// Em social_embed_view.dart:
// Quando platform == SocialPlatform.tiktok e oEmbedHtml disponível:
WebViewWidget(
  controller: _controller,
  // Após a página carregar, injetar CSS para ocultar elementos de UI:
)

// No onPageFinished:
_controller.runJavaScript('''
  // Remover header, footer, action bar, sugestões de vídeos
  const selectors = [
    '.tiktok-header', '.author-uniqueId', '.video-meta-share',
    '.action-bar', '.tiktok-footer', '[class*="DivRecommentContainer"]',
    '[data-e2e="related-video"]'
  ];
  selectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => el.remove());
  });

  // Forçar vídeo para tela cheia dentro do WebView
  const video = document.querySelector('video');
  if (video) {
    video.style.cssText = "width:100%!important;height:100%!important;object-fit:contain";
  }
''');
```
Limitação documentada: A estrutura de CSS do TikTok muda frequentemente, então este método pode quebrar e precisar de manutenção. Para uso pessoal é aceitável — para produção seria frágil.
---
PEDIDO 12 — Hábitos de baixa frequência (lavar cesto, tarefas periódicas flexíveis)
Mensagem: "como registrar coisas q nao sao necessariamente habitos? tipo lavar o cesto da maquina de lavar. é bom ser a cada 30 dias mas nao precisa ser tao certinho... quando colocar q a prioridade é baixa ter algo que anote a frequencia q eu quero fazer, e quando tiver chegando perto aparecer nos habitos do dia de um jeito diferente"
Status: ❌ ausente no doc principal — mencionado nos docs anteriores como "Hábito de baixa frequência" mas não foi incluído no `citrine_specs_completo.md`.
Viável: Sim, usando campos adicionais em `Habit`.
Spec complementar — E12: Hábitos Flexíveis/Periódicos
E12.1 — Modelo — extensão de Habit
Arquivo: `lib/models/habit_model.dart` — EDITAR
```dart
// Adicionar ao Habit:
final int?  frequencyDays;        // quero fazer a cada N dias
final bool  isFlexibleFrequency;  // true = não rígido, aparecer diferente
// (isFlexibleFrequency = true implica que schedulers não são obrigatórios)

// Serialização:
'frequency_days':       frequencyDays,
'is_flexible_frequency': isFlexibleFrequency,
// fromJson:
frequencyDays:       j['frequency_days'],
isFlexibleFrequency: j['is_flexible_frequency'] ?? false,
```
E12.2 — Formulário — `create_habit_form.dart`
Quando o usuário escolhe prioridade baixa OU ativa explicitamente o toggle, mostrar campo de frequência:
```dart
// Toggle "Frequência flexível" — aparece após os schedulers ou quando prioridade == low:
if (_priority == TaskPriority.low || _isFlexibleFrequency) ...[
  const Divider(),
  Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Frequência flexível',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('Não aparece todo dia — surge quando a data estiver chegando',
        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
    ])),
    Switch(value: _isFlexibleFrequency,
      onChanged: (v) => setState(() => _isFlexibleFrequency = v)),
  ]),
  if (_isFlexibleFrequency) ...[
    const SizedBox(height: 10),
    Row(children: [
      const Text('Quero fazer a cada', style: TextStyle(fontSize: 13)),
      const SizedBox(width: 10),
      SizedBox(width: 60, child: TextField(
        controller: _frequencyDaysCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          filled: true, fillColor: AppTheme.surfaceVariantColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 8)),
        onChanged: (v) => setState(() => _frequencyDays = int.tryParse(v)))),
      const SizedBox(width: 8),
      const Text('dias', style: TextStyle(fontSize: 13)),
    ]),
  ],
],
```
E12.3 — Card visual diferenciado na HabitsScreen
Na `_TodayView`, hábitos com `isFlexibleFrequency == true` aparecem numa terceira seção "Periódicos" (depois dos normais e dos quitting). Só aparecem quando `daysSinceLast / frequencyDays >= 0.75` (chegando perto do prazo):
```dart
// Após a seção "Evitando" (quitting habits):
Builder(builder: (ctx) {
  final flexible = ref.watch(habitsProvider).where((h) =>
    h.isFlexibleFrequency && h.status == HabitStatus.active && !h.archived).toList();
  if (flexible.isEmpty) return const SizedBox.shrink();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(width: 3, height: 14,
          decoration: BoxDecoration(color: AppColors.info,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('Periódicos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.info, letterSpacing: 0.08)),
      ])),
    const SizedBox(height: 8),
    ...flexible.map((h) {
      final daysSince = _daysSinceLast(h);
      final ratio     = h.frequencyDays != null ? daysSince / h.frequencyDays! : 0.0;
      // Só mostrar se chegando perto (ratio >= 0.6) ou passado (ratio >= 1.0)
      if (ratio < 0.6) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _FlexHabitCard(habit: h, daysSince: daysSince, ratio: ratio));
    }),
  ]);
})

int _daysSinceLast(Habit h) {
  final history = h.completionHistory ?? {};
  final now     = DateTime.now();
  for (int i = 0; i < 365; i++) {
    final d   = now.subtract(Duration(days: i));
    final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final e   = history[key];
    if (e == true || (e is Map && (e['done'] == true || e['value'] != null))) return i;
  }
  return 999; // nunca foi feito
}
```
`_FlexHabitCard` — card com cor semafórica e botões de ação:
```dart
class _FlexHabitCard extends ConsumerWidget {
  final Habit habit;
  final int   daysSince;
  final double ratio;
  const _FlexHabitCard({required this.habit, required this.daysSince, required this.ratio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ratio >= 1.0 ? AppColors.error
      : ratio >= 0.85 ? AppColors.warning : AppColors.info;

    final statusText = daysSince == 0 ? 'Feito hoje'
      : daysSince == 1 ? 'Feito ontem'
      : daysSince >= 999 ? 'Nunca feito'
      : 'Feito há $daysSince dias';

    final targetText = habit.frequencyDays != null
      ? 'Meta: a cada ${habit.frequencyDays} dias'
      : 'Sem frequência definida';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$statusText · $targetText',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ])),
          // Marcar como feito
          GestureDetector(
            onTap: () => ref.read(habitsProvider.notifier)
              .toggleHabit(habit, DateTime.now(), slotIndex: 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text('Feito!', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)))),
        ]),
        const SizedBox(height: 8),
        // Botões secundários
        Row(children: [
          // Agendar no planner
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: const Text('Agendar', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 6)),
            onPressed: () => _showScheduleOptions(context, ref))),
          const SizedBox(width: 8),
          // Reagendar lembrete
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.notifications_outlined, size: 14),
            label: const Text('Lembrar em…', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMutedColor(context),
              side: BorderSide(color: AppTheme.dividerColor(context)),
              padding: const EdgeInsets.symmetric(vertical: 6)),
            onPressed: () => _showReminderOptions(context, ref))),
        ]),
      ]));
  }

  void _showScheduleOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.calendar_month_rounded),
          title: const Text('Adicionar ao Planner'),
          onTap: () { Navigator.pop(ctx); _pickDateForPlanner(context, ref); }),
        ListTile(
          leading: const Icon(Icons.timer_rounded),
          title: const Text('Iniciar Pomodoro agora'),
          onTap: () { Navigator.pop(ctx); _startPomodoro(context, ref); }),
        const SizedBox(height: 8),
      ]));
  }

  void _showReminderOptions(BuildContext context, WidgetRef ref) async {
    final days = await showModalBottomSheet<int>(context: context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16),
          child: Text('Lembrar em quantos dias?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ...[1, 3, 7, 14, 30].map((d) => ListTile(
          title: Text('Em $d dia${d > 1 ? "s" : ""}'),
          onTap: () => Navigator.pop(ctx, d))),
        const SizedBox(height: 8),
      ]));
    if (days == null) return;
    // Criar Reminder para daqui N dias
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: habit.title,
      time: DateTime.now().add(Duration(days: days)),
      linkedHabitId: habit.id);
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lembrete criado para daqui $days dia(s)')));
  }

  Future<void> _pickDateForPlanner(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(context: context,
      initialDate: DateTime.now(), firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !context.mounted) return;
    // Criar um "bloco de tempo" no planner para essa data
    // Navegar para o planner nessa data
    Navigator.pushNamed(context, '/planner', arguments: date);
  }

  void _startPomodoro(BuildContext context, WidgetRef ref) {
    ref.read(pomodoroProvider.notifier).setCurrentItem(habit.id, habit.title);
    Navigator.pushNamed(context, '/pomodoro');
  }
}
```
---
PEDIDO 13 — Quitting Habits: não aparece no calendário nem planner, comportamento de não marcar
Mensagem: "o quitting habits nao aparece no widget de calendario, nem no planner, mas aparece no habits do dia. marcar um quitting habits como feito é ruim, o objetivo é nao marcar"
Status: ✅ Completamente coberto no doc principal — seção D1 (Quitting Habits). Especifica filtros no Planner e CalendarWidget, card visual sem checkbox, botão "Recaída" com confirmação, contador de dias limpos.
Nada a complementar.
---
PEDIDO 14 — Tracker de saúde com indicadores automáticos
Mensagem: "quero fazer um tracker de coisas q eu fico de olho pra ver se to bem - sono, buraco no cabelo, comida, frequencia do cocô. aí poderia ter um indicador automatico do quanto as coisas que eu coloquei tao saudaveis... cada um desses indicativos podem ta relacionados a oq eu marco num habito, tarefa recorrente, status de um projeto, ou oq eu coloco no tracker mesmo."
Status: ✅ Coberto no doc principal — seção D2 (Tracker de Saúde). Inclui `FieldAlertLevel`, template pré-configurado, `healthAlertsProvider`, `HealthAlertsStrip`, lembretes escalonados.
Complemento necessário: A mensagem menciona que os indicadores podem vir de hábito, tarefa recorrente ou status de projeto — não só do tracker. Isso não está no doc atual.
Spec complementar — E14: Fonte de dados para alertas de saúde
O `HealthAlert` atual só lê `TrackingRecord`. Expandir para ler de outras fontes:
```dart
// Em health_alerts_provider.dart, adicionar ao loop de campos:

// Verificar se o campo tem uma fonte alternativa configurada:
if (field.dataSourceType != null) {
  switch (field.dataSourceType!) {
    case FieldDataSource.habit:
      // Verificar se o hábito vinculado foi completado hoje
      if (field.linkedHabitId != null) {
        final habit = habits.firstWhere((h) => h.id == field.linkedHabitId);
        final todayKey = _dateKey(DateTime.now());
        final completedToday = habit.completionHistory?[todayKey];
        lastVal    = (completedToday == true) ? 1.0 : 0.0;
        lastDate   = DateTime.now();
        daysSince  = completedToday == true ? 0 : 1;
      }
    case FieldDataSource.recurringTask:
      // Verificar última task recorrente com esse título finalizada
      if (field.linkedTaskTitle != null) {
        final relatedTasks = tasks.where((t) =>
          t.title.toLowerCase().contains(field.linkedTaskTitle!.toLowerCase()) &&
          t.stage?.name == 'finalized').toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
        lastDate  = relatedTasks.isNotEmpty ? relatedTasks.first.updatedAt : null;
        daysSince = lastDate != null ? now.difference(lastDate!).inDays : 999;
      }
    case FieldDataSource.tracker:
      // Comportamento atual (TrackingRecord) — já implementado
      break;
  }
}
```
Enum de fonte de dados — adicionar ao `tracker_model.dart`:
```dart
enum FieldDataSource { tracker, habit, recurringTask }

// Em TrackerField, adicionar:
final FieldDataSource dataSource;          // default: FieldDataSource.tracker
final String? linkedHabitId;              // se dataSource == habit
final String? linkedTaskTitle;            // se dataSource == recurringTask

// No template pré-configurado, o campo "Sono" pode linkar a um hábito de
// "registrar sono" se a Laura preferir marcar via hábito em vez de tracker.
```
---
PEDIDO 15 — Salvar post social e criar/vincular tarefa ou projeto sem perder infos
Mensagem: "quero conseguir ao ir salvar um post social, conseguir criar e vincular tarefa ou projeto, sem perder as infos da tarefa/projeto nem do post"
Status: ❌ ausente no doc principal.
Viável: Sim, adicionando um passo de "vincular objetos" no fluxo de salvar o post social.
Spec complementar — E15: Social Post → Vincular Task/Projeto ao salvar
E15.1 — Fluxo
Usuário preenche o form de post social normalmente
Toca em "Salvar"
Antes de fechar, aparece uma step opcional "Vincular ao seu trabalho?" com 3 opções:
Criar task relacionada
Criar projeto relacionado
Vincular a existente (busca)
Pular
O post é salvo imediatamente antes de qualquer ação de vínculo — assim o usuário nunca perde o post mesmo se fechar o form de task no meio.
E15.2 — Implementação
```dart
// Em create_social_post_form.dart, substituir o final de _save():

Future<void> _save() async {
  // ... detecção de duplicata existente ...
  // ... lógica de build e save do post ...

  final savedPost = _buildPostForSave();

  if (widget.existingPost == null) {
    await ref.read(socialPostsProvider.notifier).addPost(savedPost);
  } else {
    await ref.read(socialPostsProvider.notifier).updatePost(savedPost);
  }

  // Post salvo com sucesso — agora oferecer vínculo
  if (!mounted) return;
  final shouldLink = await _showLinkOfferSheet(savedPost);
  if (!mounted) return;

  if (shouldLink == _LinkAction.createTask) {
    await _createAndLinkTask(savedPost);
  } else if (shouldLink == _LinkAction.createProject) {
    await _createAndLinkProject(savedPost);
  } else if (shouldLink == _LinkAction.linkExisting) {
    await _linkExisting(savedPost);
  }

  // Fechar form independentemente de ter vinculado ou não
  if (mounted) Navigator.pop(context);
}

enum _LinkAction { createTask, createProject, linkExisting, skip }

Future<_LinkAction?> _showLinkOfferSheet(SocialPost post) =>
  showModalBottomSheet<_LinkAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Post salvo! ✅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Quer vincular este post a uma tarefa ou projeto?',
          style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context))),
        const SizedBox(height: 16),
        ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_task_rounded, color: AppColors.primary, size: 18)),
          title: const Text('Criar tarefa relacionada', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Tarefa pré-preenchida com título do post', style: TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, _LinkAction.createTask)),
        ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.habitPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.folder_outlined, color: AppColors.habitPurple, size: 18)),
          title: const Text('Criar projeto relacionado', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Projeto a partir do conteúdo do post', style: TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, _LinkAction.createProject)),
        ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.link_rounded, color: AppColors.info, size: 18)),
          title: const Text('Vincular a existente', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Buscar task ou projeto já criado', style: TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, _LinkAction.linkExisting)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: TextButton(
          onPressed: () => Navigator.pop(ctx, _LinkAction.skip),
          child: const Text('Pular', style: TextStyle(color: AppColors.textMuted)))),
      ])));

Future<void> _createAndLinkTask(SocialPost post) async {
  // Abrir CreateTaskForm pré-preenchido e aguardar resultado
  final newTask = await Navigator.push<Task>(context, MaterialPageRoute(
    builder: (_) => CreateTaskForm(
      // Pré-preencher com dados do post:
      initialTitle: post.title,
      initialNotes: post.personalNote ?? post.caption,
      // Vincular o post via socialRefs da task (se Task tiver esse campo)
      // ou via organizers se o post tiver slug
    )));

  if (newTask == null) return; // usuário cancelou o form de task

  // Salvar vínculo: atualizar o post com referência à task
  final updatedPost = post.copyWith(
    socialRefs: [...(post.socialRefs ?? []), '[[${newTask.slug}]]']);
  await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);

  // E atualizar a task com referência ao post (se Task tiver campo para isso)
  // Depende de como o modelo Task armazena vínculos externos
}

Future<void> _createAndLinkProject(SocialPost post) async {
  final newProject = await Navigator.push<dynamic>(context, MaterialPageRoute(
    builder: (_) => CreateProjectForm(
      initialTitle: post.title,
      initialDescription: post.personalNote ?? post.caption)));

  if (newProject == null) return;

  final updatedPost = post.copyWith(
    socialRefs: [...(post.socialRefs ?? []), '[[${newProject.slug}]]']);
  await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);
}

Future<void> _linkExisting(SocialPost post) async {
  final obj = await Navigator.push<ContentObject>(context,
    MaterialPageRoute(builder: (_) => const UniversalSearchPickerScreen()));
  if (obj == null) return;

  final updatedPost = post.copyWith(
    socialRefs: [...(post.socialRefs ?? []), '[[${obj.slug}]]']);
  await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);
}
```
Nota importante: Para que o post seja vinculado corretamente à task/projeto, os modelos `Task` e `Project` também precisam armazenar o slug do post. Se já têm campo `socialRefs` ou `linkedObjects`, usar. Se não, adicionar:
```dart
// Em task_model.dart e project_model.dart:
final List<String> linkedPostSlugs; // slugs de SocialPosts vinculados
```
---
RESUMO: O QUE ESTÁ COBERTO E O QUE FOI ADICIONADO
#	Pedido	Status no doc	Spec adicionada
1	Tracker: gaps no gráfico não = zero	❌	✅ E1
2	Hierarquia organizer, aviso de conflito	❌	✅ E2
3	Organizer lê body e mostra itens/timeline/children	❌	✅ E3
4	Social: banner de duplicata ao salvar	✅ C19	—
5	Anotar ideias vinculadas ao vault	✅ D3	—
6	Search picker: aba Social com filtro plataforma/criador	❌	✅ E6
7	Resources: vincular e criar objeto não funciona	✅ C (crítico)	✅ E7 (código exato)
8	Caracteres especiais bugados	✅ A4	—
9	Diminuir overflow adaptando tamanhos	⚠️ C20 parcial	✅ E9 (AdaptiveLayout)
10	Rotinas: linkar objetos/trechos, scheduler, bloco no planner	❌	✅ E10
11	TikTok: transcrição automática + embed sem UI	❌	✅ E11
12	Hábitos de baixa frequência (lavar cesto, etc.)	❌	✅ E12
13	Quitting Habits: comportamento e filtros	✅ D1	—
14	Tracker de saúde com indicadores automáticos	✅ D2	✅ E14 (fontes: hábito/task)
15	Salvar social + criar/vincular task/projeto	❌	✅ E15
---
CHECKLIST ADICIONAL (complementa o checklist do doc principal)
🟡 ALTA — funcionalidade pedida sem spec anterior
[ ] `lib/ui/widgets/citrine_chart.dart` ou fl_chart — suporte a gaps (E1)
[ ] `lib/ui/widgets/universal_search_picker.dart` — aba Social com filtros (E6)
[ ] `lib/ui/forms/create_social_post_form.dart` — sheet de vínculo ao salvar (E15)
[ ] `lib/models/habit_model.dart` — `frequencyDays`, `isFlexibleFrequency` (E12)
[ ] `lib/ui/screens/habits_screen.dart` — `_FlexHabitCard` e seção "Periódicos" (E12)
🟢 MÉDIA
[ ] `lib/providers/vault_provider.dart` — `conflictingObjectsProvider` (E2)
[ ] `lib/ui/screens/universal_detail_view.dart` — banner de conflito Nota/Organizer (E2)
[ ] `lib/providers/wiki_link_resolver_provider.dart` — novo arquivo (E3)
[ ] `lib/providers/backlinks_provider.dart` — expandir para incluir body (E3)
[ ] `lib/ui/screens/organizer_detail_screen.dart` — reformular tabs com incoming + outgoing (E3)
[ ] `lib/models/note_model.dart` — `noteType: 'routine'`, `schedulerSlug`, `showInPlanner` (E10)
[ ] `lib/ui/forms/create_note_form.dart` — campos de rotina (E10)
[ ] `lib/ui/screens/planner_screen.dart` — seção "Rotinas" no backlog (E10)
[ ] `lib/ui/utils/adaptive_layout.dart` — novo arquivo helper (E9)
[ ] `lib/providers/settings_provider.dart` — `huggingFaceToken`, `suppressedConflicts` (E2, E11)
[ ] `lib/models/tracker_model.dart` — `FieldDataSource`, `linkedHabitId`, `linkedTaskTitle` (E14)
⚪ BAIXA
[ ] `lib/services/transcription_service.dart` — Whisper via HuggingFace (E11)
[ ] `lib/ui/widgets/social_embed_view.dart` — JS injection para remover UI do TikTok (E11)
[ ] `lib/ui/widgets/highlight_picker_sheet.dart` — picker de trecho de objeto (E10)