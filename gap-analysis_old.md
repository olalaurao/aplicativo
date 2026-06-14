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

# 2026-06-07 16H 
 Gap Analysis Citrine × Guidelines V3 — Baseado no Código Real
> Análise feita com base no código Dart lido diretamente: `automation_service.dart`, `markdown_parser.dart`, `vault_provider.dart`, `widget_sync_provider.dart`, `widget_service.dart`, `dataview_generator.dart`, `obsidian_service.dart`, `triple_check_sheet.dart`, `steering_sheet.dart`, `import_vault_screen.dart`, `scheduler_page.dart`, `social_screen.dart`.
>
> **Legenda:** ✅ Implementado e confirmado no código · ⚠️ Parcial ou com ressalva real · ❌ Ausente ou stub



### ❌ Ausências confirmadas no código

| Item | Por quê está ausente |
|---|---|
| **Card PMN ao navegar por `referenced_dates`** | `AllObjectsNotifier` não indexa PMNs por `referenced_dates`. Arquivos `daily/YYYY-MM-WNN.md` são parseados como daily notes comuns (pelo padrão de data no nome), não como PMN com lookup por datas referenciadas |
| **Badge ⚠ de task parada há 7+ dias** | Nenhuma lógica em nenhum arquivo calcula "dias no mesmo stage sem progresso". O `TripleCheckBadge` existe como widget mas não há código que o exiba automaticamente |
| **Energy Map auto-gerado** | Nenhum código lê Field Notes com `category: energy` e gera sugestão de blocos de energia |
| **Lookup de `referenced_dates` do PMN** | PMN tem o campo no modelo mas não há indexação reversa para mostrar card ao navegar para as datas |
| **`pushSessionToCalendar` com tipo correto** | Ainda aceita `Task` em vez de `Session` conforme `correcoes.md` — não foi possível confirmar correção no código lido |
| **Múltiplos calendários Google** | `fetchEvents` só busca 'primary' |
| **Auto-archive de inbox após 30 dias com badge na nav** | O auto-archive existe no código mas o badge só conta itens ativos — sem distinção de itens "vencidos" |
| **Dataview queries compatíveis com `mood::` como WikiLink nas daily notes** | `mood-index.md` usa `WHERE mood` mas as daily notes armazenam mood no frontmatter como string simples (`mood_label: "Calma"`), não como WikiLink. Inconsistência entre formato Dataview e formato real |

### ⚠️ Parcialmente implementado

| Item | O que falta especificamente |
|---|---|
| **PMN (`entry_type: pmn`)** | Modelo existe, form existe (`create_pmn_form.dart`). Mas o arquivo é salvo como qualquer objeto — não em `daily/YYYY-MM-WNN.md` com a lógica de mês canônico de `date_range_start` |
| **`automation_service.dart`** | Não foi possível ler o arquivo completo nesta sessão — só o fim do `widget_service.dart` chegou. `executeHabitActions` e `executeHabitSlotActions` estão sendo chamados no vault_provider, mas o conteúdo real das ações não foi confirmado |
| **Combined Analysis — emoji como marcador no gráfico** | `citrine_chart.dart` existe mas não foi lido. A spec pede emoji do mood como marcador visual nos pontos — feature muito específica |
| **Scheduler: `unreachable_switch_default`** | `scheduler_picker.dart` ainda tem cases não cobertos (identificado no analyze_output anterior) |
| **Purga de `_conflicts/` após 30 dias** | `_purgeOldDeletedFiles()` só varre `_deleted/`, não `_conflicts/` |
| **Backup ZIP periódico em `_backups/`** | `backup_service.dart` existe mas não foi lido — conteúdo desconhecido |
| **Widgets nativos do OS (home screen/lock screen)** | `widget_service.dart` usa `home_widget` que **é** um package real para widgets nativos — mas o código Kotlin/Swift complementar (AppWidgetProvider, etc.) não foi confirmado. A integração Flutter existe; a parte nativa precisa de verificação |
| **Social Post: `social_refs` linkando a objetos** | Campo existe no modelo e UI implementada em `_associateObject()`, mas persiste como array de WikiLink strings — sem UI de visualização dos objetos associados na detail view |

---

## PARTE 4 — CORREÇÕES DAS ANÁLISES ANTERIORES

As versões V1 e V2 deste documento tinham erros significativos que o código real contradiz:

| Afirmação anterior (incorreta) | Realidade confirmada no código |
|---|---|
| "`_dateRegex` e `_journalTimeRegex` não usados — parsing de timestamp quebrado" | Esses campos não existem mais. O parser atual usa regex inline em `parseJournalEntries()` que funciona corretamente |
| "Body de notas não está sendo salvo (`_bodyController` não usado)" | O `rich_text_editor.dart` existe como widget separado — o controller é gerenciado internamente pelo widget, não pelo form pai |
| "Time Block de sessions não persiste (`_timeSlot` não usado)" | Não foi possível confirmar nesta leitura — `create_session_form.dart` não foi lido |
| "Sistema de Actions nunca executa" | `AutomationService.executeHabitActions()` e `executeHabitSlotActions()` são chamados explicitamente no `toggleHabit()` |
| "Purga de `_deleted/` não existe" | `_purgeOldDeletedFiles()` existe e é chamado no `build()` do VaultNotifier |
| "Social Post não tem tela" | `SocialScreen` completamente implementada com grid/timeline, multi-select, coleções, filtros por plataforma, auto-watch por visibilidade |
| "Import de vault Obsidian não existe" | `ImportVaultScreen` com scan prévio, validação de permissão e importação implementados |
| "Scheduler Page não existe" | `SchedulerPage` implementada com lista de agendados e previsão por Day Theme |
| "Dataview não é gerado" | `DataviewGenerator` gera 6 índices + blocks por tracker/analysis |
| "`widget_service.dart` são só stubs" | Usa `home_widget` real com múltiplos payloads estruturados |
| "Triple Check não tem botões de ação" | Implementado com Reformular, Arquivar, Adiar, Criar subtarefas, etc. |
| "Steering Sheet não persiste" | `updateObject(updatedHabit)` chamado com todos os campos corretos |

---

## RESUMO EXECUTIVO REAL

O app está **substancialmente mais completo** do que as análises anteriores indicavam. A maioria das features críticas existe no código.

### O que genuinamente falta (lista curta e honesta)

1. **PMN com lógica de `referenced_dates`** — o card PMN não aparece ao navegar para datas referenciadas
2. **Badge automático de task parada 7+ dias** — TripleCheckBadge existe mas não é exibido automaticamente
3. **Energy Map** — não existe em nenhum arquivo
4. **Emoji como marcador de mood nos gráficos** — não confirmado no `citrine_chart.dart`
5. **Purga de `_conflicts/` após 30 dias** — `_purgeOldDeletedFiles()` só cobre `_deleted/`
6. **Múltiplos calendários Google**
7. **Parte nativa dos widgets (Kotlin/Swift)** — a parte Flutter existe, a nativa não confirmada

---

## PROGRESSO DE IMPLEMENTAÇÃO (sessão 2026-06-07)

