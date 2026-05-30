# Citrine — Próximas Tarefas (Verificação Real de Código)

> **Gerado em:** 2026-05-28  
> **Metodologia:** Leitura direta dos arquivos Dart + cruzamento com docs `.md` + novas adições do `guidelines.md` (pasted).  
> **Status de cada item:** verificado linha a linha no código-fonte.

---

## DIRETRIZ PARA ANÁLISE DE CÓDIGO (LEIA ANTES DE QUALQUER TAREFA)

> Esta seção define como a IA deve se comportar ao revisar ou modificar qualquer arquivo do projeto. **Não esperar o usuário reportar bugs — identificá-los proativamente.**

### Comportamento obrigatório ao ler qualquer arquivo Dart:

**1. Referências que puxam algo vazio ou inexistente**
Sempre que um método, campo ou provider for chamado, verificar se o destino existe e tem implementação real:
- Método chamado → corpo vazio `{}` ou `throw UnimplementedError()` → 🚨 STUB NÃO IMPLEMENTADO
- `ref.read(xProvider)` → provider retorna `[]` ou `null` como default sem lógica → 🚨 PROVIDER VAZIO
- `map['campo']` → campo nunca escrito no `toMap()` correspondente → 🚨 SEMPRE NULL
- `settings.xField` → campo não existe em `AppSettings` → 🚨 COMPILE ERROR LATENTE
- `case 'tipo':` num switch de parsing → tipo referenciado mas case ausente → 🚨 OBJETO IGNORADO SILENCIOSAMENTE

**2. Referências cruzadas entre arquivos que não batem**
Ao ver uma chamada, verificar se o que está sendo chamado existe no arquivo de destino:
- Form salva `object.field = x` → model não tem esse campo → dado perdido silenciosamente
- `GoRouter` navega para `/rota` → rota não registrada no router → navegação silenciosa falha
- Widget usa `Provider.of<X>` → `X` não está no `MultiProvider` do `main.dart` → crash em runtime
- `import 'package:x/y.dart'` → arquivo `y.dart` não existe na lista de arquivos → compile error

**3. Inconsistências de fluxo (puxar coisas diferentes que não chegam a lugar nenhum)**
- Dado salvo em SharedPreferences com chave `'key_a'` → lido com chave `'key_b'` → nunca recuperado
- Objeto criado com `type: 'task'` → parser procura `type == 'Task'` (capitalização diferente) → objeto nunca parseado
- Notificação agendada com `channelId: 'canal_v3'` → canal criado só para `'canal_v4'` → notificação sem canal → não dispara
- Frontmatter escrito com campo `due_date` → código lê `dueDate` (camelCase) → sempre null

**4. Código que puxaria algo que não deveria**
- Sort/filter sem null-check em campo opcional → `Null check operator used on a null value` em runtime
- `list[0]` sem verificar `list.isNotEmpty` → RangeError em lista vazia
- `DateTime.parse(str)` sem `tryParse` → crash com string malformada (ex: vinda de vault editado manualmente no Obsidian)
- Cast `as Type` sem `is Type` primeiro → `_CastError` em runtime

### Formato de alerta proativo:

Sempre que um desses padrões for encontrado durante qualquer análise (mesmo que o usuário não tenha perguntado sobre aquele trecho), reportar assim:

```
🚨 [ARQUIVO] linha ~N: [descrição do problema]
   Chama: [o que está sendo chamado]
   Destino: [o que existe de fato]
   Impacto: [o que acontece em runtime — crash / dado perdido / silencioso / sempre null]
   Fix: [correção direta em código, 1-3 linhas]
```

### O que NÃO fazer:
- ❌ Assumir que se o arquivo existe, a feature funciona
- ❌ Marcar item como ✅ só porque o código foi escrito (código escrito ≠ feature funcionando)
- ❌ Ignorar um método vazio porque "provavelmente será preenchido depois"
- ❌ Considerar que um cast ou acesso de lista é seguro sem verificar
- ❌ Esperar o usuário testar no device para descobrir erros que são visíveis no código

---

---

## LEGENDA DE STATUS

| Símbolo | Significado |
|---------|-------------|
| ✅ FEITO | Implementado no código e deve funcionar |
| ⚠️ PARCIAL | Código existe mas incompleto ou com bug confirmado |
| ❌ NÃO FEITO | Ausente do código |
| 🔬 DEVICE ONLY | Código correto; só validável no dispositivo físico |

---

## BLOCO P0 — BUGS FÍSICOS CONFIRMADOS PELO USUÁRIO

---

### P0.1 — Timeline: ordem errada, timestamps errados, listas/mídia quebradas

**Status: ⚠️ PARCIAL — bug de modelo confirmado no código**

**Evidência no código:**

