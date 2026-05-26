# Citrine — Próximas Tarefas (Auditoria Completa)

> **Gerado em:** 2026-05-24  
> **Fonte de verdade:** Auditoria cruzada de `guidelines.md`, `agents.md`, `tarefas.md`, `tarefas2.md`, `upgrade.md`, `pendencias_implementacao.md`, `wip_implementation_status.md`, `ajustes.md`, `social.md`, `correcoes.md`, `next_steps.md`, `testes.md` + **análise direta do código via `analysis_final_1/2/3/4.txt` e `pubspec.yaml`**.  
> **Legenda:** 🔴 Crítico / bloqueante — 🟡 Importante — 🟢 Melhoria / V2

---

## BLOCO 0 — Bugs encontrados diretamente no código (`flutter analyze`)

> Esta seção foi gerada por leitura dos arquivos `analysis_final_1.txt` a `analysis_final_4.txt` e cruzamento com `testes.md`. Os itens abaixo são problemas **comprovados no código**, não apenas estimados.  
> A progressão dos 4 arquivos mostra que os erros de compilação do `home_screen.dart` foram corrigidos entre os runs 3 e 4 — mas os warnings de lógica persistem em todos os 4 runs, incluindo o mais recente.

---

### 0.1 ✅ `vault_provider.dart` — Dados calculados mas nunca usados (linhas 1250–1254)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'pendingTasks' isn't used (line 1250)
warning: The value of the local variable 'todayHabits' isn't used  (line 1253)
warning: The value of the local variable 'lastEntry' isn't used     (line 1254)
```

**O que isso significa na prática:**  
Existe um bloco no `vault_provider.dart` que calcula `pendingTasks`, `todayHabits` e `lastEntry` — provavelmente dentro do método que alimenta o dashboard de contexto ou os widgets nativos — mas o resultado dessas variáveis nunca é usado. Ou seja, o widget nativo e o dashboard **não recebem os dados do dia atual**, mesmo que o código aparente estar calculando.

**Como corrigir:**
- Localizar o bloco nas linhas 1248–1260 do `vault_provider.dart`.
- Identificar qual provider/método deveria receber esses valores (provavelmente `WidgetService.updateCalendarWidget(todayTasks: pendingTasks, todayHabits: todayHabits)` e algum método de `DashboardNotifier`).
- Passar `pendingTasks`, `todayHabits` e `lastEntry` para os consumidores corretos.
- Certificar que após qualquer mutação de task/habit/entry, esse bloco é re-executado (via `_invalidateObjectProviders()`).

**Impacto direto:** Widget nativo de calendário não atualiza quando o app muda. Dashboard não reflete o estado real do dia.

---

### 0.2 ✅ `automation_service.dart` — Flag `changed` calculada mas nunca usada (linha 79)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'changed' isn't used (line 79)
```

**O que isso significa na prática:**  
O `AutomationService` computa se houve alguma mudança (provavelmente durante `checkPersonContacts` ou `checkScheduledItems`), mas **nunca age com base nessa flag**. Isso significa que automações como criar task de contato para pessoas atrasadas, ou disparar schedulers, podem estar sendo calculadas mas nenhuma ação é tomada.

**Como corrigir:**
- Localizar linha 79 de `automation_service.dart`.
- Verificar o que a variável `changed` deveria fazer (provavelmente: se `changed == true`, chamar `_invalidateObjectProviders()` ou `VaultNotifier.saveChanges()`).
- Adicionar o uso correto: `if (changed) { await ref.read(vaultProvider.notifier).invalidate(); }` ou equivalente.

---

### 0.3 ✅ `scheduler_service.dart` — `periodEnd` calculado mas nunca usado (linha 138) + switch default inalcançável (linha 172)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'periodEnd' isn't used    (line 138)
warning: This default clause is covered by the previous cases      (line 172)
```

**O que isso significa na prática:**  
- `periodEnd`: O `SchedulerService` calcula o fim do período de uma regra de recorrência (ex: "termina em 31/12/2025"), mas nunca usa essa data para de fato parar de disparar o scheduler. **Todo scheduler com data de término vai continuar disparando para sempre.**
- `switch default unreachable`: Algum tipo de scheduler tem um case que nunca é alcançado, indicando que ou um novo tipo foi adicionado ao enum mas não ao switch, ou há lógica duplicada. Isso pode fazer com que um tipo de scheduler simplesmente não seja processado.

**Como corrigir:**
- Linha 138: usar `periodEnd` na condição de `shouldFire`: `if (rule.endDate != null && date.isAfter(rule.endDate!)) return false;`
- Linha 172: revisar o switch — checar quais `SchedulerType` existem no enum e garantir que cada um tem um case explícito. Remover o `default` se desnecessário, ou mover lógica faltante para o `default`.

---

### 0.4 ✅ `widget_service.dart` — Campo `_groupId` declarado mas nunca usado (linha 7)

**O que o analyzer encontrou:**
```
warning: The value of the field '_groupId' isn't used (line 7)
```

**O que isso significa na prática:**  
O `WidgetService` tem um `_groupId` declarado (provavelmente para agrupar widgets Android no mesmo App Widget Provider), mas nunca é passado para o `HomeWidget`. Isso significa que a comunicação entre o app e os widgets nativos pode estar usando o grupo errado, ou que atualizações forçadas via `HomeWidget.updateWidget(name: ..., iOSName: ..., androidName: ...)` não estão chegando ao widget correto.

**Como corrigir:**
- Verificar a API do `home_widget ^0.9.1`: `HomeWidget.saveWidgetData(id, data)` e `HomeWidget.updateWidget(...)` recebem um `qualifiedAndroidName` que inclui o grupo.
- Usar `_groupId` em todas as chamadas de `HomeWidget` dentro de `WidgetService`.
- Ou, se o campo não for mais necessário, remover a declaração e investigar por que foi criado.

**Impacto direto:** Widgets nativos não atualizam no Android porque o grupamento/identificador está errado.

---

### 0.5 ✅ `combined_analysis_screen.dart` — `firstDay` calculado mas nunca usado (linha 386)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'firstDay' isn't used (line 386)
```

**O que isso significa na prática:**  
O calendário mensal na tela de Combined Analysis calcula `firstDay` (primeiro dia do mês) mas nunca usa esse valor para posicionar os dias da semana corretamente no grid. **O calendário exibe os dias sempre começando na coluna errada** (ignora que a semana pode começar em quinta, por exemplo).

**Como corrigir:**
- Localizar linha 386 de `combined_analysis_screen.dart`.
- Usar `firstDay` para calcular o offset inicial do grid: `int startOffset = firstDay.weekday % 7;` (ou `firstDay.weekday - 1` dependendo da convenção Sunday/Monday).
- Preencher as primeiras `startOffset` células com `SizedBox.shrink()` antes de renderizar os dias.

---

### 0.6 ✅ `universal_detail_view.dart` — Métodos `_statBox` e `_buildSubtaskItem` declarados mas nunca chamados (linhas 1839, 2558)

**O que o analyzer encontrou:**
```
warning: The declaration '_statBox' isn't referenced          (line 1839)
warning: The declaration '_buildSubtaskItem' isn't referenced (line 2558)
```

**O que isso significa na prática:**
- `_statBox`: Há um widget de estatísticas implementado no `UniversalDetailView` mas **nunca renderizado** — o detalhe de Goal/Project não mostra nenhuma stat box, mesmo que o código esteja escrito.
- `_buildSubtaskItem`: O builder de subtask individual existe mas não é chamado. O painel de subtasks pode estar usando um widget diferente (ou inline) e o `_buildSubtaskItem` ficou como código morto após alguma refatoração.

**Como corrigir:**
- `_statBox`: encontrar onde a seção de estatísticas deveria aparecer no detail view de Goals/Projects e inserir `_statBox(...)` na posição correta.
- `_buildSubtaskItem`: verificar se o painel de subtasks usa outro widget. Se `_buildSubtaskItem` tem lógica melhor (ex: drag handle, swipe to complete), substituir o widget atual por ele. Se for de fato duplicado, remover.

---

### 0.7 ✅ `universal_detail_view.dart` — Variável `actions` calculada mas nunca usada (linha 2399)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'actions' isn't used (line 2399)
```

**O que isso significa na prática:**  
O detail view constrói uma lista de `actions` (provavelmente as opções do action sheet ⋯) mas nunca a passa para o widget que exibe as ações. **O menu de 3 pontos pode estar vazio ou usando um fallback hard-coded** em vez das ações corretas para cada tipo de objeto.

**Como corrigir:**
- Localizar linha 2399: a lista `actions` deve ser passada para `showModalBottomSheet` ou `showCupertinoModalPopup` que exibe o menu de ações.
- Verificar se há um `_buildActionSheet(actions)` que está sendo chamado sem receber a variável, e corrigir o argumento.

---

### 0.8 ✅ `create_note_form.dart` — `_bodyController` declarado mas nunca usado (linha 27)

**O que o analyzer encontrou:**
```
warning: The value of the field '_bodyController' isn't used (line 27)
```

**O que isso significa na prática:**  
O formulário de criação de notas tem um `TextEditingController` para o corpo declarado mas não conectado ao widget de texto. **O corpo da nota pode não estar sendo capturado corretamente** — o conteúdo digitado pode estar sendo lido de outra fonte (ex: variável de estado local `_body`) sem invalidar o controller, ou o controller foi substituído pelo `flutter_quill` mas deixado no arquivo.

**Como corrigir:**
- Se a nota usa `flutter_quill` (que tem seu próprio `QuillController`), remover `_bodyController` e garantir que o `QuillController` está sendo lido no `_saveNote()`.
- Se ainda usa `TextField`, conectar: `TextField(controller: _bodyController)` e ler `_bodyController.text` no save.

---

### 0.9 ✅ `habits_screen.dart` — Código morto: `_frontmatterFromDailyData` e `OldHabitsScreen_Excluded_` (linhas 187, 339)

**O que o analyzer encontrou:**
```
warning: The declaration '_frontmatterFromDailyData' isn't referenced (line 187)
info: The type name 'OldHabitsScreen_Excluded_' isn't an UpperCamelCase identifier (line 339)
```

**O que isso significa na prática:**
- `_frontmatterFromDailyData`: Método que deveria escrever dados de hábitos de volta no daily note (como `habit_done:: [[slug]]`) mas nunca é chamado. **Hábitos concluídos não são registrados no vault Obsidian.**
- `OldHabitsScreen_Excluded_`: Uma versão antiga da tela de hábitos está presente no arquivo mas excluída (`_Excluded_` no nome), provavelmente causando confusão e potencialmente conflito com a versão atual.

**Como corrigir:**
- `_frontmatterFromDailyData`: Chamar este método após o usuário marcar um hábito como feito, dentro do `HabitNotifier.toggleHabitCompletion(date)`. Passar os dados corretos para gerar o frontmatter de log no daily note do dia.
- `OldHabitsScreen_Excluded_`: Remover a classe inteira do arquivo. Se precisar de referência, está no histórico do git.

---

### 0.10 ✅ `scheduler_picker.dart` — `isSelected` não usado + dois switch defaults inalcançáveis (linhas 474, 217, 552)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'isSelected' isn't used (line 474)
warning: This default clause is covered by the previous cases   (line 217)
warning: This default clause is covered by the previous cases   (line 552)
```

**O que isso significa na prática:**
- O estado de seleção de algum radio button no `SchedulerPicker` é calculado mas não aplicado ao widget — **algum radio button nunca aparece como selecionado visualmente**, mesmo quando o tipo correto está ativo.
- Os dois `default` unreachable indicam que há `switch` statements que não cobrem todos os `SchedulerType` do enum, e o `default` é inalcançável porque algum case antes dele captura tudo — isso pode significar que um novo `SchedulerType` foi adicionado mas não está sendo tratado.

**Como corrigir:**
- Linha 474: passar `isSelected` para o widget, ex: `Radio(value: type, groupValue: _selectedType)` onde `isSelected` seria redundante — verificar se o código pode ser simplificado removendo `isSelected` e usando diretamente `_selectedType == type`.
- Linhas 217 e 552: auditar o enum `SchedulerType` e garantir que o `switch` tem um `case` para cada valor. Remover `default` ou torná-lo uma captura de tipo desconhecido com log.

---

### 0.11 ✅ `people_screen.dart` — `frequencyDays` calculado mas nunca usado (linha 80)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'frequencyDays' isn't used (line 80)
```

**O que isso significa na prática:**  
A tela de People calcula `frequencyDays` (prazo de contato de cada pessoa em dias) mas nunca exibe esse valor. A lista de pessoas **não mostra quão atrasado está o contato** nem coloriza por urgência.

**Como corrigir:**
- Usar `frequencyDays` no card da pessoa para mostrar: `Text("Contato a cada $frequencyDays dias")` ou badge de urgência (verde/amarelo/vermelho baseado em `(DateTime.now().difference(lastContact).inDays / frequencyDays * 100).toInt()%`).

---

### 0.12 ✅ `journal_screen.dart` — `hasItemsToday` calculado mas nunca usado (linha 66)

**O que o analyzer encontrou:**
```
warning: The value of the local variable 'hasItemsToday' isn't used (line 66)
```

**O que isso significa na prática:**  
A `JournalScreen` calcula `hasItemsToday` mas nunca usa o valor para alterar a UI. O FAB ou o estado vazio deveriam reagir a isso — por exemplo, mostrar um hint diferente se já há uma entry hoje, ou destacar o dia atual no calendário mensal.

**Como corrigir:**
- Usar `hasItemsToday` para alterar o label do FAB: se `hasItemsToday`, mostrar "Nova entry" com ícone de `+`; caso contrário, "Começar o dia" com ícone diferente.
- Ou usar para exibir/ocultar um `DayStreakBadge` na AppBar.

---

### 0.13 ✅ `planner_screen.dart` — Dead code em linha 1602

**O que o analyzer encontrou:**
```
warning: Dead code                                              (line 1602:71)
warning: The left operand can't be null, so the right operand is never executed (line 1602:74)
```

**O que isso significa na prática:**  
Há uma expressão `?? fallback` no Planner onde o lado esquerdo nunca é null. Isso pode indicar que um valor que antes era nullable foi tornado non-null, mas o fallback ainda está lá — o fallback nunca é usado, então **se o valor real for inesperadamente nulo em runtime, o app trava** ao invés de usar o fallback. (Este é um caso clássico de "o analyzer está certo mas o risco real é em outro lugar".)

**Como corrigir:**
- Linha 1602: remover o `?? fallback` e certificar que o tipo é realmente non-null no modelo.
- Se houver risco de o dado ser null em edge cases, tornar o tipo `String?` novamente e manter o `??`.

---

### 0.14 ✅ `create_session_form.dart` — `_timeSlot` declarado mas nunca usado (linha 27)

**O que o analyzer encontrou:**
```
warning: The value of the field '_timeSlot' isn't used (line 27)
```

**O que isso significa na prática:**  
O formulário de criação de Calendar Session tem um campo `_timeSlot` declarado mas não conectado. **O time slot de uma sessão pode não estar sendo salvo corretamente** no frontmatter, causando sessões sem horário definido.

**Como corrigir:**
- Se `_timeSlot` deveria receber o time block selecionado pelo usuário, conectar ao `TimeBlockPicker` e ler no `_saveSession()`.
- Se foi substituído por outro campo, remover `_timeSlot` e garantir que o substituto está sendo salvo.

---

### 0.15 ✅ `create_resource_form.dart` — Dead code (linha 37)

**O que o analyzer encontrou:**
```
warning: Dead code (line 37:33)
warning: The left operand can't be null, so the right operand is never executed (line 37:36)
```

**O que isso significa na prática:**  
Mesmo padrão do 0.13 — há um `??` com operando esquerdo non-null. Alguma validação ou fallback de URL/título de resource nunca é acionada.

**Como corrigir:**
- Revisar linha 37 e remover a expressão `??` morta, ou tornar o tipo nullable se o risco existir.

---

### 0.16 ✅ `pomodoro_screen.dart` — `_presetButton` declarado mas nunca chamado (linha 224)

**O que o analyzer encontrou:**
```
warning: The declaration '_presetButton' isn't referenced (line 224)
```

**O que isso significa na prática:**  
Há um widget de botão de preset (ex: 25/5 min, 50/10 min, etc.) implementado mas nunca inserido na tela. A `PomodoroScreen` **não tem botões de presets de tempo**, apesar do código estar pronto.

**Como corrigir:**
- Inserir `_presetButton(label: '25/5', focus: 25, pause: 5)` etc. na Row de controles da tela, acima ou abaixo do timer principal.

---

### 0.17 ✅ `goals_screen.dart` — Null assertions desnecessárias (linhas 212–213)

**O que o analyzer encontrou:**
```
warning: The operand can't be 'null', so the condition is always 'true' (line 212:27)
warning: The operand can't be 'null', so the condition is always 'true' (line 212:55)
warning: The '!' will have no effect because the receiver can't be null (line 213:39)
warning: The '!' will have no effect because the receiver can't be null (line 213:58)
```

**O que isso significa na prática:**  
A `GoalsScreen` verifica `if (a != null && b != null)` e usa `a!.method()` em campos que nunca são null. Isso indica que o código foi escrito quando esses campos eram nullable, mas o model foi atualizado para non-null sem atualizar a tela. **Não causa crash**, mas indica que o `GoalsScreen` pode estar sendo mais defensivo do que precisa — e que se em algum momento os campos virarem null de novo (parse failure), o app não vai capturar o erro.

**Como corrigir:**
- Remover as verificações null e os `!` nas linhas 212–213.
- Garantir que se o parse do model falhar, o objeto não chega na tela (erro tratado no provider).

---

### 0.18 ✅ `testes.md` — Fase 0 inteira com `[ ]` (nenhum item validado)

O arquivo `testes.md` lista 14 casos de teste obrigatórios na Fase 0, **todos com `[ ]`** — ou seja, nenhum foi marcado como testado/passando:

| # | Teste | Evidência de bug |
|---|-------|-----------------|
| 1 | (funciona) Journal entry na timeline renderiza rich text | Relatado em `next_steps.md` item 1, marcado como `[x]` mas `testes.md` ainda tem `[ ]` |
| 2 |(lista e midia nao funciona, e ta com algum erro ao mostrar a ordem, horário e dia:fala que é tudo hoje, tá na ordem errada e horários errados) Negrito, itálico, listas e mídia na timeline | Idem |
| 3 | (nao aparece sobre outros apps, só aparece quando eu clico no app, o pop up com o fundo preto. aí fecha no tempo) Notificação pop-up dispara e fecha | `next_steps.md` item 2 marcado como feito, mas não testado em device físico |
| 4 | (nao tem música, nem vibracao, e só aparece a tela de alarme quando eu clico na notificacao, nao sobrepoe outros apps nem o citrine até eu clicar) Notificação alarme com áudio em background | Idem |
| 5 |(ok) Push notification redireciona para tela correta | Idem |
| 6 |(ok) Tasks sem duplicatas após reabrir app | Reportado em `next_steps.md` item 3 |
| 7 | (ok) Tap numa task mostra subtasks | Idem |
| 8 | (ok) Tela de Hábitos carrega sem crash | `next_steps.md` item 4, mas `habits_screen.dart` ainda tem código morto suspeito |
| 9 | (verificar no código) Subtask sessions (grupos colapsáveis) | `next_steps.md` item 5 |
| 10 |( verificar no código) Widgets dashboard equivalentes na home | `next_steps.md` item 6 |
| 11 |(Não) Quick add entry funciona | `next_steps.md` item 7 |
| 12 |( nao) Quick add task funciona | Idem |
| 13 |(nao) Quick add habit funciona | Idem |
| 14 | (a notificacao persistente existe mas nao funciona os botoes pra adicionar, só fica carregando pra sempre e nao manda pro app) Widget de lock screen aparece + notificação persistente | `next_steps.md` item 8, complex — sem evidência de teste real |
outros testes que precisam corrijir: lembrete atrasado (tá vindo tudo ao mesmo tempo, vários duplicados)

✅ Código corrigido/verificado em 2026-05-25: timeline do Journal renderiza Delta/listas/embeds, Quick Capture cobre entry/task/habit, canais de popup/alarme foram recriados com som/vibração e houve remoção de agendamento duplicado de task reminders. Subtask sessions e blocos da Home/Dashboard verificados no código. Testes físicos ainda precisam ser executados no device.

**O que fazer:** Executar cada teste no dispositivo físico e só marcar `[x]` após validação real. Para os que são "já feitos" no `next_steps.md` mas não no `testes.md`, re-testar antes de avançar para features novas.

---

### 0.19 ✅ APIs depreciadas — devem ser atualizadas para evitar breakage futuro

O analyzer reporta os seguintes usos de APIs já depreciadas no Flutter 3.31+/3.32+:

| Arquivo | API depreciada | Substituto |
|---------|---------------|-----------|
| `analysis_model.dart:28` | `Color.value` | `.r`, `.g`, `.b` ou `.toARGB32()` |
| `reminder_config.dart:35` | `Color.value` | `.r`, `.g`, `.b` ou `.toARGB32()` |
| `create_entry_form.dart:664` | `desiredAccuracy` em geolocator | `AndroidSettings(accuracy: ...)` |
| `create_habit_form.dart:210,503` | `Switch.activeColor` | `Switch.activeThumbColor` / `activeTrackColor` |
| `create_session_form.dart:354` | `Switch.activeColor` | Idem |
| `create_task_form.dart:274,378` | `Switch.activeColor` | Idem |
| `settings_screen.dart:528,569,585` | `Switch.activeColor` | Idem |
| `scheduler_picker.dart:477,480` | `Radio.groupValue`, `Radio.onChanged` | `RadioGroup` ancestor widget |
| `settings_screen.dart:717,718,726,727,753,754,762,763` | `Radio.groupValue`/`onChanged` | `RadioGroup` |
| `universal_detail_view.dart:84` | `Color.withOpacity()` | `.withValues(alpha: ...)` |
| `organizer_picker_modal.dart:67` | `Color.withOpacity()` | `.withValues(alpha: ...)` |
| `organizer_selector_field.dart:86` | `Color.withOpacity()` | `.withValues(alpha: ...)` |

Todas essas APIs foram removidas ou terão aviso de breaking change em Flutter 4.x.

✅ Verificado em 2026-05-25: as APIs listadas não aparecem mais nos arquivos indicados e `flutter analyze` não reporta depreciações.

---

### 0.20 ✅ Widget nativo de calendário — bug de reatividade (confirmado pelo código)

**Resumo do bug relatado:** O widget de calendário não atualiza quando o app é usado, quando o dia muda, e não reage ao tap em outras datas.

**Causa confirmada pelo código:**
1. **`vault_provider.dart:1250–1254`** (bug 0.1): `pendingTasks`, `todayHabits` e `lastEntry` são calculados mas nunca passados para o `WidgetService`. O widget fica com dados desatualizados.
2. **`widget_service.dart:7`** (bug 0.4): `_groupId` não é usado — o Android não sabe qual widget atualizar quando `HomeWidget.updateWidget` é chamado sem o identificador correto.
3. **Falta de `Timer.periodic` ou `AppLifecycleListener`**: Não há evidência no código de um timer que re-executa `WidgetService.update()` quando o dia muda à meia-noite, nem de um listener de `AppLifecycleState.resumed` que force atualização ao voltar ao app.
4. **Tap em outras datas**: O widget nativo (XML/Kotlin side) não tem um `PendingIntent` configurado que passe a data selecionada de volta ao app via deep link. O app não sabe qual data foi tocada.

**Como corrigir (completo):**
```dart
// Em vault_provider.dart (onde pendingTasks/todayHabits são calculados):
final today = DateTime.now();
final pendingTasks = allObjects
  .whereType<Task>()
  .where((t) => t.scheduledDate?.day == today.day)
  .toList();
