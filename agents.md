# Quartzo — Diretrizes para Agentes de IA

> **LEIA ESTE ARQUIVO INTEIRO antes de fazer qualquer alteração no código.**
> Estas diretrizes são obrigatórias. Violá-las causa regressões, bugs e inconsistências que custam horas para corrigir.

---

## 1. VISÃO GERAL DO PROJETO

**Quartzo** é um aplicativo de produtividade pessoal e journaling construído com **Flutter** (Dart). Ele funciona como um frontend premium para um vault Obsidian — todos os dados do usuário são armazenados como arquivos `.md` (Markdown com frontmatter YAML), sincronizados via Google Drive.

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
│   ├── organizer_model.dart     # OrganizerReference, Organizer (incl. Value subtype)
│   ├── routine_model.dart       # Routine, RoutineItem, RoutineExecution
│   ├── pillar_model.dart        # Pillar, PillarTouch, EnergyLevel
│   ├── action_menu_item_model.dart # ActionMenuItem
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
│   ├── routine_execution_service.dart # Execução de rotinas com sync de hábitos
│   ├── mood_routine_service.dart # Sugestão de rotinas baseadas em humor
│   ├── kpi_engine.dart          # Cálculo de KPIs
│   ├── search_service.dart      # Busca full-text no vault
│   ├── widget_service.dart      # Bridge para widgets nativos Android/iOS
│   ├── timeline_aggregator_service.dart # Agregação de timeline reutilizável
│   └── ...
└── ui/
    ├── theme.dart               # AppTheme, AppColors — design system central
    ├── screens/                 # Telas completas (navegáveis via GoRouter)
    │   ├── home_screen.dart     # Dashboard (~93KB) — blocos configuráveis
    │   ├── planner_screen.dart  # Planner Day/Week/Month (~62KB)
    │   ├── universal_detail_view.dart # Detail view universal (~116KB)
│   ├── detail_sections/     # Seções modulares por tipo de conteúdo
│   │   ├── task_detail_section.dart
│   │   ├── habit_detail_section.dart
│   │   ├── project_detail_section.dart
│   │   ├── goal_detail_section.dart
│   │   ├── note_detail_section.dart
│   │   ├── person_detail_section.dart
│   │   ├── journal_entry_detail_section.dart
│   │   ├── idea_detail_section.dart
│   │   ├── mood_detail_section.dart
│   │   ├── tracker_detail_section.dart
│   │   ├── resource_detail_section.dart
│   │   └── pillar_detail_section.dart
    │   ├── journal_screen.dart  # Timeline de journal entries
    │   └── ...                  # 33 screens no total
    ├── forms/                   # Formulários de criação/edição
    │   ├── create_task_form.dart     # (~45KB)
    │   ├── create_habit_form.dart    # (~40KB)
    │   ├── create_entry_form.dart    # (~32KB)
    │   ├── create_entry_form.dart    # (~32KB)
    │   ├── create_pillar_form.dart   # Formulário de criação de Pillar
    │   ├── scheduler_picker.dart     # (~21KB) — 11 repeat types
    │   └── ...                       # 17 forms no total
    ├── widgets/                 # Componentes reutilizáveis
    │   ├── property_grid.dart       # PropertyCard, PropertyGrid, PropertyCardState
    │   ├── timeline_day_view.dart    # Visualização de timeline
    │   ├── object_timeline_feed.dart # Feed de timeline reutilizável
    │   ├── rich_text_editor.dart     # Editor rich text
    │   ├── wiki_link_picker.dart     # Picker de WikiLinks [[]]
    │   ├── habit_detail_sheet.dart   # Sheet de detalhes de hábito
    │   ├── property_row.dart         # PropertyRow - label-value row com tap opcional
    │   ├── form_section_card.dart    # FormSectionCard - card padrão para forms
    │   ├── discard_guard.dart        # DiscardGuard - proteção de alterações não salvas
    │   ├── template_picker_sheet.dart # TemplatePickerSheet - seleção de templates
    │   ├── reminder_config_sheet.dart # ReminderConfigSheet - configuração de lembretes
    │   ├── app_color_picker.dart     # AppColorPicker - seleção de cores unificada
    │   ├── number_stepper.dart       # NumberStepper - controle de incremento/decremento
    │   ├── count_badge.dart          # CountBadge - badge de contagem
    │   ├── section_divider.dart      # SectionDivider - divisor de seções
    │   └── ...                       # 40+ widgets no total
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
│   ├── activities/  # Atividades recorrentes
│   ├── day_themes/  # Day Themes (organizer type)
│   └── time_blocks/ # Time Blocks (organizer type)
├── resources/       # Recursos (livros, filmes, etc.)
├── sessions/        # (Legado) Antigas Calendar Sessions (não usar mais)
├── _attachments/    # Fotos, áudios, mídia
├── _deleted/        # Lixeira (purge automático após 30 dias)
├── _conflicts/      # Backups de conflitos de sync
└── _backups/        # ZIPs de backup periódico
```

**NOTA**: A estrutura de pastas é configurável via Object Identification (Settings → Object Identification). O usuário pode definir onde cada tipo de objeto é armazenado (por tag, propriedade ou pasta).

---

## 4. DETAIL SECTIONS MODULARES

O `universal_detail_view.dart` foi modularizado em arquivos separados por tipo de conteúdo em `ui/screens/detail_sections/`. Cada arquivo contém funções que constroem as property cards específicas para aquele tipo de objeto.

### Arquivos de Detail Section

- `task_detail_section.dart` - `buildTaskPropertyCards()`
- `habit_detail_section.dart` - `buildHabitPropertyCards()`
- `project_detail_section.dart` - `buildProjectPropertyCards()`
- `goal_detail_section.dart` - `buildGoalPropertyCards()`
- `note_detail_section.dart` - `buildNotePropertyCards()`
- `person_detail_section.dart` - `buildPersonPropertyCards()`
- `journal_entry_detail_section.dart` - `buildJournalEntryPropertyCards()`
- `idea_detail_section.dart` - `buildIdeaPropertyCards()`
- `mood_detail_section.dart` - `buildMoodPropertyCards()`
- `tracker_detail_section.dart` - `buildTrackerPropertyCards()`
- `resource_detail_section.dart` - `buildResourcePropertyCards()`
- `routine_detail_section.dart` - `buildRoutinePropertyCards()`

### Regras de Import para Detail Sections

Arquivos em `ui/screens/detail_sections/` estão em um subdiretório, então os caminhos de import são diferentes:

```dart
// ✅ CORRETO - 3 níveis acima para models/providers
import '../../../models/task_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/kpi_engine.dart';