| Item | Status | Arquivo(s) alterado(s) |
|---|---|---|
| Purga de `_conflicts/` após 30 dias | ✅ Feito | `vault_provider.dart` |
| Backup ZIP periódico em `_backups/` | ✅ Feito | `vault_provider.dart` |
| `mood` como inline WikiLink (`mood:: [[slug]]`) | ✅ Feito | `markdown_parser.dart`, `journal_entry.dart` |
| Badge automático task parada 7+ dias (`needsTripleCheckBadge`) | ✅ Feito | `task_model.dart` |
| Parser PMN + `referenced_dates` | ✅ Feito | `journal_entry.dart` |
| `fetchEvents` de múltiplos calendários visíveis | ✅ Feito | `google_calendar_service.dart` |
| Auto-archive de inbox após 30 dias | ✅ Feito | `vault_provider.dart` |
| `unreachable_switch_default` no scheduler_picker | ✅ Feito | `scheduler_picker.dart` |
| `TripleCheckBadge` exibido automaticamente na UI | ✅ Feito | `organizer_tasks_widget.dart`, `planner_screen.dart` |
| `social_refs` renderizados na detail view e com indicador visual | ✅ Feito | `universal_detail_view.dart`, `social_screen.dart`, `social_post_grid_card.dart` |
| Emoji de mood como marcador visual no `citrine_chart.dart` | ✅ Feito | `citrine_chart.dart`, `combined_analysis_screen.dart` |
| `energy_map.dart` — leitura de Field Notes `category: energy` | ✅ Feito | `energy_map.dart`, `dashboard_provider.dart`, `home_screen.dart` |
| Card PMN na timeline por indexação de `referenced_dates` | ✅ Feito | `journal_screen.dart` |
| `AppWidgetProvider.kt` nativo Android | ✅ Feito | Encontrados em `android/app/src/main/kotlin/com/productivity/citrine/` (ex: `CitrineCalendarWidgetProvider.kt`, `CitrineTasksWidgetReceiver.kt`, etc) e declarados no `AndroidManifest.xml` |


# 2026-06-06 22H 20MIN

Citrine — Gap Analysis Completo
> Guidelines V3 × Código implementado (`olalaurao/aplicativo`)  
> Produzido em 06/06/2026 — fonte de verdade: guidelines.md (V3), lista de 166 arquivos Dart, `pendencias_implementacao.md`, `analysis_final_4.txt`, `ajustes.md`, `next_steps.md`, `wip_implementation_status.md`.

---

## Como ler este documento

Cada seção corresponde a uma parte do guidelines. Para cada item o status é classificado em:

- ✅ **Implementado** — arquivo e lógica existem no repositório com evidência clara
- ⚠️ **Parcial** — arquivo existe mas a implementação está incompleta, tem dead code, ou o fluxo não fecha
- ❌ **Ausente** — não existe nenhum arquivo correspondente, ou o guidelines descreve comportamento que não tem nenhuma base no código

---

## Parte 1 — Arquitetura Conceitual

### 1.1 Vault Structure

| Item | Status | Observação |
|---|---|---|
| Pasta padrão `app/` flat | ⚠️ | `VaultNotifier` escreve nessa pasta, mas `pendencias_implementacao.md` sec. 4 admite que o código "mistura `app/`, pastas por tipo, `daily/` e `trackers/records/`". Migração de arquivos legados não foi concluída. |
| `daily/YYYY-MM-DD.md` | ✅ | `MarkdownParser` e `VaultNotifier` geram e lêem daily notes. |
| `daily/YYYY-WNN.md` (PMN) | ⚠️ | Arquivo `journal_entry.dart` existe e tem suporte a `entry_type: pmn`, mas não há evidência de parsing do arquivo PMN próprio separado da daily note. Sem tela ou fluxo de criação dedicado visível. |
| `moods/SLUG.md` lazy | ⚠️ | `mood_model.dart` existe. Criação lazy na primeira vez que o mood é registrado não está verificada no código — não há `create_mood_file` no serviço. |
| `_attachments/`, `_deleted/`, `_conflicts/` | ⚠️ | `_deleted/` e `_conflicts/` referenciados em `sync_provider.dart` e `undo_service.dart`, mas purga automática de 30 dias não verificada. `_attachments/` mencionado sem serviço de gestão dedicado. |
| Object Identification (soberana) | ⚠️ | `type_signatures_screen.dart` existe (renomeado de Object Identification). Configuração de pasta/tag/propriedade por tipo referenciada, mas o parser de startup não demonstra usar essas regras ao indexar — ainda usa tipo no frontmatter como fallback principal. |
| Detecção de conflito de tipo (badge ⚠️) | ❌ | Não há lógica de detecção de conflito de tipo no código. Nenhuma tela "Conflitos" no menu Mais. |

### 1.2 Objetos de Conteúdo e Organizadores

| Item | Status | Observação |
|---|---|---|
| 9 tipos de conteúdo mapeados | ✅ | Todos têm model Dart correspondente. |
| 10 tipos de organizador | ⚠️ | `organizer_model.dart` existe mas `Places` (com coordenadas) e a hierarquia Area > Activity > Project completa não estão verificadas. `Activity` não aparece como tipo distinto em nenhum form. |
| Organizador tem Timeline própria | ⚠️ | `organizer_detail_screen.dart` existe. A timeline agrega dinamicamente conteúdo associado, mas `analysis_final_4.txt` aponta `unused_local_variable` dentro de `vault_provider.dart` (`pendingTasks`, `todayHabits`, `lastEntry`) — sugerindo que a agregação ainda não está totalmente conectada. |

---

## Parte 2 — Objetos de Dados

### Objeto 1: Entry (Journal Entry)

| Item | Status | Observação |
|---|---|---|
| `entry_type: standard` | ✅ | `create_entry_form.dart`, `journal_screen.dart`, `journal_entry.dart` implementados. |
| Rich text editor com bold/italic/heading/checklist/WikiLink | ⚠️ | `rich_text_editor.dart` existe. `next_steps.md` registra bug de renderização do body (`[{"insert":"lorem ipsum/n"}]`), indicando que o QuillDelta ainda não está sendo renderizado corretamente na timeline. `analysis_final_4.txt` aponta `desiredAccuracy` deprecado no form. |
| Fotos inline no body | ⚠️ | `pendencias_implementacao.md` sec. 5 lista "Salvar fotos como `![[arquivo]]` no corpo" como tarefa — indica que só existe thumbnail strip, não inserção inline real. |
| Location GPS real | ⚠️ | `create_entry_form.dart` usa `geolocator` mas a API `desiredAccuracy` está deprecada (`analysis_final_4.txt`). Location manual existe; auto-GPS não verificado como funcional. |
| `entry_type: field_note` (4 categorias, sem rich text) | ⚠️ | Modelo tem `category` e `energy_value`. Não há form dedicado de Field Note rápido — o toggle "Observação rápida" com 3 elementos não está evidente no código. |
| `entry_type: pmn` (arquivo próprio `YYYY-WNN.md`) | ✅ | Tela de criação implementada, parser na `VaultNotifier` adicionado. |
| PMN linkado a datas (`referenced_dates`) | ✅ | Model e parser de date_range e dates adicionados. |
| PMN auto-sugerindo Pact refs ativos | ✅ | Suporte básico adicionado (referências futuras para Pact/Habits). |
| Card PMN distinto na Timeline | ✅ | `PmnCard` adicionado em `timeline_card.dart` e usado nas telas. |
| Templates de Entry com CRUD | ⚠️ | `template_model.dart` e `create_template_form.dart` existem, mas `pendencias_implementacao.md` sec. 5 aponta que "Templates existem como picker, mas precisam CRUD de templates". |
| Organizers salvos como `OrganizerReference(type, slug)` | ⚠️ | `next_steps.md` menciona correção do `OrganizerReference.slug/title`, mas `pendencias_implementacao.md` sec. 5 ainda lista como pendente salvar o tipo do organizer. |

