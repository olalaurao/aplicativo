# UI Spec — Implementação Detalhada
Gerado: 09/06/2026  
Baseado em leitura direta do código atual (GitHub último commit)

---

## Prioridade de Implementação

| # | Feature | Arquivos principais |
|---|---------|-------------------|
| P1 | Caracteres especiais (UTF-8) | obsidian_service, drive_sync, backup |
| P2 | Overflow adaptativo | novo layout_utils.dart + correções pontuais |
| P3 | Ideias — definição configurável + atalho | settings_provider, create_menu_sheet, note_model |
| P4 | Outline e Collection — corrigir, linkar, navegar | notes_screen, outline_editor, collection_view, universal_detail_view |
| P5 | Wiki-links clicáveis no Outline (4b) | outline_editor, markdown_parser |
| P6 | Social posts na busca global | search_screen, universal_search_picker, search_service |
| P7 | Resource — vincular e criar objeto | universal_detail_view, social_post_detail |
| P8 | Widget nativo Note/Checklist (Android) | widget_service, note_model |
| P9 | Hábito de baixa frequência | habit_model, habits_screen, create_habit_form |
| P10 | Vincular livros e lugares ao post TikTok | social_post.dart, social_post_detail, create_social_post_form |
| P11 | Eisenhower Matrix Etapa 1 | saved_filter, novo matrix_screen |
| P12 | Unificar UI de vincular objetos | universal_search_picker, todos os detalhes |

---

## P1 — Caracteres Especiais (UTF-8)

### Problema confirmado no código
`obsidian_service.dart` tem `dart:convert` importado mas usa `file.readAsString()` e `file.writeAsString(content)` sem `encoding: utf8`. Dart usa Latin-1 como default nesses métodos.

### Correções

**`lib/services/obsidian_service.dart`** — toda ocorrência de leitura/escrita:
```dart
// ANTES:
return await file.readAsString();
await file.writeAsString(content);

// DEPOIS:
return await file.readAsString(encoding: utf8);
await file.writeAsString(content, encoding: utf8);
```
Aplicar em TODOS os métodos do arquivo: `readFile`, `saveObject`, `deleteFile`, `_loadAllFiles`, e qualquer outro que acesse o filesystem.

**`lib/services/google_drive_sync_service.dart`**:
```dart
// Upload:
final bytes = utf8.encode(markdownContent);

// Download — ao receber bytes:
final content = utf8.decode(responseBytes);
```

**`lib/services/backup_service.dart`**:
```dart
await file.writeAsString(jsonStr, encoding: utf8);
final raw = await file.readAsString(encoding: utf8);
```

**Strings bugadas no código-fonte** — rodar busca e substituir:
```
Padrão:  Ã§ → ç    Ã£ → ã    Ã© → é    Ãª → ê    Ãµ → õ    Ã­ → í
```
Confirmado em `create_social_post_form.dart`:
- `'Descartar alteraÃ§Ãµes?'` → `'Descartar alterações?'`
- `'VocÃª possui alteraÃ§Ãµes'` → `'Você possui alterações'`

Rodar grep em todo o projeto: `grep -r "Ã§\|Ã£\|Ã©\|Ãª\|Ãµ" lib/` e corrigir cada hit.

---

## P2 — Overflow Adaptativo

### Novo arquivo: `lib/ui/utils/layout_utils.dart`

```dart
import 'package:flutter/material.dart';

class AdaptiveLayout {
  /// Reduz fontSize proporcionalmente em telas estreitas
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.82;
    if (w < 380) return base * 0.91;
    return base;
  }

  /// Reduz padding horizontal em telas < 360px
  static double hPad(BuildContext context, {double normal = 16}) {
    return MediaQuery.of(context).size.width < 360 ? normal * 0.75 : normal;
  }

  /// true se tela menor que 380px
  static bool isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width < 380;

  /// contentPadding adaptativo para TextField
  static EdgeInsets fieldPadding(BuildContext context) {
    return isNarrow(context)
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);
  }
}
```

### Correções pontuais imediatas (bugs confirmados)

**`goals_screen.dart` — crash com Color() na progress bar** (linha em `_buildProgressInfo`):
```dart
// ANTES (crash):
valueColor: AlwaysStoppedAnimation(
  Color(int.parse(goal.color!.replaceAll('#', '0xFF'))),
),

// DEPOIS (usa a função segura que já existe no mesmo arquivo):
valueColor: AlwaysStoppedAnimation(_goalColor(goal.color)),
```

**`goals_screen.dart` — Row deadline + OVERDUE sem Flexible**:
```dart
// ANTES:
Text('Deadline: ${DateFormat(...).format(deadline)}',
  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),

// DEPOIS:
Flexible(
  child: Text('Deadline: ${DateFormat(...).format(deadline)}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: AdaptiveLayout.fontSize(context, 11),
      color: AppColors.textMuted)),
),
```

**`notes_screen.dart` — `_formatDate()` sem zero-pad no hour**:
```dart
// ANTES:
return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

// DEPOIS:
return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
```

**`habits_screen.dart` — semana começa no domingo**:
```dart
// ANTES:
final weekStart = now.subtract(Duration(days: now.weekday % 7));

// DEPOIS:
final weekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
```

**`habits_screen.dart` — _SummaryChip Row sem Flexible**:
```dart
// ANTES:
Row(children: [_SummaryChip(...), SizedBox(width:8), _SummaryChip(...)])

// DEPOIS:
Row(children: [
  Flexible(child: _SummaryChip(...)),
  const SizedBox(width: 8),
  Flexible(child: _SummaryChip(...)),
])
```

**`planner_screen.dart` — `timeBlocks` não passado ao `TimeLineDayView`**:
```dart
// Adicionar no construtor do TimeLineDayView dentro do planner:
TimeLineDayView(
  tasks: dayTasks,
  selectedDate: _selectedDate,
  allDayEvents: dayHabits,
  googleEvents: ...,
  timeBlocks: timeBlocks,  // ← ADICIONAR ESTA LINHA
  onTaskDrop: ...,
  ...
)
```

**Aplicar `AdaptiveLayout.fontSize` nos cards principais**:  
Em `_GoalCard`, `_buildNoteItem`, `_buildResourceCard`, `_TodayHabitCard` — substituir `fontSize: 15` por `fontSize: AdaptiveLayout.fontSize(context, 15)` nos títulos principais.

---

## P3 — Ideias: Definição Configurável + Atalho de Captura

### Conceito
Uma "ideia" não tem tipo fixo — o usuário define o que considera uma ideia nas configurações. Pode ser uma tag, uma pasta, um subtype de nota, etc.

### 3a — Configuração em `AppSettings`

**`lib/providers/settings_provider.dart`** — adicionar ao modelo `AppSettings`:
```dart
// Como o sistema reconhece uma "ideia":
final String ideaStrategy;      // 'tag' | 'folder' | 'any_note'
final String ideaTag;           // default: 'idea' (usado quando strategy='tag')
final String ideaFolder;        // ex: 'notes/ideas' (usado quando strategy='folder')
```

Valores default: `ideaStrategy: 'tag'`, `ideaTag: 'idea'`, `ideaFolder: 'notes/ideas'`.

**`copyWith` e serialização** — incluir os novos campos no `toJson`/`fromJson` e no `copyWith` do `AppSettings`.