// ✅ CORRETO - 2 níveis acima para widgets/theme
import '../../widgets/property_grid.dart';
import '../../theme.dart';

// ❌ ERRADO - não usar caminhos relativos incorretos
import '../../models/task_model.dart';  // Errado - só 2 níveis
import '../widgets/property_grid.dart'; // Errado - só 1 nível
```

### Regras de Providers em Detail Sections

**NÃO use providers específicos como `tasksProvider` ou `notesProvider`** - eles não existem mais. Use sempre `allObjectsProvider`:

```dart
// ✅ CORRETO
final allObjects = ref.watch(allObjectsProvider).value ?? [];
final tasks = allObjects.whereType<Task>().where(...).toList();

// ❌ ERRADO - tasksProvider não existe
final tasks = ref.watch(tasksProvider);
```

**Sempre use `.value ?? []` para lidar com AsyncValue:**

```dart
// ✅ CORRETO
final allObjects = ref.watch(allObjectsProvider).value ?? [];

// ❌ ERRADO - AsyncValue não tem whereType diretamente
final tasks = ref.watch(allObjectsProvider).whereType<Task>();
```

### Enums Atuais - Importante

**TaskPriority** (em `task_model.dart`):
- `none`, `low`, `medium`, `high`
- **NÃO existe** `critical`

**TaskStage** (em `task_model.dart`):
- `idea`, `backlog`, `todo`, `inProgress`, `pending`, `finalized`
- **NÃO existe** `cancelled`, **NÃO existe** `waiting`

**IdeaHorizon** (em `idea_model.dart`):
- `now`, `soon`, `someday`, `noDeadline`
- **NÃO existe** `immediate`, `shortTerm`, `mediumTerm`, `longTerm`

**GoalStatus** (em `goal_model.dart`):
- `active`, `completed`, `cancelled`, `onHold`
- Goal usa campo `state` (não `status`)

**Person** usa `TaskPriority` para `contactPriority` (não existe `ContactPriority`)

**Project** usa `TaskPriority` para `projectPriority` (não existe `ProjectPriority`)

---

## 8. SISTEMA DE EMOJIS — CONFIGURÁVEL

### 8.1 Como Funciona

Emojis são **configuráveis pelo usuário** via Object Identification (Settings → Object Identification). Cada tipo de objeto pode ter um emoji personalizado.

**Componentes do sistema:**

1. **`TypeSignature`** (em `lib/models/shared_types.dart`):
   - Define como identificar um tipo de objeto (markerType, markerValue)
   - Inclui campo `emoji` para o ícone personalizado
   - Salvo em `settings.typeSignatures` (SharedPreferences)

2. **`ObjectIcons`** (em `lib/ui/utils/object_icons.dart`):
   - `emojiForType(type, ref)` - retorna emoji configurado nas settings
   - `defaultIconForType(type)` - retorna emoji padrão (fallback)
   - `defaultIconForNoteSubtype(subtype)` - emojis para subtipos de Note
   - `defaultIconForHabitMode(mode)` - emojis para modos de Habit
   - `defaultIconForEntryType(entryType)` - emojis para tipos de Entry

3. **`type_signatures_screen.dart`**:
   - UI para editar emojis e identificadores
   - Mostra emoji atual de cada tipo
   - Campo "Emoji" no diálogo de edição (limite 2 caracteres)

### 8.2 Regras para Uso de Emojis

**✅ CORRETO — Usar emojis configuráveis:**
```dart
// Em qualquer widget Consumer
import '../utils/object_icons.dart';

// Obter emoji configurado (com fallback para padrão)
final emoji = ObjectIcons.emojiForType('task', ref);
Text(emoji, style: const TextStyle(fontSize: 20));

// Para subtipos específicos
final noteEmoji = ObjectIcons.defaultIconForNoteSubtype('outline');
```

**❌ ERRADO — Emojis hardcoded:**
```dart
// Nunca use emojis hardcoded na UI
Text('✅', style: const TextStyle(fontSize: 20));
Text('🔄', style: const TextStyle(fontSize: 20));
```

### 8.3 Emojis Padrão (Fallback)

Se o usuário não configurar um emoji, o sistema usa estes padrões:

| Tipo | Emoji Padrão |
|---|---|
| Task | ✅ |
| Habit | 🔁 |
| Goal | 🎯 |
| Note | 📝 |
| Journal Entry | 📓 |
| Event | 📅 |
| Reminder | 🔔 |
| Person | 👤 |
| Resource | 📚 |
| Idea | 💡 |
| Project | 🎯 |
| Area | 🗺️ |
| Activity | ⚡ |
| Label | 🏷️ |
| Tracker | 📊 |
| System | ⚙️ |
| Social Post | 📱 |
| Shopping List | 🛒 |
| Template | 🧩 |
| Inbox | 📥 |
| Analysis | 📊 |
| Mood Def | 😐 |

### 8.4 Quando Usar Emojis Configuráveis

**Use `ObjectIcons.emojiForType()` quando:**
- Mostrar ícone de tipo em listas (Tasks, Notes, etc.)
- Mostrar ícone em chips/badges de tipo
- Mostrar ícone em pickers/seletores
- Qualquer lugar onde o tipo de objeto é visualmente identificado

**Use emojis hardcoded apenas quando:**
- É um emoji específico de um subtipo (ex: Note subtypes)
- É um emoji contextual (ex: mood picker, status badges)
- Não representa um tipo de objeto

### Anti-Patterns Comuns em Detail Sections

**❌ ERRADO 1: Import paths incorretos**
```dart
// Errado - só 2 níveis para models
import '../../models/task_model.dart';

// Errado - só 1 nível para widgets
import '../widgets/property_grid.dart';

// Errado - caminho incorreto para theme
import '../theme.dart';
```

**✅ CORRETO 1: Import paths corretos**
```dart
// Correto - 3 níveis para models/providers
import '../../../models/task_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/kpi_engine.dart';