### Objeto 2: Task

| Item | Status | Observação |
|---|---|---|
| Campos core (stage, priority, dates, duration, etc.) | ✅ | `task_model.dart` completo. |
| `until_done`, `date_range`, `all_day` | ✅ | Modelados em `task_model.dart`. |
| Subtasks como Tasks completas com `parent_task` | ⚠️ | Subtasks existem mas `analysis_final_4.txt` aponta `_buildSubtaskItem` e `_buildHabitRow` como `unused_element` — sugerindo que o rendering pode não estar conectado. |
| Subtask sessions (grupos temáticos colapsáveis) | ⚠️ | `next_steps.md` lista como pendente explicitamente. |
| Triple Check (bloco no frontmatter, bottom sheet, 3 perguntas, diagnóstico) | ✅ | `TripleCheck` model adicionado ao `task_model.dart`, `triple_check_sheet.dart` criado com bottom sheet de 3 perguntas, diagnóstico em tempo real, botões de ação por dimensão bloqueada e persistência via `tasksProvider`. |
| Badge Triple Check no card após 7 dias sem progresso | ✅ | `TripleCheckBadge` widget adicionado ao `organizer_tasks_widget.dart` via `task.needsTripleCheckBadge` getter. |
| Triple Check no formulário de PMN (batch) | ❌ | Ausente (PMN nem existe ainda). |
| `depends_on` (array de bloqueadores) | ⚠️ | Modelado, sem UI para gestão de dependências. |
| `linked_system` | ✅ | Modelado em `task_model.dart`. |
| Reflexão ao finalizar | ⚠️ | `pendencias_implementacao.md` sec. 7 lista como pendente "Persistir reflection no markdown quando stage vira finalized". |
| Backlog modal ao salvar sem data | ⚠️ | `ajustes.md` lista backlog como implementado, mas o modal "Onde colocar?" com opção Backlog/Adicionar para hoje não está verificado como comportamento correto. |
| `social_refs` | ⚠️ | `social_post.dart` existe; link de Task → SocialPost não verificado. |
| `estimated_minutes` | ⚠️ | Modelado, sem UI dedicada de estimativa. |
| Scheduler por Task | ✅ | `scheduler.dart` e `scheduler_picker.dart` implementados. |
| Timer/Pomodoro vinculado a Task | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Vincular pomodoro a Task/Habit/Goal/Project e atualizar KPI time_spent" como pendente. |

### Objeto 3: Goal

| Item | Status | Observação |
|---|---|---|
| `goal_mode: standard` | ✅ | `goal_model.dart`, `create_goal_form.dart`, `goals_screen.dart` implementados. |
| `goal_mode: plan` (Objective, Strategy, Phases) | ⚠️ | Modelado com `objective`, `strategy`, `phases`. Sem seções distintas verificadas na detail view. `analysis_final_4.txt` tem null checks desnecessários em `goals_screen.dart` — sugerindo lógica incompleta. |
| KPIs com auto-complete de Goal | ⚠️ | `kpi_model.dart` e `kpi_engine.dart` existem. `pendencias_implementacao.md` sec. 14 lista "Implementar auto-complete de KPI" como pendente. |
| Goal como Organizador com Timeline | ⚠️ | Parcialmente via `organizer_detail_screen.dart`. |

### Objeto 4: Habit

| Item | Status | Observação |
|---|---|---|
| `habit_mode: habit` core | ✅ | `habit_model.dart`, `create_habit_form.dart`, `habits_screen.dart` implementados. |
| `habit_mode: pact` | ✅ | `habit_mode: pact` modelado e persistido corretamente. O bug de tipagem no parsing foi corrigido. |
| Steering Sheet (3 etapas: Revisão, Reflexão, Decisão) | ✅ | Componente `steering_sheet.dart` criado com fluxo completo de 3 etapas e persistência de dados. |
| Check automático de `ends_at` no startup | ✅ | Implementado checker de pactos expirados no startup em `main.dart` com disparador de notificações. |
| `previous_cycles` | ✅ | Salvo e atualizado no Markdown após cada ciclo finalizado via Steering Sheet. |
| `pact_outcome` | ✅ | Atualizado conforme a decisão (persist, pause, pivot) do usuário e persistido. |
| Slots com horário, reminder e Action independentes | ⚠️ | Slots existem no modelo. Reminders por slot existem. Actions por slot: ver seção de Actions abaixo. |
| "Days since" badge | ⚠️ | `habit_row.dart` tem UI de badge, mas lógica de atualização à meia-noite não verificada. |
| Streak e "days since" complementares | ⚠️ | Streak calculado, "days since" sem verificação de atualização automática. |
| Swipe right para completar habit | ⚠️ | Mencionado em gestos mas não verificado em `habit_row.dart`. |
| `isNegative` (habit de evitação) | ⚠️ | Modelado, sem rendering especial verificado. |
| `inputType: mood` | ⚠️ | Modelado, sem picker de mood integrado ao slot de habit. |
| `linkedTrackerSlug` | ⚠️ | Modelado, sem lógica de abertura do record form no momento de completion. |
| Dashboard `pact_today` panel | ❌ | Guidelines menciona panel "pact_today" com check-in diário. Não encontrado em `dashboard_panel.dart`. |

### Objeto 5: Tracker + Tracking Record

| Item | Status | Observação |
|---|---|---|
| Tracker definition com sections/fields | ✅ | `tracker_model.dart`, `create_tracker_form.dart`, `trackers_screen.dart` implementados. |
| 6 tipos de InputField | ⚠️ | `create_record_form.dart` tem switch com `unreachable_switch_default` (`analysis_final_4.txt`) — indica que nem todos os 6 tipos estão cobertos. |
| Tracking Record embebido na daily note | ⚠️ | `pendencias_implementacao.md` sec. 4 aponta que "Tracking records devem seguir uma regra clara: ou ficam em daily notes ou como arquivos próprios, mas não os dois sem sincronização" — problema em aberto. |
| Charts (line, bar, pie, calendar) por Tracker | ⚠️ | `citrine_chart.dart` e `tracker_metric_card.dart` existem. `pendencias_implementacao.md` sec. 12 lista "Statistics view deve permitir criar/remover summaries e charts persistidos no tracker" como pendente. |
| Summaries configuráveis | ⚠️ | Modelados, sem CRUD verificado. |
| InputField com `organizers` auto-adicionados ao Record | ❌ | Não há lógica de auto-adicionar organizers do campo ao record quando preenchido. |
| `media` field com save de arquivo | ⚠️ | `pendencias_implementacao.md` sec. 12 lista "Media field deve salvar arquivo e valor estruturado" como pendente. |
| History por campo (últimos valores) | ⚠️ | Mencionado em pendências sec. 12 como "History icon por campo deve abrir últimos valores reais" — pendente. |

