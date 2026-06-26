# Citrine — Diretrizes para Agentes de IA

> **LEIA ESTE ARQUIVO INTEIRO antes de fazer qualquer alteração no código.**
> Estas diretrizes são obrigatórias. Violá-las causa regressões, bugs e inconsistências que custam horas para corrigir.

---

## 1. VISÃO GERAL DO PROJETO

**Citrine** é um aplicativo de produtividade pessoal e journaling construído com **Flutter** (Dart). Ele funciona como um frontend premium para um vault Obsidian — todos os dados do usuário são armazenados como arquivos `.md` (Markdown com frontmatter YAML), sincronizados via Google Drive.

### Princípios Fundamentais

1. **Offline-first**: O app escreve localmente e sincroniza em background. Nunca mostre spinners de loading para operações de salvamento.
2. **Obsidian como fonte de verdade**: Todo objeto tem um arquivo `.md` correspondente. O app lê e escreve nesses arquivos — nunca em banco de dados proprietário.
3. **Unificação WHAT e WHEN**: Tasks representam tanto O QUE quanto QUANDO. O agendamento (datas, horários, blocos de tempo) é integrado diretamente ao objeto Task. Não existem mais Calendar Sessions separadas.
4. **Dualidade Content/Organizer**: Tasks, Goals, Habits e Trackers são tanto objetos de conteúdo quanto organizadores. Outros objetos podem ser associados a eles via `organizers`.
5. **Inglês como idioma primário da UI**
---

## 2. STACK TECNOLÓGICA

| Camada | Tecnologia | Versão |
|---|---|---|
| Framework | Flutter | SDK ^3.11.4 |
| State Management | Riverpod (`flutter_riverpod`) | ^2.5.1 |
| Navegação | GoRouter (`go_router`) | ^17.2.3 |
| Rich Text | Flutter Quill (`flutter_quill`) | ^11.5.0 |
| Gráficos | fl_chart | ^1.2.0 |
| Notificações | flutter_local_notifications | ^17.2.3 |
| Background Tasks | flutter_foreground_task | ^9.2.2 |
| Widgets Nativos | home_widget | ^0.9.1 |
| Sync Cloud | googleapis + googleapis_auth | ^16.0.0 |
| Auth | google_sign_in | ^6.1.6 |
| Parsing YAML | yaml | ^3.1.3 |
| Storage Local | sqflite + shared_preferences | — |
| Fonte | Google Fonts (Inter) | ^8.1.0 |

### Dependências Críticas — NÃO Remover

- `flutter_quill` — Editor de texto rico para Journal Entries e Notes
- `flutter_local_notifications` — Sistema de notificações (push, popup, alarme)
- `flutter_foreground_task` — Pomodoro em background
- `home_widget` — Widgets nativos Android/iOS
- `yaml` — Parsing de frontmatter Obsidian
- `fl_chart` — Gráficos de trackers, habits e análises

---

## 3. ARQUITETURA E ESTRUTURA DE DIRETÓRIOS