// Correto - 2 níveis para widgets/theme
import '../../widgets/property_grid.dart';
import '../../theme.dart';
```

**❌ ERRADO 2: Usar providers inexistentes**
```dart
// Errado - tasksProvider não existe mais
final tasks = ref.watch(tasksProvider);

// Errado - notesProvider não existe mais
final notes = ref.watch(notesProvider);
```

**✅ CORRETO 2: Usar allObjectsProvider**
```dart
// Correto - usar allObjectsProvider e filtrar
final allObjects = ref.watch(allObjectsProvider).value ?? [];
final tasks = allObjects.whereType<Task>().where(...).toList();
final notes = allObjects.whereType<Note>().where(...).toList();
```

**❌ ERRADO 3: Esquecer .value ?? [] para AsyncValue**
```dart
// Errado - AsyncValue não tem whereType diretamente
final tasks = ref.watch(allObjectsProvider).whereType<Task>();

// Errado - pode causar null pointer
final tasks = ref.watch(allObjectsProvider).value;
```

**✅ CORRETO 3: Sempre usar .value ?? []**
```dart
// Correto - extrair valor com fallback
final allObjects = ref.watch(allObjectsProvider).value ?? [];
final tasks = allObjects.whereType<Task>().toList();
```

**❌ ERRADO 4: Usar enums/campos que não existem**
```dart
// Errado - TaskPriority.critical não existe
case TaskPriority.critical:

// Errado - TaskStage.cancelled não existe
case TaskStage.cancelled:

// Errado - TaskStage.waiting não existe
case TaskStage.waiting:

// Errado - IdeaHorizon.immediate não existe
case IdeaHorizon.immediate:

// Errado - Goal.status não existe (é Goal.state)
if (goal.status == GoalStatus.completed):

// Errado - ContactPriority não existe
case ContactPriority.high:

// Errado - ProjectPriority não existe
case ProjectPriority.critical:
```

**✅ CORRETO 4: Usar enums/campos corretos**
```dart
// Correto - TaskPriority tem: none, low, medium, high
case TaskPriority.high:

// Correto - TaskStage tem: idea, backlog, todo, inProgress, pending, finalized
case TaskStage.finalized:

// Correto - IdeaHorizon tem: now, soon, someday, noDeadline
case IdeaHorizon.now:

// Correto - Goal usa campo state
if (goal.state == GoalStatus.completed):

// Correto - Person usa TaskPriority para contactPriority
case TaskPriority.high:

// Correto - Project usa TaskPriority para projectPriority
case TaskPriority.high:
```

**❌ ERRADO 5: Esquecer default case em switch**
```dart
// Errado - pode causar erro se enum for expandido
switch (task.priority) {
  case TaskPriority.high:
    color = Colors.red;
    break;
  case TaskPriority.medium:
    color = Colors.orange;
    break;
}
// Variável 'color' pode não ser inicializada
```

**✅ CORRETO 5: Sempre adicionar default case**
```dart
// Correto - cobre todos os casos
switch (task.priority) {
  case TaskPriority.high:
    color = Colors.red;
    break;
  case TaskPriority.medium:
    color = Colors.orange;
    break;
  case TaskPriority.low:
    color = Colors.green;
    break;
  case TaskPriority.none:
    color = Colors.grey;
    break;
  default:
    color = Colors.grey;
    break;
}
```

---

## 5. O ARQUIVO MAIS IMPORTANTE: `vault_provider.dart`

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

## 6. TIPOS DE OBJETOS — REFERÊNCIA RÁPIDA

| Tipo | Arquivo Vault | Provider | Modelo | Emoji Padrão |
|---|---|---|---|---|
| Journal Entry | `daily/YYYY-MM-DD.md` (body) | `journalEntriesProvider` | `JournalEntry` | 📝 |
| Task | `tasks/SLUG.md` | `allObjectsProvider` → filter | `Task` | ✅ |
| Goal | `goals/SLUG.md` | `allObjectsProvider` → filter | `Goal` | 🎯 |
| Habit | `habits/SLUG.md` | `allObjectsProvider` → filter | `HabitDefinition` | 🔄 |
| Tracker | `trackers/SLUG.md` | `allObjectsProvider` → filter | `TrackerDefinition` | 📊 |
| Reminder | inline ou `daily/` | `allObjectsProvider` → filter | `Reminder` | ⏰ |
| Note | `notes/SLUG.md` | `allObjectsProvider` → filter | `Note` | 📄 |
| Person | `organizers/people/SLUG.md` | `allObjectsProvider` → filter | `Person` | 👤 |
| Resource | `resources/SLUG.md` | `allObjectsProvider` → filter | `Resource` | 📚 |
| Mood Def | `moods/SLUG.md` | `moodDefinitionsProvider` | `MoodDefinition` | 😊 |
| Organizer (Area) | `organizers/areas/SLUG.md` | `organizerListProvider` → filter | `Organizer` | 🗺️ |
| Organizer (Project) | `organizers/projects/SLUG.md` | `organizerListProvider` → filter | `Organizer` | 🚀 |
| Organizer (Activity) | `organizers/activities/SLUG.md` | `organizerListProvider` → filter | `Organizer` | ⚡ |
| Organizer (Label) | `organizers/labels/SLUG.md` | `organizerListProvider` → filter | `Organizer` | 🏷️ |
| Organizer (Day Theme) | `organizers/day_themes/SLUG.md` | `organizerListProvider` → filter | `Organizer` | 🌅 |
| Organizer (Time Block) | `organizers/time_blocks/SLUG.md` | `organizerListProvider` → filter | `Organizer` | ⏱️ |
| Organizer (Routine) | `organizers/routines/SLUG.md` | `allObjectsProvider` → filter | `Routine` | 🔄 |
| Event | `events/SLUG.md` | `allObjectsProvider` → filter | `Event` | 📅 |
| Idea | `ideas/SLUG.md` | `allObjectsProvider` → filter | `Idea` | 💡 |
| System | `systems/SLUG.md` | `allObjectsProvider` → filter | `System` | ⚙️ |
| Social Post | `social/SLUG.md` | `allObjectsProvider` → filter | `SocialPost` | 📱 |
| Shopping List | `shopping/SLUG.md` | `allObjectsProvider` → filter | `ShoppingList` | 🛒 |
| Template | `templates/SLUG.md` | `allObjectsProvider` → filter | `Template` | 📋 |
| Analysis | `analyses/SLUG.md` | `allObjectsProvider` → filter | `Analysis` | 📈 |
| Wellbeing Indicator | `wellbeing/SLUG.md` | `allObjectsProvider` → filter | `WellbeingIndicator` | ❤️ |

**NOTA**: Emojis são configuráveis via Object Identification (Settings → Object Identification). O usuário pode personalizar o emoji de cada tipo de objeto conforme preferência.

### 5.1 Transformação de Day Themes e Time Blocks para Organizers

**DEPRECATION NOTICE**: Os modelos `DayTheme` e `TimeBlock` (em `lib/models/day_theme_model.dart`) estão **DEPRECIADOS**. Use o modelo unificado `Organizer` com os tipos `dayTheme` e `timeBlock` em vez disso.

**Motivo da transformação**:
- Unificar a arquitetura de organizadores
- Permitir configuração flexível via Object Identification
- Simplificar o código e reduzir duplicação

**Como migrar**:
1. **Day Themes**: Use `Organizer` com `organizerType: OrganizerType.dayTheme`
   - Campos preservados: `blockIds` → `organizers` (via OrganizerReference), `daysOfWeek`, `color`
2. **Time Blocks**: Use `Organizer` com `organizerType: OrganizerType.timeBlock`
   - Campos preservados: `timeRanges`, `color`, `energyLevel`

**Objetos existentes**: O app deve continuar suportando leitura de arquivos `.md` legados com `type: day_theme` e `type: time_block` para compatibilidade, mas novos objetos devem usar o sistema de organizadores.

---

## 7. DESIGN SYSTEM E UI/UX

### 7.1 Tema e Cores

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

### 7.2 Regras de Layout Obrigatórias

1. **SafeArea em TODA tela**: Envolver conteúdo com `SafeArea` ou respeitar `MediaQuery.of(context).padding`
2. **Overflow prevention**: Todo `Text` em listas/cards DEVE ter `maxLines` + `overflow: TextOverflow.ellipsis`
3. **Responsive**: Usar `MediaQuery` ou `LayoutBuilder` para adaptar layouts. Nunca usar dimensões fixas absolutas para containers pais
4. **Scroll**: Conteúdo entre nav bar e tab bar deve ser scrollável. Usar `SingleChildScrollView` ou `ListView`
5. **Keyboard avoidance**: Formulários devem usar `resizeToAvoidBottomInset: true`

### 7.3 Componentes Padrão

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

### 7.4 Tipografia (hierarquia)

| Uso | Tamanho | Peso |
|---|---|---|
| Título da tela (nav bar) | 17-18pt | Semibold |
| Título do card/item | 16-17pt | Regular/Medium |
| Subtítulo/metadata | 13-14pt | Regular, cor muted |
| Header de seção | 13-14pt | Semibold |
| Texto auxiliar/exemplo | 12-13pt | Regular, cinza claro |
| Label de botão CTA | 16-17pt | Semibold, branco |
| Campo de formulário | 15-16pt | Regular |

### 7.5 Interações e Feedback

- **Haptic feedback**: Light impact (hábito completo), medium (tarefa completa), warning (ação destrutiva)
- **Undo snackbar**: 5 segundos, botão "Desfazer" em roxo, aparece em TODA ação destrutiva
- **Confirmação de delete**: Alert com "Excluir" (vermelho) e "Cancelar"
- **Swipe left em listas**: Revelar ações rápidas (Delete, Change Stage)
- **Long press**: Multi-select ou menu contextual
- **Tap targets**: Mínimo 44×44pt (iOS) / 48×48dp (Android)

### 7.6 Dark Mode

- O app suporta Dark Mode. TODA nova tela/widget DEVE funcionar em ambos os temas
- Use SEMPRE `AppColors` e `Theme.of(context)` — nunca cores hardcoded
- Teste visualmente em ambos os modos antes de considerar uma tela pronta

### 7.7 Constantes de Design System — OBRIGATÓRIO

**NUNCA use valores hardcoded para spacing, border radius, font sizes, ou border width.** Use SEMPRE as constantes definidas em `lib/ui/theme.dart`:

```dart
// ✅ CORRETO
padding: const EdgeInsets.all(AppSpacing.lg),
borderRadius: BorderRadius.circular(AppBorderRadius.md),
fontSize: AppTextSize.md,
borderWidth: AppBorder.normal,

// ❌ ERRADO
padding: const EdgeInsets.all(16),
borderRadius: BorderRadius.circular(12),
fontSize: 14,
borderWidth: 1.5,
```

**Constantes disponíveis:**

#### AppBorderRadius
- `xs` = 4.0 (elementos muito pequenos)
- `sm` = 8.0 (badges, chips pequenos)
- `md` = 12.0 (inputs, botões)
- `lg` = 16.0 (cards padrão)
- `xl` = 20.0 (cards destacados, chips)
- `xxl` = 24.0 (sheets, modais)
- `xxxl` = 32.0 (elementos grandes)

#### AppSpacing
- `xs` = 4.0 (espaçamento mínimo)
- `sm` = 8.0 (espaçamento compacto)
- `md` = 12.0 (espaçamento padrão)
- `lg` = 16.0 (espaçamento confortável)
- `xl` = 20.0 (espaçamento generoso)
- `xxl` = 24.0 (espaçamento grande)
- `xxxl` = 32.0 (espaçamento muito grande)

#### AppTextSize
- `xs` = 10.0 (labels pequenas, captions)
- `sm` = 12.0 (textos auxiliares, metadata)
- `md` = 14.0 (texto de corpo padrão)
- `lg` = 16.0 (títulos de itens, corpo grande)
- `xl` = 18.0 (títulos de seção)
- `xxl` = 20.0 (títulos grandes)
- `display` = 28.0 (títulos de tela)

#### AppBorder
- `thin` = 1.0 (bordas sutis)
- `normal` = 1.5 (bordas padrão)
- `thick` = 2.0 (bordas destacadas)
- `extraThick` = 3.0 (bordas muito destacadas)

#### AppIconSize
- `xs` = 12.0 (ícones muito pequenos)
- `sm` = 16.0 (ícones pequenos)
- `md` = 20.0 (ícones padrão)
- `lg` = 24.0 (ícones grandes)
- `xl` = 32.0 (ícones muito grandes)
- `xxl` = 48.0 (ícones de destaque)
- `display` = 56.0 (ícones hero)

### 7.8 Componentes Reutilizáveis — OBRIGATÓRIO

**Use SEMPRE os componentes reutilizáveis disponíveis em `lib/ui/widgets/` em vez de reimplementar padrões duplicados:**

#### StandardSheet (`lib/ui/widgets/standard_sheet.dart`)
Use para TODOS os bottom sheets e modais:

```dart
// ✅ CORRETO
StandardSheet(
  radius: SheetRadius.large,
  showHandle: true,
  child: YourContent(),
)