### Objeto 6: Note

| Item | Status | Observação |
|---|---|---|
| Text Note com rich text | ✅ | `create_note_form.dart`, `note_model.dart` implementados. |
| `_bodyController` unused | ⚠️ | `analysis_final_4.txt` aponta `_bodyController` como `unused_field` em `create_note_form.dart` — campo do editor não conectado. |
| Outline Note (árvore, drag, focus mode, mirroring) | ⚠️ | `outline_editor.dart` e `outline_editor.dart` (widget) existem. Focus mode e mirroring não verificados. |
| Collection Note (schema + items + views list/gallery/table) | ⚠️ | `collection_editor.dart` e `collection_view.dart` existem. `pendencias_implementacao.md` sec. 6 lista "trocar contagem por split de texto por JSON/YAML estruturado, com schema e itens reais" como pendente — indica que Collection Note não está funcionando como banco de dados ainda. |
| Notes NÃO aparecem na Timeline principal | ⚠️ | Não verificado — Timeline pode estar mostrando Notes incorretamente. |
| `parent_note` e links bidirecionais | ⚠️ | Modelados, sem gestão de backlinks automática verificada. |
| WikiLink `[[]]` com picker flutuante inline | ⚠️ | `wiki_link_controller.dart` e `wiki_link_picker.dart` existem. Resolução de aliases de mood não verificada. |
| Filtros, reordenação e campos personalizados em listas de Notes | ⚠️ | `ajustes.md` lista como pendente explicitamente (item 6 e 7). |

### Objeto 7: Calendar Session

| Item | Status | Observação |
|---|---|---|
| Criação e visualização | ✅ | `create_session_form.dart`, `planner_screen.dart` implementados. |
| `_timeSlot` unused field | ⚠️ | `analysis_final_4.txt` aponta `_timeSlot` como `unused_field` em `create_session_form.dart`. |
| Chips Objectives, Time spent, Reminder | ⚠️ | `pendencias_implementacao.md` sec. 8 lista os 3 como pendentes. |
| Move modal com persistência completa | ⚠️ | `wip_implementation_status.md` lista como concluído, mas `ajustes.md` registra "no planner visualizacao day, tava dando erro quando tento mudar a duração" — indica que persistência de duração falha. |
| Redimensionar duração arrastando no Day View | ❌ | `ajustes.md` lista como pendente. |
| Timer/Pomodoro inline na sessão | ⚠️ | `pendencias_implementacao.md` sec. 8, `time_block_picker.dart` existe mas integração não verificada. |
| `exported_calendar_id` e link com Google Calendar | ⚠️ | `google_calendar_service.dart` existe. `next_steps.md` lista export como implementado, mas integração bidirecional (importar evento como sessão) está pendente. |
| Backlog de sessões | ⚠️ | Modelado, sem UI verificada. |
| `linked_google_event_*` | ⚠️ | Modelados; persistência de link verificada parcialmente. |

### Objeto 8: Reminder

| Item | Status | Observação |
|---|---|---|
| Model e form básico | ✅ | `reminder_model.dart`, `create_reminder_form.dart`, `reminders_screen.dart` implementados. |
| 3 tipos (push, popup, alarm) | ⚠️ | `notification_service.dart` existe. `ajustes.md` registra "alarme nao funciona ainda" — tipo `alarm` não funcional. |
| Botões de ação (Marcar como feito, Soneca, Dispensar) | ⚠️ | `pendencias_implementacao.md` sec. 9 lista os 3 como pendentes de implementação real — actions só imprimem log. |
| Soneca com duração configurável na hora da notificação | ❌ | Ausente. |
| Confiabilidade via alarm manager nativo | ⚠️ | `notification_service.dart` existe; permissões verificadas em `permission_service.dart`. `ajustes.md` confirma que notificações/alarmes não funcionam no Android. |
| Organizer chip, scheduler e time block no form | ⚠️ | `pendencias_implementacao.md` sec. 9 lista como pendente. |
| Opção soneca/burnout (ignorar alarmes de hábitos até X dia) | ❌ | `ajustes.md` lista como pendente explicitamente. |

### Objeto 9: System

| Item | Status | Observação |
|---|---|---|
| Model | ✅ | Presumido presente via `create_note_form.dart` com aba System e `command_center_overlay.dart`. Porém não há `system_model.dart` explícito na lista de arquivos — o System pode estar embutido em `note_model.dart`. |
| Formulário de criação (título, trigger, steps, substeps, tempo estimado) | ⚠️ | Não há `create_system_form.dart` na lista de arquivos. A criação de System pode estar dentro de `create_note_form.dart` de forma rudimentar. |
| "Estruturar com IA" (botão de AI para montar steps) | ❌ | Ausente. |
| Detail view com stats (run_count, last_run, average_minutes, histórico) | ❌ | Sem `system_detail_screen.dart`. Stats derivadas de Tasks com `linked_system` não calculadas. |
| Botão "▶ Executar" — Via A (cria Task com subtasks dos steps) | ❌ | Ausente. |
| Via B — "Aplicar System" de qualquer Task | ❌ | Ausente. |
| Via C — Quick-run efêmero (checklist sem criar Task) | ❌ | Ausente. |
| "Salvar como System" a partir de Task (menu ⋯) | ❌ | Ausente. |
| `run_count`, `last_run`, `average_minutes` derivados | ❌ | Ausente. |
| Dashboard panel `system_quick_run` | ❌ | Não encontrado em `dashboard_panel.dart`. |
| Systems como chips no Command Center | ⚠️ | `command_center_overlay.dart` existe. Seção "Systems" como quick-run não verificada. |
| Swipe right em System → quick-run | ❌ | Ausente. |

**⚠️ Sistema (Objeto 9) é a feature com maior gap do projeto — quase todo o comportamento está ausente.**

### Objeto 10: Social Post

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `social_post.dart`, `create_social_post_form.dart`, `social_screen.dart`, `social_post_detail.dart` implementados. |
| Bulk import | ✅ | `social_bulk_import_screen.dart` existe. |
| Embed view (oEmbed) | ✅ | `social_embed_view.dart`, `oembed_service.dart` implementados. |
| Linkagem com Tasks (`linked_tasks`) | ⚠️ | Modelado; UI de linkagem unificada com busca por tipo não verificada. |
| `linked_content` (qualquer objeto do vault) | ⚠️ | Modelado sem UI verificada. |

---

## Parte 3 — Objetos de Suporte

### Scheduler

| Item | Status | Observação |
|---|---|---|
| 11 tipos de regra | ⚠️ | `scheduler.dart` e `scheduler_picker.dart` existem. `analysis_final_4.txt` aponta múltiplos `unreachable_switch_default` e `unused_local_variable 'isSelected'` no `scheduler_picker.dart` — indica que nem todos os tipos estão cobertos. `pendencias_implementacao.md` sec. 8 lista "Scheduler deve usar `days_of_theme` e `days_with_block`" como pendente. |
| Regras de exclusão | ⚠️ | Modeladas, sem UI específica verificada. |
| Política de atraso (skip/keep/prompt) | ⚠️ | Modelada, sem UI de escolha verificada. |
| Múltiplas regras por scheduler (OR lógico) | ⚠️ | Modelado, sem UI para adicionar múltiplas regras. |
| Página global de Scheduler (Settings → Scheduler) | ✅ | `scheduler_management_screen.dart` e `scheduler_page.dart` existem. |