```
lib/
├── main.dart                    # Entry point, inicialização de providers
├── models/                      # Data classes (imutáveis, sem lógica de negócio)
│   ├── content_object.dart      # Classe base abstrata para todos os objetos
│   ├── habit_model.dart         # HabitDefinition, HabitSlot, HabitCompletion
│   ├── task_model.dart          # Task, Subtask, TaskStage
│   ├── journal_entry.dart       # JournalEntry
│   ├── tracker_model.dart       # TrackerDefinition, TrackerSection, InputField
│   ├── tracker_model.dart       # TrackerDefinition, TrackerSection, InputField
│   ├── goal_model.dart          # Goal
│   ├── note_model.dart          # Note (Text, Outline, Collection)
│   ├── reminder_model.dart      # Reminder
│   ├── scheduler.dart           # Scheduler (11 repeat types)
│   ├── organizer_model.dart     # OrganizerReference
│   ├── kpi_model.dart           # KPI (8+ source types)
│   ├── people_model.dart        # Person
│   ├── resource_model.dart      # Resource
│   ├── mood_model.dart          # MoodDefinition
│   └── ...                      # shared_types, sync_action, etc.
├── providers/                   # Riverpod providers (estado reativo)
│   ├── vault_provider.dart      # VaultNotifier — CORAÇÃO DO APP (~54KB)
│   ├── settings_provider.dart   # Preferências do usuário
│   ├── pomodoro_provider.dart   # Timer Pomodoro com foreground service
│   ├── navigation_provider.dart # GoRouter config + deep links
│   ├── dashboard_provider.dart  # Blocos do dashboard
│   ├── widget_sync_provider.dart# Sync de dados para widgets nativos
│   └── ...
├── services/                    # Lógica de negócio sem estado
│   ├── obsidian_service.dart    # Leitura/escrita de arquivos .md no vault
│   ├── markdown_parser.dart     # Parsing de frontmatter YAML + body markdown
│   ├── sync_manager.dart        # Orquestrador de sincronização
│   ├── google_drive_sync_service.dart # Push/pull Google Drive
│   ├── scheduler_service.dart   # Cálculo de próximas ocorrências
│   ├── notification_service.dart# Agendamento de alarmes/notificações
│   ├── kpi_engine.dart          # Cálculo de KPIs
│   ├── search_service.dart      # Busca full-text no vault
│   ├── widget_service.dart      # Bridge para widgets nativos Android/iOS
│   └── ...
└── ui/
    ├── theme.dart               # AppTheme, AppColors — design system central
    ├── screens/                 # Telas completas (navegáveis via GoRouter)
    │   ├── home_screen.dart     # Dashboard (~93KB) — blocos configuráveis
    │   ├── planner_screen.dart  # Planner Day/Week/Month (~62KB)
    │   ├── universal_detail_view.dart # Detail view universal (~116KB)
    │   ├── journal_screen.dart  # Timeline de journal entries
    │   └── ...                  # 33 screens no total
    ├── forms/                   # Formulários de criação/edição
    │   ├── create_task_form.dart     # (~45KB)
    │   ├── create_habit_form.dart    # (~40KB)
    │   ├── create_entry_form.dart    # (~32KB)
    │   ├── create_entry_form.dart    # (~32KB)
    │   ├── scheduler_picker.dart     # (~21KB) — 11 repeat types
    │   └── ...                       # 17 forms no total
    ├── widgets/                 # Componentes reutilizáveis
    │   ├── timeline_day_view.dart    # Visualização de timeline
    │   ├── rich_text_editor.dart     # Editor rich text
    │   ├── wiki_link_picker.dart     # Picker de WikiLinks [[]]
    │   ├── habit_detail_sheet.dart   # Sheet de detalhes de hábito
    │   └── ...                       # 29 widgets no total
    ├── components/              # Componentes menores (botões, chips)
    └── shell/                   # Shell de navegação (bottom bar)
```

### Vault Obsidian — Estrutura de Pastas

```
vault/
├── daily/           # Daily notes: YYYY-MM-DD.md
├── habits/          # Definições de hábitos: SLUG.md
├── trackers/        # Definições de trackers: SLUG.md
├── tasks/           # Tarefas: SLUG.md
├── goals/           # Objetivos: SLUG.md
├── notes/           # Notas (Text, Outline, Collection)
├── moods/           # Definições de mood levels
├── analyses/        # Combined Analysis definitions
├── organizers/
│   ├── areas/       # Áreas de vida
│   ├── projects/    # Projetos
│   └── activities/  # Atividades recorrentes
├── resources/       # Recursos (livros, filmes, etc.)
├── sessions/        # (Legado) Antigas Calendar Sessions (não usar mais)
├── _attachments/    # Fotos, áudios, mídia
├── _deleted/        # Lixeira (purge automático após 30 dias)
├── _conflicts/      # Backups de conflitos de sync
└── _backups/        # ZIPs de backup periódico
```

---

## 4. O ARQUIVO MAIS IMPORTANTE: `vault_provider.dart`

O `VaultNotifier` (~54KB) é o **coração do aplicativo**. Ele:

1. **Carrega o vault inteiro** na inicialização (lê todos os `.md` e parseia)
2. **Mantém o estado reativo** de todos os objetos via Riverpod
3. **Persiste mudanças** escrevendo de volta nos arquivos `.md`
4. **Gerencia o CRUD** de todos os 10+ tipos de objetos
5. **Invalida providers** após cada mutação para atualizar a UI

### Regras Críticas para o VaultNotifier

- **NUNCA** acesse o filesystem diretamente fora do VaultNotifier ou ObsidianService
- **SEMPRE** use `ref.read(vaultProvider.notifier)` para operações de escrita
- **SEMPRE** chame `_invalidateObjectProviders()` após qualquer mutação
- **NUNCA** crie providers que mantêm cópias locais de objetos do vault — use derived providers
- O método `deleteObject()` move para `_deleted/` antes de deletar o original — **NUNCA** delete diretamente

---

## 5. TIPOS DE OBJETOS — REFERÊNCIA RÁPIDA