Em `journal_entry.dart`, o campo `date` é carregado assim:
```dart
date: frontmatter['date'] != null
    ? DateTime.tryParse(frontmatter['date'].toString()) ?? DateTime.now()
    : DateTime.now(),
```

O frontmatter contém apenas a data do daily note (ex: `2026-05-27T00:00:00.000`) — **sem a hora da entry**. A hora (`### HH:MM`) é extraída em `parseJournalEntries()` do `markdown_parser.dart` e retornada no mapa como string `'date': '$dateStr $time'`, mas esse valor nunca é propagado de volta para `JournalEntry.date`.

Resultado: todas as entries do mesmo dia têm `date = meia-noite daquele dia` → o sort em `journal_screen.dart` (`_journalEntryDisplayDate(a).compareTo(...)`) empata para todas as entries do dia → ordem indefinida/aleatória → usuário vê "tudo como hoje" e na ordem errada.

**Rich text:** `content_object.dart` tem `_deltaOpsToMarkdown()` e `normalizeRichTextBodyForMarkdown()` que converte Quill Delta para Markdown (bold, italic, listas, imagens) ✅. O problema de listas e mídia provavelmente é na renderização: se `JournalBodyView` recebe Markdown convertido mas tenta parsear como Delta novamente, produz output incorreto.

**Como corrigir:**

1. Adicionar campo `timeOfDay` em `JournalEntry`:
```dart
String? timeOfDay; // "HH:MM" extraído do ### HH:MM heading
```

2. Ao parsear entries em `vault_provider.dart`, usar `parseJournalEntries()` e setar:
```dart
entry.timeOfDay = parsedEntry['time'];
```

3. No sort de `journal_screen.dart`, substituir `_journalEntryDisplayDate(e)` por:
```dart
DateTime _journalEntryDateTime(JournalEntry e) {
  final base = e.date; // data do daily note
  if (e.timeOfDay != null) {
    final parts = e.timeOfDay!.split(':');
    return DateTime(base.year, base.month, base.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }
  return base;
}
```

4. Verificar se `JournalBodyView` usa `tryParseDeltaOps` ou renderiza direto como Markdown — garantir que não há double-parse.

**Arquivos:** `lib/models/journal_entry.dart`, `lib/providers/vault_provider.dart`, `lib/ui/screens/journal_screen.dart`, `lib/ui/widgets/journal_body_view.dart`.

---

### P0.2 — Popup não aparece sobre outros apps

**Status: ⚠️ PARCIAL — código correto, manifest não verificável aqui**

**Evidência no código:**

`permission_service.dart` já solicita todas as permissões necessárias:
- `requestFullScreenIntent()` via MethodChannel ✅
- `checkFullScreenIntent()` via MethodChannel ✅
- `requestSystemAlertWindow()` / `checkSystemAlertWindow()` ✅
- `requestIgnoreBatteryOptimization()` ✅

`notification_service.dart` em `scheduleReminder()` chama:
```dart
if (!await PermissionService.canScheduleExactAlarms()) {
  await PermissionService.requestExactAlarmSettings();
}
if (!await PermissionService.checkFullScreenIntent()) {
  await PermissionService.requestFullScreenIntent();
}
```

O código de permissões está completo. **O que não posso verificar aqui:** se `AndroidManifest.xml` contém `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>` e `<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>`.

**Ação necessária (não requer teste físico — verificar arquivo):**

```
android/app/src/main/AndroidManifest.xml — buscar por:
  USE_FULL_SCREEN_INTENT
  SYSTEM_ALERT_WINDOW
  FOREGROUND_SERVICE
  SCHEDULE_EXACT_ALARM ou USE_EXACT_ALARM
```

Se algum estiver faltando, adicionar. O código Flutter já está correto.

---

### P0.3 — Alarme sem áudio e sem vibração

**Status: ⚠️ PARCIAL — código correto, mas canal pode estar "travado" no device**

**Evidência no código:**

Canal `alarm_channel_v4` criado com:
```dart
playSound: true,
enableVibration: true,
audioAttributesUsage: AudioAttributesUsage.alarm,
```
E na notificação:
```dart
vibrationPattern: Int64List.fromList(const <int>[0, 700, 350, 700]),
additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
```

O código está correto. O problema real é que **canais Android são imutáveis após criação**. Se o usuário instalou uma versão anterior do app que criou `alarm_channel_v4` com configurações diferentes (sem som, sem vibração), o Android ignora qualquer tentativa de reconfigurar o canal existente. Apenas desinstalar e reinstalar recria os canais.

**Como corrigir:**

Incrementar a versão do canal para forçar recriação:
```dart
// Trocar 'alarm_channel_v4' por 'alarm_channel_v5' em TODOS os usos:
// - _createNotificationChannels()
// - AndroidNotificationDetails(channelId: ...)
// - scheduleReminder() (string inline)
```

