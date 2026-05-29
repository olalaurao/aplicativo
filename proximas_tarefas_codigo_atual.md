# Citrine — Auditoria Atual Do Código

> Atualizado em: 2026-05-29.
> Regra desta versão: nenhum item é considerado pronto só porque um documento antigo tinha `[x]`. O estado abaixo considera código atual, bugs reproduzidos pelo usuário, `flutter analyze` e `flutter test`.
> Escopo iOS: ignorado nesta rodada, por pedido explícito do usuário.

---

## Resultado Local

- [x] `flutter analyze` passa sem issues.
- [x] `flutter test` passa inteiro.
- [x] Foram adicionados testes para snapshots de widgets não exibirem UUID/id como texto.
- [x] Foram adicionados testes para widget de filtro usar configuração salva do widget, sem depender apenas do bloco da Dashboard.
- [ ] Teste Android físico ainda obrigatório para widgets, notificações/alarmes, Google Calendar e Obsidian.

---

## Bugs Reproduzidos E Estado Atual

### 1. ID aparecendo em widgets/Dashboard

Estado anterior:
- Widgets recebiam `id` e `title`, mas se o `title` viesse técnico, vazio ou igual ao UUID, o caminho visual ainda podia exibir dado interno.
- Kotlin aceitava qualquer `title`/`label` como texto visual.
- Alguns fallbacks criavam deep link usando `id` quando `linkUri` faltava, mascarando payload incompleto.

Correções aplicadas:
- `widget_sync_provider.dart` agora usa `_displayTitle()` para impedir UUID/timestamp como título exibível.
- Kotlin `CitrineWidgetUtils.displayText()` ignora valores com cara de ID técnico.
- Kotlin não cria mais fallback visual/deep link por `id` quando `linkUri` falta.
- Fallback humano: `title` válido -> nome do arquivo -> alias -> `Sem título`.
- Testes cobrem UUID como `id` e também UUID indevidamente vindo como `title`.

Estado:
- [x] Corrigido no snapshot Flutter.
- [x] Corrigido no render Kotlin auditado.
- [x] Testado por `flutter test`.
- [ ] Retestar em Android físico com widget instalado.

### 2. Botões Dia/Semana/Mês do widget calendário não funcionam

Estado anterior:
- O widget Android usava callback de background do `home_widget`.
- Se o callback não executasse em dispositivo real, não havia fallback pelo `MainActivity`.

Correções aplicadas:
- `MainActivity` agora captura deep links `citrine://widget-toggle`.
- Flutter lê `getAndClearPendingWidgetUri` ao iniciar/resumir e processa `calendar_mode` e `calendar_offset`.
- Botões Dia/Semana/Mês e setas agora usam `openUriIntent`, então funcionam abrindo o app mesmo se o callback de background falhar.
- Handler comum `_handleWidgetToggleUri()` atualiza `settings.calendarWidgetType`, reseta/persiste offset e força `forceWidgetSync()`.

Estado:
- [x] Corrigido no código Android/Flutter.
- [x] `flutter analyze` e `flutter test` passam.
- [ ] Retestar no celular com app em background/killed.

### 3. Horários do Journal continuam errados

Estado anterior:
- O parser já extraía data do arquivo daily + heading `### HH:MM`.
- Porém criar entrada em um dia selecionado passava `_selectedDate` à meia-noite; isso gerava entry `00:00`, parecendo horário errado.
- Delete pela tela de detalhe usava `deleteObject()` em `JournalEntry`, que não é arquivo próprio; isso podia não excluir a seção da daily note.

Correções aplicadas:
- `CreateEntryForm` agora combina o dia selecionado com hora/minuto atuais ao criar entry nova.
- Edição mantém a data/hora da entry existente.
- Delete de `JournalEntry` na detail view chama `todayJournalProvider.notifier.deleteEntry()`, removendo a seção da daily note e preservando outras seções.
- Formulários agora retornam `true` ao salvar, permitindo fluxos transacionais como Inbox.

Estado:
- [x] Parser de daily note testado.
- [x] Criação em dia selecionado corrigida.
- [x] Delete pela detail view corrigido.
- [x] `flutter test` passa.
- [ ] Retestar no app real criando entry em dia passado, editando e excluindo.

### 4. Widget de filtro não funciona

Estado anterior:
- A configuração do filtro editava só metadata do bloco `home-area`.
- O snapshot do widget lia esse bloco, então se o bloco não existisse ou o widget nativo usasse settings globais, nada mudava.
- `saveUniversalWidgetConfig()` salvava por widget ID, mas o snapshot global `citrine_filter` não consumia essa configuração.