**`SettingsNotifier`** — adicionar método:
```dart
Future<void> setIdeaStrategy({
  required String strategy,
  String? tag,
  String? folder,
}) async {
  state = state.copyWith(
    ideaStrategy: strategy,
    ideaTag: tag ?? state.ideaTag,
    ideaFolder: folder ?? state.ideaFolder,
  );
  await _persist();
}
```

**Tela de configuração** — em `settings_screen.dart`, adicionar tile na seção de Preferências:
```
"Ideias"  →  abre bottom sheet com:
  [O] Por tag     → campo: tag (default: "idea")
  [O] Por pasta   → campo: pasta no vault (default: "notes/ideas")  
  [O] Toda nota   → qualquer nota é considerada ideia
```
Sheet com `RadioListTile` para a estratégia + `TextField` para o valor correspondente.

### 3b — Atalho "💡 Ideia" no CreateMenu

**`lib/ui/widgets/create_menu_sheet.dart`** — na aba Capture, adicionar botão:

```dart
_captureButton(
  icon: '💡',
  label: 'Idea',
  color: AppColors.warning,
  onTap: () {
    Navigator.pop(context);
    final settings = ref.read(settingsProvider);
    _openIdeaCapture(context, settings);
  },
),
```

Helper `_openIdeaCapture`:
```dart
void _openIdeaCapture(BuildContext context, AppSettings settings) {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => CreateNoteForm(
      initialSubtype: NoteSubtype.text,
      // Pré-preencher de acordo com a estratégia configurada:
      initialTags: settings.ideaStrategy == 'tag'
          ? [settings.ideaTag]
          : [],
      initialFolder: settings.ideaStrategy == 'folder'
          ? settings.ideaFolder
          : null,
      autofocus: true,
    ),
  ));
}
```

**`lib/ui/forms/create_note_form.dart`** — adicionar parâmetros opcionais ao construtor:
```dart
final List<String>? initialTags;
final String? initialFolder;
final bool autofocus;
```
Usar `initialTags` para pré-popular o campo de tags, `autofocus: true` para colocar o cursor no campo de título ao abrir.

### 3c — Vincular Ideia ao Objeto Atual

Quando `CreateNoteForm` for aberto de dentro de um objeto (Resource, SocialPost, Goal, etc.), aceitar um parâmetro opcional:

```dart
final ContentObject? linkedObject;
```

Se `linkedObject != null`, pré-preencher `organizers` com uma `OrganizerReference` apontando para esse objeto. Isso já funciona pelo modelo — só precisa do parâmetro sendo passado.

Nos detalhes dos objetos relevantes (`UniversalDetailView`, `SocialPostDetail`), adicionar botão "💡 Add Idea" no overflow menu ou na seção de links:
```dart
ListTile(
  leading: const Text('💡', style: TextStyle(fontSize: 18)),
  title: const Text('Add idea about this'),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => CreateNoteForm(
      initialSubtype: NoteSubtype.text,
      initialTags: [settings.ideaTag],
      linkedObject: object,
      autofocus: true,
    ),
  )),
),
```

---

## P4 — Outline e Collection: Corrigir, Editar, Linkar

### 4a — Corrigir expansão inline na NotesScreen

**`lib/ui/screens/notes_screen.dart`** — no `_buildNoteItem`, completar o bloco de expansão:

```dart
// Substituir o bloco atual:
if (isExpanded && note.noteType == 'text')
  Padding(...)

// Por:
if (isExpanded) ...[
  const Divider(height: 1),
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: _buildNoteInlineEditor(context, note),
  ),
],
```

Helper `_buildNoteInlineEditor`:
```dart
Widget _buildNoteInlineEditor(BuildContext context, dynamic note) {
  switch (note.noteType) {
    case 'text':
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: RichTextEditor(
          content: note.body,
          expands: true,
          onChanged: (newContent) {
            final updated = note.copyWith(body: newContent, updatedAt: DateTime.now());
            ref.read(vaultProvider.notifier).updateObject(updated);
          },
        ),
      );
    case 'outline':
      return OutlineEditor(
        initialContent: note.body,
        onChanged: (newContent) {
          final updated = note.copyWith(body: newContent, updatedAt: DateTime.now());
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      );
    case 'collection':
      return SizedBox(
        height: 300,
        child: CollectionEditor(
          initialContent: note.body,
          onChanged: (newContent) {
            final updated = note.copyWith(body: newContent, updatedAt: DateTime.now());
            ref.read(vaultProvider.notifier).updateObject(updated);
          },
        ),
      );
    default:
      return const SizedBox.shrink();
  }
}
```

### 4b — CollectionView: modo leitura funcional com checkbox

O `collection_view.dart` atual renderiza como `DataTable` — bom para dados, mas ruim para checklist.

**Adicionar renderização inteligente por tipo de campo** em `collection_view.dart`:

```dart
Widget _buildCell(BuildContext context, PropertyDefinition prop,
    dynamic value, Map<String, dynamic> item, int itemIndex,
    Function(String key, dynamic val)? onCellChanged) {
  switch (prop.type) {
    case PropertyType.checkbox:
      return Checkbox(
        value: value == true || value == 'true',
        onChanged: onCellChanged == null
            ? null
            : (v) => onCellChanged(prop.id, v),
      );
    case PropertyType.rating:
      final rating = int.tryParse(value?.toString() ?? '0') ?? 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 14,
          color: i < rating ? AppColors.warning : AppColors.textMuted,
        )),
      );
    default:
      return Text(value?.toString() ?? '',
        style: const TextStyle(fontSize: 14));
  }
}
```

**`onChanged` opcional** — quando `onChanged != null`, a CollectionView se torna editável inline. Quando `null`, somente leitura.

### 4c — Note detail no UniversalDetailView

**`lib/ui/screens/universal_detail_view.dart`** — no bloco `if (object is Note)` de `_buildTypeSpecificContent`, garantir que Outline e Collection têm editor funcional:

```dart
if (object is Note) ...[
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _isEditing
          ? _buildNoteEditor(context, object as Note)
          : _buildNoteViewer(context, object as Note),
    ),
  ),
],
```

`_buildNoteEditor` verifica `note.noteType` e renderiza `RichTextEditor`, `OutlineEditor` ou `CollectionEditor`. `_buildNoteViewer` renderiza `MarkdownBodyView`, `WikiTextView` (para outline) ou `CollectionView`.

**Toggle view/edit** — já foi especificado no doc2 seção 3.2. Adicionar na AppBar quando `object is Note`:
```dart
if (object is Note)
  Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _toggleBtn(Icons.visibility_outlined, false),
      _toggleBtn(Icons.edit_outlined, true),
    ]),
  ),
```

---

## P5 — Wiki-links Clicáveis no Outline (4b)

### Problema
`OutlineEditor` renderiza itens como `TextField` puro. `[[slug]]` aparece como texto sem navegação.

### Solução

**`lib/ui/widgets/outline_editor.dart`** — no `_buildItem`, detectar se o texto contém `[[...]]` e renderizar diferente:

```dart
Widget _buildItemText(int index, OutlineItem item) {
  final wikiRegex = RegExp(r'\[\[([^\]]+)\]\]');
  final hasWikiLink = wikiRegex.hasMatch(item.text);

  if (hasWikiLink && !_isEditing(index)) {
    // Modo leitura — renderizar partes clicáveis
    return _buildWikiText(item.text);
  }

  // Modo edição — TextField normal
  return _buildTextField(index, item);
}

Widget _buildWikiText(String text) {
  final spans = <InlineSpan>[];
  int lastEnd = 0;
  for (final match in RegExp(r'\[\[([^\]]+)\]\]').allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    final slug = match.group(1)!;
    spans.add(TextSpan(
      text: slug,
      style: const TextStyle(color: AppColors.info,
        decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _navigateToSlug(slug),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }
  return RichText(text: TextSpan(
    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
    children: spans,
  ));
}
```

Adicionar ao `OutlineEditor` o parâmetro:
```dart
final Function(String slug)? onWikiLinkTap;
```

No `_buildNoteViewer` do `UniversalDetailView`, passar:
```dart
OutlineEditor(
  initialContent: note.body,
  onWikiLinkTap: (slug) => _navigateToSlug(context, ref, slug),
  onChanged: ...,
)
```

Helper `_navigateToSlug`:
```dart
void _navigateToSlug(BuildContext context, WidgetRef ref, String slug) {
  final all = ref.read(allObjectsProvider).valueOrNull ?? [];
  final target = all.cast<ContentObject?>().firstWhere(
    (o) => o != null && (o.slug == slug || o.title.toLowerCase() == slug.toLowerCase()),
    orElse: () => null,
  );
  if (target != null) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UniversalDetailView(object: target),
    ));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Objeto "$slug" não encontrado')));
  }
}
```

**Botão "Inserir link" na toolbar do OutlineEditor** — ao tocar, abre `UniversalSearchPickerSheet` e insere `[[slug]]` no item focado:
```dart
IconButton(
  icon: const Icon(Icons.link_rounded, size: 18),
  onPressed: () => _insertWikiLink(index),
),

Future<void> _insertWikiLink(int index) async {
  final selected = await showModalBottomSheet<ContentObject>(
    context: context,
    isScrollControlled: true,
    builder: (_) => UniversalSearchPickerSheet(
      title: 'Vincular objeto',
      onSelected: (obj) => Navigator.pop(context, obj),
    ),
  );
  if (selected == null) return;
  setState(() {
    _items[index].text += ' [[${selected.slug}]]';
  });
  _updateContent();
}
```

---

## P6 — Social Posts na Busca Global

### 6a — `SearchService` — incluir social posts

**`lib/services/search_service.dart`** — o serviço já recebe `List<ContentObject>` e o `SocialPost` é um `ContentObject`. O problema é que `SearchScreen` pode estar filtrando por tipo antes de chamar o serviço.

Verificar em `search_screen.dart` se `_onSearchChanged` passa `allObjects` completo (incluindo social_post) — se sim, os posts já chegam ao serviço. Se não, garantir que `allObjectsProvider` inclui `SocialPost` (já deve incluir).

**Ordenação especial para social posts** — no resultado da busca, quando `_selectedType == 'social_post'` ou quando o resultado inclui posts, ordenar por `updatedAt` desc:
```dart
// Em _onSearchChanged, após _searchService.search():
_results.sort((a, b) {
  // Posts sociais sempre por updatedAt desc
  if (a.type == 'social_post' && b.type == 'social_post') {
    final aTime = a.updatedAt;
    final bTime = b.updatedAt;
    return bTime.compareTo(aTime);
  }
  return 0; // manter ordem do searchService para outros
});
```

### 6b — Sub-filtros por plataforma e criador na SearchScreen

**`lib/ui/screens/search_screen.dart`** — adicionar ao estado:
```dart
SocialPlatform? _socialPlatformFilter;
String? _socialCreatorFilter;
```

Quando `_selectedType == 'social_post'`, exibir segunda linha de chips:
```dart
if (_selectedType == 'social_post') ...[
  const SizedBox(height: 8),
  SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      // Chips de plataforma
      ...[SocialPlatform.tiktok, SocialPlatform.instagram,
          SocialPlatform.youtube, SocialPlatform.other].map((p) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(p.name),
            selected: _socialPlatformFilter == p,
            onSelected: (_) => setState(() {
              _socialPlatformFilter = _socialPlatformFilter == p ? null : p;
              _onSearchChanged(_searchController.text, objects);
            }),
          ),
        ),
      ),
      // Chips de criador (dinâmicos dos resultados)
      ..._uniqueCreators(_results).map((handle) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text('@$handle'),
            selected: _socialCreatorFilter == handle,
            onSelected: (_) => setState(() {
              _socialCreatorFilter = _socialCreatorFilter == handle ? null : handle;
              _onSearchChanged(_searchController.text, objects);
            }),
          ),
        ),
      ),
    ]),
  ),
],
```

Aplicar filtros adicionais no `_onSearchChanged`:
```dart
if (_socialPlatformFilter != null) {
  _results = _results.whereType<SocialPost>()
      .where((p) => p.platform == _socialPlatformFilter)
      .cast<ContentObject>().toList();
}
if (_socialCreatorFilter != null) {
  _results = _results.whereType<SocialPost>()
      .where((p) => p.authorHandle == _socialCreatorFilter)
      .cast<ContentObject>().toList();
}
```

Helper:
```dart
List<String> _uniqueCreators(List<ContentObject> results) {
  return results.whereType<SocialPost>()
      .map((p) => p.authorHandle)
      .whereType<String>()
      .toSet().toList();
}
```

### 6c — Aba Social no `UniversalSearchPickerSheet`

**`lib/ui/widgets/universal_search_picker.dart`** — já existe chip `'social_post'` com label `'Posts'`. Garantir que:

1. Posts aparecem nos resultados (já devem, pois `allObjectsProvider` inclui social posts)
2. Quando filtro `'social_post'` ativo, ordenar por `updatedAt` desc:
```dart
// Após filtrar por tipo, antes de aplicar query:
if (_selectedFilter == 'social_post') {
  filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
```
3. No `ListTile` de social posts, mostrar plataforma e handle:
```dart
subtitle: Text(
  obj is SocialPost
      ? '${obj.platform.name.toUpperCase()}${obj.authorHandle != null ? " · @${obj.authorHandle}" : ""}'
      : _getTypeLabel(obj).toUpperCase(),
  style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1),
),
```

---

## P7 — Resource: Vincular e Criar Objeto

### Problema confirmado
`SocialPostDetail._buildLinkedObjectsSection` tem `_pickLinkedObject(post)` que funciona (usa `UniversalSearchPickerSheet`). Mas em `UniversalDetailView` para Resource, o `onObjectSelected` callback não persiste.

### Correção em `UniversalDetailView`

**`lib/ui/screens/universal_detail_view.dart`** — encontrar onde `_pickLinkedObject` é chamado para Resource e corrigir o callback:

```dart
Future<void> _addLinkedObject(BuildContext context, WidgetRef ref) async {
  final selected = await showModalBottomSheet<ContentObject>(
    context: context,
    isScrollControlled: true,
    builder: (_) => UniversalSearchPickerSheet(
      title: 'Vincular objeto',
      onSelected: (obj) => Navigator.pop(context, obj),
      showClear: false,
    ),
  );
  if (selected == null || !mounted) return;

  // Persiste o link em socialRefs (formato [[slug]])
  final currentRefs = List<String>.from(_getSocialRefs(object));
  final newRef = '[[${selected.slug}]]';
  if (currentRefs.contains(newRef)) return; // já vinculado

  currentRefs.add(newRef);
  final updated = _copyWithSocialRefs(object, currentRefs);
  await ref.read(vaultProvider.notifier).updateObject(updated);
  setState(() {});
}

// Helper para obter socialRefs de qualquer tipo de objeto:
List<String> _getSocialRefs(ContentObject obj) {
  if (obj is Resource) return obj.socialRefs ?? [];
  if (obj is Note) return obj.socialRefs;
  if (obj is Goal) return obj.socialRefs ?? [];
  if (obj is Task) return obj.socialRefs ?? [];
  // ... demais tipos
  return [];
}

// Helper para copiar com novos socialRefs:
ContentObject _copyWithSocialRefs(ContentObject obj, List<String> refs) {
  if (obj is Resource) return obj.copyWith(socialRefs: refs);
  if (obj is Note) return obj.copyWith(socialRefs: refs);
  if (obj is Goal) return obj.copyWith(socialRefs: refs);
  if (obj is Task) return obj.copyWith(socialRefs: refs);
  return obj;
}
```

Verificar se `Resource`, `Goal`, `Task` têm campo `socialRefs: List<String>`. Se algum não tiver, adicionar ao modelo:
```dart
// Em resource_model.dart, goal_model.dart, task_model.dart se ausente:
List<String> socialRefs;
// Com default [] no construtor, e serialização no toMarkdown/fromMarkdown
```

### Criar objeto inline no picker

`UniversalSearchPickerSheet` já tem o botão "Criar Novo Objeto" quando há texto digitado. Garantir que ao criar e voltar, o objeto novo é retornado como selecionado:

```dart
// Em _showCreateTypeChoiceDialog, após criar o objeto:
final newObject = await _createObjectOfType(context, type, initialTitle);
if (newObject != null) {
  widget.onSelected(newObject); // retorna para o caller
  Navigator.pop(context);       // fecha o sheet
}
```

---

## P8 — Widget Nativo Note/Checklist (Android)

### O que existe hoje
`WidgetService` tem `updateNote()` que salva JSON em `citrine_note_$widgetId` e chama `_update('CitrineNoteWidgetProvider')`. O widget Android existe mas sem interatividade (sem checkbox, sem adicionar item).

### 8a — Novo campo `isChecklist` em `Note`

**`lib/models/note_model.dart`**:
```dart
class Note extends ContentObject {
  // ... campos existentes ...
  bool isChecklist;  // NOVO

  Note({
    // ...
    this.isChecklist = false,
  });
}
```

Serialização:
```dart
// toMarkdown:
if (isChecklist) frontmatter['is_checklist'] = true;

// fromMarkdown:
note.isChecklist = frontmatter['is_checklist'] == true;
```

`copyWith`:
```dart
bool? isChecklist,
// ...
isChecklist: isChecklist ?? this.isChecklist,
```

### 8b — Formato de dados do checklist

Quando `isChecklist == true`, `note.body` armazena JSON no formato:
```json
{
  "items": [
    {"id": "uuid1", "text": "Maçã", "checked": false, "order": 0},
    {"id": "uuid2", "text": "Leite", "checked": true,  "order": 1}
  ]
}
```

### 8c — UI de checklist no app

**Novo widget: `lib/ui/widgets/checklist_view.dart`**:

```dart
class ChecklistView extends ConsumerWidget {
  final Note note;
  final bool editable;

  const ChecklistView({super.key, required this.note, this.editable = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _parseItems(note.body);

    return Column(
      children: [
        // Lista de itens
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorder: (old, nw) => _onReorder(items, old, nw, note, ref),
          itemBuilder: (ctx, i) => _buildItem(ctx, ref, items[i], note),
        ),
        // Campo de adicionar item
        if (editable) _buildAddItemField(context, ref, note),
      ],
    );
  }

  Widget _buildItem(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> item, Note note) {
    final checked = item['checked'] == true;
    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(item['id'], note, ref),
      child: ListTile(
        key: ValueKey(item['id']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Checkbox(
          value: checked,
          onChanged: (_) => _toggleItem(item['id'], note, ref),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item['text'] ?? '',
          style: TextStyle(
            fontSize: 15,
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked
                ? AppTheme.textMutedColor(ctx)
                : AppTheme.textPrimaryColor(ctx),
          ),
        ),
        trailing: ReorderableDragStartListener(
          index: 0, // será sobrescrito pelo ReorderableListView
          child: Icon(Icons.drag_handle_rounded, size: 18,
            color: AppTheme.textMutedColor(ctx)),
        ),
      ),
    );
  }

  Widget _buildAddItemField(BuildContext context, WidgetRef ref, Note note) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        const Icon(Icons.add_rounded, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Add item...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (text) {
            if (text.trim().isEmpty) return;
            _addItem(text.trim(), note, ref);
            ctrl.clear();
          },
        )),
      ]),
    );
  }

  // Helpers para manipular items:
  List<Map<String, dynamic>> _parseItems(String body) {
    try {
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    } catch (_) { return []; }
  }

  void _toggleItem(String id, Note note, WidgetRef ref) {
    final items = _parseItems(note.body);
    final idx = items.indexWhere((i) => i['id'] == id);
    if (idx < 0) return;
    items[idx] = {...items[idx], 'checked': !(items[idx]['checked'] == true)};
    _save(items, note, ref);
  }

  void _addItem(String text, Note note, WidgetRef ref) {
    final items = _parseItems(note.body);
    items.add({'id': const Uuid().v4(), 'text': text,
      'checked': false, 'order': items.length});
    _save(items, note, ref);
  }

  void _removeItem(String id, Note note, WidgetRef ref) {
    final items = _parseItems(note.body)..removeWhere((i) => i['id'] == id);
    _save(items, note, ref);
  }

  void _save(List<Map<String, dynamic>> items, Note note, WidgetRef ref) {
    final updated = note.copyWith(
      body: jsonEncode({'items': items}),
      updatedAt: DateTime.now(),
    );
    ref.read(vaultProvider.notifier).updateObject(updated);
    // Sincronizar widget nativo:
    WidgetService.updateChecklist(noteId: note.id, title: note.title, items: items);
  }
}
```

**No `UniversalDetailView`**, quando `object is Note && note.isChecklist`:
```dart
// Em _buildTypeSpecificContent para Note:
if ((object as Note).isChecklist)
  SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: ChecklistView(note: object as Note),
  ))
else
  // editor/viewer normal de nota
```

### 8d — `WidgetService.updateChecklist()`

**`lib/services/widget_service.dart`** — adicionar:
```dart
static const _checklistProvider = 'CitrineChecklistWidgetProvider';

static Future<void> updateChecklist({
  required String noteId,
  required String title,
  required List<Map<String, dynamic>> items,
}) async {
  try {
    await _saveJson('citrine_checklist', {
      'noteId': noteId,
      'title': title,
      'items': items,                          // [{id, text, checked, order}]
      'linkUri': 'citrine:///detail/$noteId',
      'addUri': 'citrine:///checklist/$noteId/add',
      'toggleUriBase': 'citrine:///checklist/$noteId/toggle/',
    });
    await _update(_checklistProvider);
  } catch (e) {
    debugPrint('[WidgetService] updateChecklist failed: $e');
  }
}
```