// ❌ ERRADO
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).scaffoldBackgroundColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
  ),
  child: YourContent(),
)
```

#### AppChip (`lib/ui/widgets/app_chip.dart`)
Use para TODOS os chips (choice, filter, action):

```dart
// ✅ CORRETO
AppChip(
  label: 'Label',
  selected: isSelected,
  onTap: () => {},
  variant: ChipVariant.choice,
  size: ChipSize.medium,
)

// ❌ ERRADO
ChoiceChip(
  label: Text('Label'),
  selected: isSelected,
  onSelected: (_) => {},
  // ... reimplementando estilos manualmente
)
```

#### StatusBadge (`lib/ui/widgets/status_badge.dart`)
Use para TODOS os badges de status:

```dart
// ✅ CORRETO
StatusBadge(
  label: 'Completed',
  variant: BadgeVariant.success,
  size: BadgeSize.medium,
)

// ❌ ERRADO
Container(
  decoration: BoxDecoration(
    color: AppColors.success.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text('Completed'),
)
```

#### DatePickerField (`lib/ui/widgets/date_picker_field.dart`)
Use para TODOS os seletores de data:

```dart
// ✅ CORRETO
DatePickerField(
  selectedDate: _date,
  onDateChanged: (date) => setState(() => _date = date),
  label: 'Due Date',
)

// ❌ ERRADO
GestureDetector(
  onTap: () async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _date = date);
  },
  child: TextField(...),
)
```

#### TimePickerField (`lib/ui/widgets/time_picker_field.dart`)
Use para TODOS os seletores de hora:

```dart
// ✅ CORRETO
TimePickerField(
  selectedTime: _time,
  onTimeChanged: (time) => setState(() => _time = time),
  label: 'Start Time',
)

// ❌ ERRADO
GestureDetector(
  onTap: () async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _time = time);
  },
  child: TextField(...),
)
```

#### 7.8.9 Componentes Reutilizáveis - Diretrizes de Criação

**SEMPRE use componentes reutilizáveis existentes antes de criar UI inline.** Isso garante consistência de UI e reduz o custo de manutenção.

#### Componentes Reutilizáveis Disponíveis

**Componentes de Form** (`lib/ui/widgets/`):
- `PropertyRow` - Linha label-valor com ação de tap opcional
- `FormSectionCard` - Card padrão para seções de formulário
- `DiscardGuard` - Wrapper PopScope para proteção de alterações não salvas
- `DatePickerField` - Seletor de data reutilizável com UI consistente
- `AppColorPicker` - Seleção de cor unificada com paleta padrão
- `NumberStepper` - Input numérico com incremento/decremento
- `TemplatePickerSheet` - Modal sheet para seleção de templates
- `ReminderConfigSheet` - Modal sheet para configuração de lembretes
- `CreateFormScaffold` - Layout de formulário unificado com botão save e discard guard

**Componentes de Utilidade** (`lib/ui/widgets/`):
- `CountBadge` - Badge para exibir contagens
- `SectionDivider` - Divisor horizontal com label opcional
- `showNumberInputDialog` - Dialog para input numérico

**Funções de Utilidade** (`lib/ui/utils/`):
- `NotificationTypeUtils.getIcon()` - Obter ícone para tipo de notificação
- `NotificationTypeUtils.getLabel()` - Obter label para tipo de notificação

#### Quando Criar um Novo Componente Reutilizável

Crie um novo componente reutilizável quando:
1. O padrão de UI aparece em **3 ou mais lugares** no código
2. O componente tem **comportamento configurável** (não apenas conteúdo estático)
3. O componente representa uma **interação comum do usuário** (seleção de data, cor, etc.)
4. O componente se beneficiaria de **estilização centralizada** e theming

**NÃO crie componentes reutilizáveis para:**
- Padrões de UI one-off usados apenas uma vez
- Layouts estáticos simples que são específicos do contexto
- Componentes que exigiriam parâmetros de configuração excessivos

#### Checklist de Criação de Componentes

Antes de criar um novo componente reutilizável:
1. ✅ Pesquise componentes existentes para garantir que não haja duplicata
2. ✅ Verifique se o padrão aparece em 3+ locais
3. ✅ Projete uma API simples e focada (evite super-parametrização)
4. ✅ Use constantes do design system (`AppColors`, `AppSpacing`, `AppBorderRadius`)
5. ✅ Adicione comentários de documentação com exemplos de uso
6. ✅ Atualize este arquivo agents.md com o novo componente
7. ✅ Atualize guidelines.md com documentação do novo componente

#### Diretrizes de Migração

Ao refatorar UI inline para usar componentes reutilizáveis:
1. Identifique o padrão inline
2. Verifique se existe um componente reutilizável
3. Se sim, adote o componente existente
4. Se não, crie o componente reutilizável primeiro, depois adote-o
5. Teste a paridade visual e funcional
6. Atualize a documentação

**Exemplo de migração - Seletor de Data:**

❌ **Antes (inline):**
```dart
InkWell(
  onTap: () async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  },
  child: TextField(
    controller: TextEditingController(text: _selectedDate?.toString() ?? ''),
    decoration: InputDecoration(labelText: 'Date'),
    readOnly: true,
  ),
)
```

✅ **Depois (reutilizável):**
```dart
DatePickerField(
  label: 'Date',
  selectedDate: _selectedDate,
  onDateChanged: (date) => setState(() => _selectedDate = date),
)
```

#### AppDropdown (`lib/ui/widgets/app_dropdown.dart`)
Use para TODOS os dropdowns:

```dart
// ✅ CORRETO
AppDropdown<String>(
  value: _selectedValue,
  items: [
    DropdownMenuItem(value: 'option1', child: Text('Option 1')),
    DropdownMenuItem(value: 'option2', child: Text('Option 2')),
  ],
  onChanged: (value) => setState(() => _selectedValue = value),
  label: 'Select Option',
)

