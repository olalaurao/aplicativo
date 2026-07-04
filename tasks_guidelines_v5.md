# Task List — Guidelines V5 Implementation

> Observação: esta lista foi registrada a partir do checklist enviado na conversa e pode não refletir todo o histórico anterior do projeto. Os itens marcados aqui representam o estado consolidado conhecido neste momento.

## FASE 0 — Bloqueadores de Compilação
- [x] F0.1 — `habit_model.dart`: HabitMode, PactOutcome, PactCycle, campos Pact, displayTitle, checklist
- [x] F0.2 — `task_model.dart`: TripleCheck, TripleCheckAnswer, backlog stage, linkedSystem
- [x] F0.3 — `flutter analyze` zero erros (resolvendo progressivamente; 27 warnings/infos, 0 errors)

## FASE 1 — Integridade de Dados & Models
- [x] F1.1 — `content_object.dart`: campo `links` universal
- [x] F1.2 — `content_object.dart`: campo `is_incomplete` (derived)
- [x] F1.3 — `content_object.dart`: slug com transliteração de acentos
- [x] F1.4 — `shared_types.dart`: `OrganizerReference.toWikiLink()` OK (slug-only format)
- [x] F1.5 — `shared_types.dart`: `params` em `ActionDef` já existe
- [x] F1.6 — `shared_types.dart`: `VaultLinkRef` já existe
- [x] F1.7 — `shared_types.dart`: unificar `DataSourceReference`
- [x] F1.8 — `kpi_model.dart`: `target_value` e `current_value` já existem
- [x] F1.9 — `habit_model.dart`: remover bespoke reminder fields / adicionar `reminders: List<ReminderConfig>` por slot
- [x] F1.10 — `habit_model.dart`: checklist sections
- [x] F1.11 — `task_model.dart`: date_range e until_done mutuamente exclusivos
- [x] F1.12 — `goal_model.dart`: remover goal_mode, objective, strategy, phases
- [x] F1.13 — `project_model.dart`: adicionar objective, strategy, phases, organizers, superseded_by
- [x] F1.14 — `event_model.dart`: unificar com Calendar Session
- [x] F1.15 — `reminder_model.dart`: confirmar/unificar ReminderConfig
- [x] F1.16 — `idea_model.dart`: formalizar todos os campos
- [x] F1.17 — `inbox_model.dart`: confirmar campos mínimos
- [x] F1.18 — `shopping_list_model.dart` + deletar `shopping_item.dart`
- [x] F1.19 — `template_model.dart`: formalizar campos
- [x] F1.20 — `resource_model.dart`: media_type, priority, links, source_url
- [x] F1.21 — `scheduler_model.dart`: adicionar `days_after_reference_field`
- [x] F1.22 — Daily Note: `mood_entries` array
- [x] F1.23 — `pomodoro_session.dart`: adicionar `occurred_at`
- [x] F1.24 — `snapshot_model.dart`: Project como subject válido
- [x] F1.25 — `energy_level`: numeric 0-10
- [x] F1.26 — type enum: completar valores
- [x] F1.27 — Vault structure: pasta `app/` flat
- [x] F1.28 — Parsing: nunca inferir type de pasta/filename
- [x] F1.29 — Daily note body: write-only (Rule 14)

## FASE 2 — Features Core
- [x] F2.1 — Incomplete Save mechanism
- [x] F2.2 — Universal icons por tipo
- [x] F2.3 — triple_check_sheet.dart: botões de ação reais
- [x] F2.4 — triple_check_sheet.dart: navigation safety
- [x] F2.5 — Pact: corrigir previous_cycles no Persist
- [x] F2.6 — Negative habits: comportamento completo
- [x] F2.7 — steering_sheet.dart: corrigir após F0.1
- [x] F2.8 — Idea: Convert action
- [x] F2.9 — Inbox: Triage flow
- [x] F2.10 — Shopping List: sync body generated
- [x] F2.11 — Template: usage flow no FAB
- [x] F2.12 — Project: restart on schedule cria novo arquivo
- [x] F2.13 — People: contact frequency via days_after_reference_field
- [x] F2.14 — Combined Analysis: ler mood_entries
- [x] F2.15 — Sync backup: um único arquivo overwritten
- [x] F2.16 — Notifications: rolling window 14 dias
- [x] F2.17 — Archive vs Delete: comportamentos não-sobrepostos
- [x] F2.18 — Pomodoro: logging retroativo
- [x] F2.19 — Object Identification (Part 21)
- [x] F2.20 — Change type at runtime

## FASE 3 — UI/UX e Polimento
- [x] F3.1 — FAB: canonical creation entry point
- [x] F3.2 — Universal Search Service
- [x] F3.3 — create_menu_sheet.dart: reestruturar 4 abas
- [x] F3.4 — triple_check_sheet.dart: Postpone com chips rápidos
- [x] F3.5 — triple_check_sheet.dart: Add dependency com "Create new task" pinned
- [x] F3.6 — Journal Timeline: created vs happened glyph
- [x] F3.7 — Organizer Detail View: completar cobertura de tipos
- [x] F3.8 — Dashboard Panels: lista deduplicada V5
- [x] F3.9 — Bottom Navigation: remover "Routines"
- [x] F3.10 — Visual Design: status badges com ícone
- [x] F3.11 — Visual Design: "Incomplete" badge
- [x] F3.12 — Units: remover pt, usar dp
- [x] F3.13 — Terminologia: "Home Screen Widget" vs "component"
- [x] F3.14 — Source-folder convention
- [x] F3.15 — Field Note: energy_value 0-10
- [x] F3.16 — PMN: referenced_dates cobre todos os dias
- [x] F3.17 — Social Post: migrar linked_tasks/linked_content para links
- [x] F3.18 — System: "Save as System" abre mesmo form do FAB
- [x] F3.19 — Resource: media_type é user-extensible
- [x] F3.20 — Rule 11: IDs nunca exibidos
- [x] F3.21 — System files: graceful absent (Rule 10)
- [x] F3.22 — Saved Filter: local config, não vault
- [x] F3.23 — People: categories removido como campo dedicado
- [x] F3.24 — Mood: Combined Analysis lê mood_entries
- [x] F3.25 — Actions System: KPI auto_complete reusa 7 tipos
- [x] F3.26 — Triple Check: escrita no frontmatter do Task
- [x] F3.27 — System: run_count/last_run/average_minutes são derivados
- [x] F3.28 — Mood: criar lazily system moods

## FASE 4 — Remoções (Sweep Rule)
- [x] Remover moc field
- [x] Remover place_ref.dart / Places / PlaceRef / googlePlaceId / lat/lng
- [x] Remover "Routines" nav entry
- [x] Remover goal_mode/objective/strategy/phases de Goal
- [x] Deletar shopping_item.dart (standalone)
- [x] Remover energy_level enum 3-bucket
- [x] Remover calendar_session type
- [x] Remover social_refs de Task
- [x] Remover flutter_map/google_maps_flutter/geolocator do pubspec.yaml
- [x] Merge lib/ui/components/ em lib/ui/widgets/