### Day Theme e Time Block

| Item | Status | Observação |
|---|---|---|
| CRUD de Day Theme | ✅ | `day_theme_screen.dart`, `day_theme_model.dart`, `day_theme_provider.dart` existem. |
| CRUD de Time Blocks (nome, cor, hora inicial/final) | ⚠️ | `time_block_picker.dart` existe mas `pendencias_implementacao.md` sec. 18 lista "CRUD de Time Blocks com nome, cor, hora inicial/final" como pendente. |
| `energy_level` por bloco | ⚠️ | Modelado. Toggle "Camada de energia" no Planner não verificado. |
| Tints de energia no Planner (8% opacity) | ❌ | Não verificado como implementado. |
| Auto-geração de Energy Map a partir de Field Notes (14+ dias) | ❌ | Ausente — depende também de Field Notes funcionais. |
| Planner agrupa sessões/habits por Time Block | ⚠️ | `ajustes.md` lista "day times pros habits - ficar ao longo do dia no horário do slot reminder" como pendente. |

### KPI

| Item | Status | Observação |
|---|---|---|
| `kpi_model.dart` e `kpi_engine.dart` | ✅ | Existem. |
| Fontes: subtasks, tracker_field, habit, collection, entry, time_spent, manual_quantity | ⚠️ | `kpi_engine.dart` existe mas `pendencias_implementacao.md` sec. 14 lista problemas em fontes específicas (`entryCount` inconsistente, `collection` sem parse estruturado). |
| Auto-complete de KPI | ❌ | `pendencias_implementacao.md` sec. 14 lista como pendente. |
| Input inline de `manual_quantity` com botão "+N" | ⚠️ | Sem UI específica verificada. |

### Snapshot

| Item | Status | Observação |
|---|---|---|
| Model e form | ✅ | `snapshot_model.dart`, `create_snapshot_form.dart` existem. |
| Aparece na Timeline como entrada | ⚠️ | Sem verificação de que `timeline_card.dart` tem variante Snapshot. |
| Update de Snapshot | ⚠️ | `pendencias_implementacao.md` sec. 3 lista "Garantir update para Snapshot" como pendente. |

### Mood Definition

| Item | Status | Observação |
|---|---|---|
| Model com todos os campos | ✅ | `mood_model.dart` implementado. |
| 48 moods do sistema pré-carregados (12 por quadrante) | ⚠️ | Tabela do guidelines tem 48 moods. Não verificado se todos os 48 estão hardcoded no código. |
| Picker de humor em 2 passos (grade 2×2 → lista por quadrante) | ⚠️ | `mood_chart_widget.dart` existe. O picker de 2 passos (grade interativa + lista de moods do quadrante selecionado) não tem arquivo dedicado — provavelmente está inline em algum form. |
| Campo de busca no picker (label, label_en, aliases) | ⚠️ | Sem verificação de busca por `aliases` no picker. |
| "Adicionar minha própria emoção" → form de mood user | ⚠️ | `mood_settings_screen.dart` existe para gerenciar moods. Criação inline no picker não verificada. |
| Moods system: apenas `hidden` e `aliases` editáveis | ⚠️ | Lógica de restrição não verificada. |
| Moods system: arquivo criado lazily na 1ª vez | ⚠️ | Lógica lazy não verificada no código. |
| `aliases` como campo nativo de aliases do Obsidian | ⚠️ | Sem verificação de escrita no frontmatter como array `aliases:`. |
| Emoji como marcador nos gráficos de linha | ⚠️ | `mood_chart_widget.dart` e `citrine_chart.dart` existem. Emoji como marcador de ponto visual não verificado. |
| Emoji no calendário de Combined Analysis | ⚠️ | `analysis_calendar.dart` existe. Emoji no centro do dia não verificado. |
| 4 campos separados na daily note (`mood_pleasantness`, `mood_energy`, `mood_label`, `mood_emoji`) | ⚠️ | Formato canônico definido no guidelines; escrita dos 4 campos separados não verificada no `MarkdownParser`. |

---

## Parte 4 — Telas e Navegação

### Bottom Navigation Bar

| Item | Status | Observação |
|---|---|---|
| 5 slots padrão com Dashboard fixo e Mais fixo | ✅ | `app_shell.dart` implementado. |
| Slots 2–4 customizáveis (adicionar, remover, reordenar) | ✅ | `navigation_shortcut_picker.dart` e `navigation_provider.dart` existem. `ajustes.md` lista como implementado. |
| Máximo de 7 slots | ⚠️ | Sem verificação de enforcement do limite. |
| Atalhos para nota específica, filtro de área, tarefa específica | ⚠️ | `ajustes.md` lista "quero poder colocar atalhos pra qualquer página" como pendente no contexto de customização avançada. |

### FAB Global "Criar"

| Item | Status | Observação |
|---|---|---|
| Bottom sheet com abas Journal/Plan/Record/Note | ✅ | `create_menu_sheet.dart` implementado. |
| Aba Journal → Entry / Field Note / PMN | ⚠️ | Entry existe. Field Note e PMN como opções distintas não verificadas. |
| Aba Note → System | ⚠️ | System não tem form dedicado. |
| Snapshot, Voice Note, Scan Document funcionais | ⚠️ | `pendencias_implementacao.md` sec. 1 lista os 3 como pendentes de implementação real. |

### Command Center (scroll-up)

| Item | Status | Observação |
|---|---|---|
| Overlay com busca, Recentes, Notas, Próximas Sessões | ✅ | `command_center_overlay.dart` implementado. |
| Seção "Systems" com 3 Systems como chips de quick-run | ❌ | Não implementado (System não existe de forma completa). |
| Ações rápidas: "Novo System" | ❌ | Ausente. |

---

## Parte 5 — Padrões de Interação

| Item | Status | Observação |
|---|---|---|
| Gestos: tap, long press, swipe left, swipe right, drag, scroll-up | ⚠️ | Maioria implementada. Swipe right em System → quick-run: ausente. Swipe right em Habit/Pact para completar: não verificado. |
| Undo em Delete/Archive (snackbar 5s, `_deleted/`) | ✅ | `undo_service.dart` implementado. `wip_implementation_status.md` lista como concluído. |
| Drag-and-drop no Planner com persistência | ⚠️ | `wip_implementation_status.md` lista como concluído, mas `pendencias_implementacao.md` sec. 11 lista "Todo drag/drop deve persistir no objeto e reescrever markdown" como pendente — contradição. |
| Organizer Detail View com 4 seções dinâmicas | ⚠️ | `organizer_detail_screen.dart` existe. `analysis_final_4.txt` aponta variáveis locais não usadas no `vault_provider.dart` que alimentam essas seções. |

---

## Parte 6 — Sistema de Actions (Habits e Trackers)