// ❌ ERRADO
DropdownButtonFormField<String>(
  value: _selectedValue,
  items: [...],
  onChanged: (value) => setState(() => _selectedValue = value),
  decoration: InputDecoration(...),
)
```

#### AppSwitchTile (`lib/ui/widgets/app_switch_tile.dart`)
Use para TODOS os switches em listas:

```dart
// ✅ CORRETO
AppSwitchTile(
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value),
  title: 'Enable Feature',
  subtitle: 'Description of the feature',
)

// ❌ ERRADO
SwitchListTile.adaptive(
  contentPadding: EdgeInsets.zero,
  title: Text('Enable Feature'),
  subtitle: Text('Description'),
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value),
)
```

#### ConfirmDialog (`lib/ui/widgets/confirm_dialog.dart`)
Use para TODOS os diálogos de confirmação:

```dart
// ✅ CORRETO
final confirmed = await ConfirmDialog.show(
  context,
  title: 'Delete item?',
  content: 'This action can be undone for 30 days.',
  confirmText: 'Delete',
  cancelText: 'Cancel',
  isDestructive: true,
);

// ❌ ERRADO
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Delete item?'),
    content: const Text('This action can be undone for 30 days.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        child: const Text('Delete'),
      ),
    ],
  ),
);
```

#### FormSection (`lib/ui/widgets/form_section.dart`)
Use para TODAS as seções de formulário:

```dart
// ✅ CORRETO
FormSection(
  title: 'Basic Information',
  description: 'Enter the basic details',
  children: [
    TextFormField(...),
    TextFormField(...),
  ],
)

// ❌ ERRADO
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Basic Information', style: ...),
    Text('Description', style: ...),
    const SizedBox(height: 12),
    TextFormField(...),
    TextFormField(...),
    const SizedBox(height: 16),
  ],
)
```

#### ListItem (`lib/ui/widgets/list_item.dart`)
Use para TODOS os itens de lista interativos:

```dart
// ✅ CORRETO
ListItem(
  leading: Icon(Icons.task),
  title: Text('Task Title'),
  subtitle: Text('Task description'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => navigateToDetail(),
)

// ❌ ERRADO
InkWell(
  onTap: () => navigateToDetail(),
  borderRadius: BorderRadius.circular(12),
  child: Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(...),
  ),
)
```

#### UniversalSearchPickerSheet (`lib/ui/widgets/universal_search_picker.dart`)
Use para TODOS os pickers de busca de objetos do vault:

```dart
// ✅ CORRETO
final selected = await showModalBottomSheet<ContentObject>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => UniversalSearchPickerSheet(
    title: 'Vincular objeto',
    initialFilter: 'task',
    onSelected: (obj) => Navigator.pop(context, obj),
  ),
);

// ❌ ERRADO
// Não implemente seu próprio picker de busca
```

#### WikiLinkPicker (`lib/ui/widgets/wiki_link_picker.dart`)
Use para TODOS os pickers de WikiLinks em editores de texto rico:

```dart
// ✅ CORRETO
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => WikiLinkPicker(
    onSelected: (obj) {
      // Inserir link [[obj.title]]
    },
  ),
);

// ❌ ERRADO
// Não implemente seu próprio picker de wiki links
```

#### showOrganizerPickerModal (`lib/ui/widgets/organizer_picker_modal.dart`)
Use para TODOS os pickers de seleção múltipla de organizers:

```dart
// ✅ CORRETO
final selected = await showOrganizerPickerModal(
  context,
  ref,
  initialSelected,
);
if (selected != null) {
  setState(() => _organizers = selected);
}

// ❌ ERRADO
// Não implemente seu próprio modal de seleção de organizers
```

#### OrganizerSelectorField (`lib/ui/widgets/organizer_selector_field.dart`)
Use para TODOS os campos de seleção de organizers em formulários:

```dart
// ✅ CORRETO
OrganizerSelectorField(
  label: 'Coleções',
  selectedOrganizers: _organizers,
  onChanged: (value) => setState(() => _organizers = value),
)

// ❌ ERRADO
// Não implemente seu próprio campo de seleção de organizers
```

### 6.9 Propriedades Themeable

O `AppThemeConfig` agora suporta as seguintes propriedades themeable:

- `borderRadius` (default: 16.0) - Arredondamento global da UI
- `spacingScale` (default: 1.0) - Escala de espaçamento (0.8 = compact, 1.2 = spacious)
- `fontScale` (default: 1.0) - Escala de fonte (0.9 = smaller, 1.1 = larger)
- `cardElevation` (default: 0.0) - Elevação de cards
- `useShadows` (default: true) - Uso de sombras
- `habitColors` - Paleta de cores de hábitos customizável
- `statusColors` - Paleta de cores de status customizável
- `priorityColors` - Paleta de cores de prioridade customizável

**Ao atualizar o tema via `AppearanceScreen`, preserve TODAS as propriedades existentes:**

```dart
final updatedTheme = AppThemeConfig(
  id: activeTheme.id,
  label: activeTheme.label,
  accentColor: activeTheme.accentColor,
  backgroundColor: backgroundColor,
  icon: activeTheme.icon,
  description: activeTheme.description,
  fontFamily: activeTheme.fontFamily,
  borderRadius: activeTheme.borderRadius,           // ← Preserve
  spacingScale: activeTheme.spacingScale,           // ← Preserve
  fontScale: activeTheme.fontScale,                 // ← Preserve
  cardElevation: activeTheme.cardElevation,         // ← Preserve
  useShadows: activeTheme.useShadows,               // ← Preserve
);
```

---

## 8. FORMATO DE DADOS OBSIDIAN

### 8.1 Daily Note (`daily/YYYY-MM-DD.md`)

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

### 8.2 Parsing Rules — CRÍTICO

1. **Frontmatter**: Entre o primeiro e segundo `---`. YAML puro
2. **Hábitos**: Chaves YAML que correspondem a `habit_slug`. `true/false` para boolean, número para contagem
3. **Trackers**: YAML aninhado. Chave externa = `tracker_slug`, internas = `field_slug`
4. **Journal entries**: Headings `### HH:MM` sob `## Journal Entries`
5. **Mood**: Inline Dataview `mood:: [[slug]]` — cria backlink no Obsidian
6. **Organizers**: Inline Dataview `organizers:: [[slug1]], [[slug2]]`
7. **Tags**: `#tag` no corpo da entry