| Tipo | Arquivo Vault | Provider | Modelo |
|---|---|---|---|
| Journal Entry | `daily/YYYY-MM-DD.md` (body) | `journalEntriesProvider` | `JournalEntry` |
| Task | `tasks/SLUG.md` | `allObjectsProvider` → filter | `Task` |
| Goal | `goals/SLUG.md` | `allObjectsProvider` → filter | `Goal` |
| Habit | `habits/SLUG.md` | `allObjectsProvider` → filter | `HabitDefinition` |
| Tracker | `trackers/SLUG.md` | `allObjectsProvider` → filter | `TrackerDefinition` |
| Reminder | inline ou `daily/` | `allObjectsProvider` → filter | `Reminder` |
| Reminder | inline ou `daily/` | `allObjectsProvider` → filter | `Reminder` |
| Note | `notes/SLUG.md` | `allObjectsProvider` → filter | `Note` |
| Person | `organizers/people/SLUG.md` | `allObjectsProvider` → filter | `Person` |
| Resource | `resources/SLUG.md` | `allObjectsProvider` → filter | `Resource` |
| Mood Def | `moods/SLUG.md` | `moodDefinitionsProvider` | `MoodDefinition` |
| Organizer | `organizers/TYPE/SLUG.md` | `organizerListProvider` | `OrganizerReference` |

---

## 6. DESIGN SYSTEM E UI/UX

### 6.1 Tema e Cores

O design system está centralizado em `ui/theme.dart`. Use **SEMPRE** as classes `AppTheme` e `AppColors`.

```dart
// ✅ CORRETO
color: AppColors.accent,
style: AppTheme.titleStyle,

// ❌ ERRADO — nunca use cores hardcoded
color: Color(0xFF6B5EA8),
color: Colors.purple,
```

**Paleta principal:**
- **Accent/Primary**: laranja (usado em botões CTA, chips ativos, borda lateral de seções)
- **Surface**: Background adaptativo (branco no light, cinza escuro no dark)
- **Text Primary/Secondary/Muted**: Hierarquia de 3 níveis de texto
- **Destructive**: Vermelho para ações de deletar
- **Success/Warning**: Verde e amarelo para badges de status

### 6.2 Regras de Layout Obrigatórias

1. **SafeArea em TODA tela**: Envolver conteúdo com `SafeArea` ou respeitar `MediaQuery.of(context).padding`
2. **Overflow prevention**: Todo `Text` em listas/cards DEVE ter `maxLines` + `overflow: TextOverflow.ellipsis`
3. **Responsive**: Usar `MediaQuery` ou `LayoutBuilder` para adaptar layouts. Nunca usar dimensões fixas absolutas para containers pais
4. **Scroll**: Conteúdo entre nav bar e tab bar deve ser scrollável. Usar `SingleChildScrollView` ou `ListView`
5. **Keyboard avoidance**: Formulários devem usar `resizeToAvoidBottomInset: true`

### 6.3 Componentes Padrão

| Componente | Padrão | Exemplo |
|---|---|---|
| Botão CTA primário | Full-width, laranja, texto branco, pill shape, fixo no bottom | "Salvar", "Adicionar", "Done" |
| Card de seção | `Container` com `borderRadius: 12-16`, fundo de surface | Propriedades, Subtarefas |
| Barra lateral de seção | Borda vertical roxa à esquerda + título semibold | "Timeline", "Dashboard" |
| Chips | Rounded pill, accent color quando ativo, outline quando inativo | Organizers, feelings |
| Menu ⋯ | Popup menu com ações contextuais | Editar, Excluir, Arquivar |
| Empty state | Ilustração + headline + CTA centralizado | "Nenhum hábito ainda" |
| Modal/Sheet | Bottom sheet com handle pill no topo, ou full-screen com X no canto | Pickers, forms |
| Lista | Separador hairline inset 16pt, ou cards individuais | Timeline, Tasks |

### 6.4 Tipografia (hierarquia)

| Uso | Tamanho | Peso |
|---|---|---|
| Título da tela (nav bar) | 17-18pt | Semibold |
| Título do card/item | 16-17pt | Regular/Medium |
| Subtítulo/metadata | 13-14pt | Regular, cor muted |
| Header de seção | 13-14pt | Semibold |
| Texto auxiliar/exemplo | 12-13pt | Regular, cinza claro |
| Label de botão CTA | 16-17pt | Semibold, branco |
| Campo de formulário | 15-16pt | Regular |

### 6.5 Interações e Feedback

- **Haptic feedback**: Light impact (hábito completo), medium (tarefa completa), warning (ação destrutiva)
- **Undo snackbar**: 5 segundos, botão "Desfazer" em roxo, aparece em TODA ação destrutiva
- **Confirmação de delete**: Alert com "Excluir" (vermelho) e "Cancelar"
- **Swipe left em listas**: Revelar ações rápidas (Delete, Change Stage)
- **Long press**: Multi-select ou menu contextual
- **Tap targets**: Mínimo 44×44pt (iOS) / 48×48dp (Android)