| Item | Status | Observação |
|---|---|---|
| `automation_service.dart` | ✅ | Existe. |
| 7 tipos de Action | ⚠️ | `analysis_final_4.txt` aponta `unused_local_variable 'changed'` em `automation_service.dart` — automação existe mas a variável de resultado não é usada, sugerindo que as actions não são disparadas de fato. |
| Trigger: completar slot individual | ❌ | Não verificado como disparado. |
| Trigger: atingir daily goal | ❌ | Não verificado como disparado. |
| Trigger: salvar tracking record | ❌ | Não verificado como disparado. |
| Configuração de Action por slot (independente do reminder) | ❌ | UI de configuração de Action por slot não encontrada. |

**⚠️ Actions é outra feature com gap significativo — o serviço existe mas as actions não são efetivamente disparadas.**

---

## Parte 7 — Pomodoro

| Item | Status | Observação |
|---|---|---|
| Timer funcional (work/short break/long break) | ✅ | `pomodoro_screen.dart`, `pomodoro_provider.dart`, `pomodoro_bg_service.dart` implementados. |
| UI full-screen com countdown circular, controles, indicador de blocos | ✅ | `pomodoro_screen.dart` implementado. |
| Notificação persistente com Pausar/Retomar/Parar | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Foreground notification precisa ter ações Pause/Resume/Stop conectadas ao provider" como pendente. |
| PomodoroSession persistida na daily note (`## Pomodoros`) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "escrever `## Pomodoros` no daily note" como pendente. |
| Vincular Pomodoro a Task/Habit/Goal/Project | ⚠️ | `pendencias_implementacao.md` sec. 10 lista como pendente. |
| `pendingTasks` e `todayHabits` unused no vault_provider | ⚠️ | `analysis_final_4.txt` — sugere que integração Pomodoro → KPI time_spent não está conectada. |
| Pomodoro Agendado (cria CalendarSession ou Reminder) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista "Botão 'Agendar Pomodoro' deve criar CalendarSession ou Reminder, não apenas snackbar" como pendente. |
| Histórico de sessões do vault (não só memória) | ⚠️ | `pendencias_implementacao.md` sec. 10 lista como pendente. |
| `pomodoro_floating_clock.dart` e `pomodoro_week_overview.dart` | ✅ | Existem. |

---

## Parte 8 — People

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `people_model.dart`, `create_person_form.dart`, `people_screen.dart` implementados. |
| `last_contact_date` derivado de backlinks reais | ⚠️ | `pendencias_implementacao.md` sec. 15 lista "Calcular `last_contact_date` por backlinks reais, journal entries e eventos" como pendente. Variável `frequencyDays` apontada como unused no `people_screen.dart` (`analysis_final_4.txt`). |
| Scheduler automático → Task "Contatar [nome]" | ⚠️ | `automation_service.dart` tem `checkPersonContacts` mas com `unused_local_variable 'changed'` — não conectado. |
| Ao concluir a task automática → atualiza `last_contact_date` | ❌ | Ausente (depende de task completion callback). |
| Histórico de contatos e menções navegáveis | ⚠️ | `pendencias_implementacao.md` sec. 15 lista como pendente. |
| Editar `contact_frequency` inline | ⚠️ | `pendencias_implementacao.md` sec. 15 lista como pendente. Unused `frequencyDays` confirma. |

---

## Parte 9 — Resources

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `resource_model.dart`, `create_resource_form.dart`, `resources_screen.dart` implementados. |
| Dead code em `create_resource_form.dart` | ⚠️ | `analysis_final_4.txt` aponta `dead_code` e `dead_null_aware_expression` — lógica quebrada no form. |
| Settings → Resources: regras de filtro configuráveis | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. |
| Cover image via WikiLink embed | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. |
| Rating persistido imediatamente | ⚠️ | `pendencias_implementacao.md` sec. 16 lista como pendente. Status duplicado no modelo apontado. |
| Lazy loading do grid | ⚠️ | `ajustes.md` lista "grid de resources deve ser lazy loading" como pendente. |

---

## Parte 10 — Projects

| Item | Status | Observação |
|---|---|---|
| Model, form, tela | ✅ | `project_model.dart`, `create_project_form.dart` implementados. |
| `primary_kpi` como drive do % de progresso | ⚠️ | `kpi_engine.dart` existe mas integração com Projects não verificada. |
| `quick_access` (links rápidos) | ⚠️ | Modelado, sem UI de adição de links verificada. |
| `total_pomodoro_time` derivado | ❌ | Depende de Pomodoro → Task linkado, que está pendente. |
| Project detail com todas as seções | ⚠️ | `pendencias_implementacao.md` sec. 14 lista "Project detail deve expor edição inline de state, priority, due date, KPIs e tarefas vinculadas" como pendente. |
| Scheduler recorrente de projeto (reinicia no schedule) | ⚠️ | Modelado, sem fluxo de reinicialização verificado. |

---

## Parte 11 — Combined Analysis

| Item | Status | Observação |
|---|---|---|
| Tela existe | ✅ | `combined_analysis_screen.dart` implementado. |
| CRUD de objeto CombinedAnalysis persistente | ⚠️ | `pendencias_implementacao.md` sec. 13 lista "Criar CRUD de CombinedAnalysis com title, description, data_sources, chart configs" como pendente — análises são temporárias em estado local. |
| `analysis_model.dart` | ✅ | Existe (com deprecated `.value` apontado em `analysis_final_4.txt`). |
| Picker de fontes com cor/label/field/source type | ⚠️ | Pendente (sec. 13). |
| `normalization: dual_axis / normalize_0_1` | ❌ | Sem evidência de normalização de eixo duplo implementada. |
| `value_mapping` para campos categóricos | ❌ | Sem evidência de mapeamento categórico → numérico. |
| Emoji como marcador em gráficos de linha | ❌ | `analysis_final_4.txt` aponta `unused_local_variable 'firstDay'` em `combined_analysis_screen.dart` — lógica de calendário incompleta. |
| Calendário mensal com emoji de mood + dots coloridos | ⚠️ | `analysis_calendar.dart` existe mas sem emoji de mood verificado. |
| Mood como fonte com dimensão pleasantness/energy | ⚠️ | Pendente (sec. 13). |

---

## Parte 12 — Sync, Offline e Conflitos

| Item | Status | Observação |
|---|---|---|
| Sync com Google Drive (offline-first) | ✅ | `google_drive_sync_service.dart`, `sync_provider.dart`, `sync_queue_service.dart`, `sync_manager.dart` implementados. |
| `fetchRemoteFiles` recursivo | ⚠️ | `pendencias_implementacao.md` sec. 19 lista "hoje busca só filhos diretos da pasta raiz" como pendente. |
| Hash por arquivo para detecção correta de conflito | ⚠️ | Pendente (sec. 19). |
| UI de conflito com comparação campo a campo | ✅ | `conflict_resolution_dialog.dart`, `sync_conflict_dialog.dart`, `sync_conflicts_screen.dart` existem. `wip_implementation_status.md` lista como concluído. |
| Fila offline visível ao usuário | ⚠️ | `pendencias_implementacao.md` sec. 19 lista "Mostrar fila offline e erros de sync ao usuário" como pendente. |
| Indicador de status (synced/syncing/offline/error) | ⚠️ | `sync_provider.dart` tem estados; UI de indicador não verificada. |
| Backup ZIP periódico (diário/semanal/por abertura) | ✅ | `backup_service.dart` existe. Configuração de retenção não verificada. |
| Purga automática de `_deleted/` em 30 dias | ❌ | Sem serviço de purga verificado. |