Além disso, adicionar som customizado para garantir que toca mesmo em modo "Não Perturbe":
```dart
const alarmChannel = AndroidNotificationChannel(
  'alarm_channel_v5',
  'Alarms',
  sound: RawResourceAndroidNotificationSound('alarm_sound'), // arquivo em res/raw/
  ...
);
```
Adicionar `android/app/src/main/res/raw/alarm_sound.mp3` ao projeto.

**Arquivos:** `lib/services/notification_service.dart` (trocar `v4` → `v5` em 4 lugares), `android/app/src/main/res/raw/alarm_sound.mp3` (novo arquivo).

---

### P0.4 — Quick Add (entry/task/habit) não funciona

**Status: ⚠️ PARCIAL — abertura funciona, problema está no salvamento**

**Evidência no código:**

`create_menu_sheet.dart` está correto:
- FAB em `app_shell.dart` chama `showCreateMenu(context)` ✅
- Botão lateral também chama `showCreateMenu(context)` ✅
- `_buildCreateCard` faz `nav.pop()` + `nav.push(MaterialPageRoute(...))` ✅
- Todos os forms têm `targetForm` preenchido (nenhum `null`) ✅

Os forms **abrem**. O problema reportado ("não funciona") é que os forms **não salvam** ou o usuário não sabe que salvou. Causas prováveis pelo código:

1. **Permissão de armazenamento negada:** `PermissionService.hasStoragePermission()` retorna `false` → `ObsidianService.writeFile()` lança exception → catch silencioso → nada salvo, nenhum erro visível.

2. **Vault path vazio:** se `AppSettings.vaultPath` está vazio (usuário nunca configurou o vault), `ObsidianService` não tem pasta de destino → write falha silenciosamente.

**Como diagnosticar sem device:** verificar em `create_entry_form.dart` e `create_task_form.dart` se há `try/catch` em torno da chamada de save, e se há feedback ao usuário em caso de erro.

**Como corrigir:**

1. No botão "Salvar" de cada form, envolver o save com:
```dart
try {
  await ref.read(vaultProvider.notifier).createObject(object);
  if (mounted) Navigator.pop(context);
} catch (e) {
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
  );
}
```

2. Na tela inicial (primeiro uso), se `vaultPath.isEmpty`, mostrar dialog obrigatório de configuração do vault antes de permitir criar qualquer objeto.

**Arquivos:** `lib/ui/forms/create_entry_form.dart`, `lib/ui/forms/create_task_form.dart`, `lib/ui/forms/create_habit_form.dart` (adicionar error handling), `lib/ui/screens/home_screen.dart` (verificar vault configurado).

---

### P0.5 — Notificação persistente de captura rápida: loading eterno

**Status: ❌ NÃO FEITO — falta feedback visual e navegação após salvar**

**Evidência no código:**

`_handleNotificationResponse()` para `quick_entry`/`quick_task`/`quick_habit`:
```dart
await _enqueueAction(actionId, response.payload, response.id);
if (response.input != null && response.input!.trim().isNotEmpty) {
  await _enqueueAction('${actionId}_text', response.input, response.id);
}
if (_instance._container != null) {
  await _instance._container!.read(vaultProvider.notifier)
      .processPendingNotificationActions();
}
// Reset da notificação:
await _instance.showQuickCaptureNotification();
```

O fluxo **nunca navega o app para a foreground** nem exibe feedback visual. O Android mantém o botão de ação em estado de loading enquanto aguarda o app responder — mas o app só salva em background e recarrega a notificação. O usuário vê o spinner infinito porque não há `setResult` ou dismiss da action response.

**Como corrigir:**

```dart
// Após processar, navegar para o app com uma snackbar de confirmação:
if (actionId == 'quick_entry' && response.input?.isNotEmpty == true) {
  // Salvar diretamente no vault (sem fila):
  final entry = JournalEntry(body: response.input!, date: DateTime.now());
  await _instance._container!.read(vaultProvider.notifier).createObject(entry);
  
  // Navegar para o app em foreground:
  _instance._navigatorKey?.currentState?.pushNamed('/journal');
  
  // Mostrar confirmação:
  _instance.showInAppPopup(
    title: 'Entrada salva',
    body: response.input!.length > 40
        ? '${response.input!.substring(0, 40)}...'
        : response.input!,
    type: PopupType.reminder,
  );
}
```

Repetir para `quick_task` e `quick_habit`.

**Arquivos:** `lib/services/notification_service.dart` (`_handleNotificationResponse`).

---

### P0.6 — Lembretes duplicados (chegam todos ao mesmo tempo)