### 6.6 Dark Mode

- O app suporta Dark Mode. TODA nova tela/widget DEVE funcionar em ambos os temas
- Use SEMPRE `AppColors` e `Theme.of(context)` — nunca cores hardcoded
- Teste visualmente em ambos os modos antes de considerar uma tela pronta

---

## 7. FORMATO DE DADOS OBSIDIAN

### 7.1 Daily Note (`daily/YYYY-MM-DD.md`)

```yaml
---
date: 2026-05-12
tags: [daily]
# Hábitos (chave = slug do hábito)
meditar: true
agua: 6
# Trackers (chave = slug do tracker, sub-chaves = slugs dos campos)
saude:
  energia: 3
  dor_cabeca: false
sono:
  horas: 7.5
  qualidade: boa
---

# 2026-05-12

## Journal Entries

### 08:30
Acordei bem disposta.
mood:: [[good]]
organizers:: [[saude]]
#manha

---

### 14:30
Reunião produtiva.
mood:: [[neutral]]
organizers:: [[trabalho]]

---

## Habits
- [x] Meditar (Slot 1: 08:00)
- [x] Água (6/8)

## Trackers
### Saúde
- **Energia:** 3
- **Dor de cabeça:** Não

## Tasks
- [x] Finalizar relatório [priority:: High]
- [ ] Ligar para cliente [priority:: Medium]

## Pomodoros
### 09:00 — Trabalho no Projeto Alpha
- Linked: [[projeto-alpha]]
- Blocos: 3
- Tempo: 75 min
```

### 7.2 Parsing Rules — CRÍTICO

1. **Frontmatter**: Entre o primeiro e segundo `---`. YAML puro
2. **Hábitos**: Chaves YAML que correspondem a `habit_slug`. `true/false` para boolean, número para contagem
3. **Trackers**: YAML aninhado. Chave externa = `tracker_slug`, internas = `field_slug`
4. **Journal entries**: Headings `### HH:MM` sob `## Journal Entries`
5. **Mood**: Inline Dataview `mood:: [[slug]]` — cria backlink no Obsidian
6. **Organizers**: Inline Dataview `organizers:: [[slug1]], [[slug2]]`
7. **Tags**: `#tag` no corpo da entry

### 7.3 Regras de Escrita

- **NUNCA** sobrescreva um daily note inteiro — leia, faça merge, escreva
- **NUNCA** altere campos de frontmatter que você não reconhece — preserve-os
- **SEMPRE** preserve a ordem das seções no body (`## Journal Entries` → `## Habits` → `## Trackers` → `## Tasks` → `## Pomodoros`)
- **SEMPRE** gere slugs em kebab-case: `minha-tarefa-importante.md`

---

## 8. REGRAS DE DESENVOLVIMENTO — O QUE FAZER E NÃO FAZER

### 8.1 ✅ FAZER SEMPRE

1. **Ler o arquivo atual antes de editar** — nunca assuma o conteúdo
2. **Usar `try-catch` em TODA operação de I/O** — arquivo pode não existir
3. **Invalidar providers após mutações** — chamar `_invalidateObjectProviders()`
4. **Testar em dark mode E light mode** — usar `AppColors` para ambos
5. **Adicionar `maxLines` + `overflow: ellipsis`** em textos dentro de listas, cards e rows
6. **Envolver listas em `Expanded` ou `Flexible`** dentro de `Column` e `Row`
7. **Usar `const` constructors** onde possível para performance
8. **Respeitar a hierarquia de navegação** — back button volta ao anterior, não ao pai
9. **Preservar comentários existentes** — não remova documentação que não esteja relacionada à sua mudança
10. **Usar PT-BR** em todos os textos de UI

### 8.2 ❌ NUNCA FAZER

1. **NUNCA deletar arquivos do vault diretamente** — use `VaultNotifier.deleteObject()` que move para `_deleted/`
2. **NUNCA hardcodar cores** — use `AppColors` e `Theme.of(context)`
3. **NUNCA criar providers que dupliquem estado** do `allObjectsProvider` — derive deles
4. **NUNCA usar `setState` em telas que já usam Riverpod** — use `ref.watch` e `ref.read`
5. **NUNCA ignorar erros silenciosamente** — pelo menos logue com `debugPrint`
6. **NUNCA usar `Container` sem propósito** — use `SizedBox` para espaçamento, `Padding` para padding
7. **NUNCA adicionar dependências ao `pubspec.yaml`** sem justificativa explícita
8. **NUNCA sobrescrever um arquivo .md inteiro** — faça merge com conteúdo existente
9. **NUNCA criar widgets com dimensões fixas** que não se adaptem a diferentes tamanhos de tela
10. **NUNCA usar `print()` em produção** — use `debugPrint()`
11. **NUNCA usar `late` sem necessidade** — prefira nullable com null check
12. **NUNCA bloquear a UI com `await`** em providers de inicialização — use `AsyncValue` e `maybeWhen`