O widget Android (`CitrineChecklistWidgetProvider`) precisa ser criado/atualizado no lado nativo (Kotlin/Java) para:
- Exibir título da lista
- Listar itens com checkbox nativo
- Toggle de item via deeplink `citrine:///checklist/$noteId/toggle/$itemId`
- Botão "+" via deeplink `citrine:///checklist/$noteId/add`
- O app Flutter intercepta os deeplinks e chama `_toggleItem`/`_addItem` via `NotesProvider`

### 8e — Selecionar qual nota exibir no widget

**`WidgetService.saveChecklistWidgetConfig()`** — novo método:
```dart
static Future<void> saveChecklistWidgetConfig({
  required int widgetId,
  required String noteId,
  required String noteTitle,
}) async {
  await _saveJson('citrine_checklist_config_$widgetId', {
    'noteId': noteId,
    'title': noteTitle,
  });
}
```

**No app** — quando usuário long-press no widget Android e seleciona "Configure", o sistema chama uma Activity de configuração que abre o app numa tela de seleção de nota. Criar `ChecklistWidgetConfigScreen`:

```dart
class ChecklistWidgetConfigScreen extends ConsumerWidget {
  final int widgetId;
  const ChecklistWidgetConfigScreen({super.key, required this.widgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    // Mostrar todas as notas com isChecklist=true primeiro, depois as demais
    final checklists = notes.where((n) => n.isChecklist).toList();
    final others = notes.where((n) => !n.isChecklist).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select note for widget')),
      body: ListView(children: [
        if (checklists.isNotEmpty) ...[
          _sectionHeader('Checklists'),
          ...checklists.map((n) => _noteTile(context, ref, n)),
        ],
        _sectionHeader('Other notes'),
        ...others.map((n) => _noteTile(context, ref, n)),
      ]),
    );
  }

  Widget _noteTile(BuildContext context, WidgetRef ref, Note note) {
    return ListTile(
      leading: Text(note.isChecklist ? '✅' : '📝',
        style: const TextStyle(fontSize: 20)),
      title: Text(note.title),
      onTap: () async {
        await WidgetService.saveChecklistWidgetConfig(
          widgetId: widgetId,
          noteId: note.id,
          noteTitle: note.title,
        );
        // Sincronizar conteúdo atual da nota no widget:
        final items = _parseItems(note.body);
        await WidgetService.updateChecklist(
          noteId: note.id, title: note.title, items: items);
        Navigator.pop(context);
      },
    );
  }
}
```

### 8f — Criar nova nota como checklist

**`lib/ui/forms/create_note_form.dart`** — adicionar opção de tipo "Checklist" no seletor de subtipo:
```dart
// Adicionar ao seletor de tipo junto com Text/Outline/Collection:
_typeButton('Checklist', Icons.checklist_rounded, NoteSubtype.text,
  isChecklist: true),
```

Quando selecionado, o form cria uma `Note` com `subtype: text, isChecklist: true` e `body: '{"items":[]}'`.

---

## P9 — Hábito de Baixa Frequência

### 9a — Novos campos no modelo

**`lib/models/habit_model.dart`**:
```dart
class Habit extends ContentObject {
  // ... campos existentes ...
  int? frequencyDays;        // NOVO: meta de dias entre cada execução (ex: 30)
  bool isFlexibleFrequency;  // NOVO: true = não é hábito diário rígido
}
```

Construtor: `this.frequencyDays, this.isFlexibleFrequency = false`

`copyWith`:
```dart
int? frequencyDays,
bool? isFlexibleFrequency,
// ...
frequencyDays: frequencyDays ?? this.frequencyDays,
isFlexibleFrequency: isFlexibleFrequency ?? this.isFlexibleFrequency,
```

Serialização (`toMarkdown`/`fromMarkdown`):
```dart
// toMarkdown:
if (frequencyDays != null) frontmatter['frequency_days'] = frequencyDays;
if (isFlexibleFrequency) frontmatter['flexible_frequency'] = true;

// fromMarkdown:
habit.frequencyDays = int.tryParse(frontmatter['frequency_days']?.toString() ?? '');
habit.isFlexibleFrequency = frontmatter['flexible_frequency'] == true;
```

### 9b — Formulário: `CreateHabitForm`

**`lib/ui/forms/create_habit_form.dart`** — adicionar seção de frequência flexível.

Quando `priority == TaskPriority.low` OU quando o usuário ativa manualmente o toggle, mostrar:

```dart
SwitchListTile(
  title: const Text('Flexible frequency'),
  subtitle: const Text('No fixed daily schedule — just a target interval'),
  value: _isFlexibleFrequency,
  onChanged: (v) => setState(() {
    _isFlexibleFrequency = v;
    if (v) _schedulers.clear(); // limpa schedulers rígidos
  }),
),

if (_isFlexibleFrequency) ...[
  const SizedBox(height: 8),
  Row(children: [
    const Text('Target: every '),
    SizedBox(
      width: 64,
      child: TextField(
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(isDense: true),
        onChanged: (v) => setState(() => _frequencyDays = int.tryParse(v)),
      ),
    ),
    const Text(' days'),
  ]),
],
```

Ao salvar: `Habit(..., frequencyDays: _frequencyDays, isFlexibleFrequency: _isFlexibleFrequency)`

### 9c — UX na `HabitsScreen`: seção "Periodic"

**`lib/ui/screens/habits_screen.dart`** — na `_TodayView`, após a lista de hábitos normais, adicionar:

```dart
// Ao final do ListView, depois de ...habits.map(...):
Builder(builder: (context) {
  final periodicHabits = ref.watch(habitsProvider)
      .where((h) =>
        h.status == HabitStatus.active &&
        !h.archived &&
        h.isFlexibleFrequency &&
        h.frequencyDays != null)
      .toList();

  if (periodicHabits.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      // Separador com label
      Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('PERIODIC', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.08,
          color: AppTheme.textMutedColor(context))),
      ]),
      const SizedBox(height: 10),
      ...periodicHabits.map((h) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _PeriodicHabitCard(habit: h),
      )),
    ],
  );
}),
```

**Novo widget `_PeriodicHabitCard`**:

```dart
class _PeriodicHabitCard extends ConsumerWidget {
  final Habit habit;
  const _PeriodicHabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = habit.daysSinceLastCompletion;
    final freq = habit.frequencyDays!;
    final ratio = days < 0 ? 0.0 : (days / freq).clamp(0.0, 1.5);

    final color = ratio > 1.0
        ? AppColors.error
        : ratio > 0.75
            ? AppColors.warning
            : AppColors.habitGreen;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(habit.displayTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            // Botão agendar
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.calendar_today_rounded, size: 18, color: color),
              onPressed: () => _showScheduleSheet(context, ref),
            ),
            // Botão marcar feito
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(habitsProvider.notifier)
                    .toggleHabit(habit, DateTime.now());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: habit.isCompletedToday ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                ),
                child: habit.isCompletedToday
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // Meta e urgência
          Text(
            days < 0
                ? 'Never done · target: every ${freq}d'
                : 'Done ${days}d ago · target: every ${freq}d',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          // Barra de urgência
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      ),
    );
  }

  void _showScheduleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.calendar_month_rounded),
          title: const Text('Add to planner'),
          onTap: () {
            Navigator.pop(ctx);
            _pickDateForHabit(context, ref);
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer_rounded),
          title: const Text('Start Pomodoro now'),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PomodoroScreen()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Remind me in X days'),
          onTap: () {
            Navigator.pop(ctx);
            _setReminderDays(context, ref);
          },
        ),
      ]),
    ));
  }

  void _pickDateForHabit(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(
        Duration(days: habit.frequencyDays ?? 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    // Criar uma task ou reminder para esse dia com o título do hábito:
    final reminder = Reminder(
      title: habit.displayTitle,
      time: DateTime(picked.year, picked.month, picked.day, 9, 0),
    );
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set for ${DateFormat('d MMM').format(picked)}')));
    }
  }

  void _setReminderDays(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(
      text: habit.frequencyDays?.toString() ?? '7');
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remind me in how many days?'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffix: Text('days')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Set')),
        ],
      ),
    );
    if (days == null || !context.mounted) return;
    final reminderDate = DateTime.now().add(Duration(days: days));
    final reminder = Reminder(
      title: habit.displayTitle,
      time: DateTime(reminderDate.year, reminderDate.month,
        reminderDate.day, 9, 0),
    );
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder in $days days')));
    }
  }
}
```