---

## Parte 13 — Notificações

| Item | Status | Observação |
|---|---|---|
| `notification_service.dart` | ✅ | Existe. |
| 3 tipos: push, popup, alarm | ✅ | Push e popup funcionam; Alarm foi ajustado e verificado para rodar e permitir ações reais. |
| Botões de ação reais (não apenas log) | ✅ | Implementado em `vault_provider.dart` (`_markNotificationTargetDone`, `_snoozeNotification`, `_recordNotificationDismissal`) e nas telas `AlarmScreen` e `PopupScreen`. Suporte a Task, Habit e Reminder. |
| Confiabilidade via alarm manager do sistema | ⚠️ | `permission_service.dart` existe; `ajustes.md` confirma falhas. |
| Notificação persistente de Captura Rápida (lockscreen) | ⚠️ | `next_steps.md` lista como implementado com ressalva (botões físicos não suportados pelo OS). |
| Popup sobre lockscreen | ✅ | `popup_notification_screen.dart` implementado com ações reais e fallback corrigido. |

---

## Parte 14 — Archive Universal

| Item | Status | Observação |
|---|---|---|
| `archived: true` no frontmatter | ✅ | Todos os modelos têm `archived`. |
| Página Archive com lista, filtro por tipo, busca, Restaurar | ✅ | `archive_screen.dart` existe. `wip_implementation_status.md` lista como concluído. |
| Banner "Arquivado" na detail view em read-only | ⚠️ | Não verificado em `universal_detail_view.dart`. |
| "Ver arquivados" por seção via menu ⋯ | ⚠️ | Sem evidência de implementação por seção. |

---

## Parte 15 — Widgets (Home Screen / Lock Screen)

| Item | Status | Observação |
|---|---|---|
| `widget_service.dart` e `widget_sync_provider.dart` | ✅ | Existem. |
| Quick-add widget (2×1) | ⚠️ | `pendencias_implementacao.md` sec. 20 lista "Quick-add widget: botões Journal Entry e Add Task com deep links" como pendente. |
| Calendar widget com dots | ⚠️ | Pendente (sec. 20). |
| Category widget configurável | ⚠️ | Pendente (sec. 20). |
| Obsidian Note widget (renderiza nota específica) | ⚠️ | Pendente (sec. 20). |
| Widget configuration sheet real | ✅ | `widget_config_sheet.dart` existe. |
| Deep links e atualização em background no Android/iOS | ⚠️ | Pendente (sec. 20). |

---

## Parte 16 — Linking Universal

| Item | Status | Observação |
|---|---|---|
| `links` no frontmatter | ✅ | Todos os modelos têm `links`. |
| Inline WikiLink `[[]]` com picker flutuante | ✅ | `wiki_link_controller.dart`, `wiki_link_picker.dart`, `wiki_text_view.dart` implementados. |
| Filtragem fuzzy por título e aliases no picker | ⚠️ | Aliases de mood não verificados como indexados. |
| Menções/Backlinks em todas as detail views | ⚠️ | `universal_detail_view.dart` existe mas `analysis_final_4.txt` aponta `_statBox`, `actions` e `_buildSubtaskItem` como `unused_element` — partes da detail view não conectadas. |
| Busca indexa body de markdown, frontmatter, tags, backlinks | ⚠️ | `search_service.dart` existe. `pendencias_implementacao.md` sec. 17 lista "Search deve indexar todos os corpos de markdown" como pendente — indica indexação incompleta. |

---

## Parte 17 — Navigation History

| Item | Status | Observação |
|---|---|---|
| `history_provider.dart` | ✅ | Existe. |
| Back button em toda tela não-root | ⚠️ | `ajustes.md` lista "Botão de voltar deve sempre voltar para a página anterior, não para o pai (corrigir go_router)" como pendente. |
| Breadcrumb trail quando stack > 2 níveis | ❌ | Sem `breadcrumb.dart` ou equivalente na lista de arquivos. |
| Restaurar posição de scroll e estado de form ao voltar | ❌ | Não implementado. |

---

## Parte 18 — Design Visual

| Item | Status | Observação |
|---|---|---|
| Cores por tipo de objeto | ⚠️ | `theme.dart` existe. Cores por subtipo (field_note por categoria, PMN por seção, System laranja) não verificadas. |
| "Days since" badge em Habits | ⚠️ | `habit_row.dart` tem badge, mas pill vermelha `#E53935` após 1+ dia e atualização à meia-noite não verificadas. |
| Badge "PACT" (pill branca, fundo = cor do habit) | ⚠️ | `habit_row.dart` tem badge PACT, styling exato não verificado. |
| Color picker visual (nunca HEX direto) | ⚠️ | `ajustes.md` e guidelines explicitam isso. Não verificado em todos os forms. |
| Energy level tints no Planner (8% opacity) | ❌ | Não verificado. |
| Dark mode completo sem textos ilegíveis | ⚠️ | `ajustes.md` e `next_steps.md` listam dark mode como corrigido, mas com ressalvas. `analysis_final_4.txt` tem múltiplos `withOpacity` deprecated que afetam cores. |

---

## Parte 19 — UI Fundamentals

| Item | Status | Observação |
|---|---|---|
| Safe Areas (iOS notch, Android status bar) | ⚠️ | `app_shell.dart` usa SafeArea. Consistência em todos os modais não verificada. |
| Back button (‹) em telas pushed, X em modais | ⚠️ | `ajustes.md` lista correção do back button como pendente. |
| Botão Done/Save (pill arredondada, roxo escuro) | ⚠️ | Não verificado como padrão consistente. |
| Keyboard avoidance (CTA sobe com teclado) | ⚠️ | Não verificado em todos os forms. |
| Handle pill em bottom sheets (36×4pt) | ⚠️ | Não verificado como padrão. |
| Stacking de modais com escala do anterior | ⚠️ | Não verificado. |
| Altura de row (48–52pt), padding horizontal (16pt) | ⚠️ | Não verificado como padrão consistente. |
| Haptic feedback (light/medium/warning por tipo de ação) | ⚠️ | Não verificado. |
| Empty states com ilustração, headline e CTA real | ⚠️ | `empty_state.dart` existe. `pendencias_implementacao.md` sec. 21 lista "Adicionar empty states com CTA real em todas as telas" como pendente. |
| Loading: offline-first (instantâneo) + sync indicator | ⚠️ | Arquitetura offline-first existe; feedback visual de sync não verificado em todos os lugares. |
| Delete sempre com confirmation alert nomeando o item | ⚠️ | Não verificado como padrão consistente. |
| Título duplicado/não-fixo no topo | ⚠️ | `ajustes.md` lista "tira o título duplicado que não tá fixo" como pendente. |

---

## Parte 20 — Vault Obsidian: Esquema Completo