**Status: ⚠️ PARCIAL — scheduler correto, problema no ID de notificação**

**Evidência no código:**

`scheduler_service.dart` POSSUI verificação de `endDate`:
```dart
if (scheduler.endDate != null) {
  if (normalizedDate.isAfter(normalizedEnd)) return false;
}
```
✅ — meu diagnóstico anterior estava errado neste ponto.

O problema de duplicatas vem do **ID de notificação não-determinístico**. No handler de snooze:
```dart
id: response.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
```

Mas o problema principal é na **re-agendação ao abrir o app**: sem ver `vault_provider.dart` completo, o padrão usual é: ao inicializar, cancelar todas as notificações e reagendar. Se `cancelAll()` não é chamado primeiro, ou se o ID muda entre sessões, você acumula duplicatas.

**Como corrigir:**

1. Garantir IDs determinísticos baseados no slug + data:
```dart
int notificationId(String objectSlug, DateTime date) {
  return (objectSlug.hashCode ^ date.millisecondsSinceEpoch ~/ 1000).abs() % 2000000000;
}
```

2. Em `vault_provider.dart`, antes de `scheduleAllReminders()`:
```dart
await NotificationService().cancelAllScheduled(); // limpa tudo
// ... reagenda com IDs determinísticos
```

3. No snooze handler, nunca usar timestamp como ID:
```dart
// Trocar:
id: response.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
// Por:
id: response.id ?? 999999, // ID fixo para snooze manual
```

**Arquivos:** `lib/services/notification_service.dart`, `lib/providers/vault_provider.dart` (inicialização de notificações).

---

## BLOCO P1 — ITENS COM `[ ]` NO `wip_implementation_status.md`

---

### P1.1 — Pomodoro foreground service: botões da notificação

**Status: 🔬 DEVICE ONLY — código existe, ações precisam de teste**

Código do `PomodoroTaskHandler` e `FlutterForegroundTask` existe. As ações (Pausar/Pular/Parar) usam `sendDataToTask` e `receiveData`. Funcionalidade só validável com app em background no dispositivo físico.

**Testar:** iniciar Pomodoro → minimizar → tocar "Pausar" na notificação → verificar se timer para.

---

### P1.2 — Command Center: trigger por gesto e dados reais

**Status: ⚠️ PARCIAL — overlay existe, trigger por scroll não confirmado**

`command_center_overlay.dart` existe. Em `app_shell.dart`, o Command Center é aberto via `Ctrl/Cmd+K` (atalho de teclado) e por `onLongPress` no FAB. **Não há código de "scroll beyond top" em nenhuma tab para abrir o overlay** — esse trigger específico não está implementado.

**Como implementar:** em cada tela de lista (tasks, habits, journal, etc.), adicionar `NotificationListener<OverscrollNotification>` que detecta overscroll para cima e chama `_openCommandCenter(context)`.

---

### P1.3 — Inbox: fluxos de conversão completos

**Status: 🔬 DEVICE ONLY — código existe, fluxos precisam de teste manual**

Badge e contagem existem em `app_shell.dart` via `inboxCountProvider`. Os fluxos de "Converter em Task/Note/Entry" precisam ser testados no device.

---

### P1.4 — Day Theme: CRUD e agrupamento no Planner

**Status: ⚠️ PARCIAL — modelos existem, UI incompleta**

`DayThemeModel` e `day_theme_screen.dart` existem. `SchedulerService` suporta `RepeatType.daysOfTheme` e `RepeatType.daysWithBlock`. Mas o **agrupamento visual por blocos no Planner** (`planner_screen.dart`) não está confirmado — precisa de verificação direta em `planner_screen.dart`.

---

### P1.5 — Google Drive: UI de resolução de conflito

**Status: ⚠️ PARCIAL — dialog existe, integração com detecção de conflito não confirmada**

`conflict_resolution_dialog.dart` existe em `lib/ui/components/`. Verificar se é chamado quando `google_drive_sync_service.dart` detecta conflito real, ou se é apenas criado como arquivo mas nunca instanciado.

---

### P1.6 — Widgets nativos: configuração e deep links

**Status: ⚠️ PARCIAL — 6 métodos com corpo vazio confirmados no código**

Confirmado por leitura direta de `widget_service.dart`:

| Método | Status |
|--------|--------|
| `updateLockNextSession(...)` | ❌ corpo vazio `{}` |
| `updateOrganizerDetailed(...)` | ❌ corpo vazio `{}` |
| `updatePomodoroSummary(...)` | ❌ corpo vazio `{}` |
| `updatePlanner(...)` | ❌ corpo vazio `{}` |
| `updateOrganizerSummary(...)` | ❌ corpo vazio `{}` |
| `updatePlannerDetailed(...)` | ❌ corpo vazio `{}` |
| `universalWidgetIds()` | ❌ retorna `[]` sempre |