Correções aplicadas:
- `WidgetConfigSheet` agora salva também em `settingsProvider.updateUniversalWidgetSettings(type: 'filter', organizer, objectTypes)`.
- `_buildFilterSnapshot()` agora usa `settings.universalWidgetOrganizer` e `settings.universalWidgetObjectTypes` antes de cair para metadata da Dashboard.
- O filtro funciona mesmo sem bloco `home-area`.
- Teste novo valida que o snapshot usa configuração salva do widget.

Estado:
- [x] Corrigido no fluxo Flutter/snapshot.
- [x] Testado por `flutter test`.
- [ ] Retestar em Android físico com widget já instalado.

### 5. Permissão de alarme/notificação não aparece após reinstalar

Estado anterior:
- O manifest declarava `SCHEDULE_EXACT_ALARM` e `USE_EXACT_ALARM`.
- `USE_EXACT_ALARM` pode fazer o sistema tratar o app de forma diferente e impedir o fluxo esperado de autorização de "alarmes e lembretes".
- A checagem dependia do plugin, que podia retornar um resultado genérico.

Correções aplicadas:
- Removido `android.permission.USE_EXACT_ALARM`.
- Mantido `android.permission.SCHEDULE_EXACT_ALARM`.
- `MainActivity` agora expõe `checkScheduleExactAlarm` usando `AlarmManager.canScheduleExactAlarms()`.
- `PermissionService.canScheduleExactAlarms()` usa a checagem nativa antes do plugin.
- Se negado, o app abre `Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM`.

Estado:
- [x] Corrigido no manifest e platform channel.
- [x] `flutter analyze` passa.
- [ ] Retestar em Android 12+ após reinstalar/limpar dados.

### 6. Inbox não funciona / perde item ao triage

Estado anterior:
- `InboxNotifier.addItem/deleteItem` gravava e deletava direto pelo `ObsidianService`.
- A triagem apagava o item antes do formulário salvar; cancelar o form perdia a captura.

Correções aplicadas:
- `InboxItem` agora usa `VaultNotifier.createObject()` e `deleteObject()`.
- Pasta padrão `inbox` foi adicionada ao roteamento de objetos.
- Triage agora abre o formulário primeiro e só remove o item se o formulário retornar `true` após salvar.
- `CreateTaskForm`, `CreateNoteForm` e `CreateEntryForm` retornam `true` no `Navigator.pop` quando salvam.

Estado:
- [x] Fluxo transacional corrigido.
- [x] Mutações passam por `VaultNotifier`.
- [x] `flutter analyze` e `flutter test` passam.
- [ ] Retestar no app real: capturar -> triagem -> cancelar mantém item; salvar remove item.

---

## Validação Ainda Necessária Em Android Físico

1. Widget filtro:
   - instalar widget;
   - escolher organizador/tipos;
   - salvar;
   - confirmar mudança visual;
   - reiniciar app e confirmar persistência.

2. Widget calendário:
   - tocar Dia/Semana/Mês com app aberto, background e killed;
   - confirmar atualização visual e persistência.

3. Journal:
   - criar entry em dia passado;
   - confirmar horário atual, não `00:00`;
   - editar sem mudar horário;
   - excluir pela detail view;
   - confirmar daily note preserva hábitos/trackers/tasks/pomodoros.

4. Notificações/alarmes:
   - reinstalar ou limpar dados;
   - confirmar pedido de permissão de notificações;
   - confirmar abertura da tela de acesso especial de alarmes;
   - criar alarme e validar toque no horário.

5. Inbox:
   - capturar item;
   - abrir triagem e cancelar form;
   - confirmar item permanece;
   - salvar como task/note/journal;
   - confirmar item sai do Inbox.

---

## Pendências Não Resolvidas Nesta Rodada

- Google Calendar real ainda precisa teste com conta.
- Obsidian deep link real ainda precisa teste com vault no celular.
- Scheduler contextual (`daysOfTheme`, `daysWithBlock`, linked item rules) ainda precisa auditoria separada.
- Notificações de popup/fullscreen ainda precisam teste físico; o código foi ajustado para permissão de alarme, mas não há validação local que prove comportamento sobre lock screen/outros apps.
- Existem textos de UI em inglês em telas antigas; não foram todos padronizados nesta rodada para evitar refatoração ampla fora dos bugs críticos.

---

## Checklist Atual

- [x] Análise estática limpa.
- [x] Testes automatizados limpos.
- [x] Journal: parser/data, criação em dia selecionado e delete corrigidos no código.
- [x] Widgets: ID visual bloqueado em Flutter snapshot e Kotlin render.
- [x] Widget calendário: fallback por deep link no `MainActivity`.
- [x] Widget filtro: configuração global passa a alimentar snapshot.
- [x] Alarme: checagem nativa e manifest ajustados.
- [x] Inbox: triagem transacional e mutações via `VaultNotifier`.
- [ ] Android físico validado ponta a ponta.