### 8.3 Regras de Escrita

- **NUNCA** sobrescreva um daily note inteiro — leia, faça merge, escreva
- **NUNCA** altere campos de frontmatter que você não reconhece — preserve-os
- **SEMPRE** preserve a ordem das seções no body (`## Journal Entries` → `## Habits` → `## Trackers` → `## Tasks` → `## Pomodoros`)
- **SEMPRE** gere slugs em kebab-case: `minha-tarefa-importante.md`

---

## 9. REGRAS DE DESENVOLVIMENTO — O QUE FAZER E NÃO FAZER

### 9.1 ✅ FAZER SEMPRE

1. **Ler o arquivo atual antes de editar** — nunca assuma o conteúdo
2. **Usar `try-catch` em TODA operação de I/O** — arquivo pode não existir
3. **Invalidar providers após mutações** — chamar `_invalidateObjectProviders()`
4. **Testar em dark mode E light mode** — usar `AppColors` para ambos
5. **Adicionar `maxLines` + `overflow: ellipsis`** em textos dentro de listas, cards e rows
6. **Envolver listas em `Expanded` ou `Flexible`** dentro de `Column` e `Row`
7. **Usar `const` constructors** onde possível para performance
8. **Respeitar a hierarquia de navegação** — back button volta ao anterior, não ao pai
9. **Preservar comentários existentes** — não remova documentação que não esteja relacionada à sua mudança
10. **Usar ingles** em todos os textos de UI
11. **Após cada implementação, verificar se `agents.md` ou `guidelines.md` precisam ser atualizados** — se a mudança altera arquitetura, padrões ou regras, documente

### 9.2 ❌ NUNCA FAZER

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

### 9.3 Performance (CRÍTICO)

1. **Listas grandes**: Use `ListView.builder` (lazy) em vez de `ListView(children: [...])`.
2. **Rebuild desnecessário**: Use `select` em `ref.watch` para observar apenas campos necessários.
3. **Imagens**: Cache com `precacheImage` quando necessário.
4. **Sync**: `WidgetSyncProvider._updateAllWidgets()` deve ser não-bloqueante e usar debounce.
5. **Parsing**: O `MarkdownParser` faz I/O pesado — use o cache do `allObjectsProvider` sempre que possível.
6. **Init**: Inicialize serviços em paralelo no `main.dart` usando `Future.wait`.
7. **Providers**: Evite filtragem manual de `allObjectsProvider` em múltiplos providers independentes; use o `groupedObjectsProvider`.

---

## 10. PADRÕES DE CRUD

### 10.1 Criação de Objetos

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

## 11. SINCRONIZAÇÃO E DADOS

### 11.1 Fluxo de Sync

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

## 12. SEGURANÇA E PRIVACIDADE

### 12.1 Princípios

1. **Zero dados em servidores do app** — tudo fica no dispositivo e no Google Drive do usuário
2. **Auth via Google Sign-In** — tokens OAuth, nunca armazenar senhas
3. **Biometria opcional** — via `local_auth` para desbloquear o app
4. **Vault local é plain text** — não criptografar (compatibilidade com Obsidian)
5. **Tokens OAuth** são armazenados via `shared_preferences` com scope mínimo

### 12.2 Permissões (Android)

| Permissão | Uso | Obrigatória? |
|---|---|---|
| `INTERNET` | Sync Google Drive | Sim |
| `ACCESS_FINE_LOCATION` | Journal entry location | Não |
| `CAMERA` | Fotos em entries/trackers | Não |
| `READ_EXTERNAL_STORAGE` | Acesso ao vault local | Sim |
| `SCHEDULE_EXACT_ALARM` | Notificações precisas | Sim |
| `FOREGROUND_SERVICE` | Pomodoro timer | Sim |
| `USE_BIOMETRIC` | Lock screen | Não |

### 12.3 Validação de Input

- **Sempre sanitize** títulos antes de gerar slugs (remover caracteres especiais, converter para kebab-case)
- **Nunca confie em dados** do frontmatter YAML — faça type checking (`is String`, `is int`)
- **Trate `null`** para todo campo opcional — use operadores `?.` e `??`
- **Limite tamanhos** de input onde faz sentido (título: 500 chars, body: sem limite)

---

## 13. NOTIFICAÇÕES

### 13.1 Três Tipos

| Tipo | Comportamento | Configuração |
|---|---|---|
| **Push** | Notification shade padrão | Som, vibração, LED color |
| **Popup** | Full-screen sobre lock screen | Background color, botões |
| **Alarm** | Toca como alarme (ignora silencioso) | Ringtone, snooze duration |

### 13.2 Action Buttons em Todas as Notificações

- **"Concluído"** — marca o objeto como completo SEM abrir o app
- **"Adiar"** — adia pela duração de snooze configurada (padrão: 10min)
- **"Dispensar"** — fecha sem marcar como completo

### 13.3 Regras de Implementação

- Usar `AlarmManager.setExactAndAllowWhileIdle()` no Android
- Registrar alarmes no MOMENTO da criação, não ao abrir o app
- Cada objeto pode ter múltiplos reminders independentes

---

## 14. ARMADILHAS CONHECIDAS (NÃO REINTRODUZIR)

### 14.1 Overflow de Texto

**Problema**: Textos longos causam `RenderFlex overflowed`.
**Solução**: TODO `Text` em listas/cards DEVE ter `maxLines` + `overflow: TextOverflow.ellipsis`.

### 14.2 Widget de Mês Travado em "Carregando..."