---

## P10 — Vincular Livros e Lugares ao Post TikTok

### 10a — Novo modelo `PlaceRef`

**Novo arquivo: `lib/models/place_ref.dart`**:
```dart
class PlaceRef {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? googlePlaceId;
  final String? notes;

  const PlaceRef({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.googlePlaceId,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name,
    if (address != null) 'address': address,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (googlePlaceId != null) 'place_id': googlePlaceId,
    if (notes != null) 'notes': notes,
  };

  factory PlaceRef.fromMap(Map<String, dynamic> m) => PlaceRef(
    id: m['id'] ?? const Uuid().v4(),
    name: m['name'] ?? '',
    address: m['address'],
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    googlePlaceId: m['place_id'],
    notes: m['notes'],
  );
}
```

### 10b — Novo campo `places` em `SocialPost`

**`lib/models/social_post.dart`**:
```dart
List<PlaceRef> places;  // NOVO

// Construtor: List<PlaceRef>? places → this.places = places ?? []

// toMarkdown:
if (places.isNotEmpty)
  frontmatter['places'] = places.map((p) => p.toMap()).toList();

// fromMarkdown:
if (frontmatter['places'] is List) {
  post.places = (frontmatter['places'] as List)
      .map((p) => PlaceRef.fromMap(p as Map<String, dynamic>))
      .toList();
}

// copyWith:
List<PlaceRef>? places,
places: places ?? List.from(this.places),
```

### 10c — Seção de lugares no `SocialPostDetail`

**`lib/ui/screens/social_post_detail.dart`** — adicionar seção após `_buildLinkedObjectsSection`:

```dart
_buildPlacesSection(post),
```

```dart
Widget _buildPlacesSection(SocialPost post) {
  return _section(
    title: '📍 Places',
    trailing: TextButton.icon(
      onPressed: () => _addPlace(post),
      icon: const Icon(Icons.add_location_rounded, size: 18),
      label: const Text('Add'),
    ),
    child: post.places.isEmpty
        ? const Text('No places added',
            style: TextStyle(color: AppColors.textMuted))
        : Column(
            children: post.places.map((place) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_rounded, color: AppColors.primary),
              title: Text(place.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
              subtitle: place.address != null
                  ? Text(place.address!, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11))
                  : null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (place.lat != null && place.lng != null)
                  IconButton(
                    icon: const Icon(Icons.map_rounded, size: 18),
                    onPressed: () => _openInMaps(place),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18,
                    color: AppColors.error),
                  onPressed: () => _removePlace(post, place.id),
                ),
              ]),
            )).toList(),
          ),
  );
}

Future<void> _addPlace(SocialPost post) async {
  // Opção 1: campo de texto simples (sempre disponível)
  // Opção 2: busca no Google Places (se disponível)
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add place'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Name (required)')),
        const SizedBox(height: 8),
        TextField(controller: addressCtrl,
          decoration: const InputDecoration(hintText: 'Address (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Add')),
      ],
    ),
  );

  if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

  final newPlace = PlaceRef(
    id: const Uuid().v4(),
    name: nameCtrl.text.trim(),
    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
  );
  final updated = post.copyWith(
    places: [...post.places, newPlace]);
  ref.read(socialPostsProvider.notifier).updatePost(updated);
}

void _removePlace(SocialPost post, String placeId) {
  final updated = post.copyWith(
    places: post.places.where((p) => p.id != placeId).toList());
  ref.read(socialPostsProvider.notifier).updatePost(updated);
}

void _openInMaps(PlaceRef place) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${place.lat},${place.lng}');
  if (await canLaunchUrl(uri)) launchUrl(uri);
}
```

### 10d — Criar resource de livro rapidamente

No `_buildLinkedObjectsSection` do `SocialPostDetail`, ao lado do botão "Vincular", adicionar botão específico para criar resource rápido:

```dart
// No trailing do _section de objetos vinculados:
Row(mainAxisSize: MainAxisSize.min, children: [
  TextButton.icon(
    onPressed: () => _quickCreateResource(post),
    icon: const Icon(Icons.book_outlined, size: 18),
    label: const Text('+ Book'),
  ),
  TextButton.icon(
    onPressed: () => _pickLinkedObject(post),
    icon: const Icon(Icons.add_link_rounded, size: 18),
    label: const Text('Link'),
  ),
]),
```

```dart
Future<void> _quickCreateResource(SocialPost post) async {
  final ctrl = TextEditingController();
  final authorCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add book/resource'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Title (required)')),
        const SizedBox(height: 8),
        TextField(controller: authorCtrl,
          decoration: const InputDecoration(hintText: 'Author (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Create')),
      ],
    ),
  );

  if (confirmed != true || ctrl.text.trim().isEmpty || !mounted) return;

  final resource = Resource(
    title: ctrl.text.trim(),
    resourceType: 'Book',
    author: authorCtrl.text.trim().isEmpty ? null : authorCtrl.text.trim(),
    status: ResourceStatus.toConsume,
  );
  await ref.read(resourcesProvider.notifier).addResource(resource);

  // Vincular ao post automaticamente:
  final newRef = '[[${resource.slug}]]';
  final updated = post.copyWith(
    socialRefs: [...post.socialRefs, newRef]);
  ref.read(socialPostsProvider.notifier).updatePost(updated);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${resource.title}" created and linked')));
  }
}
```

---

## P11 — Eisenhower Matrix (Etapa 1)

### 11a — Modelos

**Adicionar ao `lib/models/saved_filter.dart`** (arquivo que precisa ser criado, ver spec do sistema de filtros):