### 8.3 Performance (CRÍTICO)

1. **Listas grandes**: Use `ListView.builder` (lazy) em vez de `ListView(children: [...])`.
2. **Rebuild desnecessário**: Use `select` em `ref.watch` para observar apenas campos necessários.
3. **Imagens**: Cache com `precacheImage` quando necessário.
4. **Sync**: `WidgetSyncProvider._updateAllWidgets()` deve ser não-bloqueante e usar debounce.
5. **Parsing**: O `MarkdownParser` faz I/O pesado — use o cache do `allObjectsProvider` sempre que possível.
6. **Init**: Inicialize serviços em paralelo no `main.dart` usando `Future.wait`.
7. **Providers**: Evite filtragem manual de `allObjectsProvider` em múltiplos providers independentes; use o `groupedObjectsProvider`.

---

## 9. PADRÕES DE CRUD

### 9.1 Criação de Objetos

```dart
// 1. Criar o modelo
final task = Task(
  id: const Uuid().v4(),
  title: 'Minha Tarefa',
  stage: TaskStage.todo,
  createdAt: DateTime.now(),
  // ... demais campos
);

// 2. Persistir via VaultNotifier
await ref.read(vaultProvider.notifier).createObject(task);
// ↑ Isso escreve o .md, invalida providers, atualiza widgets

// 3. Navegar para o detalhe (opcional)
context.push('/detail/${task.id}');
```

### 9.2 Edição de Objetos

```dart
// 1. Ler o objeto atual
final current = ref.read(allObjectsProvider).value!
    .firstWhere((o) => o.id == objectId);

// 2. Criar cópia modificada
final updated = (current as Task).copyWith(title: 'Novo título');

// 3. Persistir
await ref.read(vaultProvider.notifier).updateObject(updated);
```

### 9.3 Exclusão de Objetos

```dart
// 1. Confirmar com o usuário
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Excluir tarefa?'),
    content: const Text('Esta ação pode ser desfeita por 30 dias.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
        child: const Text('Excluir'),
      ),
    ],
  ),
);

// 2. Deletar (move para _deleted/)
if (confirmed == true) {
  await ref.read(vaultProvider.notifier).deleteObject(object);
  // 3. Mostrar undo snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${object.title} excluído'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: AppColors.accent,
        onPressed: () => ref.read(vaultProvider.notifier).restoreObject(object),
      ),
    ),
  );
}
```

### 9.4 Leitura de Objetos

```dart
// Em widgets — usar ref.watch para reatividade
final allObjects = ref.watch(allObjectsProvider);
allObjects.when(
  data: (objects) {
    final tasks = objects.whereType<Task>().toList();
    // renderizar
  },
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Erro: $e'),
);

// Em callbacks — usar ref.read (não reativo)
final habits = ref.read(allObjectsProvider).value!
    .whereType<HabitDefinition>()
    .where((h) => h.status == HabitStatus.active)
.toList();
```

---

## 10. SINCRONIZAÇÃO E DADOS

### 10.1 Fluxo de Sync

```
App (local) ──write──> Vault (filesystem local)
                           |
                     SyncManager (background, a cada 15min)
                           |
                      +----+----+
                      v         v
               Google Drive   Widget Service
              (push/pull)    (atualiza widgets nativos)
```

### 10.2 Regras de Sync

1. **Escrita local é instantânea** — a UI nunca espera pelo sync remoto
2. **Sync é assíncrono** — usa `SyncManager` com fila (`SyncQueueService`)
3. **Conflitos criam backup** em `_conflicts/` — nunca sobrescreva silenciosamente
4. **Arquivos em `_deleted/` são purgados** automaticamente após 30 dias
5. **O `SyncManager` processa ações de notificação** (done/snooze) ANTES de enviar para a nuvem
6. **Ao detectar conflito**: criar backup de ambas versões, mostrar dialog visual de resolução

### 10.3 SyncQueue

Toda mutação (create/update/delete) enfileira uma `SyncAction`. A fila é processada pelo `SyncManager` em background. Ações pendentes sobrevivem ao restart do app (persistidas em SQLite).

---

## 11. SEGURANÇA E PRIVACIDADE