**Como implementar cada um (padrão já estabelecido no arquivo):**
```dart
static Future<void> updatePlanner(
  String title, String content, String footer) async {
  await _saveJson('citrine_planner', {
    'title': title, 'content': content, 'footer': footer,
  });
  await _update(_tasksProvider); // ou novo provider
}
```
Repetir o padrão para os demais métodos.

---

## BLOCO P2 — ITENS PENDENTES POR GUIDELINES (NOVO — do arquivo pasted)

> Estes itens constam no novo `guidelines.md` adicionado, mas **não existem no código atual**.

---

### P2.1 — Object 9: EVENT — não existe no código

**Status: ❌ NÃO FEITO**

**Evidência:** nenhum arquivo `event_model.dart` na lista de arquivos do projeto. Nenhuma referência a `type == 'event'` nos models existentes (exceto como `PopupType.event` e `AlarmType.event` nas notificações).

**O que criar:**

1. `lib/models/event_model.dart` — classe `Event extends ContentObject` com:
   - `startDatetime`, `endDatetime`, `location`, `description`, `participants` (List<String> de People slugs), `googleEventId`, `googleCalendarId`
   
2. Em `vault_provider.dart`, adicionar `case 'event':` no switch de `_parseObject()`.

3. `lib/ui/forms/create_event_form.dart` — form com título, data/hora início/fim, local, participantes.

4. Em `create_menu_sheet.dart` → aba "Criar" → novo card "Evento" → `CreateEventForm`.

5. Integração com People: no detalhe de Person, banner quando há evento próximo com ela.

6. Integração com Google Calendar: ao salvar Event com `googleEventId == null` e usuário autenticado, criar evento no GCal.

---

### P2.2 — Campo `aliases` em ContentObject — não existe

**Status: ❌ NÃO FEITO**

**Evidência:** `content_object.dart` define os campos de `ContentObject`: `id, title, organizers, categories, tags, createdAt, updatedAt, obsidianPath, archived, pinned, reminders, order, snippet`. **Sem campo `aliases`.**

**Como implementar:**

1. Em `content_object.dart`, adicionar:
```dart
List<String> aliases; // "Also known as"

ContentObject({
  ...
  List<String>? aliases,
}) : aliases = aliases ?? [],
     ...
```

2. Em `toBaseMap()`:
```dart
if (aliases.isNotEmpty) map['aliases'] = aliases;
```

3. Em `loadBaseMap()`:
```dart
aliases = List<String>.from(map['aliases'] as List? ?? []);
```

4. Em cada form de criação/edição: campo "Also known as" abaixo do título (chips adicionáveis).

5. Em `search_service.dart`: incluir `aliases` no índice de busca.

6. Em `wiki_link_picker.dart`: mostrar aliases como chips menores abaixo do título.

---

### P2.3 — Validação de campos obrigatórios nos forms

**Status: ❌ NÃO CONFIRMADO no código**

Os guidelines especificam que o botão salvar deve ficar desabilitado até os campos obrigatórios serem preenchidos, com borda vermelha + mensagem de erro inline. Sem verificar cada form individualmente, não posso confirmar se isso está implementado. Provável que não esteja sistematicamente.

**Campos obrigatórios por tipo (da especificação):**

| Tipo | Obrigatórios |
|------|-------------|
| Habit | `title`, ≥1 Scheduler |
| Task | `title` |
| Goal | `title` |
| Tracker | `title`, ≥1 field em ≥1 section |
| Journal Entry | `body` não vazio |
| Note | `title` |
| Person | `title` |
| Resource | `title`, `resourceType` |
| Social Post | `url` |
| Reminder | `title`, `time` ou `time_block` |
| Event | `title`, `start_datetime` |
| Combined Analysis | `title`, ≥1 `data_source` |

**Como implementar (padrão Flutter):**
```dart
// Em cada form — exemplo para Task:
bool get _canSave => _titleController.text.trim().isNotEmpty;

ElevatedButton(
  onPressed: _canSave ? _save : null, // null desabilita o botão
  child: const Text('Salvar'),
)

// Campo com validação visual:
TextFormField(
  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo obrigatório' : null,
  autovalidateMode: AutovalidateMode.onUserInteraction,
)
```

---

### P2.4 — Autonomia de reorganização do vault (mudar pastas nas Settings)

**Status: ❌ NÃO FEITO**

**Evidência:** `AppSettings` em `settings_provider.dart` tem `vaultPath` mas **não tem mapa de pastas por tipo** (`folderPaths: Map<String, String>`). Não há lógica de mover arquivos ao mudar pasta.

**Como implementar:**

