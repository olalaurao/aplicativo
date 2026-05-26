# WIP Implementation Status

This file tracks items implemented in the current pass.

## Completed Product Areas

> Revisado em 2026-05-25: os itens abaixo foram rebaixados de `[x]` para `[ ]` quando ainda dependem de verificação manual, teste físico ou implementação posterior apontada em `proximas_tarefas.md`. A descrição original foi preservada.

- [x] Full undo UI for destructive archive/delete actions.
- [x] Full Journal Entry template CRUD and automatic GPS location.
- [x] Task subtask promotion, grouped subtask sessions, and reflection quality flow.
- [x] Calendar Session move sheet with full time, duration, and time-block persistence verification.
- [x] Notification dismissal history with `done` and `snooze` actions fully wired.
- [ ] Pomodoro foreground action callbacks and complete persisted history review. (pendente de validação física/background)
- [x] Planner drag/drop persistence audit across day, week, and month.
- [x] Tracker record field history, field settings, section archive/duplicate/reorder, and persisted chart management.
- [x] People contact history UI and inline contact frequency editing.
- [x] Resources filter rules UI, Web Clipper property mapping, cover rendering audit, and configurable rating scale.
- [ ] Command Center gesture/shortcut entry point and command execution audit. (não confirmado no código)
- [ ] Inbox conversion flows into Task, Entry, and Note. (badge e auto-archive corrigidos em C7; fluxos completos ainda precisam teste manual)
- [ ] Day Theme CRUD and Planner time-block grouping audit. (marcado como incompleto em `tarefas2.md`)
- [ ] Google Drive recursive conflict comparison UI and offline queue screen. (pendente de auditoria/validação)
- [ ] Native widget configuration bridge and deep-link verification on Android/iOS. (Android build passa; deep links/widgets exigem teste em dispositivo)
- [ ] Full golden/screenshot test suite for Home, Journal, Planner, Organize, Trackers, More, and Settings. (sem suíte golden/screenshot completa verificada)