### 11.1 Princípios

1. **Zero dados em servidores do app** — tudo fica no dispositivo e no Google Drive do usuário
2. **Auth via Google Sign-In** — tokens OAuth, nunca armazenar senhas
3. **Biometria opcional** — via `local_auth` para desbloquear o app
4. **Vault local é plain text** — não criptografar (compatibilidade com Obsidian)
5. **Tokens OAuth** são armazenados via `shared_preferences` com scope mínimo

### 11.2 Permissões (Android)

| Permissão | Uso | Obrigatória? |
|---|---|---|
| `INTERNET` | Sync Google Drive | Sim |
| `ACCESS_FINE_LOCATION` | Journal entry location | Não |
| `CAMERA` | Fotos em entries/trackers | Não |
| `READ_EXTERNAL_STORAGE` | Acesso ao vault local | Sim |
| `SCHEDULE_EXACT_ALARM` | Notificações precisas | Sim |
| `FOREGROUND_SERVICE` | Pomodoro timer | Sim |
| `USE_BIOMETRIC` | Lock screen | Não |

### 11.3 Validação de Input

- **Sempre sanitize** títulos antes de gerar slugs (remover caracteres especiais, converter para kebab-case)
- **Nunca confie em dados** do frontmatter YAML — faça type checking (`is String`, `is int`)
- **Trate `null`** para todo campo opcional — use operadores `?.` e `??`
- **Limite tamanhos** de input onde faz sentido (título: 500 chars, body: sem limite)

---

## 12. NOTIFICAÇÕES

### 12.1 Três Tipos

| Tipo | Comportamento | Configuração |
|---|---|---|
| **Push** | Notification shade padrão | Som, vibração, LED color |
| **Popup** | Full-screen sobre lock screen | Background color, botões |
| **Alarm** | Toca como alarme (ignora silencioso) | Ringtone, snooze duration |

### 12.2 Action Buttons em Todas as Notificações

- **"Concluído"** — marca o objeto como completo SEM abrir o app
- **"Adiar"** — adia pela duração de snooze configurada (padrão: 10min)
- **"Dispensar"** — fecha sem marcar como completo

### 12.3 Regras de Implementação

- Usar `AlarmManager.setExactAndAllowWhileIdle()` no Android
- Registrar alarmes no MOMENTO da criação, não ao abrir o app
- Cada objeto pode ter múltiplos reminders independentes

---

## 13. ARMADILHAS CONHECIDAS (NÃO REINTRODUZIR)

### 13.1 Overflow de Texto

**Problema**: Textos longos causam `RenderFlex overflowed`.
**Solução**: TODO `Text` em listas/cards DEVE ter `maxLines` + `overflow: TextOverflow.ellipsis`.

### 13.2 Widget de Mês Travado em "Carregando..."

**Problema**: `WidgetSyncProvider` bloqueava quando `allObjectsProvider` não tinha carregado.
**Solução**: Usar `maybeWhen`. Garantir que `monthFocus` nunca seja vazio — usar fallback.

### 13.3 Exclusão de Hábitos Não Funcionava

**Problema**: `deleteObject()` falhava quando backup retornava null.
**Solução**: Deletar o original INDEPENDENTE do sucesso da cópia de backup.

### 13.4 Duplicação de Objetos

**Problema**: Arquivos em `_deleted/` eram re-parseados.
**Solução**: Filtrar `_deleted/` e `_attachments/` durante o scan do vault.

### 13.5 Journal Entry Mostrando JSON Bruto

**Problema**: Campo `body` armazenado como JSON do Quill Delta.
**Solução**: Converter Delta para plain text em previews.

### 13.6 Organizer Summary Acessando Campo Inexistente

**Problema**: Dashboard acessava `.id` em `OrganizerReference`.
**Solução**: Usar `.slug` e `.title`.

---

## 14. CHECKLIST DE REVISÃO DE CÓDIGO

### UI/UX
- [ ] Funciona em light mode E dark mode
- [ ] Nenhum overflow em resoluções comuns (360x640, 390x844, 412x915)
- [ ] Textos em listas têm `maxLines` + `overflow: ellipsis`
- [ ] Textos de UI em PT-BR
- [ ] Empty states com mensagem + CTA
- [ ] Modais com X ou handle pill

### Dados
- [ ] Mutações via `VaultNotifier`
- [ ] `_invalidateObjectProviders()` chamado após mutações
- [ ] Merge com conteúdo existente (não sobrescrever .md)
- [ ] Campos YAML desconhecidos preservados
- [ ] `SyncAction` enfileirada para toda operação CRUD