**Problema**: `WidgetSyncProvider` bloqueava quando `allObjectsProvider` não tinha carregado.
**Solução**: Usar `maybeWhen`. Garantir que `monthFocus` nunca seja vazio — usar fallback.

### 14.3 Exclusão de Hábitos Não Funcionava

**Problema**: `deleteObject()` falhava quando backup retornava null.
**Solução**: Deletar o original INDEPENDENTE do sucesso da cópia de backup.

### 14.4 Duplicação de Objetos

**Problema**: Arquivos em `_deleted/` eram re-parseados.
**Solução**: Filtrar `_deleted/` e `_attachments/` durante o scan do vault.

### 14.5 Journal Entry Mostrando JSON Bruto

**Problema**: Campo `body` armazenado como JSON do Quill Delta.
**Solução**: Converter Delta para plain text em previews.

### 14.6 Organizer Summary Acessando Campo Inexistente

**Problema**: Dashboard acessava `.id` em `OrganizerReference`.
**Solução**: Usar `.slug` e `.title`.

---

## 15. CHECKLIST DE REVISÃO DE CÓDIGO

### UI/UX
- [ ] Funciona em light mode E dark mode
- [ ] Nenhum overflow em resoluções comuns (360x640, 390x844, 412x915)
- [ ] Textos em listas têm `maxLines` + `overflow: ellipsis`
- [ ] Textos de UI em ingles
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
import 'package:Quartzo/models/event_model.dart';
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
   Fix:     await _saveJson('Quartzo_planner', {'title': title, 'content': content,
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

### Property grid (Padrão para todas as propriedades)

- **Mandatório**: Resumos de propriedades em TODAS as telas de detalhe devem usar `ui/widgets/property_grid.dart`, seguindo o padrão implementado nas Notas.
- **Layout**: O grid de propriedades (`PropertyGrid`) deve usar sempre 2 colunas, em cards individuais.
- **Interação (Pop-ups)**: Ao clicar no card de uma propriedade, o app deve exibir um pop-up de edição (AlertDialog) com os botões "Salvar" e "Descartar", em vez de controles em linha (como Switch). Utilize os métodos `_showStringPropertyPicker`, `_showBoolPropertyPicker` e `_showEnumPropertyPicker` existentes em `universal_detail_view.dart`.
- **Visibilidade Inicial**: A seção que envolve o grid de propriedades (`_CollapsiblePropertiesSection`) deve sempre iniciar fechada (`_isExpanded = false`).

### Diagnósticos

- Use a chave persistida `vaultPath` ao sincronizar o destino dos crash reports.
- A exportação agregada da tela de diagnósticos deve continuar simples e rápida, priorizando cópia consolidada para área de transferência.

---

## Complementos — Pilares, Valores & Timeline (sessão 2026-07)

### Pillar & Value
- Pillar é um `ContentObject` próprio (tipo `pillar`), sem `state`/`deadline` — só `archived`. Nunca renderizar como "sequência quebrada"; estatísticas são sempre afirmativas ("tocado N dias", "última vez: há N dias").
- Value é `OrganizerType.value` — reaproveita a classe `Organizer` existente, ganha só o campo `statement`. Não tem touch log nem action menu.
- Ambos aparecem automaticamente em Object Identification assim que registrados em `_defaultSignatures()` — não precisa de tela nova.

### Action Menu Items
- Cada ação é seu próprio `ContentObject` (tipo `action`), não embutido no Pilar.
- Usa `organizers` para se ligar a 1+ Pilares/Valores.
- Action Menu na tela do Pilar é uma visualização derivada (`backlinksProvider(pillar.id).whereType<ActionMenuItem>()`).
- Campos: `energyLevel` (quando usar), `energyCost` (quanto consome), `priority` (reusa TaskPriority).

### Timeline
- `ObjectTimelineFeed` é o único widget de timeline daqui pra frente. Não criar nova lógica de agrupamento-por-dia em nenhuma tela nova — sempre `ObjectTimelineFeed`.
- Emoji de qualquer item da timeline vem **sempre** de `ObjectIcons.emojiForType()` — nunca `Icons.*` hardcoded nem switch duplicado por tela.
- Distinção criado/editado/programado/aconteceu é sempre `TodayItemOrigin` — não inventar uma segunda enum equivalente.
- Glyph de origem: 🕐 criado, ✏️ editado, 📅 programado, ⚡ aconteceu.
- Antes de remover `timeline_screen.dart`, confirmar no `go_router`/`navigation_provider.dart` se alguma rota ainda aponta pra ele. Status atual: Usado — rota `/timeline` existe em navigation_provider.dart.

### Bug Fixes Aplicados
- `organizer_selector_field.dart`: migrado de `Icons.*` hardcoded para `ObjectIcons.emojiForType()`. Corrigido bug no `_getTypeLabel()` que fazia switch em valores inexistentes de `OrganizerType`.
- `timeline_screen.dart`: migrado para `ObjectIcons.emojiForType()`.

---

## Complementos do gap-analysis.md atual (Week Timeline & Notes)

### Week Timeline
- Uma tela full-screen "Week Timeline" (`lib/ui/screens/week_timeline_screen.dart`), acessada ao tocar no header do componente "This Week" no dashboard.
- Reutiliza `TodayAggregatorService` e `todayItemsProvider` por dia. Não introduz nova lógica de agregação ou modelo de dados.
- Scroll: infinito para o futuro (carrega automaticamente os próximos dias), e manual para o passado (controle explícito "Mostrar dias anteriores").
- O layout do `WeekOverviewComponent` (7 colunas no dashboard) permanece igual e serve como ponto de entrada para o Week Timeline.

### Note page redesign
- As Notas possuem um layout de "página de leitura" dedicado, diferente do card genérico dos outros objetos. Inclui: imagem de capa opcional, título grande, corpo sem borda (`borderless body`) e blocos de callout coloridos (`tinted callout blocks`).
- Novo campo opcional em `Note`: `coverImagePath` (chave frontmatter: `cover_image_path`).
- As propriedades de todos os objetos estão sendo migradas para usar o `PropertyGrid` com o novo comportamento de pop-up ao clicar (botões salvar/descartar) e toggle fechado por padrão.