| Item | Status | Observação |
|---|---|---|
| `markdown_parser.dart` e `obsidian_service.dart` | ✅ | Existem. |
| Algoritmo de parsing no startup (8 etapas) | ⚠️ | `vault_provider.dart` existe (1250+ linhas). Múltiplos warnings de variáveis não usadas no startup (`analysis_final_4.txt`). Object Identification não soberana no startup. |
| Parse de daily note: habits, trackers, mood 4 campos, entries | ⚠️ | Parcialmente implementado. Mood como 4 campos separados no frontmatter não verificado. Field Notes no formato `### HH:MM` não verificado. |
| Parse de PMN (`daily/YYYY-WNN.md`) | ❌ | Ausente. |
| Criação lazy de arquivo de mood | ⚠️ | Ausente ou não verificado. |
| Derivação de `run_count`, `last_run`, `average_minutes` do System | ❌ | System não implementado. |
| Derivação do Energy Map de Field Notes | ❌ | Ausente. |
| Lookup de PMN por data | ❌ | Ausente. |
| Testes de ida-e-volta objeto → markdown → objeto | ⚠️ | `pendencias_implementacao.md` sec. 4 e sec. 22 listam como pendentes. |
| `dataview_generator.dart` | ✅ | Existe. |
| Queries Dataview de exemplo | ✅ | `dataview_generator.dart`. |

---

## Parte 21 — Object Identification

| Item | Status | Observação |
|---|---|---|
| Tela Settings → Object Identification | ✅ | `type_signatures_screen.dart` existe. |
| 3 tipos de marcador (Folder, Tag, Property) | ⚠️ | UI existe mas parser de startup não usa as regras definidas como soberano. |
| Badge ⚠️ em conflito de tipo | ❌ | Ausente. |
| Página "Conflitos" no menu Mais | ❌ | Ausente. |
| Editar tipo de qualquer objeto (tornar Area em Task, etc.) | ⚠️ | `ajustes.md` lista como implementado. |
| Compatibilidade com Tasks Plugin do Obsidian (`- [ ] [due:: ...] [priority:: ...]`) | ⚠️ | `markdown_parser.dart` existe mas compatibilidade com sintaxe do Tasks Plugin não verificada. |

---

## Parte 22 — Notas de Implementação (regras críticas)

| Regra | Status | Observação |
|---|---|---|
| Sempre ler `habit_mode` antes de renderizar | ⚠️ | Bug de runtime `type map dynamic is not a subtype of list dynamic` confirma que o parsing não é robusto. |
| Sempre ler `entry_type` antes de renderizar | ⚠️ | Field Note e PMN não têm rendering diferenciado verificado. |
| Sempre ler `goal_mode` antes de renderizar | ⚠️ | Null checks desnecessários em `goals_screen.dart` confirmam lógica frágil. |
| Nunca exibir campo `id` ao usuário | ⚠️ | Não verificado como regra aplicada. |
| Color picker visual obrigatório (nunca HEX direto) | ⚠️ | Não verificado em todos os forms. |
| PMN em arquivo próprio, indexado por `referenced_dates` | ❌ | Não implementado. |
| Mood como WikiLink nas entries + 4 campos na daily note | ⚠️ | WikiLink existe; 4 campos na daily não verificados. |
| Moods system criados lazily | ⚠️ | Não verificado. |
| Object Identification soberana no parser de startup | ❌ | Não implementado como soberano. |
| Actions são obrigatórias (7 tipos) | ❌ | Actions não são disparadas. |
| Triple Check não cria arquivo — bloco no frontmatter da Task | ✅ | Implementado: `TripleCheck.toMap()` serializa inline no frontmatter, nunca cria arquivo separado. |
| `run_count`/`last_run`/`average_minutes` sempre derivados | ❌ | System não implementado. |
| Steering Sheet em 3 etapas ao expirar Pact | ❌ | Não implementado. |
| PMN e Triple Check com batch no formulário de PMN | ❌ | PMN não implementado; Triple Check sem UI. |
| `value_mapping` apenas para campos categóricos | ❌ | Não implementado em Combined Analysis. |

---

## Resumo Executivo por Prioridade

### 🔴 Crítico — Ausente ou quebrado em runtime

1. ✅ **PMN completo** — implementado, com tela de criação, card na Timeline, e integração com o VaultNotifier.
2. ✅ **System (Objeto 9)** — implementado: `system_model.dart`, `systems_provider.dart`, `create_system_form.dart`, `system_detail_screen.dart` criados; Vias A (criar Task), B (aplicar steps a Task existente) e C (quick-run efêmero com stats) implementadas; painel `systemQuickRun` adicionado ao dashboard.
3. ✅ **Steering Sheet** — fluxo de revisão de Pact ao término com SteeringSheet de 3 etapas (Revisão, Reflexão, Decisão) e check automático de expiração no startup com notificações locais implementado.
4. ✅ **Triple Check** — UI de bottom sheet com 3 perguntas (Head/Heart/Hand), diagnóstico em tempo real por dimensão bloqueada, botões de ação contextuais (Reformular/Arquivar, Criar subtasks/Adiar, Adicionar dependência), badge ⚠️ após 7 dias sem progresso e persistência no frontmatter da Task implementados.
5. **Notificações — actions reais** — mark done, snooze e dismiss ainda apenas imprimem log; alarm type não funcional.
6. **Actions de Habit/Tracker** — `automation_service.dart` existe mas nenhuma action é efetivamente disparada em nenhum trigger.
7. **Object Identification soberana no startup** — parser não respeita as regras configuradas pelo usuário.
8. **Bug crítico de runtime em Habits** — `type map dynamic is not a subtype of list dynamic` impede a tela de carregar.

### 🟡 Importante — Parcial ou com lógica quebrada

9. **Pomodoro** — timer funciona; persistência na daily note, linkagem com Tasks/Goals, KPI `time_spent` e foreground notification actions pendentes.
10. **Combined Analysis** — tela existe mas análises são temporárias; sem `dual_axis`, sem `value_mapping`, sem emoji de mood nos gráficos.
11. **Field Notes** — modelo existe; form dedicado rápido e rendering diferenciado na Timeline ausentes.
12. **Rich text body na Timeline** — body renderiza como JSON Delta cru em vez de texto formatado.
13. **People CRM automático** — `last_contact_date` derivado de memória, não de backlinks; task automática não cria/atualiza corretamente.
14. **Planner Day View** — redimensionamento de tarefas por drag ausente; duração curta não mostra nome; habits não posicionados por horário de slot.
15. **KPI auto-complete** — engine existe mas auto-complete quando `current >= target` não executa ação.
16. **Back navigation** — botão voltar não restaura tela anterior corretamente em go_router.
17. **Tracker records** — formato dual (daily note + arquivo próprio) sem sincronização definida.
18. **Google Drive sync** — não recursivo; hash de conflito não persistido.

### 🟢 Implementado com ressalvas menores

19. Vault structure básica, modelos Dart, CRUD core de Tasks/Goals/Habits/Notes/Resources.
20. Planner Day/Week/Month com visualização básica.
21. Journal Entry standard com rich text (bugs de rendering existem).
22. Mood model com picker parcial e mood_settings_screen.
23. Sync com Google Drive (arquitetura presente, robustez incompleta).
24. Archive Universal com restore.
25. Scheduler básico (faltam tipos avançados e regras de exclusão na UI).
26. Pomodoro timer funcional.
27. Conflict resolution UI.
28. Command Center overlay.
29. Navigation shortcuts customizáveis.
30. Social Posts com bulk import e oEmbed.

---

*Fim do gap analysis. Total de itens analisados: ~220. Implementados sem ressalvas: ~30 (~14%). Parciais: ~110 (~50%). Ausentes: ~80 (~36%).*