### Robustez
- [ ] I/O em try-catch
- [ ] Nenhuma cor hardcoded
- [ ] `ListView.builder` para listas grandes
- [ ] `const` constructors onde possível
- [ ] `debugPrint` em vez de `print`

---

---

## 16. RECOMENDAÇÕES DE IMPLEMENTAÇÃO E OTIMIZAÇÃO

### 16.1 Inicialização e Boot
- **Paralelismo**: Nunca use `await` sequencial no `_initApp` para serviços independentes. Use `Future.wait([...])`.
- **Lazy Loading**: Não bloqueie a UI esperando o vault carregar totalmente se puder mostrar um estado parcial ou esqueleto.

### 16.2 Gerenciamento de Estado (Riverpod)
- **Granularidade**: Use `.select((val) => val.field)` ao observar objetos grandes para evitar rebuilds quando campos irrelevantes mudam.
- **Unificação de Derivados**: Em vez de criar 10 providers que filtram `allObjectsProvider`, use um único `groupedObjectsProvider` que retorna um mapa indexado por tipo.
- **Evitar Redundância**: Providers como `dailyNoteDataProvider` devem consumir dados já parseados na memória em vez de ler o arquivo novamente.

### 16.3 I/O e Sincronização
- **Debouncing**: Operações de escrita pesada ou sincronização com sistemas nativos (como `HomeWidget`) DEVEM ser debouncadas (ex: 500ms) para evitar gargalos em operações rápidas e sucessivas.
- **Escrita em Background**: Garanta que o processamento de markdown e escrita em disco não bloqueie a thread principal da UI.
- **Deduplicação de Loops**: Mantenha apenas um loop de sincronização ativo (via `SyncManager`).

### 16.4 Widgets e UI
- **Const**: Use `const` em todos os widgets e estilos que não mudam.
- **Repaint Boundaries**: Use `RepaintBoundary` em animações complexas ou listas pesadas para isolar o custo de renderização.

---

> **Última atualização**: 2026-05-15
> **Gerado a partir de**: Consolidação da arquitetura centrada em tarefas (Task-centric)


## REGRA FUNDAMENTAL: ANÁLISE PROATIVA, NÃO REATIVA

O agente **não deve esperar o usuário reportar um bug para identificá-lo**. Ao ler qualquer arquivo Dart do projeto, o agente deve procurar ativamente por erros, independentemente do que foi perguntado.

---

## PADRÕES DE ERRO QUE DEVEM SEMPRE ACENDER ALERTA

### 1. Stub não implementado
```
método() async {}          // corpo vazio
método() { return null; }  // retorno sem lógica
throw UnimplementedError() // nunca implementado
```
🚨 Alerta: identificar quem chama esse método e qual feature depende dele.

### 2. Provider/lista sempre vazia
```dart
static Future<List<int>> widgetIds() async => [];  // sempre vazio
final state = AsyncData([]);                        // nunca preenchido
```
🚨 Alerta: quem consome esse provider recebe sempre vazio — feature silenciosamente quebrada.

### 3. Campo escrito com uma chave, lido com outra
```dart
map['due_date'] = value;   // escrita
final x = map['dueDate'];  // leitura — sempre null
```
🚨 Alerta: dado salvo mas nunca recuperado — bug silencioso, sem crash.

### 4. Type mismatch em parsing
```dart
// Arquivo escreve:
frontmatter['type'] = 'task';
// Parser lê:
case 'Task': // capitalização diferente — nunca faz match
```
🚨 Alerta: objeto nunca parseado — desaparece silenciosamente do vault.

### 5. Canal/ID não-determinístico
```dart
id: DateTime.now().millisecondsSinceEpoch % 100000  // ID diferente a cada chamada
```
🚨 Alerta: mesmo objeto gera IDs diferentes em sessões distintas — duplicatas garantidas.

### 6. Acesso sem null-check ou bounds-check
```dart
list[0]                    // crash se lista vazia
map['campo']!              // crash se campo ausente
DateTime.parse(str)        // crash se str malformada
object as ConcreteType     // crash se tipo errado
```
🚨 Alerta: crash em runtime com dados reais do vault (usuário pode ter editado no Obsidian).

### 7. Rota referenciada mas não registrada
```dart
context.push('/create/event')  // no form
// GoRouter não tem '/create/event' registrado
```
🚨 Alerta: navegação falha silenciosamente (GoRouter retorna erro no console, UI não responde).

### 8. Import de arquivo inexistente
```dart
import 'package:citrine/models/event_model.dart';
// event_model.dart não existe na lista de arquivos
```
🚨 Alerta: compile error — app não builda.