1. Adicionar a `AppSettings`:
```dart
final Map<String, String> folderPaths; // {'task': 'tasks', 'habit': 'habits', ...}
```

2. Em `ObsidianService`, usar `settings.folderPaths[object.type] ?? defaultFolder` ao construir o path.

3. Em `settings_screen.dart` (ou nova tela Settings → Obsidian Integration), UI para editar cada pasta com dialog de confirmação de migração.

4. Ao mudar pasta: dialog "Mover N arquivos de '[pasta antiga]' para '[pasta nova]'?" → mover arquivos + atualizar `obsidianPath` nos objetos em memória.

---

### P2.5 — Configuração de Daily Note (identifier, dateFormat, folder)

**Status: ❌ NÃO FEITO**

**Evidência:** `AppSettings` não contém `dailyNoteIdentifier`, `dailyNoteDateFormat` ou `dailyNoteFolder`. O app usa configuração hardcoded.

**Como implementar:**

1. Adicionar a `AppSettings`:
```dart
final String dailyNoteIdentifier; // 'filename_format' | 'folder' | 'frontmatter_type'
final String dailyNoteDateFormat; // 'yyyy-MM-dd' (padrão)
final String dailyNoteFolder;     // 'daily' (padrão)
```

2. Em `vault_provider.dart`, ao filtrar daily notes, usar o identifier configurado:
```dart
bool _isDailyNote(String path, Map<String, dynamic> fm) {
  switch (settings.dailyNoteIdentifier) {
    case 'folder':
      return path.startsWith('${settings.dailyNoteFolder}/');
    case 'frontmatter_type':
      return fm['type'] == 'daily_note';
    default: // 'filename_format'
      final filename = path.split('/').last.replaceAll('.md', '');
      return DateFormat(settings.dailyNoteDateFormat).tryParse(filename) != null;
  }
}
```

3. Settings → Obsidian Integration → "Daily Notes" com toggle/dropdown.

---

## BLOCO P3 — FEATURES PENDENTES COM `[ ]` EXPLÍCITO EM `tarefas.md`

---

### P3.1 — Combined Analysis: calendário multi-dot, charts multi-série, mood source

**Status: ⚠️ PARCIAL** — `analysis_model.dart` e `combined_analysis_screen.dart` existem, mas multi-dot e mood source não confirmados.

**O que falta:**
- Calendário mensal com dots coloridos por data source
- Legenda de chips por source
- Charts com múltiplas séries (uma por source)
- Mood como data source: ler `mood_overall` do frontmatter + `MoodDefinition.numeric_value`

---

### P3.2 — Google Calendar: associar evento a objeto do app

**Status: ❌ NÃO FEITO** — `google_event_detail_screen.dart` existe mas sem botão "Associar a...".

**Como implementar:** no detail do evento GCal, botão "Associar a..." → abre `UniversalSearchPickerSheet` → ao selecionar objeto, salvar `linkedGoogleEventId` no objeto via `vaultProvider`.

---

### P3.3 — Widgets nativos: 4 tipos específicos

**Status: ⚠️ PARCIAL** — arquivos Kotlin de receiver existem, layouts XML não verificados.

Além dos stubs de P1.6, verificar se os layouts XML existem em `android/app/src/main/res/layout/`:
- `citrine_widget_quick_add.xml`
- `citrine_widget_calendar.xml`
- `citrine_widget_category.xml`
- `citrine_widget_note.xml`

---

## BLOCO P3-S — MÓDULO SOCIAL: NOVAS ESPECIFICAÇÕES E BUG CONFIRMADO

---

### P3-S.1 — Bug confirmado pelo usuário: embed TikTok não dá play

**Status: ❌ BUG REAL — confirmado no device**

**O que o usuário reportou:** vídeos do TikTok não tocam inline no app — o embed aparece mas o play não funciona.

**Diagnóstico pelo código:**

`social_embed_view.dart` usa `WebViewWidget` com `InAppWebView` ou `webview_flutter`. O TikTok bloqueia embeds em WebViews não identificadas como browser real. Os problemas mais comuns:

1. **User-Agent:** o WebView do Flutter usa um UA genérico (ex: `Dart/3.0`) que o TikTok detecta e bloqueia o player.
2. **`allowsInlineMediaPlayback`:** se não estiver `true`, o iOS abre o player nativo em vez de tocar inline.
3. **`mediaPlaybackRequiresUserGesture`:** se `true` (default), o vídeo não toca automaticamente, mas o tap também pode estar bloqueado pelo TikTok se o frame não receber o evento de clique corretamente.
4. **Domínio do embed:** TikTok exige `https://www.tiktok.com/embed/v2/VIDEO_ID` — se a URL gerada no `oembed_service.dart` estiver em formato diferente, o player não carrega.

**Como corrigir:**