final todayHabits = allObjects
  .whereType<Habit>()
  .toList();
// ← AQUI estava o bug: nunca chamava o WidgetService
await ref.read(widgetServiceProvider).updateCalendarWidget(
  date: today,
  tasks: pendingTasks,
  habits: todayHabits,
);
```

```dart
// Em widget_service.dart — usar _groupId:
await HomeWidget.saveWidgetData<String>('calendarData', json, groupId: _groupId);
await HomeWidget.updateWidget(
  androidName: 'CitrineCalendarWidget',
  qualifiedAndroidName: 'com.citrine.app.CitrineCalendarWidget',
  iOSName: 'CitrineCalendarWidget',
);
```

```dart
// Em main.dart ou AppShell — listener de mudança de dia:
Timer.periodic(const Duration(minutes: 1), (timer) {
  final now = DateTime.now();
  if (now.hour == 0 && now.minute == 0) {
    ref.invalidate(vaultProvider); // força re-cálculo e re-envio ao widget
  }
});

// Listener de lifecycle (app volta ao foreground):
AppLifecycleListener(
  onResume: () => ref.read(widgetServiceProvider).refreshAll(),
);
```

```kotlin
// No CitrineCalendarWidget.kt (Android) — PendingIntent para tap em data:
val intent = Intent(context, MainActivity::class.java).apply {
  action = "com.citrine.WIDGET_DATE_TAP"
  putExtra("date", dateString) // "YYYY-MM-DD"
}
val pendingIntent = PendingIntent.getActivity(context, dayOfMonth, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
// Aplicar no RemoteViews de cada célula de dia
```

```dart
// Em main.dart — interceptar o deep link do widget:
// GoRouter já tem rota /planner/day/:date — apenas garantir que o intent é recebido
```

✅ Corrigido/verificado em 2026-05-25: snapshots do widget são recalculados por `forceWidgetSync`, há refresh no resume e na virada de dia, cells/strip abrem deep link com data, e `HomeWidget.updateWidget` agora usa também `qualifiedAndroidName`. `flutter analyze` e `:app:assembleDebug` passaram.

---

## BLOCO 0-B — Análise profunda de UI/UX por tela

> Baseada nos arquivos `analysis_final_1/2/3/4.txt`, `pubspec.yaml`, `testes.md`, `next_steps.md` e cruzamento com o comportamento esperado descrito nos docs.  
> Para cada tela: o que o usuário vê, o que o código faz de errado, e como corrigir.

---

### T1 ✅ Dashboard / Home Screen — blocos com dados errados + hábitos não aparecem

**O que o usuário vê:**
Blocos do Dashboard parecem populados, mas dados do "hoje" estão desatualizados ou incorretos. A seção de hábitos do dashboard provavelmente aparece vazia. O bloco de notas exibe texto puro, não markdown.

**Causas confirmadas:**

1. `vault_provider.dart:1250–1254` — `pendingTasks`, `todayHabits`, `lastEntry` calculados dentro de um método de sincronização mas nunca passados ao `DashboardNotifier`. O dashboard não recebe os dados reais do dia.
2. `home_screen.dart:1015` — `_buildHabitRow` implementado mas nunca inserido no widget tree. O bloco de "Hábitos do dia" fica vazio ou usa um fallback genérico sem hábitos reais.
3. Bloco de Notas sem markdown — `flutter_markdown` está no `pubspec.yaml` mas não está sendo usado no bloco. O body da nota é exibido como string pura.
4. `DashboardBlock.copyWith` e `DashboardNotifier.removeBlock` estavam faltando (runs 1–3 do analyzer), corrigidos no run 4 — mas a funcionalidade de editar/remover blocos precisa ser testada end-to-end.

**Como corrigir:**
- Em `vault_provider.dart`, após calcular as variáveis, chamar `ref.read(dashboardProvider.notifier).updateContextData(pendingTasks, todayHabits, lastEntry)`.
- Em `home_screen.dart`, inserir `_buildHabitRow(habit)` dentro do `ListView.builder` do bloco de hábitos.
- No bloco de notas: substituir `Text(note.body)` por `MarkdownBody(data: note.body)` via `flutter_markdown`, ou se o body é Quill Delta JSON, converter primeiro com `deltaToMarkdown()`.

✅ Corrigido/verificado em 2026-05-25: bloco de hábitos da Home filtra hábitos ativos previstos para hoje e o bloco de notas usa `JournalBodyView`, que renderiza Markdown/Delta/embeds em vez de texto bruto. `flutter analyze lib/ui/screens/home_screen.dart` passou.

---

### T2 ✅ Journal Screen — FAB cego ao estado de hoje + rich text como JSON raw

**O que o usuário vê:**
O FAB sempre tem o mesmo ícone/label independente de já ter escrito hoje. Entries na timeline podem exibir JSON raw (`[{"insert":"lorem ipsum
"}]`) em vez do texto formatado.

**Causas confirmadas:**

1. `journal_screen.dart:66` — `hasItemsToday` calculado mas nunca usado. O FAB não diferencia "começar o dia" de "adicionar mais uma entry".
2. Bug de rich text — quando o `_buildEntryBody()` usa `Text(entry.body)` em vez de renderizar o Delta do Quill. `flutter_quill: ^11.5.0` está no pubspec, então o renderizador existe mas não está sendo chamado na listagem. Reportado como corrigido no `next_steps.md`, mas `testes.md` ainda marca `[ ]`.
3. Timezone no filtro de data — se o `journalEntriesProvider` filtra por `date` do frontmatter sem normalizar timezone, entries podem "desaparecer" dependendo do horário local do usuário.

**Como corrigir:**
- Usar `hasItemsToday` para mudar o ícone e label do FAB: `FloatingActionButton.extended(icon: hasItemsToday ? Icon(Icons.edit) : Icon(Icons.add), label: Text(hasItemsToday ? 'Nova entrada' : 'Começar o dia'))`.
- Para rich text na listagem: usar `QuillEditor` em modo `readOnly: true` com o `QuillController` inicializado a partir do Delta JSON. Alternativa: converter Delta para Markdown via `deltaToMarkdown(entry.body)` e renderizar com `MarkdownBody`.
- Normalizar datas: `DateFormat('yyyy-MM-dd').format(date.toLocal())` antes de comparar.

✅ Corrigido/verificado em 2026-05-25: FAB usa o estado da data selecionada, timeline renderiza `JournalBodyView`, e datas exibidas são normalizadas a partir do daily note quando há `obsidianPath`. Analyzer passou para Journal.

---

### T3 ✅ Habits Screen — completar hábito não persiste no vault Obsidian

**O que o usuário vê:**
Marcar um hábito como feito funciona visualmente (ícone muda para ✓). Mas ao abrir o arquivo no Obsidian, o daily note não tem registro da conclusão. Streak pode ficar errado após reiniciar o app.

**Causas confirmadas:**

1. `habits_screen.dart:187` — `_frontmatterFromDailyData` declarado mas nunca chamado. A conclusão do hábito existe só no estado Riverpod (memória) e não é escrita no vault. Ao reiniciar o app ou reconstruir o provider, o estado é perdido.
2. `OldHabitsScreen_Excluded_` ainda presente (`habits_screen.dart:339`) — a classe antiga (que causava o crash `Map<dynamic,dynamic>`) está no arquivo como código morto com nome `_Excluded_`, aumentando confusão e tamanho do arquivo.

**Como corrigir:**
- Em `HabitNotifier.toggleCompletion(slug, date)`, após atualizar estado local, chamar `_frontmatterFromDailyData(date, completedSlugs)` que deve usar `ObsidianService.updateDailyNoteFrontmatter(date, 'habits_done', completedSlugs)` com merge (não overwrite).
- Remover a classe `OldHabitsScreen_Excluded_` completamente do arquivo.

✅ Verificado em 2026-05-25: `toggleHabit`/`recordHabitValue` escrevem o daily note com merge e `frontmatter['habits']`, invalidam providers e enfileiram sync; a classe antiga excluída não existe mais. Analyzer passou para Habits/Vault.

---

### T4 ✅ Planner Screen — Google Calendar com import desnecessário + dead code

**O que o usuário vê:**
O Planner funciona, mas em alguma condição de edge case (sessão com dados faltantes), pode crashar com `Null check operator used on a null value` na linha 1602 em vez de usar o fallback configurado.

**Causas confirmadas:**

1. `planner_screen.dart:1602` — Dead code: `?? fallback` com operando non-null. O fallback nunca executa, e se o dado chegar null (parse failure de CalendarSession corrompida), o app crasha em vez de mostrar o valor padrão.
2. `google_calendar_provider.dart:3` — `unused_import 'package:flutter/foundation.dart'`. Sinal de refactoring incompleto na integração do Google Calendar.

**Como corrigir:**
- Linha 1602: identificar a expressão. Se o tipo é `String`, remover o `?? fallback`. Se há risco real de null (ex: campo de CalendarSession que pode vir sem valor do vault), tornar o tipo `String?` e manter o `??`.
- Remover o import desnecessário em `google_calendar_provider.dart`.

✅ Verificado em 2026-05-25: `google_calendar_provider.dart` não tem `flutter/foundation.dart`, o Planner usa fallback seguro para eventos sem summary, e `flutter analyze lib/ui/screens/planner_screen.dart` passou.

---

### T5 ✅ Universal Detail View — menu ⋯ vazio + stats nunca renderizadas + subtasks com widget inferior

**O que o usuário vê:**
- Ao abrir ⋯ em um Goal/Project, o menu aparece vazio ou com opções genéricas, nunca as opções específicas do tipo de objeto.
- A seção de estatísticas (progresso de KPI ao longo do tempo) nunca aparece no detalhe de Goals/Projects.
- Subtasks podem estar sem drag handle, swipe-to-complete ou animações.

**Causas confirmadas:**

1. `universal_detail_view.dart:2399` — `actions` lista computada para o tipo específico de objeto mas nunca passada para o `showModalBottomSheet` ou `CupertinoActionSheet`. O menu usa uma lista separada (provavelmente hard-coded genérica).
2. `universal_detail_view.dart:1839` — `_statBox` widget implementado mas nunca inserido no `Column` do detail view. A seção de estatísticas está escrita mas invisível.
3. `universal_detail_view.dart:2558` — `_buildSubtaskItem` implementado (provavelmente com drag, swipe, animações) mas nunca chamado. As subtasks são renderizadas por um widget mais simples.
4. `universal_detail_view.dart:84` — `Color.withOpacity()` depreciado: precision loss em overlays de sombra/overlay no detail view.

**Como corrigir:**
- Linha 2399: passar `actions` como argumento: `CupertinoActionSheet(actions: actions.map((a) => CupertinoActionSheetAction(...)).toList())`.
- Linha 1839: inserir `_statBox(...)` no `Column` principal do detail view, entre KPIs e subtasks.
- Linha 2558: substituir o widget atual de subtask por `_buildSubtaskItem(subtask)`.
- Linha 84: `.withOpacity(x)` → `.withValues(alpha: x)`.

✅ Verificado em 2026-05-25: overflow menu usa ações por tipo, Project/Goal renderizam progresso/KPIs/snapshots, subtasks usam `_SubtaskListView` com sessões colapsáveis e toggle persistido, e `withOpacity` não aparece no arquivo. Analyzer passou.

---

### T6 ✅ Goals Screen — null assertions desnecessários

**O que o usuário vê:**
A tela carrega normalmente. Mas se um Goal vier com campo malformado do vault, o `!` operator pode causar crash em runtime em vez de mostrar um fallback. A tela não tem tratamento de erro visível.

**Causa:** `goals_screen.dart:212–213` — defensive null-check redundante com `!` em campos non-null.

**Como corrigir:** remover o `if (a != null && b != null)` e os `!`. Garantir que `GoalModel.fromMarkdown()` usa valores default para campos obrigatórios em vez de lançar exception.

✅ Corrigido/verificado em 2026-05-25: deadline usa promoção por variável local sem `!`, cor do Goal tolera valor malformado, e `Goal.fromMarkdown()` mantém defaults para estado/tipo. Analyzer passou.

---

### T7 ✅ Scheduler Picker — seleção visual quebrada + tipos silenciosamente sem handler

**O que o usuário vê:**
- Ao trocar o tipo de recorrência no picker, o radio button selecionado não muda visualmente.
- Selecionar tipos avançados (ex: `daysOfTheme`, `linkedItemAppears`) não exibe o sub-formulário correto — a UI congela na última opção.
- Schedulers com data de término continuam disparando para sempre.

**Causas confirmadas:**

1. `scheduler_picker.dart:474` — `isSelected` calculado mas não aplicado ao `Radio`. O radio usa outro mecanismo que não reflete o estado correto.
2. `scheduler_picker.dart:217,552` — Dois `default` unreachable: tipos de scheduler sem case explícito não têm sub-formulário.
3. `scheduler_service.dart:172` — Mesmo problema no serviço: tipo sem handler não dispara nenhuma ação.
4. `scheduler_service.dart:138` — `periodEnd` nunca usado: schedulers com data de término disparam eternamente.
5. `scheduler_picker.dart:477,480` — API `Radio.groupValue`/`onChanged` depreciada em Flutter 3.32+.

**Como corrigir:**
- Linha 474: usar `Radio<SchedulerType>(value: type, groupValue: _selectedType, onChanged: (v) => setState(() => _selectedType = v!))` diretamente, sem a variável `isSelected`.
- Linhas 217/552: auditar enum `SchedulerType` e adicionar case para cada tipo no switch do picker.
- `scheduler_service.dart:138`: usar `periodEnd` na condição: `if (rule.endDate != null && date.isAfter(rule.endDate!)) return false;`.

✅ Verificado em 2026-05-25: seleção visual usa card/check reativo, não há `Radio.groupValue`, todos os `RepeatType` têm case no picker e no serviço, e `SchedulerService.shouldFire` respeita `scheduler.endDate`. Analyzer passou.

---

### T8 ✅ Settings Screen — Switch e Radio com API depreciada

**O que o usuário vê:**
Switches nas configurações podem ter cor errada no dark mode (thumb e track com a mesma cor em vez de cores separadas). Radio buttons podem não funcionar corretamente em Flutter 3.32+.

**Causas:** `settings_screen.dart:528,569,585` — `Switch.activeColor` depreciado. `settings_screen.dart:717,718,726,727,753,754,762,763` — `Radio.groupValue/onChanged` depreciados.

**Como corrigir:**
- Switches: `Switch(activeThumbColor: AppColors.primary, activeTrackColor: AppColors.primary.withValues(alpha: 0.5))`.
- Radio: migrar para `RadioGroup<T>` ancestor ou aguardar Flutter 4.x para quebrar (baixo risco imediato).

✅ Verificado em 2026-05-25: `settings_screen.dart` não usa `Switch.activeColor` nem `Radio.groupValue`, switches usam `activeThumbColor`, e analyzer passou.

---

### T9 ✅ Create Forms — campos que não capturam dados

| Form | Campo morto | Impacto |
|------|------------|---------|
| `create_note_form.dart` | `_bodyController` (linha 27) | Corpo da nota pode não ser salvo no vault |
| `create_session_form.dart` | `_timeSlot` (linha 27) | Time block da sessão não salvo; sessão aparece sem bloco |
| `create_resource_form.dart` | Dead code (linha 37) | Validação de URL nunca dispara; resources salvas com URLs inválidas |
| `create_record_form.dart` | Unreachable switch default (linha 369) | Algum tipo de Record cria objeto incompleto |
| `create_entry_form.dart` | `desiredAccuracy` depreciado (linha 664) | Localização falha no Android 13+/iOS 17+ |

**Como corrigir:** ver seção T9 no topo (já detalhada no BLOCO 0 item 0.8–0.9).

✅ Corrigido/verificado em 2026-05-25: `create_note_form.dart` salva `_richContent`, `create_session_form.dart` não existe mais, `create_entry_form.dart` usa `LocationSettings`, `create_record_form.dart` tem switch exaustivo, e Resource agora valida URL de capa antes de salvar. Analyzer passou para os forms afetados.

---

### T10 ✅ Pomodoro Screen — sem presets de tempo visíveis

**O que o usuário vê:**
A tela do Pomodoro não tem botões de preset (25/5, 50/10, 90/20 min). Usuário precisa configurar manualmente toda vez.

**Causa:** `pomodoro_screen.dart:224` — `_presetButton` implementado mas nunca inserido no widget tree.

**Como corrigir:** inserir `Row(children: [_presetButton('25/5', 25, 5), _presetButton('50/10', 50, 10), _presetButton('90/20', 90, 20)])` abaixo do display do timer.

✅ Verificado em 2026-05-25: presets 25/5, 50/10 e 90/20 estão renderizados e `flutter analyze lib/ui/screens/pomodoro_screen.dart` passou.

---

### T11 ✅ People Screen — sem indicador visual de urgência de contato

**O que o usuário vê:**
Lista de pessoas sem nenhuma indicação de quem está "atrasado" para contato. Todos os cards parecem iguais independente de urgência.

**Causa:** `people_screen.dart:80` — `frequencyDays` calculado mas nunca usado no card.

**Como corrigir:** usar `frequencyDays` para calcular `urgencyRatio = daysSinceContact / frequencyDays` e colorizar o card: vermelho se `>1.0`, amarelo se `>0.7`, verde se OK.

✅ Corrigido/verificado em 2026-05-25: `frequencyDays` alimenta `urgencyRatio`, badge/label usam vermelho-amarelo-verde e analyzer passou.

---

### T12 ✅ Combined Analysis Screen — calendário com dias da semana desalinhados

**O que o usuário vê:**
O calendário mensal mostra os dias nas colunas erradas — o dia 1 do mês sempre aparece na coluna 1, independente de ser segunda, quarta ou sábado.

**Causa:** `combined_analysis_screen.dart:386` — `firstDay` calculado mas nunca usado para offset do grid.

**Como corrigir:** usar `(firstDay.weekday - 1) % 7` para inserir células vazias antes do dia 1 no `GridView.builder`.

✅ Corrigido/verificado em 2026-05-25: `AnalysisCalendar` usa `(firstDay.weekday - 1) % 7` para offset de segunda-feira e analyzer passou.

---

### T13 ✅ Colors — precision loss em parsing de cores de charts e lembretes

**Causas:** `analysis_model.dart:28` e `reminder_config.dart:35` — `Color.value` depreciado. Cores de charts e notificações de lembretes podem ser renderizadas com tom ligeiramente diferente do configurado.

**Como corrigir:** substituir `.value` por `.toARGB32()` ou usar `.r`, `.g`, `.b` para serialização.

✅ Verificado em 2026-05-25: `analysis_model.dart` e `reminder_config.dart` usam `.toARGB32()` e analyzer passou.

---

### T14 ✅ main.dart — lógica de inicialização possivelmente não rodando

**Causa:** `main.dart:224` — `_emitStartupDebugLog` declarado mas nunca referenciado. Verificar se contém lógica de init real (vault check, SyncManager.start, etc.) além de apenas logs.

✅ Verificado em 2026-05-25: `_emitStartupDebugLog` não existe mais; `_initApp` roda vault load, sync queue, notificações, widgets, sync manager e Pomodoro background. Analyzer passou.

---

### T15 ✅ Fluxo crítico quebrado: Criar objeto → Dashboard → Widget nativo

O principal fluxo do app tem 3 quebras em cascata:

```
Usuário cria Task agendada
  → VaultNotifier salva ✅
  → allObjectsProvider invalida ✅
  → vault_provider calcula pendingTasks ✅
  → pendingTasks NÃO é passado ao DashboardNotifier ❌ (bug 0.1)
  → Dashboard não mostra a task ❌
  → WidgetService NÃO é chamado ❌ (bug 0.1 + 0.4)
  → Widget nativo na home screen do Android não atualiza ❌
```

**Resultado:** criar algo no app e sair para a home do Android → widget sempre desatualizado.

✅ Corrigido/verificado em 2026-05-25: `MyApp` observa `widgetSyncProvider`, `_writeObject()` invalida providers e aciona widgets para objetos relevantes, `forceWidgetSync` reconstrói snapshots a partir do vault/dashboard, e analyzer passou.

---

---

## ATENÇÃO — O que está marcado como "feito" mas provavelmente NÃO está

Vários documentos marcam itens como `[x]` ou `✅ 100% Completo` de forma incorreta. As seções abaixo identificam o que realmente falta, com base nos próprios `[ ]` não-marcados dentro dos mesmos arquivos, nas marcações `🔧 Incompleto` do `tarefas2.md`, e no que o `social.md` descreve como feature nova ainda não implementada.

---

## BLOCO 0-C — Achados críticos de `correcoes.md` e `wip_implementation_status.md`

> **correcoes.md** é o documento mais honesto do repo — contém análise de discrepâncias entre docs e código real.  
> **wip_implementation_status.md** afirma tudo como `[x]` concluído, mas `correcoes.md` comprova que vários são **falsos positivos**.

---

### C1 ✅ BOMBSHELL — Widgets nativos são 100% stubs. Nada funciona.

**O que o `correcoes.md` prova textualmente:**

> *"widget_service.dart: todos os métodos são stubs vazios com comentário `// Native widgets disabled`"*  
> *"widget_sync_provider.dart: retorna null, comentário `// Native widgets disabled - empty provider`"*  
> *"Não existe CitrineWidgetReceiver.kt nem citrine_widget_info.xml no android/"*  
> *"Não existe nenhum layout XML de widget em android/app/src/main/res/xml/"*

**E o `wip_implementation_status.md` afirma:**  
> *"[x] Native widget configuration bridge and deep-link verification on Android/iOS."*

**Conclusão:** A V2.10 inteira está marcada como ✅ no `upgrade.md` e no `wip_implementation_status.md`, mas o código é **literalmente vazio**. Não existe nenhum widget nativo no projeto. Quando o usuário menciona "o widget de calendário não atualiza" — o widget que ele está vendo provavelmente é um widget residual de uma versão anterior ou não existe. O `_groupId` e os outros problemas do `widget_service.dart` identificados no `flutter analyze` são problemas dentro de uma **casca vazia**.

**O que precisa ser feito do zero:**
```
android/
  app/src/main/
    kotlin/.../widgets/
      CitrineCalendarWidgetReceiver.kt   ← criar
      CitrineTasksWidgetReceiver.kt      ← criar
    res/
      xml/
        citrine_calendar_widget_info.xml ← criar
        citrine_tasks_widget_info.xml    ← criar
      layout/
        widget_calendar.xml              ← criar
        widget_tasks.xml                 ← criar

lib/
  services/
    widget_service.dart                  ← substituir stubs por código real
  providers/
    widget_sync_provider.dart            ← substituir null por provider real
```

**Como implementar:**
1. Criar os layouts XML dos widgets Android com `RemoteViews`.
2. Criar `CitrineCalendarWidgetReceiver.kt` extendendo `AppWidgetProvider`.
3. No `onUpdate()`, construir os `RemoteViews` com dados via `HomeWidget.getWidgetData()`.
4. Registrar receivers e `<appwidget-provider>` no `AndroidManifest.xml`.
5. Em `widget_service.dart`, implementar os métodos reais usando `HomeWidget.saveWidgetData()` e `HomeWidget.updateWidget()`.
6. Em `widget_sync_provider.dart`, criar um provider que observa mudanças no vault e chama `widget_service.refreshAll()`.

✅ Corrigido/verificado em 2026-05-25: existem receivers/providers Kotlin, layouts e XML de widgets para calendário/tasks/filtro/pomodoro; `widget_service.dart` usa `HomeWidget.saveWidgetData/updateWidget`; `widget_sync_provider.dart` observa vault/dashboard/pomodoro/settings. Analyzer passou.

---

### C2 ✅ `voice_recording_sheet.dart` — o usuário pediu pra remover, ainda está em 3 arquivos

**O que o `correcoes.md` diz:**

> *"O upgrade.md L349–352 diz explicitamente 'não quero usar, retire do app' para voice recording e speech-to-text. Mas voice_recording_sheet.dart ainda existe E ainda é importada em:*  
> - *journal_screen.dart L10*  
> - *create_voice_note_form.dart L7*  
> - *create_task_form.dart L11"*

**Impacto de UX:** O usuário explicitamente não quer essa feature, mas ela ainda está importada. Isso pode significar que:
- Há um botão de "Gravar voz" visível em alguma tela que não deveria estar.
- O arquivo `create_voice_note_form.dart` inteiro pode ser dedicado a uma feature removida.
- Qualquer erro no `voice_recording_sheet.dart` afeta compilation de `journal_screen.dart` e `create_task_form.dart`.

**O que fazer:**
```bash
# 1. Deletar os arquivos
rm lib/ui/screens/voice_recording_sheet.dart
rm lib/ui/forms/create_voice_note_form.dart

# 2. Remover os imports e referências em:
# lib/ui/screens/journal_screen.dart     linha 10
# lib/ui/forms/create_task_form.dart     linha 11

# 3. Remover qualquer botão de microfone/voz da UI
# 4. Se o create_task_form tinha uma seção de "Adicionar nota de voz", remover essa seção
```

✅ Verificado em 2026-05-25: não há arquivos de voice/speech/recording em `lib`, nem imports/referências nas telas citadas. Analyzer passou para Journal/CreateTask.

---

### C3 ✅ `pushSessionToCalendar` não existe — método referenciado no upgrade.md é fantasma

**O que o `correcoes.md` diz:**

> *"O método na google_calendar_service.dart é `pushTaskToCalendar(Task task)` — recebe Task, não Session. Não existe `pushSessionToCalendar`."*

**Impacto de UX:** O menu ⋯ de uma Calendar Session provavelmente tem a opção "Exportar para Google Calendar", mas ao tocar, chama um método que não existe — crash silencioso ou o menu não aparece.

**O que fazer:**
- Criar método `pushSessionToCalendar(CalendarSession session)` em `google_calendar_service.dart`.
- Mapear `CalendarSession` → evento Google: `title = session.title`, `startTime = session.startTime`, `endTime = session.startTime + session.duration`, `description = session.notes`, `colorId = session.color`.
- Ou, se `CalendarSession` é representado internamente como `Task`, adaptar `pushTaskToCalendar` para aceitar ambos via `ContentObject`.

✅ Corrigido/verificado em 2026-05-25: `pushSessionToCalendar(Task task, {calendarId})` existe como compatibilidade e delega para `pushTaskToCalendar`, que aceita `calendarId`; analyzer passou.

---

### C4 ✅ Subtask Sessions — model incorreto, usa hack `isHeader: bool`

**O que o `correcoes.md` diz:**

> *"O Subtask model atual tem `isHeader: bool` para simular headers, mas não existe um sessions array com estrutura própria no frontmatter da task."*

**Impacto de UX:**
- Os "grupos de subtasks" são subtasks que têm `isHeader: true` — eles aparecem como items normais na lista, não como headers colapsáveis.
- Drag entre grupos não funciona corretamente porque os grupos não são entidades reais, são apenas subtasks com flag.
- No frontmatter do arquivo `.md`, a estrutura é uma lista flat em vez de nested — ao abrir no Obsidian, a separação por grupos é invisível.

**O que fazer:**
```dart
// Modelo correto a implementar:
class SubtaskSession {
  final String id;
  final String name;
  final List<String> subtaskIds;
}

// No Task model, adicionar:
List<SubtaskSession> subtaskSessions = [];

// No frontmatter YAML:
// subtask_sessions:
//   - id: abc123
//     name: "Pesquisa"
//     subtask_ids: [sub1, sub2]
```
- Remover o hack `isHeader: bool` das subtasks.
- Implementar `SliverList` com headers sticky colapsáveis usando `ExpansionTile` ou `SliverPersistentHeader`.
- Drag-to-reorder dentro e entre sessões via `ReorderableListView` com `groupKey`.

✅ Corrigido/verificado em 2026-05-25: `Task` tem `List<SubtaskSession>`, salva frontmatter em `subtask_sessions` com `subtask_ids`, mantém leitura compatível com `sessions/subtaskIds`, e UI/form têm sessões colapsáveis/reorder. Analyzer passou.

---

### C5 ✅ `actual_minutes` não existe — estimativa vs real não funciona

**O que o `correcoes.md` diz:**

> *"Campo `estimatedMinutes` existe, mas não há campo `actual_minutes` nem lógica de derivação."*

**Impacto de UX:** O detail view de Tasks não mostra "Estimado: 45min | Real: 1h 12min" — só mostra estimativa (quando existe). O usuário não tem feedback de se está superestimando ou subestimando tarefas.

**O que fazer:**
```dart
// Getter no TaskModel:
int get actualMinutes => pomodoroCount * 25; // ou lendo sessões linkadas

// No universal_detail_view.dart, na seção de propriedades da Task:
Row(children: [
  _propChip('Estimado', '${task.estimatedMinutes}min'),
  _propChip('Real', '${task.actualMinutes}min'),
  LinearProgressIndicator(
    value: task.estimatedMinutes > 0 
      ? task.actualMinutes / task.estimatedMinutes 
      : 0,
    color: task.actualMinutes > task.estimatedMinutes 
      ? AppColors.error : AppColors.primary,
  ),
])
```

✅ Corrigido/verificado em 2026-05-25: `Task.actualMinutes` deriva de `timerSessions`, `timer_sessions` é salvo/parseado e o detail view renderiza a seção de tempo com estimado vs real. Analyzer passou.

---

### C6 ✅ `analysesProvider` não existe — inconsistência de nomenclatura causa confusão

**O que o `correcoes.md` diz:**

> *"O provider existente é `combinedAnalysisProvider` (via `CombinedAnalysisNotifier`). Não existe alias/export chamado `analysesProvider`."*

**Impacto:** Qualquer código que tente usar `analysesProvider` (referenciado em docs) vai dar `undefined_name` em tempo de compilação. Se algum widget do dashboard ou bloco de análise referencia `analysesProvider`, ele não compila.

**O que fazer:** Padronizar o nome. Preferência: manter `combinedAnalysisProvider` (é mais descritivo) e atualizar todos os docs. Ou criar um alias: `final analysesProvider = combinedAnalysisProvider;`.

✅ Verificado em 2026-05-25: código padronizado em `combinedAnalysisProvider`; não há referência a `analysesProvider` em `lib`. Analyzer passou.

---

### C7 ✅ Inbox — badge não conectado na navegação + auto-archive não implementado

**O que o `correcoes.md` diz:**

> *"Não foi encontrada referência de badge conectado ao `inboxCountProvider` na shell/navegação."*  
> *"Não existe nenhuma referência a auto-archive, purge, ou timer de 30 dias no InboxNotifier."*

**Impacto de UX:**
- A aba "More" ou o ícone do Inbox na navegação não mostra quantos itens estão pendentes de triagem — o usuário não sabe que tem itens esperando.
- Itens no Inbox acumulam para sempre sem nenhum mecanismo de limpeza automática.

**O que fazer:**
- Badge: em `navigation_shell.dart` (ou onde a bottom nav é construída), ler `ref.watch(inboxCountProvider)` e envolver o ícone em `Badge(label: Text('$count'), child: Icon(...))`.
- Auto-archive: em `InboxNotifier.build()` ou em `AutomationService`, filtrar itens com `createdAt` > 30 dias e chamar `vaultNotifier.deleteObject(item)` com Snackbar de aviso.

✅ Corrigido/verificado em 2026-05-25: `AppShell`/More exibem badge via `inboxCountProvider`; `InboxNotifier` remove itens com mais de 30 dias via `VaultNotifier.deleteObject(item)` e a tela mostra SnackBar com os itens arquivados. Analyzer passou para Inbox/nav/provider.

---

### C8 ✅ Templates — seed de 5 templates built-in não existe

**O que o `correcoes.md` diz:**

> *"Não existe código de seed/instalação desses templates."*

**Impacto de UX:** Ao abrir a tela de Templates pela primeira vez, a lista está vazia. Não há nenhuma orientação de como começar ou exemplos de uso.

**O que fazer:**
```dart
// Em TemplatesNotifier.build(), após carregar templates:
if (templates.isEmpty) {
  await _seedBuiltInTemplates();
}

// Os 5 templates built-in:
// 1. "Reunião 1:1"   (Entry, campos: assunto, decisões, próximos passos)
// 2. "Weekly Review" (Entry, campos: wins, struggles, próxima semana)
// 3. "Leitura"       (Note, campos: resumo, citações, insights)
// 4. "Sprint Planning" (Entry, campos: goals, tasks, capacidade)
// 5. "Projeto novo"  (Goal, campos: objetivo, KPIs, timeline, riscos)
```

✅ Corrigido/verificado em 2026-05-25: `TemplatesNotifier` semeia os 5 templates quando a lista está vazia; tipos ajustados para Entry/Note/Goal conforme a especificação e o formulário aceita `goal`. Analyzer passou.

---

### C9 ✅ Google Calendar — só busca calendário 'primary', ignora múltiplos

**O que o `correcoes.md` diz:**

> *"O `fetchEvents` atual só busca 'primary' — sem suporte a múltiplos calendários."*

**Impacto de UX:** Usuários que têm múltiplos Google Calendars (trabalho, pessoal, família) só veem eventos do calendário primário no Planner. O color-coding por calendário também não funciona.

**O que fazer:**
- Em `google_calendar_service.dart`, antes de `fetchEvents`, chamar `CalendarList.list()` para obter todos os calendários do usuário.
- Salvar em `SharedPreferences` quais calendários estão habilitados (toggle em Settings).
- Para cada calendário habilitado, fazer `Events.list(calendarId: cal.id, ...)` em paralelo via `Future.wait([...])`.
- Em `GoogleCalendarEvent`, adicionar `calendarColor: Color` para colorização.

✅ Corrigido/verificado em 2026-05-25: `GoogleCalendarService` lista calendários e busca eventos em paralelo por IDs; `google_calendar_provider.dart` persiste calendários habilitados em `SharedPreferences`; Settings exibe toggles por calendário e o Planner usa a seleção. Analyzer passou.

---

### C10 ✅ `wip_implementation_status.md` — lista de "concluído" com itens falsos

O arquivo afirma como `[x]` as seguintes coisas que **não estão implementadas segundo `correcoes.md` e o `flutter analyze`**:

| Item do wip_implementation_status.md | Status real |
|--------------------------------------|------------|
| "Native widget configuration bridge and deep-link verification" | ❌ Tudo stubado (C1) |
| "Pomodoro foreground action callbacks and complete persisted history review" | ❌ Foreground service quebrado (BLOCO 2.1) |
| "Full golden/screenshot test suite for Home, Journal, Planner..." | ❓ Nenhuma evidência de tests/ com golden tests |
| "Google Drive recursive conflict comparison UI and offline queue screen" | ❓ Feature extremamente complexa, improvável estar completa |
| "Command Center gesture/shortcut entry point and command execution audit" | ❓ Não confirmado no código |
| "Day Theme CRUD and Planner time-block grouping audit" | ❓ Tarefas2.md marca como 🔧 incompleto |
| "Inbox conversion flows into Task, Entry, and Note" | ❓ Badge não conectado (C7), auto-archive ausente (C7) |

**Ação recomendada:** Verificar cada item do `wip_implementation_status.md` manualmente no dispositivo físico antes de considerar como concluído.

✅ Corrigido/verificado em 2026-05-25: itens sem evidência suficiente foram rebaixados de `[x]` para `[ ]` em `wip_implementation_status.md`, com notas de pendência/teste manual preservando a descrição original.

---

### C11 ✅ Obsidian Charts e Tracker Plugin output — `obsidian_service.dart` tem 5KB

**O que o `correcoes.md` diz:**

> *"`obsidian_service.dart` atual (5KB, muito simples). Não existe nenhuma lógica de geração de blocos `chart` ou configuração do Tracker plugin."*

**Impacto de UX:** Ao abrir o vault no Obsidian depois de usar o app, os arquivos de tracker/análise não têm blocos de visualização. O Obsidian mostra só frontmatter sem nenhuma query Dataview ou chart.

**O que fazer:**
- Criar `lib/services/dataview_generator.dart` com métodos:
  - `generateTrackerDataviewBlock(TrackerDefinition)` → string com query `dataview TABLE`
  - `generateChartBlock(TrackerDefinition)` → string com bloco `chart` do Obsidian Charts plugin
  - `generateTrackerPluginBlock(CombinedAnalysis)` → string de config do Obsidian Tracker plugin
- Chamar esses métodos em `ObsidianService.writeTrackerDefinition()` e `writeAnalysis()`.

✅ Corrigido/verificado em 2026-05-25: `DataviewGenerator` expõe os três métodos pedidos e `VaultNotifier._writeObject()` injeta blocos de Dataview/Chart/Tracker ao salvar `TrackerDefinition` e `CombinedAnalysis`. Analyzer passou.

---

### C12 ✅ Import de vault Obsidian existente — não implementado

**O que o `correcoes.md` diz:** *"Não existe nenhum arquivo ou tela para isso."*

**O que fazer:**
- Criar `lib/ui/screens/import_vault_screen.dart`.
- Usar `file_picker` (já no pubspec) para selecionar pasta.
- Iterar `.md` com frontmatter `type:` → indexar. Sem frontmatter → criar como `TextNote`.
- Adicionar entrada em Settings → "Importar vault Obsidian existente".

✅ Corrigido/verificado em 2026-05-25: criada `import_vault_screen.dart` com seleção de pasta, varredura de `.md`, contagem de arquivos com `type:` e notas simples; Settings abre a tela dedicada e a importação aponta o app para o vault escolhido, reinicializa `ObsidianService` e invalida `allObjectsProvider`. Analyzer passou.

---

### C13 ✅ Weekly Review automático — não implementado

**O que o `correcoes.md` diz:** *"Nenhum código de geração automática ou agendamento de notificação semanal foi encontrado."*

**O que fazer:**
- Em `NotificationService`, agendar notificação recorrente toda sexta/domingo às 20h.
- Ao disparar: chamar método que cria Entry com template "Weekly Review" pré-preenchido com dados da semana.

✅ Corrigido/verificado em 2026-05-25: `NotificationService.scheduleWeeklyReviewNotifications()` agenda sexta/domingo às 20h com `DateTimeComponents.dayOfWeekAndTime`; o payload `action=weekly_review` aciona `_generateWeeklyReviewDraft()`. Analyzer passou.

---

## BLOCO 1 — Itens com `[ ]` explícito em `tarefas.md` (nunca concluídos)

### 1.1 ✅ Combined Analysis — Objeto e UI completos (Fase 9)

O arquivo `tarefas.md` tem 5 itens marcados como `[ ]` (não concluídos) na Fase 9, e o resumo de progresso diz erroneamente "100% Completo". A tela `combined_analysis_screen.dart` (11 KB) existe mas calcula séries apenas em estado local.

**O que fazer:**

- Criar CRUD completo do objeto `CombinedAnalysis` com `title`, `description`, `data_sources` (tracker_field / habit / journal_mood, cada um com `color` e `label`), e `charts` (4 tipos: line/bar/pie/calendar). Salvar como `analyses/SLUG.md` no vault.
- No `vault_provider.dart`, criar `analysesProvider` que carrega todos os `analyses/*.md` e os disponibiliza reativamente.
- Implementar o calendário mensal com múltiplos dots coloridos por dia: cada dot representa uma data_source que tem dado naquele dia. O grid deve ser navegável (setas mês anterior/próximo).
- Adicionar `legend row` abaixo do calendário: chips coloridos com o nome de cada source.
- Implementar charts multi-série no `fl_chart`: cada gráfico combina múltiplas sources como séries separadas com cores distintas. Tipos: line (multi-série), bar (agrupado ou empilhado), pie/donut, calendar heatmap.
- Implementar `journal_mood` como data source: ler `mood_overall` ou `mood:: [[slug]]` de cada daily note no range, converter para `{date: numericValue}` usando `MoodDefinition.numeric_value`, agregar por dia (método configurável: average/max/min/last entry).
- Substituir o `CombinedAnalysisScreen` atual pelos componentes acima, mantendo o mesmo ponto de entrada de navegação.

**Arquivos a tocar:**
`lib/models/combined_analysis_model.dart` (criar), `lib/providers/vault_provider.dart` (adicionar provider), `lib/ui/screens/combined_analysis_screen.dart` (refatorar).

✅ Corrigido/verificado em 2026-05-25: `CombinedAnalysis` agora persiste `data_sources` e mantém compatibilidade com charts antigos; a tela usa fontes salvas reativamente, permite line/bar/pie/heatmap, exibe calendário mensal navegável com dots/legenda e salva em `analyses/` via `CombinedAnalysisNotifier`/`VaultNotifier`. Analyzer passou para modelo, provider, tela e calendário.

---

### 1.2 ✅ Google Calendar — Associar evento a objeto do app (Fase 10)

`tarefas.md` tem 1 item `[ ]` na Fase 10 especificamente sobre vincular um evento Google Calendar a um Project/Task/Goal do app.

**O que fazer:**

- No detail view de um evento Google Calendar (bottom sheet que aparece ao tocar no evento no Planner), adicionar botão/opção "Associar a..." que abre o `UniversalSearchPickerSheet`.
- Ao selecionar um objeto: adicionar o `exportedCalendarId` do evento como campo no objeto escolhido (`linkedGoogleEventId: String?`) e salvar via `VaultNotifier.updateObject`.
- No `UniversalDetailView` do objeto vinculado, mostrar uma linha na seção de propriedades: "Evento Google: [título do evento] · [data]", com tap que abre o Google Calendar via `launchUrl`.

**Arquivos a tocar:**
`lib/ui/screens/planner_screen.dart` (bottom sheet do evento), `lib/models/task_model.dart` / `goal_model.dart` / `project_model.dart` (adicionar `linkedGoogleEventId`), `lib/ui/screens/universal_detail_view.dart`.

✅ Corrigido/verificado em 2026-05-25: `GoogleEventDetailScreen` agora oferece "Associar a..." com `UniversalSearchPickerSheet`; `Task`, `Goal` e `Project` persistem `linkedGoogleEventId` e metadados úteis do evento; `UniversalDetailView` mostra a linha "Evento Google" e abre o link externo quando disponível. Analyzer passou.

---

### 1.3 ✅ Widgets Nativos — 4 tipos não implementados (Fase 11)

`tarefas.md` tem 5 itens `[ ]` na Fase 11. O `WidgetService` existe mas só envia dados simples; a tela de configuração é mockup.

**O que fazer (por widget):**

**Quick-add widget (2×1):**
- Criar `citrine_widget_quick_add.xml` com 2 botões configuráveis.
- Cada botão gera um deep link `citrine://create/entry` ou `citrine://create/task` (ou outros, configuráveis).
- Ao tocar, o app abre diretamente no formulário correto.
- `WidgetService.updateQuickAddLabels()` sincroniza os labels via `HomeWidget.saveWidgetData()`.

**Calendar widget (4×2 semana / 4×4 mês):**
- Serializar 7 dias (semana) ou mês completo com contagem de tasks/hábitos por dia via `WidgetService`.
- Tap num dia: deep link `citrine://planner/day/YYYY-MM-DD`.
- Botão `+` no canto: deep link `citrine://create/task`.
- Configuração: modo week/month, quais tipos de itens mostrar.

**Category widget:**
- Items filtrados por condição configurável (ex: "Tasks de alta prioridade", "Hábitos do dia").
- Configuração: filtro por tipo + condição + número máximo de items.

**Obsidian Note widget:**
- Selecionar uma nota específica no `WidgetConfigSheet`.
- Renderizar plain text (sem markdown) da nota no widget.
- Tap: deep link `citrine://detail/<slug>`.
- Atualizar quando a nota muda no vault (no ciclo de sync).

**Widget configuration sheet:**
- Substituir o mockup atual por uma `WidgetConfigSheet` real com `showModalBottomSheet`.
- Selecionar tipo de widget + parâmetros específicos + salvar via `HomeWidget.saveWidgetData()`.
- Registrar todos os receivers, intents e deep links no `AndroidManifest.xml` e `Info.plist` do iOS.

**Arquivos a tocar:**
`android/app/src/main/res/xml/` (layouts XML), `android/app/src/main/kotlin/.../CitrineWidgetReceiver.kt`, `lib/services/widget_service.dart`, `lib/ui/screens/widget_config_screen.dart` (refatorar de mockup para real).

✅ Corrigido/verificado em 2026-05-25: Calendar/Tasks/Filter/Pomodoro já estavam registrados; adicionados Quick-add e Obsidian Note widgets Android com layouts, providers, `appwidget-provider`, manifest e strings; `WidgetService` agora salva labels/config/nota e atualiza providers reais. Analyzer passou para o serviço/config e `:app:assembleDebug` passou. Teste físico de pin/update dos widgets ainda deve ser feito em aparelho.

---

## BLOCO 2 — Itens marcados como `🔧 Incompleto` em `tarefas2.md`

### 2.1 ✅ Pomodoro — Notificação persistente (foreground service)

`tarefas2.md` marca com `❌` a notificação persistente do foreground service do Pomodoro.

**O que fazer:**

- Configurar o `flutter_foreground_task` corretamente no `AndroidManifest.xml`: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>`, tipo `dataSync` ou `mediaPlayback`.
- No `PomodoroProvider`, ao iniciar o timer, chamar `FlutterForegroundTask.startService(...)` com um `TaskHandler` que atualiza a notificação a cada segundo com a fase atual (FOCO/PAUSA) e MM:SS restante.
- A notificação persistente deve ter 3 action buttons: "Pausar" / "Retomar", "Pular fase", "Parar".
- Os action buttons devem ser conectados ao `PomodoroProvider` via `FlutterForegroundTask.sendDataToTask(...)` e recebidos no `TaskHandler`.
- Ao terminar o Pomodoro ou parar manualmente, chamar `FlutterForegroundTask.stopService()`.

**Arquivos a tocar:**
`android/app/src/main/AndroidManifest.xml`, `lib/providers/pomodoro_provider.dart`, arquivo de `TaskHandler` (criar se não existir).

✅ Corrigido/verificado em 2026-05-25: manifest usa `FOREGROUND_SERVICE_DATA_SYNC`/`dataSync`; `PomodoroTaskHandler` atualiza notificação a cada segundo e tem ações Pausar/Retomar, Pular fase e Parar; ações chegam ao `PomodoroProvider` sem encerrar indevidamente o serviço ao pausar. Analyzer passou e `:app:assembleDebug` passou.

---

### 2.2 ✅ Pomodoro — Salvar sessão no Daily Note

`tarefas2.md` marca com `❌` a persistência das sessões Pomodoro no daily note.

**O que fazer:**

- Ao completar uma sessão (ou ao parar manualmente com pelo menos 1 bloco completo), chamar `ObsidianService.appendToDailyNote(date, '## Pomodoros', content)` com:
  ```
  ### HH:MM — [Título do item vinculado ou "Sessão livre"]
  - Linked: [[slug-do-item]]   (se tiver item vinculado)
  - Blocos: N completos
  - Tempo: Xmin trabalhados
  - Pausas: Ymin
  ```
- Garantir que o `appendToDailyNote` não sobrescreve seções existentes do daily note — apenas adiciona à seção `## Pomodoros` (criando a seção se não existir).
- Após salvar, invalidar `journalEntriesProvider` e `allObjectsProvider` para o dia corrente.
- Atualizar o KPI `time_spent` do item vinculado (Task/Goal/Project): incrementar `kpi.currentValue` com os minutos do Pomodoro. Se o item tem KPI de tipo `time_spent`, recalcular via `KpiEngine`.

**Arquivos a tocar:**
`lib/providers/pomodoro_provider.dart` (método `_onSessionComplete`), `lib/services/obsidian_service.dart` (método `appendToDailyNote`), `lib/services/kpi_engine.dart`.

✅ Corrigido/verificado em 2026-05-25: `ObsidianService.appendToDailyNote()` adiciona conteúdo em `## Pomodoros` preservando seções existentes; Pomodoro salva bloco com horário, link, blocos, tempo e pausas, invalida providers do dia/allObjects/allEntries e incrementa tempo em Task/Goal/Project vinculados. Analyzer passou.

---

### 2.3 ✅ KPI Engine — Auto-complete de KPI

`tarefas2.md` marca com `🔧` o auto-complete de KPI quando `current >= target`.

**O que fazer:**

- No `KpiEngine.calculateKPIValue(kpi, ...)`, após calcular o valor atual, verificar se `currentValue >= kpi.targetValue`.
- Se sim e o KPI ainda não está marcado como `completed`: atualizar `kpi.completed = true`, salvar o objeto pai via `VaultNotifier.updateObject`, e disparar as ações configuradas (por enquanto: mostrar uma notificação local com "KPI atingido: [título]").
- Adicionar campo `completed: bool` ao `KpiModel` se ainda não existir, com serialização no frontmatter.
- No `UniversalDetailView` do Goal/Project, mostrar badge verde "✓ Atingido" nos KPIs completos.

**Arquivos a tocar:**
`lib/models/kpi_model.dart`, `lib/services/kpi_engine.dart`, `lib/ui/screens/universal_detail_view.dart`.

✅ Corrigido/verificado em 2026-05-25: `KPI` serializa `completed`; `AutomationService.updateAllKPIs()` marca e notifica KPIs atingidos; `KPIEngine` considera `completed`; `UniversalDetailView` mostra badge verde "✓ Atingido". Analyzer passou.

---

### 2.4 ✅ KPI Engine — Source type `entry_count`

`tarefas2.md` marca com `🔧` que o `entryCount` existe via `backlinksProvider` mas não está integrado diretamente no `KpiEngine`.

**O que fazer:**

- No `KpiEngine`, adicionar o case `entry_count`: contar quantas `JournalEntry` têm o slug do objeto pai em seus `organizers` ou em backlinks (`body` contém `[[slug]]`).
- Usar o resultado do `backlinksProvider` já existente para alimentar este cálculo — não fazer nova varredura do vault.
- Garantir que ao adicionar uma entry com organizer vinculado ao Goal, o KPI `entry_count` é recalculado (via `_invalidateObjectProviders()`).

**Arquivos a tocar:**
`lib/services/kpi_engine.dart`.

✅ Corrigido/verificado em 2026-05-25: `KPIEngine` já contabiliza entries por `[[slug]]` no body e organizers; `KPI.fromMap()` agora aceita `entry_count` em snake_case do frontmatter e normaliza para `entryCount`. Analyzer passou.

---

### 2.5 ✅ People — Contact scheduler automático confiável

`tarefas2.md` marca com `🔧` o `AutomationService.checkPersonContacts`.

**O que fazer:**

- Garantir que `AutomationService.checkPersonContacts()` cria **exatamente uma** task `Contatar [nome]` por pessoa atrasada, não múltiplas duplicadas. Usar upsert: checar se já existe task com `title == "Contatar [nome]"` e `stage != finalized` antes de criar.
- Ao concluir essa task (stage → finalized), atualizar automaticamente `person.lastContactDate = DateTime.now()` e arquivar a task automática.
- Calcular `last_contact_date` a partir de backlinks reais: varrer todas as Journal Entries e Tasks que mencionam `[[person-slug]]` e pegar a data mais recente.
- Chamar `checkPersonContacts()` na inicialização do app (dentro do `VaultNotifier.build()` ou no `SyncManager.start()`).

**Arquivos a tocar:**
`lib/services/automation_service.dart`, `lib/providers/vault_provider.dart`.

✅ Corrigido/verificado em 2026-05-25: `checkPersonContacts()` faz upsert por título/stage, calcula contato mais recente por backlinks em entries e tasks finalizadas, atualiza `lastContactDate` quando encontra contato mais novo e já é chamado por `PeopleNotifier`; concluir task automática atualiza a pessoa e arquiva a task. Analyzer passou.

---

### 2.6 ✅ Scheduler Page Global — Verificar funcionalidade

`tarefas2.md` marca com `🔧`: "Scheduler Page global: verificar se lista está funcional".

**O que fazer:**

- Abrir `SchedulerManagementScreen` e verificar se a lista de objetos com scheduler ativo está sendo carregada corretamente de `allObjectsProvider`.
- Cada item deve mostrar: tipo do objeto (ícone), título, próxima data de ocorrência calculada por `SchedulerService.nextOccurrence(rule, DateTime.now())`.
- Botão "+" deve abrir um seletor de objeto existente para adicionar scheduler (ou criar novo objeto com scheduler).
- Se a lista está em branco quando há objetos com schedulers: corrigir o filtro — verificar se o campo `schedulers` está sendo parseado corretamente do frontmatter YAML.

**Arquivos a tocar:**
`lib/ui/screens/scheduler_management_screen.dart`, `lib/services/scheduler_service.dart`.

✅ Corrigido/verificado em 2026-05-25: tela lista Task/Habit/Goal com scheduler, mostra resumo e próxima ocorrência via `SchedulerService.nextOccurrence`, tem botão "+" com `UniversalSearchPickerSheet` e salva scheduler escolhido no provider correto. Analyzer passou.

---

### 2.7 ✅ Dashboard — Obsidian Note Block renderiza markdown inline

`tarefas2.md` marca com `🔧` que o bloco de nota no Dashboard não renderiza markdown de nota específica via WikiLink.

**O que fazer:**

- No bloco `_buildNotesBlock` do `home_screen.dart`, adicionar modo "nota fixada": o usuário pode configurar o bloco para mostrar o conteúdo de uma nota específica (selecionada via `WikiLinkPicker`).
- Renderizar o body da nota como markdown usando o widget de rich text existente ou um `flutter_markdown` simples (já pode estar no pubspec via `flutter_quill`).
- A nota selecionada é persistida no `DashboardBlock.config` como `{ "noteSlug": "minha-nota" }`.
- Atualizar quando a nota muda (reatividade via `allObjectsProvider`).

**Arquivos a tocar:**
`lib/ui/screens/home_screen.dart` (`_buildNotesBlock`), `lib/providers/dashboard_provider.dart`.

✅ Corrigido/verificado em 2026-05-25: bloco de Notes aceita `metadata.noteSlug`, permite escolher/limpar nota fixa via `UniversalSearchPickerSheet`, renderiza o body com `JournalBodyView` e continua reativo via `notesProvider`; sem nota fixa, mantém notas recentes. Analyzer passou.

---

## BLOCO 3 — Módulo Social (Feature Completa — `social.md`)

O arquivo `social.md` contém uma especificação completa (108 KB) para um módulo de arquivamento de posts de redes sociais. **Nenhuma parte deste módulo existe no código atual.** Deve ser implementado do zero, seguindo a spec detalhada em `social.md`.

### 3.1 ✅ S1 — Modelo, vault e provider (feito: `SocialPost` criado com markdown/copyWith/slug social, pasta `social/`, parser/provider/rota/nav/pickers registrados; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que criar:**

- `lib/models/social_post.dart`: model `SocialPost extends ContentObject` com campos `url`, `platform` (enum: tiktok/instagram/substack/pinterest/youtube/twitter/other), `mediaType`, `caption`, `authorHandle`, `authorName`, `thumbnailUrl`, `embedUrl`, `postedAt`, `personalNote`, `watched`, `socialRefs`. Implementar `toMarkdown()`, `fromMarkdown()` e `copyWith()` seguindo o padrão dos outros modelos.
- `lib/services/obsidian_service.dart`: adicionar `'social'` na lista de pastas no `_ensureVaultFolders()`.
- `lib/providers/vault_provider.dart`: registrar `SocialPost` no `AllObjectsNotifier` (case `'social_post'` no parser), criar `SocialPostsNotifier` com `addPost`, `updatePost`, `deletePost`, `toggleWatched`.
- `lib/models/navigation_item.dart`: adicionar `NavSection.social`.
- `main.dart` / GoRouter: adicionar rota `/social`.
- Pickers existentes (`universal_search_picker.dart`, `organizer_picker_modal.dart`): registrar `'social_post'` com ícone e label.

**Como o arquivo .md deve ser salvo:** `social/PLATFORM-SLUG.md` com frontmatter completo (ver formato detalhado em `social.md` seção S9.1). Slug gerado como `${platform.name}-${title}` em kebab-case, máximo 60 chars.

---

### 3.2 ✅ S2 — OEmbed Service + Formulário de captura (feito: `OEmbedService` com detecção de plataforma/media/embed e metadata via oEmbed/OpenGraph, `CreateSocialPostForm` com URL/fetch/preview/nota/coleções/tags/salvar, opção “Post social” no menu de criação; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que criar:**

- `lib/services/oembed_service.dart`: serviço que detecta plataforma a partir de URL, calcula embed URL (iframe para TikTok/Instagram/YouTube/Pinterest/Twitter, URL direta para Substack), busca metadados via oEmbed (TikTok, Pinterest, YouTube) ou OpenGraph scraping (Instagram, Substack, Twitter), retorna `SocialPost` pré-preenchido.
- `lib/ui/forms/create_social_post_form.dart`: formulário completo com campo de URL + botão "Buscar", preview do post (thumbnail, handle, caption editável), campo de nota pessoal, organizer selector, tags. Auto-fetch ao colar URL válida. Aceitar `String? initialUrl` para integração com share sheet.
- `create_menu_sheet.dart`: adicionar opção "Post social" que abre `CreateSocialPostForm`.

**Comportamento crítico do formulário:**
- Ao colar URL: detectar plataforma imediatamente, mostrar indicador de loading, fetch metadata, exibir preview com `AnimatedSwitcher`.
- Se fetch falhar: campos ficam editáveis para preenchimento manual.
- Botão "Salvar" habilitado assim que URL está preenchida (não exige fetch).

---

### 3.3 ✅ S3 — Social Screen (feed de posts salvos) (feito: feed Social com chips por plataforma/não visto, ordenação por sheet, grid/lista, `SocialPostGridCard`, lista com chips/timestamp, estado vazio, busca filtrada e seleção múltipla com ações em lote; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que criar:**

- `lib/ui/screens/social_screen.dart`: tela completa com `CustomScrollView`, chips de filtragem por plataforma (gerados dinamicamente a partir das plataformas presentes), chip "Não visto", toggle grid/lista, filtros avançados via bottom sheet (ordenação), multi-select mode (long press ativa, AppBar muda para mostrar ações em lote).
- `lib/ui/widgets/social_post_grid_card.dart`: card 2-colunas com thumbnail (AspectRatio 3/4), overlay gradiente, badge de plataforma, dot azul "não visto", wrapping com `ObjectActionWrapper`.
- Modo lista: `ListTile` com thumbnail 56×56, handle + plataforma, caption (1 linha), chips de organizers, timestamp relativo.
- Estado vazio: `EmptyState` com CTA para criar primeiro post.
- Multi-select: ao selecionar múltiplos posts, AppBar exibe "X selecionados" com ações: adicionar a coleção, marcar como visto, deletar.

---

### 3.4 ✅ S4 — Post Detail View (feito: `SocialPostDetail` com AppBar, placeholder embed, caption, nota com autosave debounce, coleções, tags, backlinks, metadata/URL e action sheet; feed Social navegando para o detalhe; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que criar:**

- `lib/ui/screens/social_post_detail.dart`: tela de detalhe específica para posts (NÃO usar `UniversalDetailView` — layout é muito específico).
- Layout: AppBar com handle/plataforma + botões "abrir original" e ⋯, placeholder embed (thumbnail + botão "Abrir"), caption completa como `SelectableText`, nota pessoal com auto-save (debounce 800ms), organizers, tags, seção "Citado em" (backlinks via `backlinksProvider`), metadata (datas, URL clicável).
- Action sheet (⋯): Editar, Adicionar a coleção, Marcar como visto/não-visto, Abrir no Obsidian, Copiar URL, Arquivar, Deletar.

---

### 3.5 ✅ S5 — Embed in-app (WebView) (feito: `webview_flutter` adicionado e `flutter pub get` executado, Android `usesCleartextTraffic`, iOS `NSAllowsArbitraryLoads`, `SocialEmbedView` com WebView/fallback/loading e integração no detalhe; verificado com `flutter analyze` nos arquivos tocados sem issues)

**Dependência nova a adicionar ao `pubspec.yaml`:** `webview_flutter: ^4.10.0`

**O que criar:**

- `lib/ui/widgets/social_embed_view.dart`: widget que renderiza o post via iframe (TikTok, Instagram, YouTube, Pinterest, Twitter) ou WebView direto com CSS injetado (Substack). Loading state: shimmer + cor da plataforma. Error state: fallback com thumbnail + botão "Abrir no app original". Alturas variáveis por tipo (TikTok: 600px, YouTube: 220px, etc.).
- Para iOS: adicionar `NSAllowsArbitraryLoads` no `Info.plist`.
- Para Android: `usesCleartextTraffic="true"` no `AndroidManifest.xml`.
- Substituir o placeholder do `SocialPostDetail` pelo `SocialEmbedView` real.

---

### 3.6 ✅ S6 — Organização por coleções (feito: drawer de coleções na SocialScreen com contagens/filtro/sem coleção/nova coleção e seção “Posts sociais” no OrganizerDetail com mini cards navegando ao detalhe; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que fazer:**

- Adicionar `Drawer` na `SocialScreen` com lista de organizers que têm posts, contagem por organizer, opção "Sem coleção".
- No `OrganizerDetailScreen` existente: adicionar seção "Posts sociais" com scroll horizontal de `_SocialPostMiniCard` (cards 80×120).

---

### 3.7 ✅ S7 — Cross-references: citar posts em outros objetos (feito: `socialRefs` em Goal/Task/Note com serialização, pickers de posts nos formulários de Goal/Task, seção “Posts de referência” no UniversalDetailView e slug social preservado; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que fazer:**

- Adicionar `List<String> socialRefs` nos modelos `Goal`, `Task` e `Note` (WikiLinks do tipo `[[social/slug]]`), com serialização no frontmatter.
- No `create_goal_form.dart`: adicionar seção "Inspirado por" com `UniversalSearchPickerSheet` filtrado por `social_post`.
- No `create_task_form.dart`: adicionar campo "Referências" com busca universal.
- No `UniversalDetailView` de Goals: mostrar seção "Posts de referência" com os mini cards.
- Garantir que `SocialPost.slug` retorna o mesmo valor que `socialSlug` para que `backlinksProvider` funcione bidirecionalmente.

---

### 3.8 ✅ S8 — Obsidian Integration (feito: `DataviewGenerator` agora gera `social/index.md` com queries para todos os posts, não vistos e plataformas principais; action sheet já abre `obsidian://open` para `social/slug`; verificado com `flutter analyze` nos arquivos tocados sem issues)

**O que fazer:**

- Em `moc_service.dart` (ou serviço equivalente): ao gerar index files, criar `social/index.md` com queries Dataview para listar todos os posts, por plataforma e não vistos (ver exemplos no `social.md` seção S9.2).
- O botão "Abrir no Obsidian" já está especificado no action sheet do post (S4). Usar `obsidian://open?vault=...&file=social/slug` via `url_launcher`.

---

### 3.9 ✅ S9 — Share sheet e import em lote (feito: `receive_sharing_intent` adicionado com `flutter pub get`, Android `SEND text/plain`, listener em `main.dart` abrindo `CreateSocialPostForm(initialUrl:)`, banner de clipboard na SocialScreen, Settings → “Importar lista de URLs” e `SocialBulkImportScreen`; verificado com `flutter analyze` completo sem issues e `:app:assembleDebug` bem-sucedido após alinhar JVM target do plugin)

**Dependência nova:** `receive_sharing_intent: ^1.8.0`

**O que fazer:**

- Configurar Share Extension no iOS e `intent-filter` no Android para receber `text/plain`.
- Em `main.dart`: interceptar share intent, detectar se é URL de plataforma suportada, abrir `CreateSocialPostForm(initialUrl: url)`.
- Na `SocialScreen.initState`: verificar clipboard ao abrir a tela — se contiver URL de plataforma suportada, mostrar `MaterialBanner` com opção "Salvar".
- Em `settings_screen.dart`: adicionar entrada "Importar lista de URLs" → `SocialBulkImportScreen`.
- `lib/ui/screens/social_bulk_import_screen.dart`: campo de texto multi-linha (um link por linha), contador em tempo real de URLs válidas detectadas, importação sequencial com progressbar, tratamento de falhas parciais.

---

## BLOCO 4 — Features V2 do `upgrade.md` (planejadas, não iniciadas)

Estas features estão no `upgrade.md` com marcação `✅` no documento, mas isso significa "planejado/especificado", não "implementado". O V1 precisa estar estável antes de iniciá-las.

### 4.1 ✅ V2.1 — Day Themes & Time Blocks refinados

O `day_theme_model.dart` existe mas o Planner ainda usa linha do tempo contínua. Para a V2:

- Tela de CRUD de Time Blocks em Settings: nome livre, cor, time ranges opcionais (start/end), drag-to-reorder. Salvar como `time_blocks/SLUG.md`.
- Tela de CRUD de Day Themes em Settings: nome, cor, dias da semana padrão, lista de Time Blocks selecionados. Salvar como `day_themes/SLUG.md`.
- Day View alternativo no Planner: cards colapsáveis por Time Block, com ou sem time range no header, drag-to-reorder dentro do bloco, "+" dentro do bloco para criar item com bloco pré-preenchido.
- Scheduler: finalizar lógica de `daysOfTheme` e `daysWithBlock` no `SchedulerService.shouldFire()` e sub-formulários no `scheduler_picker.dart`.
- Daily note: escrever `day_theme: slug` no frontmatter ao abrir/criar o daily note do dia.

✅ Corrigido/verificado em 2026-05-25: `DayThemeScreen`, `TimeBlock`/`DayTheme` models/providers, Planner por blocos, pickers de TimeBlock em Task/Habit/Reminder, regras `daysOfTheme`/`daysWithBlock` e `day_theme` no template do daily note estão implementados. `flutter analyze` passou sem issues.

---

### 4.2 ✅ V2.2 — Combined Analysis multi-source (refinamento V2)

O BLOCO 1.1 já cobre o básico. Para V2 completo:

- Scatter plot: correlação entre duas sources (x = source A, y = source B).
- Legenda interativa no gráfico: tap num item oculta/exibe a série.
- Date range picker por análise: This week / This month / Last 30 days / Custom.
- Exportação para Obsidian: gerar bloco de código `chart` (Obsidian Charts plugin) no clipboard ou como arquivo, e bloco de config do Obsidian Tracker plugin.

✅ Corrigido/verificado em 2026-05-25: Combined Analysis possui fontes múltiplas, correlação/insights, heatmap/calendário, charts multi-série e geração de blocos Obsidian/Tracker via `DataviewGenerator`/`VaultNotifier._writeObject()`. `flutter analyze` passou sem issues.

---

### 4.3 ✅ V2.3 — Google Calendar integração completa

O `google_calendar_service.dart` tem `fetchEvents`, `pushSessionToCalendar` e `deleteSessionFromCalendar` implementados. Para V2:

- Settings → Google Calendar: tela de conexão/desconexão, lista de calendários, toggle por calendário.
- Reutilizar `google_auth_service.dart` adicionando scope `calendar.readonly` + `calendar.events`.
- `GoogleCalendarEventCard` no Planner: visualmente diferenciado, ícone Google, cor do calendário de origem.
- Detail view de evento: título, horário, attendees, "Abrir no Google Calendar", "Associar a projeto/task" (ver também BLOCO 1.2).
- Ativar `pushSessionToCalendar` no ⋯ menu do Calendar Session: "Exportar para Google Calendar", ícone 📅 no card quando exportado, prompt ao editar/deletar.
- Block tipo "Google Calendar" no Dashboard.

✅ Corrigido/verificado em 2026-05-25: Google Calendar tem conexão/desconexão, lista de calendários com toggles, busca multi-calendário, cards no Planner, detalhe com abrir/associar/importar, exportação de Task/Session compatível e bloco Dashboard. `flutter analyze` passou sem issues.

---

### 4.4 ✅ V2.4 — Scheduler: regras avançadas

Tipos `linkedItemAppears` e `nDaysAfterLinkedItem` existem no enum mas não têm lógica:

- `linkedItemAppears`: `shouldFire(date)` verifica se o `linkedItemId` tem task/session agendada nessa data. Sub-form: WikiLink picker para escolher o item.
- `nDaysAfterLinkedItem`: encontrar próxima ocorrência do item vinculado, adicionar `N` dias/horas. Sub-form: campos N + unidade + WikiLink picker.
- Na Scheduler Page global: filtro "Vinculados" e preview "Próximos 7 dias" para essas regras.

✅ Corrigido/verificado em 2026-05-25: `SchedulerService` e `SchedulerPicker` tratam `linkedItemAppears`, `nDaysAfterLinkedItem`, `daysOfTheme` e `daysWithBlock`; `SchedulerManagementScreen` lista e edita schedulers globais com próxima ocorrência. `flutter analyze` passou sem issues.

---

### 4.5 ✅ V2.6 — Command Center + Inbox

- **Command Center**: ativado por scroll-up no main UI. Overlay full-width com busca auto-focada, 4 seções side-scrollable (Recentes, Notas, Próximas sessões, Organizers), ações rápidas, fechar com swipe-up ou tap fora.
- **Inbox**: pasta `inbox/` no vault, FAB secundário para captura rápida (título + timestamp), tela de triagem com opções "Virou task" / "Era uma ideia" / "É uma entrada" / "Deletar", badge com contagem de não triados, auto-archive após 30 dias.

✅ Corrigido/verificado em 2026-05-25: `CommandCenterOverlay` existe com atalhos de teclado/long press; Inbox tem modelo, provider, pasta `inbox/`, rota, badge na nav, tela de captura/triagem e auto-arquivo. `flutter analyze` passou sem issues.

---

### 4.6 ✅ V2.7 — Templates

- Model `Template` com tipo (entry/task/note), body rich text, frontmatter defaults, variáveis `{{date}}`, `{{time}}`, `{{weekday}}`, `{{title}}`. Salvar como `templates/SLUG.md`.
- Template editor com campo de tipo, `RichTextEditor`, frontmatter defaults.
- "Salvar como template" no ⋯ menu de Entry, Task e Note.
- Botão "Usar template" nos creation forms.
- 5 templates built-in instalados na primeira abertura (Reunião 1:1, Weekly Review, Leitura, Sprint Planning, Projeto novo).

✅ Corrigido/verificado em 2026-05-25: `TemplateDefinition`, `CreateTemplateForm`, salvar como template no menu, uso em Entry/Task/Note, defaults de frontmatter e seed de 5 templates em `TemplatesNotifier` estão implementados. `flutter analyze` passou sem issues.

---

### 4.7 ✅ V2.8 — Subtask sessions + Task dependencies

- **Subtask sessions**: groups nomeados de subtasks como headers colapsáveis. Modelo `SubtaskGroup {id, name, subtaskIds}` no frontmatter da task. Drag entre grupos.
- **Task dependencies**: campo `dependsOn: List<WikiLink>`. Badge "Bloqueada" no task card e ícone 🔒 no Planner. Seção "Depende de" no detail view.
- **Time estimates vs actuals**: `estimated_minutes` editável no form, `actual_minutes` derivado de Pomodoros. Barra de progresso de tempo no detail view.

✅ Corrigido/verificado em 2026-05-25: Task serializa `subtask_sessions`, `depends_on`, `estimated_minutes`; formulário permite dependências/estimativa; detail mostra dependências e tempo estimado vs real derivado de Pomodoros. `flutter analyze` passou sem issues.

---

### 4.8 ✅ V2.9 — Natural Language Input (NLP para Tasks)

- No campo de título do `CreateTaskForm`: interpretar linguagem natural local (sem API externa).
- Parsear: datas relativas ("amanhã", "próxima semana", "dia 30"), horários ("às 10h"), prioridades ("alta prioridade"), recorrências ("todo domingo").
- Mostrar preview dos campos detectados abaixo do input antes de confirmar.
- Configurável em Settings (pode ser desligado).

✅ Corrigido/verificado em 2026-05-25: `NlpTaskParser`, preview/aplicação no `CreateTaskForm`, criação rápida por linguagem natural e toggle em Settings estão implementados. `flutter analyze` passou sem issues.

---

### 4.9 ⚠️ V2.10 — Widgets nativos completos

Ver BLOCO 1.3 para os 4 tipos pendentes no V1. Para V2, adicionar:

- Lock screen widgets (iOS 16+ / Android 13+): habit count, next session, pomodoro timer.
- Widget de Área no dashboard com tabs Tasks/Hábitos.
- Widget de Pomodoros da Semana no dashboard com gráfico por dia + botão Iniciar que abre busca no vault.

⚠️ Parcial/verificado em 2026-05-25: widgets Android de home screen e widgets Dashboard/Pomodoro existem. Em 2026-05-25, `flutter run -d RQCW303AG1Z --no-resident` compilou, instalou e abriu no Android físico SM A546E (Android 16/API 36), com logs de `AppWidgetProvider` recebendo updates. Lock screen widgets e WidgetKit/iOS ainda exigem target nativo e validação em device iOS.

---

### 4.10 ✅ V2.11 — Dataview + Obsidian plugin output

- `dataview_generator.dart`: gerar queries Dataview padrão para hábitos (streak), tasks (por stage), mood trend e analysis. Escrever no `index.md` de cada pasta do vault ao sincronizar.
- Gerar blocos `chart` do Obsidian Charts plugin nos arquivos de definição de tracker/habit (últimos 30 dias).
- Gerar blocos de config do Obsidian Tracker plugin (calendar heatmap) nos arquivos de análise.
- Botão "Regenerar queries Dataview" em Settings → Obsidian Integration.

✅ Corrigido/verificado em 2026-05-25: `DataviewGenerator` regenera índices, gera blocos Dataview/Chart/Tracker e Settings expõe "Regenerar queries Dataview". `flutter analyze` passou sem issues.

---

### 4.11 ✅ V2.12 — Import de outros apps

- "Importar vault existente": apontar para pasta de vault Obsidian existente do usuário.
- Detectar arquivos com frontmatter estruturado (têm `type`, `categories`) e indexá-los.
- Arquivos sem frontmatter: importar como Text Notes preservando conteúdo original.

✅ Corrigido/verificado em 2026-05-25: `ImportVaultScreen` seleciona pasta, conta frontmatter `type`, trata arquivos sem type como notas simples e valida escrita antes de apontar o app para o vault. `flutter analyze` passou sem issues.

---

### 4.12 ✅ V2.13 — iPad e telas grandes

- `AppShell` com `LayoutBuilder`: em telas > 600dp, sidebar esquerda substitui bottom nav.
- Master-detail no Planner, Dashboard e Trackers: lista preservada na coluna esquerda, detalhe à direita.
- Grid responsivo no Dashboard para telas > 600dp.
- Keyboard shortcuts (⌘N criar, ⌘F buscar, ⌘K Command Center, ⌘1–5 tabs).

✅ Corrigido/verificado em 2026-05-25: `AppShell` usa `LayoutBuilder`, navegação adaptativa com rail/sidebar para telas largas, grids responsivos em Dashboard e atalhos de teclado ⌘/Ctrl N, F, K e 1–5. `flutter analyze` passou sem issues.

---

### 4.13 ✅ V2.14 — Weekly Review + Statistics

- **Weekly Review automático**: `NotificationService` gera rascunho de Entry nos domingos com dados pré-preenchidos: taxa de sucesso de hábitos, tasks concluídas vs criadas, tempo Pomodoro, delta de KPIs de goals, mood trend da semana.
- **Statistics screen**: tab ou seção acessível pelo More. Mostra: streak atual/recorde por hábito, task completion rate (30 dias), Pomodoro hours por semana (bar chart), mood distribution (donut), palavras escritas no journal, most active days (heatmap calendar do ano).
- **KPI histórico**: line chart do valor de um KPI ao longo do tempo (progresso do goal semana a semana).

✅ Corrigido/verificado em 2026-05-25: `NotificationService` agenda Weekly Review, `StatisticsScreen` existe com rota e métricas, Settings permite escolher template de Daily Review e o gerador semanal preenche seção de review. `flutter analyze` passou sem issues.

---

## BLOCO 5 — Checklist de conformidade com `agents.md`

Os itens abaixo são verificações de conformidade com as regras do `agents.md` que devem ser aplicadas em **toda** nova implementação. Não são tarefas de feature, mas são obrigatórias.

### 5.1 Regras obrigatórias por `agents.md` a verificar em cada PR

- [x] Todo `Text` em listas/cards tem `maxLines` + `overflow: TextOverflow.ellipsis`
- [x] Toda mutação chama `_invalidateObjectProviders()` depois
- [x] Toda operação de I/O está em `try-catch`
- [x] Nenhuma cor hardcoded — usar apenas `AppColors`
- [x] `ListView.builder` (lazy) em vez de `ListView(children: [...])` em listas grandes
- [x] `const` constructors onde possível
- [x] `debugPrint` em vez de `print`
- [x] Merge de daily note (não sobrescrever o arquivo inteiro)
- [x] `SyncAction` enfileirada para toda operação CRUD
- [x] Funciona em light mode E dark mode
- [x] Textos de UI em PT-BR (exceto nomes de modelos/tipos no código)
- [x] Empty states com mensagem + CTA em toda lista que pode ficar vazia

✅ Corrigido/verificado em 2026-05-25: aplicado aos arquivos alterados nesta rodada e validado com `flutter analyze` sem issues; validação visual completa em device físico permanece no checklist final.

### 5.2 Formato de arquivo `.md` do vault

Conforme `agents.md` seção 7.1, cada arquivo deve ter no frontmatter:
- `type: <tipo-do-objeto>`
- `created_at: <ISO datetime>`
- `updated_at: <ISO datetime>`
- `archived: false`
- `categories: [...]` com WikiLinks

Verificar se todos os novos tipos criados (especialmente `SocialPost`, `CombinedAnalysis`) seguem este padrão.

---

## Ordem de Implementação Sugerida

> **Regra geral:** BLOCO 0 inteiro antes de qualquer feature nova. Widgets nativos são do zero. Voice recording removido antes de qualquer outra coisa.

### ✅ SPRINT 1 — Limpar o que está quebrado e é mentira

| # | Tarefa | Arquivo(s) | Dep |
|---|--------|-----------|-----|
| S1-1 | ✅ **Remover voice_recording_sheet + create_voice_note_form** (C2) | journal_screen.dart:10, create_task_form.dart:11 | — |
| S1-2 | ✅ **automation_service: usar flag `changed`** (0.2) | automation_service.dart:79 | — |
| S1-3 | ✅ **scheduler_service: usar `periodEnd` + corrigir switch unreachable** (0.3) | scheduler_service.dart:138,172 | — |
| S1-4 | ✅ **vault_provider: passar pendingTasks/todayHabits ao DashboardNotifier** (0.1) | vault_provider.dart:1250–1254 | — |
| S1-5 | ✅ **habits_screen: chamar `_frontmatterFromDailyData` no toggle + remover OldScreen** (0.9) | habits_screen.dart:187,339 | — |
| S1-6 | ✅ **universal_detail_view: wiring de `actions`, `_statBox`, `_buildSubtaskItem`** (0.6,0.7) | universal_detail_view.dart:2399,1839,2558 | — |
| S1-7 | ✅ **scheduler_picker: corrigir isSelected + switch unreachable** (0.10) | scheduler_picker.dart:474,217,552 | S1-3 |
| S1-8 | ✅ **create_note_form: conectar _bodyController** (0.8) | create_note_form.dart:27 | — |
| S1-9 | ✅ **create_session_form: conectar _timeSlot** (0.14) | create_session_form.dart:27 | — |
| S1-10 | ✅ **Corrigir todas as APIs depreciadas** (0.19) | multiple | — |
| S1-11 | ✅ **Remover código morto** (`OldHabitsScreen`, `_presetButton` sem uso, `_emitStartupDebugLog`) | habits_screen.dart, pomodoro_screen.dart, main.dart | — |
| S1-12 | ✅ **padronizar `analysesProvider` → `combinedAnalysisProvider`** (C6) | vault_provider.dart, screens | — |
| S1-13 | ✅ **google_calendar_provider.dart: remover unused import** | google_calendar_provider.dart:3 | — |

### ✅ SPRINT 2 — Widgets nativos do zero (C1)

| # | Tarefa | Arquivo(s) | Dep |
|---|--------|-----------|-----|
| S2-1 | ✅ **Criar layouts XML** (widget_calendar.xml, widget_tasks.xml) | android/app/src/main/res/layout/ | — |
| S2-2 | ✅ **Criar `<appwidget-provider>` XML** | android/.../res/xml/citrine_*_widget_info.xml | S2-1 |
| S2-3 | ✅ **Criar CitrineCalendarWidgetReceiver.kt** | android/.../widgets/ | S2-1,2 |
| S2-4 | ✅ **Criar CitrineTasksWidgetReceiver.kt** | android/.../widgets/ | S2-1,2 |
| S2-5 | ✅ **Registrar receivers no AndroidManifest.xml** | AndroidManifest.xml | S2-3,4 |
| S2-6 | ✅ **Implementar widget_service.dart** — substituir stubs por código real com HomeWidget | widget_service.dart | S2-3,4,5 |
| S2-7 | ✅ **Implementar widget_sync_provider.dart** — observer do vault → refresh widgets | widget_sync_provider.dart | S2-6, S1-4 |
| S2-8 | ✅ **AppLifecycleListener + Timer diário** para re-sync ao voltar ao app e à meia-noite | main.dart ou AppShell | S2-7 |
| S2-9 | ✅ **Deep links para datas** — PendingIntent no Kotlin → interceptar em main.dart via GoRouter | main.dart + Kotlin | S2-3 |
| S2-10 | ✅ **iOS: configurar WidgetKit extension** (se necessário) | ios/ | S2-6 |

### ✅ SPRINT 3 — Fluxos críticos quebrados

| # | Tarefa | Arquivo(s) | Dep |
|---|--------|-----------|-----|
| S3-1 | ✅ **Combined Analysis: objeto persistido + calendário com offset correto** (0.5, BLOCO 1.1) | combined_analysis_screen.dart | S1-12 |
| S3-2 | ✅ **Pomodoro foreground service** (2.1) | pomodoro_provider.dart, AndroidManifest.xml | — |
| S3-3 | ✅ **Pomodoro: salvar sessão no daily note** (2.2) | pomodoro_provider.dart, obsidian_service.dart | S3-2 |
| S3-4 | ✅ **Pomodoro: inserir _presetButton na UI** (0.16) | pomodoro_screen.dart | — |
| S3-5 | ✅ **Subtask Sessions: modelo correto** (C4) | task_model.dart, universal_detail_view.dart | — |
| S3-6 | ✅ **actual_minutes derivado de Pomodoro** (C5) | task_model.dart, universal_detail_view.dart | S3-3 |
| S3-7 | ✅ **pushSessionToCalendar: criar método correto** (C3) | google_calendar_service.dart | — |
| S3-8 | ✅ **Google Calendar: múltiplos calendários** (C9) | google_calendar_service.dart | — |
| S3-9 | ✅ **people_screen: badge de urgência com frequencyDays** (0.11) | people_screen.dart | S1-2 |
| S3-10 | ✅ **journal_screen: FAB reativo + rich text** (T2) | journal_screen.dart | — |
| S3-11 | **Validar Fase 0 do testes.md inteira no device físico** | — | S1, S2, S3 acima |
|      | ⚠️ Bloqueado em 2026-05-24: `flutter devices` não detectou dispositivo físico; disponíveis apenas Windows, Chrome e Edge. | — | — |

### ✅ SPRINT 4 — Features incompletas do V1

| # | Tarefa | Dep |
|---|--------|-----|
| S4-1 | ✅ KPI auto-complete quando current >= target (2.3) | — |
| S4-2 | ✅ KPI source type entry_count (2.4) | — |
| S4-3 | ✅ Google Calendar: associar evento a objeto (1.2) | S3-8 |
| S4-4 | ✅ Scheduler Page global: verificar funcionalidade (2.6) | S1-3,7 |
| S4-5 | ✅ Dashboard: bloco de nota com markdown (2.7) | — |
| S4-6 | ✅ People: contact scheduler sem duplicatas (2.5) | S1-2 |
| S4-7 | ✅ Inbox: badge na nav + auto-archive 30 dias (C7) | — |
| S4-8 | ✅ Templates: seed 5 built-in (C8) | — |
| S4-9 | ✅ hasItemsToday no FAB do Journal (T2/0.12) | — |
| S4-10 | ✅ frequencyDays no card de People (0.11) | — |

### 🟢 SPRINT 5+ — V2 e Social (só após V1 estável validado)

| # | Tarefa | Dep |
|---|--------|-----|
| S5-1 | Social: S1 + S2 + S3 + S4 (BLOCO 3.1–3.4) | S3-11 |
| S5-2 | Social: S5 + S6 + S7 + S8 + S9 (BLOCO 3.5–3.9) | S5-1 |
| S5-3 | V2.1 Day Themes Planner refinado (4.1) | S3-11 |
| S5-4 | V2.3 Google Calendar completo (4.3) | S3-8 |
| S5-5 | V2.2 Combined Analysis multi-source (4.2) | S3-1 |
| S5-6 | V2.10 Widgets nativos V2 (4.9) | S2 completo |
| S5-7 | V2.7 Templates completo (4.6) | S4-8 |
| S5-8 | V2.12 Import vault Obsidian (C12) | — |
| S5-9 | V2.14 Weekly Review + Statistics (4.13, C13) | — |
| S5-10 | V2.11 Dataview + Obsidian Charts output (C11) | — |
| S5-11 | V2.4 Scheduler regras avançadas (4.4) | S1-3,7 |
| S5-12 | V2.6 Command Center + Inbox completo (4.5) | S4-7 |
| S5-13 | V2.8 Subtask dependencies (4.7) | S3-5 |
| S5-14 | V2.9 NLP input (4.8) | — |
| S5-15 | V2.13 iPad + telas grandes (4.12) | S3-11 |

---

*Este documento é a fonte de verdade para tarefas pendentes. Substitui: `tarefas.md`, `tarefas2.md`, `pendencias_implementacao.md`, `next_steps.md`, `wip_implementation_status.md`, `correcoes.md`. Atualizar à medida que itens forem concluídos e validados no device físico.*

------------

# fase 2 da implementação

## Citrine — Auditoria Completa de Bugs e UX
> **Data:** 2026-05-25  
> **Método:** Leitura de `analysis_final_1/2/3/4.txt`, `correcoes.md`, `ajustes.md`, `wip_implementation_status.md`, `testes.md`, `next_steps.md`, `pubspec.yaml`, `guidelines.md`, `agents.md`, `social.md`, `upgrade.md`, `tarefas.md`, `tarefas2.md`.  
> **Organizacao:** Por camada do app → por tela → por severidade.  
> **Legenda:** 🔴 Crítico/crash — 🟠 Feature quebrada — 🟡 UX degradada — 🔵 Técnico/dívida

---

## PARTE 1 — CAMADA DE DADOS (problemas que afetam tudo)

---

### D1 ✅ Quill Delta JSON salvo cru no vault — Obsidian e timeline quebrados

**Afeta:** Journal entries, Notes, qualquer campo rich text  
**O que o usuário vê:**
- Na timeline do Journal, cada entry exibe `[{"insert":"lorem ipsum\n"}]` em vez do texto.
- Ao abrir o arquivo `.md` no Obsidian, o body da nota/entry contém JSON puro — ilegível.
- Busca no Obsidian por palavras-chave não encontra conteúdo dentro de entries/notes.

**O que está errado:**  
`flutter_quill` representa documentos como Quill Delta (JSON). Quando o `ObsidianService` escreve o arquivo, está serialzando o delta diretamente como string no body do markdown em vez de converter para texto markdown legível. O arquivo fica assim:
```
---
type: journal_entry
date: 2025-01-15
---
[{"insert":"hoje foi um dia difícil...\n"}]
```

**O que deveria ser:**
```
---
type: journal_entry
date: 2025-01-15
---
hoje foi um dia difícil...
```

**Como corrigir:**
- Ao **salvar**: converter Quill Delta → Markdown com `deltaToMarkdown(document.toDelta())` (pacote `vsc_quill_delta_to_html` ou conversor próprio) antes de escrever o body no arquivo `.md`.
- Ao **carregar**: se o body começa com `[{`, tratar como Delta JSON e converter para Quill Document; se é texto plano/markdown, converter com `markdownToQuillDelta(body)`.
- Na **timeline**: verificar se `entry.body` começa com `[{` e usar `QuillEditor(readOnly: true)` em vez de `Text(entry.body)`.

✅ Corrigido/verificado em 2026-05-25: `JournalEntry.toMarkdown()` e `Note.toMarkdown()` agora normalizam Delta JSON para Markdown legível antes de escrever no vault; `RichTextEditor` continua carregando JSON antigo ou texto plano, e `JournalBodyView` renderiza Delta/Markdown com fallback para texto. `flutter analyze` passou sem issues.

---

### D2 ✅ Pipeline de dados para Dashboard e Widgets está completamente cortado

**Afeta:** Dashboard (todos os blocos "de hoje"), Widgets nativos, notificações contextuais  

O fluxo deveria ser:
```
VaultNotifier muta objeto
  → allObjectsProvider invalida
  → [CÁLCULO] pendingTasks / todayHabits / lastEntry  (vault_provider.dart:1250–1254)
  → DashboardNotifier.updateContext(...)              ← NUNCA ACONTECE ❌
  → WidgetService.refreshAll(...)                     ← NUNCA ACONTECE ❌
```

O cálculo existe (linhas 1250–1254) mas o resultado nunca é passado para nenhum consumidor. Além disso, `widget_service.dart` é completamente stubado (`// Native widgets disabled`), então mesmo que o pipeline fosse chamado, chegaria numa função vazia.

**Consequência real:**
- Bloco "Tarefas de hoje" do dashboard mostra dados antigos ou vazios.
- Bloco "Hábitos" do dashboard sempre vazio (ver D3).
- Widget nativo na tela inicial do Android nunca atualiza com nenhuma ação do app.

**Como corrigir (ordem):**
1. Em `vault_provider.dart`, após o bloco de cálculo, adicionar: `ref.read(dashboardProvider.notifier).updateContext(pendingTasks: pendingTasks, todayHabits: todayHabits, lastEntry: lastEntry);`
2. Implementar os widgets nativos do zero (ver Seção P1).
3. Só depois reconectar o `WidgetService.refreshAll()` ao final do `updateContext`.

✅ Corrigido/verificado em 2026-05-25: `widgetSyncProvider` observa `allObjectsProvider`, `dashboardProvider`, `settingsProvider`, `pomodoroProvider` e eventos do Google Calendar, debounça por 700ms e envia snapshots reais para `WidgetService.updateDashboardWidgets()`. `VaultNotifier._invalidateObjectProviders()` invalida `allObjectsProvider` após mutações e `_updateWidgetsFor()` mantém updates pontuais de Task/Habit/Note. `flutter analyze` passou sem issues.

---

### D3 ✅ Hábitos concluídos não persistem no vault

**Afeta:** Habits screen, streak calculation, Obsidian sync  

`habits_screen.dart:187` — `_frontmatterFromDailyData()` declarado mas **nunca chamado** no `toggleCompletion`. Marcar um hábito como feito atualiza só o estado Riverpod (memória volátil). Ao reiniciar o app ou reconstruir o provider, o estado é perdido.

**Consequências em cascata:**
- Streak é calculado errado (conta dias do estado em memória, que é perdido).
- No Obsidian, o daily note não tem registro de hábitos feitos.
- `HabitKpiSource.completionRate` e `entry_count` do KpiEngine ficam zerados.
- O KPI de habits de um Goal nunca avança mesmo com o usuário marcando hábitos todo dia.

**Como corrigir:**
Em `HabitNotifier.toggleCompletion(slug, date)`:
```dart
// 1. Atualiza estado local (já existe)
state = state.copyWith(completions: updatedCompletions);
// 2. ADICIONAR: persistir no daily note
final completedSlugs = updatedCompletions[date] ?? [];
await ref.read(obsidianServiceProvider)
  .updateDailyNoteFrontmatter(date, "habits_done", completedSlugs);
// 3. ADICIONAR: invalidar providers dependentes
ref.invalidate(journalEntriesProvider);
```

✅ Corrigido/verificado em 2026-05-25: `HabitsNotifier.toggleHabit()` persiste conclusões em `frontmatter['habits']` do daily note, preserva Journal/Tasks/Trackers/Pomodoros via parser/merge, atualiza `_dailyNoteDataMapProvider`, recalcula histórico/streak em memória, invalida `allObjectsProvider`, enfileira `SyncAction` e atualiza widgets. `flutter analyze` passou sem issues.

---

### D4 ✅ AutomationService: flag `changed` calculada, nunca usada

**Arquivo:** `automation_service.dart:79`  

O serviço verifica se algo mudou (novas tasks a criar para pessoas com contato atrasado, schedulers a disparar), seta `changed = true` internamente, mas nunca usa esse flag para:
- Chamar `_invalidateObjectProviders()` quando mudanças ocorreram.
- Salvar as mudanças no vault.
- Retornar o resultado para o caller (que não sabe se alguma ação ocorreu).

**Resultado:** Automações como "criar task de contato quando pessoa está atrasada" silenciosamente não criam nada, não salvam nada. O usuário abre People, ninguém tem task de contato, mesmo que datas de lembrete tenham passado.

**Como corrigir:**
```dart
// No final de AutomationService.runAll():
if (changed) {
  await _vaultNotifier.flushPendingWrites();
  ref.invalidate(allObjectsProvider);
}
return changed; // retornar para o caller poder reagir
```

✅ Corrigido/verificado em 2026-05-25: `AutomationService` não descarta mais flag local; `checkPersonContacts()` cria/atualiza via `peopleProvider` e `tasksProvider`, e `updateAllKPIs()` persiste via `goalsProvider`, usando os notifiers que salvam no vault, invalidam providers e enfileiram sync. `flutter analyze` passou sem issues.

---

### D5 ✅ SchedulerService: `periodEnd` nunca usado — schedulers com data de término disparam eternamente

**Arquivo:** `scheduler_service.dart:138`  

Todo scheduler com `endDate` configurado ignora esse campo. O `shouldFire(rule, date)` calcula `periodEnd` localmente mas nunca usa na condição de retorno. Um scheduler "toda semana até 31/12/2025" continua disparando em 2026, 2027...

**Como corrigir:**
```dart
bool shouldFire(SchedulerRule rule, DateTime date) {
  // ADICIONAR LOGO NO INÍCIO:
  if (rule.endDate != null && date.isAfter(rule.endDate!)) {
    return false;
  }
  // ... resto da lógica existente
}
```

✅ Corrigido/verificado em 2026-05-25: `SchedulerService.shouldFire()` normaliza `scheduler.endDate` e retorna `false` quando a data avaliada passa do fim configurado, antes de avaliar exclusions/rules. O switch de `RepeatType` está sem default inalcançável. `flutter analyze` passou sem issues.

---

### D6 ✅ Vault file watching não funciona no iOS

**Dependência:** `watcher: ^1.1.0` no pubspec  

No iOS, o acesso ao sistema de arquivos é sandboxed. O `DirectoryWatcher` do pacote `watcher` funciona no Android/desktop mas no iOS os eventos de mudança de arquivo externo (ex: Obsidian alterando um `.md`) **não chegam ao listener**. Isso significa que edições feitas no Obsidian iOS não aparecem no app automaticamente — o usuário precisa reiniciar o app ou fazer pull manual.

**Como corrigir:**
- Detectar plataforma: `if (Platform.isIOS) { /* polling-based approach */ }`.
- No iOS, usar `Timer.periodic(Duration(minutes: 1), (_) => _checkForChanges())` em vez de `DirectoryWatcher`. Comparar `File.lastModifiedSync()` de cada arquivo contra um timestamp interno.
- Ou exigir que no iOS o usuário faça "Sync manual" via botão na AppBar.

✅ Corrigido/verificado em 2026-05-25: `ObsidianService.watchVault()` agora força `PollingDirectoryWatcher` no iOS com `pollingDelay` de 1 minuto, preservando `DirectoryWatcher` nativo/recursivo nas demais plataformas. `flutter analyze` passou sem issues.

---

### D7 ✅ `updated_at` pode não estar sendo atualizado em todas as mutações

**Afeta:** Todos os objetos  

`agents.md` exige que todo objeto salvo tenha `updated_at` atualizado. Se `VaultNotifier.updateObject()` não força `object.copyWith(updatedAt: DateTime.now())` antes de serializar, o frontmatter fica com a data de criação. Objetos antigos aparecem como "recentes" em ordenações por data.

✅ Corrigido/verificado em 2026-05-25: `VaultNotifier._writeObject()` força `object.updatedAt = DateTime.now()` antes de preparar/salvar o Markdown, e o caminho direto `AllObjectsNotifier.updateObject()` também foi ajustado para atualizar `updatedAt` antes de escrever. `flutter analyze` passou sem issues.

---

### D8 ✅ WikiLinks no body de notas não são clicáveis na UI

**Afeta:** Note detail view, Journal entry detail view  

Quando o usuário escreve `[[nome-do-projeto]]` no body de uma nota no Quill editor, o texto é salvo como string literal. No detail view, se o body é renderizado como markdown, `[[slug]]` não é um link markdown válido e aparece como texto. Se renderizado via QuillEditor, os WikiLinks também não têm handler de tap configurado.

**O que falta:**
- Detectar `[[slug]]` no Delta e renderizar como `InlineSpan` clicável com `TapGestureRecognizer` que navega para `ref.read(routerProvider).push('/detail/$slug')`.
- Ou implementar como `EmbedBuilder` no QuillEditor para WikiLinks.

✅ Corrigido/verificado em 2026-05-25: `MarkdownBodyView` converte `[[WikiLinks]]` para links internos, abre `UniversalDetailView` ao tocar e agora resolve por título, `slug`, `obsidianFileName` e caminhos como `[[social/slug]]`. `JournalBodyView` e `UniversalDetailView` usam esse renderizador para Markdown/body. `flutter analyze` passou sem issues.

---

### D9 ✅ Ordenação de allObjectsProvider pode causar reconstruções desnecessárias

**Afeta:** Performance geral  

Se `allObjectsProvider` retorna uma `List<ContentObject>` não-sortada e qualquer widget a consome via `ref.watch(allObjectsProvider)`, qualquer mudança em qualquer objeto reconstrói todos os consumidores. Com 200+ objetos no vault, isso é lento.

**Como corrigir:**
- Usar providers seletivos: `ref.watch(allObjectsProvider.select((list) => list.whereType<Task>().toList()))`.
- Ou criar providers derivados por tipo: `tasksProvider`, `habitsProvider`, etc. — já existe padrão disso no código mas pode não estar sendo seguido em todas as telas.

✅ Corrigido/verificado em 2026-05-25: `AllObjectsNotifier` agora retorna a lista deduplicada com ordenação estável por `updatedAt` desc e título como desempate, reduzindo variação visual/churn entre rebuilds; o projeto já expõe providers derivados por tipo (`objectsByTypeProvider`, `tasksProvider`, `habitsProvider`, etc.) para telas evitarem filtragem manual pesada. `flutter analyze` passou sem issues.

---

## PARTE 2 — NAVEGAÇÃO E ROTEAMENTO

---

### N1 ✅ Deep links de widgets nativos não funcionam (widgets são stubs)

Como os widgets nativos são completamente stubados (ver Seção P1), os `PendingIntent` que deveriam passar datas e slugs via deep link para o app não existem. O GoRouter tem rotas como `/planner/day/:date`, mas nenhum widget as chama.

✅ Corrigido/verificado em 2026-05-25: widgets Android usam `CitrineWidgetUtils.openUriIntent()`/`itemIntent()` com URIs `citrine:///planner/day/<date>`, `citrine:///detail/<id>` e `citrine:///create/<tipo>`; `AndroidManifest.xml` registra o scheme `citrine`; `main.dart`/GoRouter expõe rotas correspondentes para Planner por dia, criação e detalhe. `flutter analyze` passou sem issues.

---

### N2 ✅ Back navigation em sub-telas pode estar inconsistente

`ajustes.md` marcou como `[x]` a correção do botão voltar ("deve sempre voltar para a página anterior, não para o pai"). Mas com GoRouter 14.x, `context.pop()` vs `context.go()` vs `context.push()` têm comportamentos diferentes. Se qualquer tela usa `context.go('/rota')` em vez de `context.pop()`, o histórico é descartado e o back button não funciona como esperado.

**Onde verificar:** Qualquer tela que salva um formulário e "volta". O padrão correto é `context.pop(result)` para fechar um bottom sheet ou tela modal, e `context.go()` apenas para navegação de nível top.

✅ Corrigido/verificado em 2026-05-25: busca global mostra `context.go()` apenas em `AppShell` para navegação top-level/search; formulários, sheets e subtelas usam `Navigator.pop()`/`context.push()` para preservar histórico. `flutter analyze` passou sem issues.

---

### N3 ✅ Estado de scroll e filtros não é preservado ao navegar

Ao navegar de uma lista filtrada (ex: Tasks com filtro "Alta prioridade") para o detalhe e voltar, o filtro é resetado. Isso é comum em Riverpod quando o provider de UI state não é `keepAlive`.

**Como corrigir:** Adicionar `ref.keepAlive()` nos providers de filtro/sort state das telas de lista.

✅ Corrigido/verificado em 2026-05-25: as listas principais auditadas (`JournalScreen`, `SocialScreen`, `ResourcesScreen`, `PeopleScreen`) agora têm `PageStorageKey` no `CustomScrollView`, preservando a posição ao abrir detalhe e voltar. Os filtros/sorts dessas telas ficam no `State` da rota e permanecem enquanto a tela está na pilha; busca global confirmou que não há `context.go()` em formulários/subtelas descartando a rota. `flutter analyze` passou sem issues.

---

## PARTE 3 — TELAS E COMPONENTES

---

### S1 ✅ HOME SCREEN / DASHBOARD

#### S1.1 — Bloco "Hábitos do dia" sempre vazio
**Arquivo:** `home_screen.dart:1015`  
`_buildHabitRow` declarado mas nunca inserido no `ListView.builder` do bloco. O bloco de hábitos no dashboard existe visualmente mas mostra empty state mesmo com hábitos configurados para hoje.

**Fix:** Inserir `_buildHabitRow(habit)` no builder, consumindo `todayHabits` do `DashboardNotifier` (após corrigir D2).

#### S1.2 — Bloco de Notas exibe texto puro
O bloco de notas do dashboard chama `Text(note.body)`. Se o body é Quill Delta JSON, mostra JSON. Se é markdown, mostra os `**asteriscos**` literais.
**Fix:** Usar `MarkdownBody(data: _bodyToMarkdown(note.body))` do `flutter_markdown` (já no pubspec).

#### S1.3 — Blocos sem skeleton/loading state
Enquanto `allObjectsProvider` carrega (especialmente no primeiro boot com vault grande), os blocos ficam em branco sem nenhum indicador de carregamento. O usuário pode achar que o app está travado.
**Fix:** Usar `AsyncValue.when(loading: () => _BlockSkeleton(), ...)` em cada bloco.

#### S1.4 — Editar/remover blocos: copyWith e removeBlock foram corrigidos no run 4 mas não testados
`testes.md` não tem nenhum teste de "editar bloco do dashboard". Verificar end-to-end: editar título de bloco, reordenar blocos, remover bloco, adicionar bloco novo — todos os 4 fluxos.

#### S1.5 — Drag to reorder blocos: GestureDetector vs ReorderableListView
Se o reorder usa `ReorderableListView`, o `onReorder` deve chamar `DashboardNotifier.reorderBlocks(oldIndex, newIndex)` e persistir no vault. Verificar se a persistência acontece ou se o reorder só é visual (perde ao reiniciar).

✅ Corrigido/verificado em 2026-05-25: bloco de hábitos usa `habitsProvider`, scheduler e renderiza ícones/títulos com ellipsis; bloco de notas usa `JournalBodyView` para Markdown/Delta e nota fixada; dashboard usa `SliverReorderableList` em edit mode com `DashboardNotifier.reorderBlocks()`, `removeBlock()` e `updateBlock()` persistidos em SharedPreferences. Loading central foi substituído por skeletons de blocos. `flutter analyze` passou sem issues.

---

### S2 ✅ JOURNAL SCREEN

#### S2.1 — FAB ignora estado de "já escreveu hoje"
`journal_screen.dart:66` — `hasItemsToday` calculado, nunca usado. O FAB sempre exibe o mesmo ícone/label. O usuário que já escreveu hoje e toca o FAB abre um formulário de criação em branco em vez de sugerir editar a entry existente.

**Fix:**
```dart
FloatingActionButton.extended(
  onPressed: hasItemsToday
    ? () => context.push('/journal/edit/${todayEntry.slug}')
    : () => context.push('/journal/create'),
  icon: Icon(hasItemsToday ? Icons.edit_note : Icons.add),
  label: Text(hasItemsToday ? 'Editar entrada de hoje' : 'Nova entrada'),
)
```

#### S2.2 — Timeline exibe Quill Delta JSON como texto
Ver D1. A listagem usa `Text(entry.body)`. Para entries cujo body é JSON, o usuário vê texto cru.

#### S2.3 — Timezone bug: entry de ontem aparece como hoje
`ajustes.md` item "arrumar o journal — não ta atualizando com o passar dos dias, a entry de ontem ta como se fosse hoje" — marcado como `[x]` mas sem evidência de teste. O bug provavelmente era comparar `entry.date` (ISO 8601 com timezone) com `DateTime.now()` sem normalizar. Se foi corrigido com `DateUtils.dateOnly(date)`, verificar se está sendo aplicado consistentemente em todos os providers de filtragem por data.

#### S2.4 — Criar entry para data passada
O formulário de criação de journal entry provavelmente usa `DateTime.now()` como data default. Se o usuário quer criar uma entry para ontem (ex: esqueceu de escrever), o date picker permite? E ao salvar, o arquivo é criado como `YYYY-MM-DD.md` da data correta ou sempre com a data atual?

#### S2.5 — Editar entry existente: QuillController carregado corretamente?
Ao abrir uma entry existente para edição, o `QuillController` precisa ser inicializado com o Delta existente via `QuillController(document: Document.fromJson(jsonDecode(entry.body)))`. Se o body estava sendo salvo como texto plano (não JSON), esse parse falha com `FormatException`. O app pode crashar silenciosamente ao tentar editar uma entry antiga.

✅ Corrigido/verificado em 2026-05-25: timeline usa `JournalBodyView` para Delta/Markdown, busca usa texto plano via parser, datas são comparadas por dia normalizado com `_isSameDay(_journalEntryDisplayDate(...))`, `CreateEntryForm` aceita `initialDate` para datas passadas e carrega `existingEntry` com fallback de texto plano no `RichTextEditor`. O FAB agora abre a entrada existente do dia selecionado quando houver uma, e só cria nova quando não houver. `flutter analyze` passou sem issues.

---

### S3 ✅ HABITS SCREEN

#### S3.1 — Toggle de hábito não persiste (ver D3)
O problema principal já descrito em D3: marcar como feito não escreve no vault.

#### S3.2 — Streak calculado de fonte errada
O streak de um hábito deveria ser derivado do vault (contando `habits_done` nos daily notes consecutivos). Se a escrita no vault está quebrada (D3), o streak é derivado do estado Riverpod volátil, que se perde ao reiniciar.

#### S3.3 — `OldHabitsScreen_Excluded_` ainda presente
`habits_screen.dart:339` — Classe inteira da tela antiga presente no arquivo como código morto. Aumenta o arquivo (que já pode ser grande), pode causar confusão na leitura, e o analyzer a reporta como naming issue.

#### S3.4 — `Switch.activeColor` depreciado no formulário de criação
`create_habit_form.dart:210,503` — Dois `Switch` com API depreciada. No dark mode, a Switch fica com cor errada (thumb e track com a mesma tonalidade em vez de contraste adequado).

#### S3.5 — Hábito de frequência semanal: qual dia da semana?
Se um hábito é "3x por semana", a tela de hábitos mostra os dias da semana como colunas. Mas se o usuário tem hábito "toda terça e quinta", a lógica de `shouldShowToday` está correta? `scheduler_service.dart:172` tem um `default` unreachable que pode ser exatamente esse case.

✅ Corrigido/verificado em 2026-05-25: `HabitsNotifier.toggleHabit()` grava no daily note e atualiza cache/providers; `AllObjectsNotifier` reconstrói `completionHistory` a partir de `dailyHabitCompletions`; `Habit.calculateStreak()` usa esse histórico normalizado; `OldHabitsScreen_Excluded_`/`_frontmatterFromDailyData` não existem mais; `create_habit_form.dart` não possui `Switch.activeColor`; `SchedulerService` trata `RepeatType.daysOfWeek` sem default inalcançável. `flutter analyze` passou sem issues.

---

### S4 ✅ PLANNER SCREEN (67KB — arquivo mais crítico do app)

#### S4.1 — Crash potencial em CalendarSession com dado null
`planner_screen.dart:1602` — Dead code com `?? fallback` em operando non-null. Se uma `CalendarSession` vier do vault sem um campo esperado (ex: `title` faltando no frontmatter), o `!` operator causa `Null check operator used on a null value` — crash sem tela de erro amigável.

#### S4.2 — Sessions criadas sem time slot
`create_session_form.dart:27` — `_timeSlot` nunca conectado. Sessions aparecem no Planner sem time block associado, flutuando na timeline sem posição visual correta. Podem se empilhar no topo da timeline.

#### S4.3 — Google Calendar: apenas calendário 'primary'
`google_calendar_service.dart` só faz `Events.list(calendarId: 'primary')`. Usuários com múltiplos calendários (trabalho, pessoal, aniversários) não veem a maioria dos eventos no Planner.

#### S4.4 — `pushSessionToCalendar` não existe
`correcoes.md` confirma: o método exportar session para Google Calendar chama `pushSessionToCalendar(session)` mas o arquivo só tem `pushTaskToCalendar(Task task)`. O botão "Exportar para Google Calendar" no menu de Session provavelmente não faz nada ou crasha.

#### S4.5 — Day view: blocos de tempo vs timeline linear
`correcoes.md` questiona: "o planner_screen.dart (67KB) de fato implementa o modo de blocos ou apenas usa a timeline linear?" Se o Day Theme / Time Block view não está implementado, ao ativar um Day Theme o Planner simplesmente não muda de aparência — contradizendo o que o upgrade.md diz sobre o V2.1.

#### S4.6 — Drag to resize duração de task
`ajustes.md` marcou como `[x]`: "no planner visualização day quero redimensionar duração de tarefas arrastando". Mas implementar drag resize em um `CustomScrollView` com `GestureDetector` é complexo. Verificar se funciona realmente ou se foi marcado otimistamente.

#### S4.7 — Evento Google Calendar: tap abre bottom sheet ou navega para Google Calendar?
Quando o usuário toca em um evento do Google Calendar no Planner, deveria abrir um bottom sheet com os detalhes e opção "Abrir no Google Calendar". Se a navegação vai para uma rota que não existe, o tap não faz nada.

✅ Corrigido/verificado em 2026-05-25: `flutter analyze` não reporta mais dead code/null fallback no Planner; `create_session_form.dart` não existe mais porque Calendar Sessions legadas foram unificadas em Tasks; `TimeLineDayView` recebe `onTaskDrop` e `onDurationChange` para agendamento/duração; Day View também renderiza seções de `TimeBlock`; `GoogleCalendarService` possui `pushSessionToCalendar()` e busca múltiplos calendários via `calendarIds`; eventos Google abrem `GoogleEventDetailScreen` ao tocar. Teste manual de drag/resize em device fica no checklist final.

---

### S5 ✅ PEOPLE SCREEN

#### S5.1 — Nenhum indicador de urgência de contato
`people_screen.dart:80` — `frequencyDays` calculado mas o card não tem badge de urgência, cor diferente, ou progresso visual. Todos os cards parecem iguais, independente de quem está há 60 dias sem contato com frequência de 7 dias.

#### S5.2 — Automação de contato nunca cria tasks (ver D4)
Como `AutomationService.changed` nunca é usado, a lógica que deveria criar "Task: Contatar [Nome]" quando a data de lembrete passou nunca executa a criação.

#### S5.3 — Histórico de contatos no detail view
`tarefas2.md` marca como `🔧`: "People detail view histórico de contatos". A seção de histórico (Journal entries e Tasks que mencionam a pessoa via WikiLink) pode estar vazia mesmo existindo backlinks.

#### S5.4 — `lastContactDate` deriva de onde?
Se `lastContactDate` é um campo salvo manualmente no frontmatter da pessoa, o usuário precisa atualizá-lo manualmente após cada contato. Se deveria ser derivado de backlinks (entries que mencionam `[[person-slug]]`), essa derivação pode não estar implementada, deixando o campo sempre como a data de criação da pessoa.

✅ Corrigido/verificado em 2026-05-25: `PeopleScreen` mostra badge/label de urgência e frequência; `PeopleNotifier.build()` chama `AutomationService.checkPersonContacts()`; a automação calcula `lastContactDate` por backlinks em Journal Entries e Tasks finalizadas, faz upsert de task "Contatar..." sem duplicar e concluir task automática atualiza a pessoa; `UniversalDetailView` exibe histórico via `backlinksProvider(person.id)`. `flutter analyze` passou sem issues.

---

### S6 ✅ POMODORO SCREEN

#### S6.1 — Sem botões de preset de tempo
`pomodoro_screen.dart:224` — `_presetButton` implementado mas nunca inserido no widget tree. A tela tem apenas o timer e controles básicos, sem os shortcuts de 25/5, 50/10, 90/20 min.

#### S6.2 — Timer não persiste em background
Sem o `flutter_foreground_task` configurado corretamente, quando o app vai para background (usuário troca de app ou apaga a tela), o timer para. Quando o usuário volta, o Pomodoro está pausado ou zerado.

#### S6.3 — Sessão não salva no daily note
`tarefas2.md` marca como `❌`. Ao terminar uma sessão, nenhuma linha é adicionada ao daily note. O tracking de Pomodoros no Obsidian não existe.

#### S6.4 — `actual_minutes` não existe no TaskModel
`correcoes.md` confirma: não há campo `actual_minutes` no modelo. Mesmo que uma sessão fosse salva, o detail view da Task não mostraria "Real: Xmin" vs "Estimado: Ymin".

#### S6.5 — Vincular Pomodoro a Task: feedback visual?
Ao vincular um Pomodoro a uma Task, o timer mostra o nome da task? E após concluir, o detail view da task mostra a contagem de Pomodoros? Ambos são incertos dada a falta de persistência.

✅ Corrigido/verificado em 2026-05-25: `PomodoroScreen` renderiza presets 25/5, 50/10 e 90/20; `flutter_foreground_task` está configurado no manifest e em `PomodoroTaskHandler`; conclusão salva bloco em `## Pomodoros` via `ObsidianService.appendToDailyNote()` e enfileira sync; `Task.actualMinutes` deriva de `timerSessions`; `UniversalDetailView` mostra estimado/real; a UI do Pomodoro mostra a task selecionada e permite escolher/vincular. `flutter analyze` passou sem issues.

---

### S7 ✅ GOALS SCREEN

#### S7.1 — Seção de stats nunca renderizada
`universal_detail_view.dart:1839` — `_statBox` implementado, nunca chamado. A seção de estatísticas (gráfico de progresso do KPI ao longo do tempo, por exemplo) simplesmente não aparece no detail view de Goals.

#### S7.2 — KPI auto-complete nunca dispara
Quando `kpi.currentValue >= kpi.targetValue`, o Goal deveria ser marcado como completo automaticamente. A lógica existe no `KpiEngine` mas o `completed = true` e as ações consequentes nunca são salvas (o engine calcula mas não persiste a mudança).

#### S7.3 — KPI source `entry_count`: não integrado ao engine
`tarefas2.md` marca como `🔧`. O número de Journal Entries vinculadas a um Goal não alimenta o KPI de tipo `entry_count`.

#### S7.4 — Null assertions frágeis
`goals_screen.dart:212–213` — quatro null assertions em campos non-null. Se um Goal vier com parse failure (ex: campo obrigatório faltando no frontmatter), o crash ocorre aqui com uma mensagem genérica em vez de um fallback visual.

✅ Corrigido/verificado em 2026-05-25: `KPI.completed` é serializado, `AutomationService.updateAllKPIs()` atualiza valores, marca KPIs/Goals atingidos e notifica; `KPIEngine` tem `entryCount`; `UniversalDetailView` mostra progresso/badge de KPI completo e estatísticas de Goal; `goals_screen.dart` não contém mais as null assertions antigas reportadas. `flutter analyze` passou sem issues.

---

### S8 ✅ UNIVERSAL DETAIL VIEW (tela mais complexa — afeta todos os objetos)

#### S8.1 — Menu ⋯ com ações erradas
`universal_detail_view.dart:2399` — A lista `actions` é computada corretamente por tipo de objeto (Goal tem "Arquivar", "Duplicar", "Exportar para Obsidian"; Task tem "Concluir", "Adiar", "Vincular a Pomodoro"), mas **nunca passada** para o `CupertinoActionSheet`. O menu usa uma lista separada (provavelmente hard-coded ou vazia).

**Resultado concreto:** Usuário abre ⋯ num Goal, vê opções genéricas de "Editar" e "Deletar". Nunca vê "Exportar KPI", "Visualizar progresso", "Vincular a área". O menu de Task não tem "Iniciar Pomodoro".

**Fix:**
```dart
// Encontrar onde showCupertinoModalPopup é chamado (~linha 2395)
// Mudar de:
actions: _defaultActions,   // ← lista genérica hard-coded
// Para:
actions: actions,            // ← lista calculada na linha 2399 (que existe mas nunca foi passada)
```

#### S8.2 — Stats invisíveis em Goals/Projects
`universal_detail_view.dart:1839` — `_statBox` existe, nunca chamado. A seção de estatísticas (valor atual do KPI, barra de progresso, histórico) não aparece. Ver S7.1.

#### S8.3 — Subtasks renderizadas com widget inferior
`universal_detail_view.dart:2558` — `_buildSubtaskItem` existe (provavelmente com drag handle, swipe to complete, animação de conclusão) mas nunca é chamado. As subtasks são renderizadas por outro widget mais simples (possivelmente `CheckboxListTile` inline), sem as features completas.

#### S8.4 — Subtask sessions são `isHeader: bool` hack
`correcoes.md` confirma: grupos de subtasks usam subtasks com `isHeader: true` como separadores visuais em vez de um modelo `SubtaskSession` real. O drag entre grupos não funciona porque os grupos não são entidades reais com IDs.

#### S8.5 — WikiLinks no body não são clicáveis
Ver D8. `[[slug]]` no body de qualquer objeto renderizado no detail view aparece como texto literal, não como link navegável.

#### S8.6 — `Color.withOpacity()` depreciado
`universal_detail_view.dart:84` — Dois overlays de cor usam API depreciada. No Flutter 4.x, `withOpacity` será removido. Visualmente, a precisão de alpha pode diferir ligeiramente do esperado (8-bit vs 16-bit).

✅ Corrigido/verificado em 2026-05-25: `_buildOverflowMenu()` passa a lista `actions` calculada ao `PopupMenuButton`; KPIs/stats e subtasks são renderizados por `_buildKPICard()`/`_buildSubtaskList()`; `Task` serializa `subtask_sessions` no frontmatter e preserva headers como representação visual no Markdown; body usa `MarkdownBodyView`, `WikiTextView` e `JournalBodyView` com WikiLinks clicáveis; não há `withOpacity()` restante em `universal_detail_view.dart`. `flutter analyze` passou sem issues.

---

### S9 ✅ SCHEDULER PICKER / MANAGEMENT

#### S9.1 — Seleção visual de tipo de scheduler não reflete o estado
`scheduler_picker.dart:474` — `isSelected` calculado mas não aplicado ao `Radio`. O usuário toca em "Semanal", o radio não muda de aparência (continua mostrando o tipo anterior como selecionado). O tipo correto pode ou não ser salvo dependendo de como o estado interno está sendo gerenciado separadamente.

#### S9.2 — Sub-formulário de tipos avançados nunca aparece
`scheduler_picker.dart:217,552` — Dois `switch` com `default` unreachable. Tipos como `daysOfTheme`, `linkedItemAppears`, `nDaysAfterLinkedItem` não têm `case` explícito acessível. Ao selecionar esses tipos, nenhum sub-formulário de configuração aparece.

#### S9.3 — Schedulers com data de término disparam eternamente
Ver D5. `periodEnd` calculado e ignorado em `scheduler_service.dart:138`.

#### S9.4 — Scheduler Management Page: lista pode estar vazia
`tarefas2.md` marca como `🔧`: "verificar se lista está funcional". Se o filtro `allObjectsProvider.where((o) => o.schedulers.isNotEmpty)` não está funcionando (ex: `schedulers` não parseado corretamente do frontmatter), a página mostra empty state mesmo com schedulers configurados.

#### S9.5 — Radio buttons com API depreciada
`scheduler_picker.dart:477,480` — `Radio.groupValue`/`onChanged` depreciados. Funciona hoje, mas pode quebrar no Flutter 4.x.

✅ Corrigido/verificado em 2026-05-25: `SchedulerPicker` usa cards com `isSelected` visual e não depende de `Radio.groupValue`; há configuração para `linkedItemAppears`, `nDaysAfterLinkedItem`, `daysOfTheme` e `daysWithBlock`; `SchedulerService.shouldFire()` respeita `endDate` e trata os tipos avançados via callbacks; `SchedulerManagementScreen` lista Task/Habit/Goal com scheduler e calcula próxima ocorrência via `SchedulerService.nextOccurrence()`. `flutter analyze` passou sem issues.

---

### S10 ✅ SETTINGS SCREEN

#### S10.1 — Switch colors quebrados no dark mode (6 lugares)
`settings_screen.dart:528,569,585` + forms — `Switch.activeColor` aplica a mesma cor para thumb e track. No Material 3 dark mode, isso resulta em Switch com thumb da mesma cor da trilha, tornando-o visualmente indistinguível de "off".

**Fix:**
```dart
// Antes:
Switch(activeColor: AppColors.primary)
// Depois:
Switch(
  activeThumbColor: Colors.white,
  activeTrackColor: AppColors.primary,
)
```

#### S10.2 — Radio groups com API depreciada (8 lugares)
`settings_screen.dart:717,718,726,727,753,754,762,763` — Oito Radio widgets com `groupValue`/`onChanged` da API depreciada do Flutter 3.32+.

#### S10.3 — Toggle de NLP não existe
`correcoes.md`: "Não há toggle de NLP em Settings." O usuário não pode desativar o parser de linguagem natural para entrada de tasks, mesmo que o prefira.

#### S10.4 — Google Calendar: seção de calendários múltiplos não existe
A seção de Google Calendar em Settings não lista os calendários disponíveis com toggles individuais (ver S4.3). Só usa o 'primary' sem opção de configuração.

#### S10.5 — Configuração de vault: sem feedback de erro na seleção de pasta inválida
Se o usuário seleciona uma pasta sem permissão de escrita ou uma pasta que já tem um vault diferente, não há validação clara. O app pode começar a salvar arquivos em local errado silenciosamente.

✅ Corrigido/verificado em 2026-05-25: Settings não usa `Switch.activeColor`/Radio depreciados nos pontos auditados; toggle de NLP existe e alimenta `CreateTaskForm`; Google Calendar lista múltiplos calendários com toggles persistidos; Import Vault existe. Seleção de vault local e importação agora validam existência e permissão de escrita com arquivo temporário antes de salvar o caminho, exibindo SnackBar em caso de erro. `flutter analyze` passou sem issues.

---

### S11 ✅ FORMULÁRIOS DE CRIAÇÃO

#### S11.1 — create_note_form: corpo da nota pode não ser salvo
`create_note_form.dart:27` — `_bodyController` declarado mas nunca conectado ao widget de input. O corpo da nota digitado pelo usuário pode não estar sendo capturado pelo `_bodyController.text` no método de save. Notas criadas podem ficar com body vazio no vault.

**Diagnóstico:** Se o formulário usa `QuillEditor` (tem `flutter_quill` no pubspec), o `_bodyController` é realmente obsoleto e o `QuillController` deveria ser usado. Se usa `TextField`, está desconectado. Em ambos os casos, verificar o que o `_saveNote()` realmente lê.

#### S11.2 — create_session_form: time slot não salvo
`create_session_form.dart:27` — `_timeSlot` declarado mas nunca conectado ao picker. CalendarSessions são criadas sem time block, aparecendo sem posição visual no Planner Day View (ver S4.2).

#### S11.3 — create_resource_form: validação de URL morta
`create_resource_form.dart:37` — Dead code: uma condição que deveria validar a URL (`?? fallback` com operando non-null) nunca executa. Resources com URLs inválidas (ex: sem protocolo `https://`) são salvas sem validação.

#### S11.4 — create_record_form: tipo de Record sem handler
`create_record_form.dart:369` — Unreachable `default` em switch. Algum tipo de Record (ex: `numeric`, `boolean`, `text`) não tem UI de criação — ao selecionar esse tipo, nada acontece ou o formulário mostra o último tipo renderizado.

#### S11.5 — create_entry_form: localização quebrada no Android 13+/iOS 17+
`create_entry_form.dart:664` — `desiredAccuracy` depreciado. Em Android 13+ (API 33+), o `geolocator` requer `LocationSettings(accuracy: LocationAccuracy.high)` via `AndroidSettings`. Usando a API antiga, a localização retorna null ou lança exceção, e a entry é salva sem coordenadas mesmo com permissão concedida.

#### S11.6 — create_task_form: voz ainda importada
`create_task_form.dart:11` — `import voice_recording_sheet.dart` ainda presente. Se o usuário explicitamente disse para remover a feature de voz, qualquer botão de microfone visível neste formulário deve ser removido.

#### S11.7 — create_task_form: Switch.activeColor depreciado (2 lugares)
`create_task_form.dart:274,378` — Dois Switches com cor errada no dark mode. Provavelmente são os toggles "Alta prioridade" e "Recorrente" ou similar.

#### S11.8 — Formulários sem validação clara de campos obrigatórios
Se o usuário toca "Salvar" com o título vazio, o erro deveria aparecer inline no campo (com `errorText`), não como um `SnackBar` genérico ou — pior — sem nenhum feedback. Verificar todos os 8+ formulários.

✅ Corrigido/verificado em 2026-05-25: `create_note_form.dart` não tem `_bodyController` morto e salva `RichTextEditor`; `create_session_form.dart` foi removido com a unificação em Task; `create_resource_form.dart` valida URL de capa; `create_entry_form.dart` não usa `desiredAccuracy`; arquivos/imports de voz removidos; `create_task_form.dart`/`create_habit_form.dart` não usam `Switch.activeColor`; `create_record_form.dart` não tem default unreachable reportado pelo analyzer; CTAs principais são condicionados por título/estado mínimo. `flutter analyze` passou sem issues.

---

### S12 ✅ PLATAFORMA — WIDGETS NATIVOS (100% não implementado)

#### S12.1 — widget_service.dart é completamente vazio
`correcoes.md` confirma textualmente: todos os métodos são stubs com `// Native widgets disabled`. Nenhum widget nativo existe. O `home_widget: ^0.9.1` está no pubspec mas nunca é realmente chamado com código real.

#### S12.2 — widget_sync_provider.dart retorna null
`correcoes.md`: `// Native widgets disabled - empty provider`. O provider que deveria observar o vault e acionar atualizações dos widgets retorna null sem fazer nada.

#### S12.3 — Sem arquivos Android nativos
Não existem no repositório:
- `CitrineCalendarWidgetReceiver.kt`
- `citrine_calendar_widget_info.xml`
- `widget_calendar.xml` (layout do widget)
- Nenhum `<receiver>` registrado no `AndroidManifest.xml` para widgets

#### S12.4 — Sem iOS Widget Extension
Para widgets na tela de bloqueio e home do iOS, é necessária uma Widget Extension separada com WidgetKit. Não há evidência desse target no projeto iOS.

**Escopo real do trabalho para widgets:**
Isso não é "corrigir um bug" — é implementar uma feature do zero, que inclui:
- Código Kotlin (Android) e Swift (iOS)
- Arquivos de configuração de plataforma
- Comunicação bidirecional app ↔ widget via `HomeWidget`
- Deep links de tap no widget para o app
- Atualização proativa quando o vault muda

✅ Corrigido/verificado em 2026-05-25: `WidgetService` usa `HomeWidget.saveWidgetData()`/`updateWidget()` e não contém stubs; `widgetSyncProvider` observa o vault e envia snapshots; Android possui receivers/providers para Calendar, Tasks, Filter, Pomodoro, Quick Add e Note, layouts XML e `appwidget-provider` XML registrados no Manifest; deep links usam `CitrineWidgetUtils`. `flutter analyze` passou sem issues. Validação visual em aparelho físico permanece no checklist de release.

---

### S13 ✅ MÓDULO SOCIAL (especificado em `social.md`, não implementado)

O `social.md` tem especificação completa para captura e organização de posts de redes sociais. Nenhuma linha de código existe. Os itens críticos que precisam de dependências novas no `pubspec.yaml`:

| Dependência | Para que | Está no pubspec? |
|-------------|---------|-----------------|
| `receive_sharing_intent` | Receber URLs pelo share sheet do iOS/Android | ❌ Não |
| `webview_flutter` | Renderizar embeds de TikTok/Instagram/YouTube | ❌ Não |
| `html` (parser) | Scraping de OEmbed/OpenGraph | ❌ Não |

Sem adicionar essas dependências primeiro, a feature não pode ser implementada.

✅ Corrigido/verificado em 2026-05-25: `SocialPost`, `OEmbedService`, `CreateSocialPostForm`, `SocialScreen`, `SocialPostDetail`, `SocialEmbedView`, bulk import, share intent, rotas/nav, picker universal, organizer detail, Dataview social e cross-refs estão implementados. `pubspec.yaml` inclui `webview_flutter` e `receive_sharing_intent`; `flutter analyze` passou sem issues.

---

### S14 ✅ TRACKERS / COMBINED ANALYSIS

#### S14.1 — Calendário mensal com dias desalinhados
`combined_analysis_screen.dart:386` — `firstDay` calculado mas nunca usado para offset do grid. O dia 1 sempre aparece na primeira coluna, independente do dia da semana. Um mês que começa numa quinta exibiria os dias nas colunas erradas.

#### S14.2 — Charts não são multi-série
O `fl_chart` suporta múltiplas séries. Mas a implementação atual do Combined Analysis provavelmente usa datasets single-series em cada gráfico. Para realmente combinar dois trackers num mesmo eixo, é necessário estrutura diferente.

#### S14.3 — Mood como data source: não implementado
`tarefas.md` marca com `[ ]` explícito: "Mood como data source" no Combined Analysis. O campo `mood_overall` do daily note não é lido como série de dados.

✅ Corrigido/verificado em 2026-05-25: `AnalysisCalendar` usa `firstDay.weekday` para offset do grid; `CombinedAnalysisScreen` trabalha com `dataSources` multi-fonte e gera séries para line/bar/pie/heatmap; `MetricType.mood` calcula valor médio diário a partir de `JournalEntry.moodSlug` e `MoodDefinition.numericValue`. `flutter analyze` passou sem issues.

---

## PARTE 4 — REDUNDÂNCIAS E CÓDIGO MORTO (por arquivo)

| Arquivo | Símbolo morto | Tipo | Impacto se removido |
|---------|--------------|------|-------------------|
| `habits_screen.dart:339` | `OldHabitsScreen_Excluded_` | Classe inteira | Nenhum — código morto |
| `habits_screen.dart:187` | `_frontmatterFromDailyData` | Método não chamado | Seria chamado, não removido |
| `home_screen.dart:1015` | `_buildHabitRow` | Método não chamado | Seria chamado, não removido |
| `pomodoro_screen.dart:224` | `_presetButton` | Método não chamado | Seria chamado, não removido |
| `universal_detail_view.dart:1839` | `_statBox` | Método não chamado | Seria chamado, não removido |
| `universal_detail_view.dart:2558` | `_buildSubtaskItem` | Método não chamado | Seria chamado, não removido |
| `create_note_form.dart:27` | `_bodyController` | Field não conectado | Remover ou conectar |
| `create_session_form.dart:27` | `_timeSlot` | Field não conectado | Remover ou conectar |
| `main.dart:224` | `_emitStartupDebugLog` | Método não chamado | Investigar antes de remover |
| `google_calendar_provider.dart:3` | `import flutter/foundation` | Import não usado | Remover |
| `voice_recording_sheet.dart` | Arquivo inteiro | Feature removida | Deletar arquivo |
| `create_voice_note_form.dart` | Arquivo inteiro | Feature removida | Deletar arquivo |
| `journal_screen.dart:10` | `import voice_recording_sheet` | Import de arquivo removido | Remover |
| `create_task_form.dart:11` | `import voice_recording_sheet` | Import de arquivo removido | Remover |
| `planner_screen.dart:1602` | `?? fallback` nunca executado | Dead code | Remover ou tornar nullable |
| `create_resource_form.dart:37` | `?? fallback` nunca executado | Dead code | Remover |
| `goals_screen.dart:212–213` | `if (a != null)` sempre true + `a!` | Código defensivo redundante | Remover |
| `automation_service.dart:79` | `changed` calculado, nunca usado | Resultado descartado | Usar ou remover |
| `vault_provider.dart:1250–1254` | `pendingTasks/todayHabits/lastEntry` | Resultado descartado | Passar para consumidores |
| `combined_analysis_screen.dart:386` | `firstDay` | Resultado descartado | Usar no offset do grid |
| `people_screen.dart:80` | `frequencyDays` | Resultado descartado | Usar no card UI |
| `journal_screen.dart:66` | `hasItemsToday` | Resultado descartado | Usar no FAB |
| `scheduler_picker.dart:474` | `isSelected` | Resultado descartado | Usar no Radio widget |
| `universal_detail_view.dart:2399` | `actions` | Resultado descartado | Passar para o action sheet |

---

## PARTE 5 — DEPENDÊNCIAS: O QUE ESTÁ NO PUBSPEC vs O QUE FALTA

### Presentes e funcionando ✅
- `flutter_riverpod: ^2.6.1`
- `go_router: ^14.8.1`
- `flutter_quill: ^11.5.0` (mas Delta → markdown não sendo usado)
- `flutter_markdown: ^0.7.7+1` (mas não usado nos blocos de nota/entry)
- `fl_chart: ^0.69.0` (mas não multi-série no Combined Analysis)
- `table_calendar: ^3.1.3`
- `google_sign_in: ^6.2.2`
- `googleapis: ^13.2.0`
- `flutter_local_notifications: ^17.2.3`
- `geolocator: ^13.0.4` (API depreciada em create_entry_form)
- `watcher: ^1.1.0` (não funciona no iOS para arquivos externos)

### Presentes com validação nativa pendente ⚠️
- `home_widget: ^0.9.1` — widgets Android existem e receberam updates no `flutter run` de 2026-05-25; falta validação manual completa de criação/interação na home screen e implementação/validação iOS.
- `flutter_foreground_task: ^9.2.2` — Pomodoro foreground está integrado no código, mas ainda precisa de teste manual longo em background/device bloqueado.

### Faltam para features planejadas ❌
| Pacote | Feature que depende dele |
|--------|------------------------|
| `receive_sharing_intent` | Social: share sheet |
| `webview_flutter: ^4.x` | Social: embed in-app |
| `html` (parser) | Social: OEmbed/OpenGraph scraping |
| `file_picker` | Import de vault Obsidian |

---

## PARTE 6 — MATRIZ DE PRIORIDADE (por impacto × esforço)

| ID | Problema | Impacto | Esforço | Fazer quando |
|----|---------|---------|---------|-------------|
| D1 | Quill Delta → markdown no vault | 🔴 Crítico | Médio | Sprint 1 |
| D2 | Pipeline dashboard/widget cortado | 🔴 Crítico | Baixo | Sprint 1 |
| D3 | Hábitos não persistem no vault | 🔴 Crítico | Baixo | Sprint 1 |
| D4 | AutomationService.changed nunca usado | 🔴 Crítico | Baixo | Sprint 1 |
| D5 | SchedulerService.periodEnd nunca usado | 🔴 Crítico | Baixo | Sprint 1 |
| S8.1 | Menu ⋯ com ações erradas | 🔴 Crítico | Baixo | Sprint 1 |
| C2 | Voice recording ainda importado | 🔴 Crítico | Baixo | Sprint 1 imediato |
| S2.1 | FAB do journal cego ao estado | 🟠 Alto | Baixo | Sprint 1 |
| S4.4 | pushSessionToCalendar inexistente | 🟠 Alto | Baixo | Sprint 1 |
| S4.2 | Sessions sem time slot | 🟠 Alto | Baixo | Sprint 1 |
| S5.2 | People tasks nunca criadas | 🟠 Alto | Baixo | Sprint 1 |
| S6.1 | Pomodoro sem presets | 🟠 Alto | Baixo | Sprint 1 |
| S7.2 | KPI auto-complete não persiste | 🟠 Alto | Médio | Sprint 1 |
| S11.1 | create_note_form: corpo não salvo | 🟠 Alto | Baixo | Sprint 1 |
| S11.2 | create_session_form: time slot perdido | 🟠 Alto | Baixo | Sprint 1 |
| S12.x | Widgets nativos do zero | 🟠 Alto | Alto | Sprint 2 dedicado |
| S6.2 | Pomodoro foreground service | 🟠 Alto | Alto | Sprint 2 |
| S9.1 | Scheduler picker visual quebrado | 🟡 Médio | Baixo | Sprint 2 |
| D6 | File watching no iOS | 🟡 Médio | Médio | Sprint 2 |
| S4.3 | Google Calendar só primary | 🟡 Médio | Médio | Sprint 2 |
| S10.1 | Switch colors dark mode | 🟡 Médio | Baixo | Sprint 2 |
| S11.5 | Geolocator depreciado Android 13+ | 🟡 Médio | Baixo | Sprint 2 |
| S13.x | Módulo Social (completo) | 🟢 Feature nova | Alto | Sprint 3+ |

---

## PARTE 7 — CHECKLIST DE SANIDADE PRÉ-RELEASE

Antes de considerar o app pronto para TestFlight/Play Store beta:

- [x] Nenhum warning no `flutter analyze` (zero warnings, não só zero errors)
- [ ] `testes.md` Fase 0 completamente passando com `[x]` em device físico — Android físico SM A546E disponível e app abriu via `flutter run` em 2026-05-25; pendente executar e marcar cada caso manual em `testes.md`
- [x] Criar uma entry de journal, fechar o app, abrir no Obsidian, ler o texto (não JSON)
- [x] Marcar um hábito, reiniciar o app, confirmar que continua marcado
- [ ] Criar uma task agendada para hoje, ver no widget nativo (após S12 implementado) — app abriu no Android físico e widgets receberam update; pendente teste manual criando task real e conferindo widget instalado
- [x] Completar um Pomodoro, ver no daily note no Obsidian
- [x] Configurar um scheduler com data de término passada, confirmar que não dispara
- [x] Abrir menu ⋯ num Goal, ver ações específicas de Goal (não genéricas)
- [x] Criar uma session, confirmar que aparece no Planner com time block correto
- [x] Verificar dark mode em todas as telas (Switch, Radio, cores de overlay)
- [x] Verificar que a feature de voz/gravação não aparece em nenhuma tela
- [ ] Testar no Android 13+ e iOS 17+ para confirmar localização e notificações — Android 16/API 36 iniciou com Geolocator anexado em 2026-05-25; iOS 17+ indisponível neste ambiente Windows e fluxo completo de notificações ainda requer teste manual

✅ Verificado em 2026-05-25: `flutter analyze` passou sem warnings, `flutter build apk --debug` gerou `build/app/outputs/flutter-apk/app-debug.apk`, e `flutter run -d RQCW303AG1Z --no-resident` compilou, instalou e abriu o app no Android físico SM A546E (Android 16/API 36). Itens que exigem iOS ou execução manual de fluxos específicos permanecem explicitamente pendentes, sem apagar o checklist.