### 9. Método chamado em objeto potencialmente null
```dart
_navigatorKey?.currentState?.push(...)  // ok — safe call
_navigatorKey!.currentState.push(...)   // crash se null
_container!.read(provider)              // crash se container não inicializado
```
🚨 Alerta: verificar se o campo é garantidamente não-null no momento da chamada.

### 10. Canal de notificação desatualizado
```dart
AndroidNotificationDetails(channelId: 'alarm_channel_v4')
// mas o canal criado é 'alarm_channel_v5'
```
🚨 Alerta: notificação vai para canal inexistente — não dispara, sem crash, bug silencioso total.

## Crash Reporting Logs

The application automatically records crash reports via **CrashReportService** (`lib/services/crash_report_service.dart`).

- **Internal storage** – located in the app's documents directory under:
  ```
  <app_documents_directory>/diagnostics/crash_reports
  ```
  You can retrieve the list programmatically with:
  ```dart
  final reports = await CrashReportService.instance.getInternalReports();
  ```
  Each file is a markdown (`.md`) document containing front‑matter, error details, stack trace and recent app events.

- **Vault storage** – if a vault path is configured (`prefs.getString('vault_path')`), a copy is written to:
  ```
  <vault_path>/_diagnostics/crash_reports
  ```
  This keeps a permanent record synced with Google Drive.

### How to access the logs
1. **From code** – call `CrashReportService.instance.getInternalReports()` or `CrashReportService.instance._writeReport(...)` for custom handling.
2. **From the device** – use a file explorer or `adb pull` to copy the directory:
   ```
   adb pull "$(adb shell "echo $HOME")/files/diagnostics/crash_reports" ./crash_reports
   ```
3. **From the vault** – navigate to the `_diagnostics/crash_reports` folder inside your Obsidian vault.

### Guidelines
- Never delete these files manually; use `CrashReportService` methods to clear them.
- Ensure the vault path is set in **Settings → Vault Path** so the dual‑write works.
- The service is initialized in `main.dart` (see lines 182‑185) and is active in both debug and release builds.

---

## FORMATO DE REPORTE OBRIGATÓRIO

Quando encontrar qualquer um dos padrões acima, reportar **imediatamente** neste formato, mesmo que o usuário não tenha perguntado sobre aquele trecho:

```
🚨 [ARQUIVO:LINHA] TIPO_DO_ERRO
   Chama:   o que o código está tentando fazer
   Destino: o que existe de fato (ou o que está faltando)
   Impacto: crash / dado perdido / sempre null / duplicata / feature inativa
   Fix:     correção direta (1-3 linhas de código)
```

Exemplo real encontrado neste projeto:
```
🚨 [widget_service.dart:~89] STUB NÃO IMPLEMENTADO
   Chama:   updatePlanner(title, content, footer) — chamado pelo dashboard ao atualizar
   Destino: corpo do método é {} — não faz nada
   Impacto: widget de planner no dashboard nunca atualiza
   Fix:     await _saveJson('citrine_planner', {'title': title, 'content': content,
            'footer': footer}); await _update(_plannerProvider);
```

---

## O QUE NÃO É ACEITÁVEL

| Comportamento proibido | Comportamento correto |
|------------------------|----------------------|
| "O código existe então provavelmente funciona" | Verificar se o código tem implementação real |
| Marcar ✅ sem testar ou ver o corpo do método | Só marcar ✅ se implementação real + sem os padrões de erro acima |
| Ignorar método vazio porque está fora do escopo da pergunta | Reportar o stub com o formato de alerta |
| Assumir que dados do vault estão sempre bem formatados | Verificar null-safety e tryParse em todos os acessos |
| Esperar o usuário testar no device para descobrir bugs visíveis no código | Identificar o bug pelo código antes do teste |

---

*Esta regra se aplica a toda análise, independentemente do que foi perguntado. Se o agente está lendo um arquivo para qualquer motivo e encontra um desses padrões, ele alerta.*

---

## Complementos do gap 2026-06-24

### Tema global

- O tema persistente agora depende de `themeMode` e `activeThemeId` em `settingsProvider`.
- `themeProvider` é a camada responsável por transformar preferências em `ThemeData`.
- A tela `appearance_screen.dart` deve ser tratada como a interface principal para troca de tema e modo claro/escuro.

### Property grid

- Resumos de propriedades em telas de detalhe devem usar `ui/widgets/property_grid.dart`.
- Prefira células curtas, com título, valor e ação opcional, em vez de listas longas de `ListTile` com divisórias.

### Diagnósticos

- Use a chave persistida `vaultPath` ao sincronizar o destino dos crash reports.
- A exportação agregada da tela de diagnósticos deve continuar simples e rápida, priorizando cópia consolidada para área de transferência.