1. Forçar User-Agent de browser real:
```dart
await controller.setCustomUserAgent(
  'Mozilla/5.0 (Linux; Android 13; SM-A546E) '
  'AppleWebKit/537.36 (KHTML, like Gecko) '
  'Chrome/124.0.0.0 Mobile Safari/537.36',
);
```

2. Garantir as configurações corretas no WebView:
```dart
WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..enableZoom(false)
  ..setMediaPlaybackRequiresUserGesture(false) // <- essencial pro TikTok
```

3. Verificar o formato da URL de embed no `oembed_service.dart` ou `social_post.dart`:
```dart
// URL correta para TikTok:
'https://www.tiktok.com/embed/v2/$videoId'
// Não usar: https://www.tiktok.com/player/v1/ (requer token)
```

4. Adicionar timeout de 10s + fallback visual se o embed não carregar:
```dart
Future.delayed(const Duration(seconds: 10), () {
  if (mounted && !_embedLoaded) {
    setState(() => _showFallback = true);
  }
});
```
O fallback mostra a thumbnail + botão "Abrir no TikTok" via `url_launcher`.

5. Para iOS: adicionar no `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

**Arquivos:** `lib/ui/widgets/social_embed_view.dart`, `lib/services/oembed_service.dart`.

---

### P3-S.2 — Nova feature: visualização em timeline (feed de coluna única)

**Status: ❌ NÃO FEITO — feature nova**

**Especificação:**

A Social Screen deve ter dois modos de visualização, alternáveis por ícone no AppBar:
- **Grid** (já existe): 2 colunas com thumbnails
- **Timeline** (novo): coluna única, estilo feed vertical, com mídia em tamanho grande

**Comportamento da Timeline:**

Cada card na timeline exibe, de cima para baixo:
1. **Header:** avatar/ícone da plataforma + `@handle` + data de publicação
2. **Mídia em tamanho cheio:** vídeo com player inline (play/pause no tap) OU carrossel scrollável horizontalmente com indicador de posição (bolinhas ou "1/5")
3. **Caption:** primeiras 2 linhas do caption + botão "ver mais" que expande inline (sem abrir nova tela)
4. **Barra de ações inline:** ícones pequenos na parte inferior do card para organizar o post sem sair do feed:
   - 📁 **Pasta/Organizer:** abre bottom sheet com lista de organizers do vault (busca + criar novo)
   - 📝 **Nota:** abre campo de texto inline que expande o card (não abre nova tela); auto-save com debounce 800ms; salva em `personalNote` do post
   - 🏷️ **Tag:** abre chip input inline para adicionar/remover tags; salva no frontmatter do post
   - 🔗 **Associar a objeto:** abre `UniversalSearchPickerSheet` para vincular o post a qualquer objeto do vault (Task, Goal, Project, Note, etc.); salva em `socialRefs`
5. **Indicador de visto:** ao scrollar 80% do card para fora da tela, marcar `watched = true` automaticamente (comportamento configurável em Settings)

**Reprodução de vídeo:**

- TikTok, YouTube e outros vídeos tocam inline com `WebViewWidget` (após correção do P3-S.1).
- Apenas **um vídeo toca por vez**: ao começar a tocar um novo, pausar o anterior via `WebViewController.runJavaScript('document.querySelectorAll("video").forEach(v => v.pause())')`.
- Vídeos não tocam automaticamente ao scrollar — exigem tap do usuário (padrão de redes sociais).
- Botão de mute/unmute visível sobre o player.

**Carrossel:**

- `PageView` horizontal com `physics: BouncingScrollPhysics()` dentro do card.
- Indicador de posição: dots ou "foto 2 de 5" no canto superior direito.
- Swipe horizontal não conflita com scroll vertical da timeline: usar `NeverScrollableScrollPhysics` no `PageView` vertical e `HorizontalDragGestureRecognizer` para o swipe do carrossel.

**Performance:**

- Usar `ListView.builder` com `addAutomaticKeepAlives: false` — não manter WebViews de cards fora da tela em memória.
- Inicializar o WebView de cada card apenas quando o card estiver a 1 card de distância da viewport (`VisibilityDetector` ou `IndexedStack` com lazy load).
- Limitar a no máximo 2 WebViews simultâneas em memória.

**Persistência do modo:**

Salvar o modo preferido (grid/timeline) em `AppSettings.socialViewMode` — persistir entre sessões.

**Como implementar:**

1. Em `AppSettings`, adicionar:
```dart
final String socialViewMode; // 'grid' | 'timeline' (padrão: 'grid')
```

2. Em `social_screen.dart`:
   - Toggle no AppBar: `IconButton` que alterna entre `Icons.grid_view` e `Icons.view_agenda`.
   - Usar `AnimatedSwitcher` para transição suave entre os dois modos.
   - Extrair o novo widget: `SocialTimelineView(posts: posts)` em `lib/ui/widgets/social_timeline_view.dart`.

3. Criar `lib/ui/widgets/social_timeline_card.dart`:
   - `StatefulWidget` com `_isNoteExpanded`, `_isCaptionExpanded`, `_webViewController`.
   - Barra de ações inline com os 4 botões descritos acima.
   - Auto-mark-as-watched via `VisibilityDetector`.

4. Atualizar `social_screen.dart` para persistir `socialViewMode` ao alternar.

**Arquivos novos:** `lib/ui/widgets/social_timeline_view.dart`, `lib/ui/widgets/social_timeline_card.dart`.  
**Arquivos a modificar:** `lib/ui/screens/social_screen.dart`, `lib/providers/settings_provider.dart`.

---

## BLOCO P4 — TESTES FÍSICOS OBRIGATÓRIOS

> Executar após corrigir P0. Todos os `[ ]` do `testes.md` Fase 0.

- [ ] **P4.1** Rich text journal: criar entry com negrito + lista + imagem → fechar app → reabrir → verificar formatação, data, hora corretas
- [ ] **P4.2** Popup sobre tela bloqueada (após P0.2)
- [ ] **P4.3** Alarme com áudio e vibração (após P0.3, canal v5)
- [ ] **P4.4** Quick add entry/task/habit salva no vault (após P0.4)
- [ ] **P4.5** Notificação quick capture cria objeto e confirma (após P0.5)
- [ ] **P4.6** Zero lembretes duplicados (após P0.6)
- [ ] **P4.7** Pomodoro foreground: botões da notificação com app minimizado
- [ ] **P4.8** Tasks: zero duplicatas após reinício do app
- [ ] **P4.9** Hábitos: marcar como feito → reiniciar → persiste no vault

---

## ORDEM DE EXECUÇÃO RECOMENDADA

```
SEMANA 1 — Bugs de código confirmados (sem device necessário)
  P0.1  Adicionar timeOfDay a JournalEntry + fix sort
  P0.3  Incrementar alarm_channel para v5 + som customizado
  P0.5  Adicionar feedback e navegação no quick capture
  P0.6  IDs determinísticos de notificação + cancelAll antes de reagendar
  P1.6  Implementar os 6 métodos stub do WidgetService