```dart
enum ViewMode { grid, list, grouped, matrix }  // adicionar 'matrix'

class MatrixConfig {
  final String axisXProperty;   // propriedade para colunas, ex: 'priority'
  final List<String> axisXValues; // 2 valores = 2 colunas, ex: ['high','low']
  final String axisXLabels;     // ex: 'Important' / 'Not important'
  final String axisYProperty;   // propriedade para linhas, ex: 'tags'
  final List<String> axisYValues; // 2 valores = 2 linhas
  final String axisYLabels;
  final String title;

  const MatrixConfig({
    required this.axisXProperty,
    required this.axisXValues,
    this.axisXLabels = '',
    required this.axisYProperty,
    required this.axisYValues,
    this.axisYLabels = '',
    required this.title,
  });

  Map<String, dynamic> toJson() => {
    'axisXProperty': axisXProperty,
    'axisXValues': axisXValues,
    'axisXLabels': axisXLabels,
    'axisYProperty': axisYProperty,
    'axisYValues': axisYValues,
    'axisYLabels': axisYLabels,
    'title': title,
  };

  factory MatrixConfig.fromJson(Map<String, dynamic> j) => MatrixConfig(
    axisXProperty: j['axisXProperty'] ?? 'priority',
    axisXValues: List<String>.from(j['axisXValues'] ?? []),
    axisXLabels: j['axisXLabels'] ?? '',
    axisYProperty: j['axisYProperty'] ?? 'tags',
    axisYValues: List<String>.from(j['axisYValues'] ?? []),
    axisYLabels: j['axisYLabels'] ?? '',
    title: j['title'] ?? 'Matrix',
  );

  // Preset de Eisenhower clássico:
  static MatrixConfig get eisenhower => const MatrixConfig(
    title: 'Eisenhower',
    axisXProperty: 'priority',
    axisXValues: ['high', 'low'],
    axisXLabels: 'Important',
    axisYProperty: 'tags',
    axisYValues: ['urgent', 'not-urgent'],
    axisYLabels: 'Urgent',
  );
}
```

Adicionar `MatrixConfig? matrixConfig` em `SavedFilter`.

### 11b — `MatrixScreen`

**Novo arquivo: `lib/ui/screens/matrix_screen.dart`**:

```dart
class MatrixScreen extends ConsumerStatefulWidget {
  final SavedFilter filter;
  const MatrixScreen({super.key, required this.filter});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksProvider);
    final cfg = widget.filter.matrixConfig!;

    // Aplicar filtros do SavedFilter:
    final filtered = widget.filter.apply(allTasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(cfg.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {/* abrir configuração da matrix */},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // Header eixo X
          Row(children: [
            const SizedBox(width: 32),
            Expanded(child: Row(children: cfg.axisXValues.map((v) =>
              Expanded(child: Center(child: Text(v,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted))))).toList())),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: Row(children: [
              // Header eixo Y (rotacionado)
              SizedBox(width: 32, child: Column(children: cfg.axisYValues.map((v) =>
                Expanded(child: Center(child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(v, style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                )))).toList())),
              // 4 quadrantes
              Expanded(
                child: Column(children: cfg.axisYValues.map((yVal) =>
                  Expanded(child: Row(children: cfg.axisXValues.map((xVal) =>
                    Expanded(child: _buildQuadrant(context, ref, filtered, cfg, xVal, yVal)),
                  ).toList())),
                ).toList()),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildQuadrant(BuildContext context, WidgetRef ref,
      List<Task> tasks, MatrixConfig cfg, String xVal, String yVal) {

    // Filtrar tasks para este quadrante:
    final items = tasks.where((t) {
      final xMatch = _matchesProp(t, cfg.axisXProperty, xVal);
      final yMatch = _matchesProp(t, cfg.axisYProperty, yVal);
      return xMatch && yMatch;
    }).toList();

    // Cor do quadrante baseada na posição:
    final isTopLeft = cfg.axisXValues.indexOf(xVal) == 0 &&
        cfg.axisYValues.indexOf(yVal) == 0;
    final quadrantColor = isTopLeft
        ? AppColors.error.withValues(alpha: 0.05)
        : AppColors.surfaceVariant.withValues(alpha: 0.3);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) =>
          _moveToQuadrant(details.data, xVal, yVal, cfg, ref),
      builder: (ctx, candidates, _) => Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.08)
              : quadrantColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: [
          // Badge de contagem:
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('${items.length}',
                style: const TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
          ),
          // Lista de items:
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            children: items.map((t) => _buildMatrixCard(t, ref)).toList(),
          )),
        ]),
      ),
    );
  }

  Widget _buildMatrixCard(Task task, WidgetRef ref) {
    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(task.title, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _cardContent(task, ref)),
      child: _cardContent(task, ref),
    );
  }

  Widget _cardContent(Task task, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => UniversalDetailView(object: task))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardFillColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          // Checkbox inline:
          SizedBox(width: 20, height: 20,
            child: Checkbox(
              value: task.stage == TaskStage.finalized,
              onChanged: (_) => ref.read(tasksProvider.notifier)
                  .updateTask(task.copyWith(stage: TaskStage.finalized)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(task.title, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              decoration: task.stage == TaskStage.finalized
                  ? TextDecoration.lineThrough : null,
            ))),
        ]),
      ),
    );
  }

  bool _matchesProp(Task task, String property, String value) {
    return switch (property) {
      'priority' => task.priority.name == value,
      'tags' => task.tags.contains(value),
      'status' || 'stage' => task.stage.name == value,
      _ => false,
    };
  }

  void _moveToQuadrant(Task task, String xVal, String yVal,
      MatrixConfig cfg, WidgetRef ref) {
    Task updated = task;
    // Atualizar propriedade X:
    if (cfg.axisXProperty == 'priority') {
      updated = updated.copyWith(
        priority: TaskPriority.values.firstWhere((p) => p.name == xVal,
          orElse: () => task.priority));
    }
    // Atualizar propriedade Y (ex: tags):
    if (cfg.axisYProperty == 'tags') {
      // Remove os valores de eixo Y que existiam, adiciona o novo:
      final cleanTags = task.tags
          .where((t) => !cfg.axisYValues.contains(t))
          .toList();
      updated = updated.copyWith(tags: [...cleanTags, yVal]);
    }
    ref.read(tasksProvider.notifier).updateTask(updated);
  }
}
```

### 11c — Acessar a Matrix

No `FilterSortSheet` (quando implementado), quando `viewMode == ViewMode.matrix`, o botão "Apply" navega para `MatrixScreen(filter: draft)`.

Como atalho antes disso, adicionar em qualquer tela de tasks um botão temporário:
```dart
IconButton(
  icon: const Icon(Icons.grid_4x4_rounded),
  tooltip: 'Eisenhower Matrix',
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => MatrixScreen(
      filter: SavedFilter(
        id: 'eisenhower',
        name: 'Eisenhower',
        targetType: 'task',
        matrixConfig: MatrixConfig.eisenhower,
      ),
    ),
  )),
),
```

---

## P12 — Unificar UI de Vincular Objetos

### Referência visual: como está hoje no SocialPostDetail

O `SocialPostDetail._buildLinkedObjectsSection` é a referência de UX desejada:
- Título da seção "Objetos vinculados"
- Botão "Vincular" com ícone `add_link_rounded` no trailing
- Itens agrupados por `displayType` com label uppercase muted
- Cada item como `InputChip` com título, onPressed navega, onDeleted remove

### Padrão unificado para todos os objetos

**Criar widget reutilizável: `lib/ui/widgets/linked_objects_section.dart`**:

```dart
class LinkedObjectsSection extends ConsumerWidget {
  final ContentObject owner;           // objeto dono dos links
  final List<String> socialRefs;       // [[slug]] refs atuais
  final Future<void> Function(ContentObject selected) onAdd;
  final Future<void> Function(String slug) onRemove;
  final String? addButtonLabel;        // default: 'Link'

  const LinkedObjectsSection({
    super.key,
    required this.owner,
    required this.socialRefs,
    required this.onAdd,
    required this.onRemove,
    this.addButtonLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final linked = _resolve(allObjects, socialRefs);
    final grouped = <String, List<ContentObject>>{};
    for (final obj in linked) {
      grouped.putIfAbsent(obj.displayType, () => []).add(obj);
    }

    return _Section(
      title: 'Linked objects',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton.icon(
          onPressed: () => _pickObject(context),
          icon: const Icon(Icons.add_link_rounded, size: 18),
          label: Text(addButtonLabel ?? 'Link'),
        ),
      ]),
      child: linked.isEmpty
          ? const Text('No linked objects',
              style: TextStyle(color: AppColors.textMuted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                      style: const TextStyle(color: AppColors.textMuted,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8,
                      children: entry.value.map((obj) => InputChip(
                        label: Text(obj.title, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                            UniversalDetailView(object: obj))),
                        onDeleted: () => onRemove('[[${obj.slug}]]'),
                      )).toList(),
                    ),
                  ],
                ),
              )).toList(),
            ),
    );
  }

  List<ContentObject> _resolve(List<ContentObject> all, List<String> refs) {
    final slugs = refs.map((r) =>
      r.replaceAll('[[', '').replaceAll(']]', '').trim()).toSet();
    return all.where((o) => slugs.contains(o.slug)).toList();
  }

  void _pickObject(BuildContext context) async {
    final selected = await showModalBottomSheet<ContentObject>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Link object',
        onSelected: (obj) => Navigator.pop(context, obj),
        showClear: false,
      ),
    );
    if (selected != null) await onAdd(selected);
  }
}
```

**Substituir em todos os arquivos que têm seção de links**:

| Arquivo | Substituir |
|---------|-----------|
| `social_post_detail.dart` | `_buildLinkedObjectsSection` → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Resource) | seção de links → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Note) | `socialRefs` → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Goal) | social refs → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Task) | social refs → usa `LinkedObjectsSection` |
| `universal_detail_view.dart` (Habit) | social refs → usa `LinkedObjectsSection` |

**Helper genérico para salvar socialRef em qualquer objeto**:

```dart
// Em um arquivo utilitário lib/ui/utils/social_ref_utils.dart:
Future<void> addSocialRef(
    ContentObject obj, ContentObject target, WidgetRef ref) async {
  final slug = '[[${target.slug}]]';
  final current = _getRefs(obj);
  if (current.contains(slug)) return;
  final updated = _withRefs(obj, [...current, slug]);
  await ref.read(vaultProvider.notifier).updateObject(updated);
}

Future<void> removeSocialRef(
    ContentObject obj, String slugRef, WidgetRef ref) async {
  final updated = _withRefs(obj,
    _getRefs(obj).where((r) => r != slugRef).toList());
  await ref.read(vaultProvider.notifier).updateObject(updated);
}

List<String> _getRefs(ContentObject obj) {
  if (obj is SocialPost) return obj.socialRefs;
  if (obj is Note)       return obj.socialRefs;
  if (obj is Resource)   return obj.socialRefs ?? [];
  if (obj is Goal)       return obj.socialRefs ?? [];
  if (obj is Task)       return obj.socialRefs ?? [];
  if (obj is Habit)      return obj.socialRefs ?? [];
  return [];
}

ContentObject _withRefs(ContentObject obj, List<String> refs) {
  if (obj is SocialPost) return obj.copyWith(socialRefs: refs);
  if (obj is Note)       return obj.copyWith(socialRefs: refs);
  if (obj is Resource)   return obj.copyWith(socialRefs: refs);
  if (obj is Goal)       return obj.copyWith(socialRefs: refs);
  if (obj is Task)       return obj.copyWith(socialRefs: refs);
  if (obj is Habit)      return obj.copyWith(socialRefs: refs);
  return obj;
}
```

**Uso em qualquer detalhe**:
```dart
LinkedObjectsSection(
  owner: object,
  socialRefs: _getRefs(object),
  onAdd: (selected) => addSocialRef(object, selected, ref),
  onRemove: (slug) => removeSocialRef(object, slug, ref),
),
```

---

## Checklist de arquivos a criar/modificar

### Novos arquivos
- [ ] `lib/ui/utils/layout_utils.dart`
- [ ] `lib/ui/utils/social_ref_utils.dart`
- [ ] `lib/ui/widgets/linked_objects_section.dart`
- [ ] `lib/ui/widgets/checklist_view.dart`
- [ ] `lib/ui/screens/matrix_screen.dart`
- [ ] `lib/ui/screens/checklist_widget_config_screen.dart`
- [ ] `lib/models/place_ref.dart`

### Modificar modelos
- [ ] `lib/models/note_model.dart` — `isChecklist: bool`
- [ ] `lib/models/habit_model.dart` — `frequencyDays: int?`, `isFlexibleFrequency: bool`
- [ ] `lib/models/social_post.dart` — `places: List<PlaceRef>`
- [ ] `lib/models/resource_model.dart` — verificar/adicionar `socialRefs: List<String>`
- [ ] `lib/models/goal_model.dart` — verificar/adicionar `socialRefs: List<String>`
- [ ] `lib/models/task_model.dart` — verificar/adicionar `socialRefs: List<String>`
- [ ] `lib/models/habit_model.dart` — verificar/adicionar `socialRefs: List<String>`

### Modificar providers
- [ ] `lib/providers/settings_provider.dart` — `ideaStrategy`, `ideaTag`, `ideaFolder`, `setIdeaStrategy()`

### Modificar serviços
- [ ] `lib/services/obsidian_service.dart` — encoding utf8 em toda leitura/escrita
- [ ] `lib/services/google_drive_sync_service.dart` — encoding utf8
- [ ] `lib/services/backup_service.dart` — encoding utf8
- [ ] `lib/services/widget_service.dart` — `updateChecklist()`, `saveChecklistWidgetConfig()`

### Modificar UI
- [ ] `lib/ui/screens/notes_screen.dart` — `_buildNoteInlineEditor` com cases para outline/collection
- [ ] `lib/ui/screens/universal_detail_view.dart` — toggle view/edit para Note, `_addLinkedObject` funcional, usar `LinkedObjectsSection` em todos os tipos
- [ ] `lib/ui/screens/social_post_detail.dart` — `_buildPlacesSection`, `_quickCreateResource`, usar `LinkedObjectsSection`
- [ ] `lib/ui/screens/search_screen.dart` — sub-filtros social, ordenação por updatedAt, buscas recentes persistidas
- [ ] `lib/ui/screens/habits_screen.dart` — semana começa segunda, `_PeriodicHabitCard`, seção Periodic no TodayView
- [ ] `lib/ui/screens/goals_screen.dart` — fix crash Color(), fix Flexible no deadline
- [ ] `lib/ui/widgets/outline_editor.dart` — wiki-links clicáveis, botão inserir link
- [ ] `lib/ui/widgets/collection_view.dart` — renderização por tipo (checkbox interativo)
- [ ] `lib/ui/widgets/universal_search_picker.dart` — ordenação por updatedAt para social, exibir plataforma/handle
- [ ] `lib/ui/widgets/create_menu_sheet.dart` — botão "💡 Idea" na aba Capture
- [ ] `lib/ui/forms/create_note_form.dart` — params `initialTags`, `initialFolder`, `linkedObject`, `autofocus`, tipo Checklist
- [ ] `lib/ui/forms/create_habit_form.dart` — toggle frequência flexível, campo `frequencyDays`
- [ ] Todos os `.dart` com strings bugadas (Ã§ etc) — corrigir encoding