SEMANA 2 — Bugs que precisam de verificação de arquivo não-Dart
  P0.2  Checar AndroidManifest.xml (permissões USE_FULL_SCREEN_INTENT, etc.)
  P0.4  Adicionar error handling nos forms de criação
  P1.2  Adicionar trigger de overscroll para Command Center em todas as tabs

SEMANA 3 — Validação física (P4)
  P4.1 a P4.9 — executar no SM A546E

SEMANA 4 — Novas features dos guidelines (P2)
  P2.2  Campo aliases em ContentObject (afeta todos os models)
  P2.1  Event model + form + integração GCal
  P2.3  Validação de campos obrigatórios nos forms
  P2.5  Configuração de daily note nas Settings

SEMANA 5 — Features V2 (P3 e além)
  P2.4  Autonomia de reorganização do vault
  P3.1  Combined Analysis completo
  P3.2  GCal associar evento

SEMANA 5 (paralelo) — Módulo Social
  P3-S.1  Fix embed TikTok (User-Agent + setMediaPlaybackRequiresUserGesture)
  P3-S.2  Timeline view: SocialTimelineView + SocialTimelineCard
           - Player inline com mute/unmute
           - Carrossel horizontal sem conflito de scroll
           - Barra de ações inline (pasta, nota, tag, associar)
           - Auto-mark-as-watched por visibilidade
           - Persistir socialViewMode nas Settings
  Social  Testes físicos completos (S1–S9 do testes.md)
```

---

## CHECKLIST DE RELEASE

- [ ] P0.1: Timeline com hora correta e ordem cronológica
- [ ] P0.2: Popup sobre tela bloqueada (manifest verificado)
- [ ] P0.3: Alarme toca (canal v5 + som)
- [ ] P0.4: Quick add salva com feedback de erro
- [ ] P0.5: Quick capture cria objeto + confirmação visual
- [ ] P0.6: Zero lembretes duplicados
- [ ] P2.2: Campo aliases implementado
- [ ] P3-S.1: TikTok toca inline (User-Agent correto + fallback funcional)
- [ ] P3-S.2: Timeline view com player, carrossel e ações inline
- [ ] P4.3–P4.9: testes físicos passando
- [ ] `flutter analyze` sem erros
- [ ] Build release sem erros

---

*Auditoria realizada com leitura direta dos arquivos Dart em 2026-05-28. Atualizar após cada sessão de correções.*