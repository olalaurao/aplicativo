

## Por que o app trava e mostra "Aguardar / Fechar"

Isso é um **ANR (Application Not Responding)** — o Android detecta que a thread principal ficou bloqueada por mais de ~5 segundos. O app tem **vários pontos críticos** que causam isso.

---

### 🔴 Causa 1 — `AllObjectsNotifier.build()` bloqueia o app inteiro na inicialização

Em `vault_provider.dart`, o método `build()` do `AllObjectsNotifier` lê e parseia **todos os arquivos `.md` do vault em paralelo** logo na abertura do app:

```dart
final mdFiles = (await service.getFilesInFolder('')).where(...).toList();
// batches de 50 arquivos em paralelo com Future.wait(...)
```

Se o vault tiver dezenas ou centenas de arquivos (o que é normal depois de algum uso), esse processo é pesado em I/O. O pior: toda vez que qualquer dado muda, `ref.invalidate(allObjectsProvider)` é chamado, e **tudo é relido do disco do zero**. Isso acontece em cascata em vários lugares, como após toggle de hábito, salvar tarefa, sync, etc.

---

### 🔴 Causa 2 — `SyncManager._runStartupTasks()` dispara operações pesadas logo no boot

No startup do `SyncManager`:

```dart
Future<void> _runStartupTasks() async {
  await _ref.read(vaultProvider.notifier).processPendingNotificationActions();
  if (settings.autoSync && await authService.ensureClient() != null) {
    await performSync(); // ← sync completo com Google Drive na abertura
  }
  Timer(const Duration(minutes: 5), () async {
    await backupService.createBackup(); // ← zip de todo o vault
    await backupService.cleanOldBackups();
  });
}
```

O `performSync()` envolve:
- Autenticação OAuth
- Listagem de arquivos no Google Drive
- Downloads e uploads de arquivos
- `DataviewGenerator.regenerateAll()` — reescreve todos os `index.md`
- `_refreshNotificationsFromLocalVault()` — lê todos os objetos novamente e recalcula notificações

Tudo isso acontece logo na abertura, potencialmente enquanto o usuário já está usando o app.

---

### 🔴 Causa 3 — `ref.invalidate(allObjectsProvider)` é chamado em cascata

Apenas no `HabitsNotifier.toggleHabit()` (marcar um hábito), o código chama:

```dart
ref.invalidate(allObjectsProvider); // força releitura de TODOS os arquivos
```

O mesmo padrão se repete em `updateEntry`, `deleteEntry`, `addEntry`, e em praticamente todo o `VaultNotifier`. Cada pequena ação do usuário relê o vault inteiro do disco.

---

### 🔴 Causa 4 — `_refreshNotificationsFromLocalVault()` no pós-sync

Depois de cada sync, o código:

```dart
_ref.invalidate(allObjectsProvider);
final allObjects = await _ref.read(allObjectsProvider.future); // relê tudo
for (final object in allObjects.whereType<ContentObject>()) {
  for (final reminder in object.reminders) {
    await NotificationService().scheduleReminder(...); // uma chamada por reminder
  }
}
```

Com muitos objetos com reminders, isso pode levar vários segundos bloqueando operações.

---

## O que fazer

### Correções imediatas (maior impacto)

**1. Atrasar o sync inicial**

No `_runStartupTasks`, não fazer sync logo de cara. Esperar o app estar idle:

```dart
Future<void> _runStartupTasks() async {
  await _ref.read(vaultProvider.notifier).processPendingNotificationActions();
  
  // ← Adicionar delay antes de sync
  await Future.delayed(const Duration(seconds: 5));
  
  if (settings.autoSync && await authService.ensureClient() != null) {
    await performSync();
  }
}
```

**2. Parar de invalidar `allObjectsProvider` em toda pequena ação**

Em vez de reler o vault inteiro ao marcar um hábito, atualizar só o estado em memória (o código já faz isso para o estado local do `HabitsNotifier`). Remover o `ref.invalidate(allObjectsProvider)` do `toggleHabit` e usar `ref.invalidateSelf()` apenas no notifier específico.

**3. Trocar `ref.invalidate(allObjectsProvider)` por atualização pontual no cache**

O `_dailyNoteDataMapProvider` já existe exatamente para isso — fazer cache O(1) de daily notes. Mas o código continua invalidando o provider global junto. Basta confiar no cache local que já foi implementado.

**4. Fazer `_refreshNotificationsFromLocalVault` em background isolado**

Usar `compute()` do Flutter ou um `Isolate` para não bloquear a thread principal ao processar notificações pós-sync.

---

### Resumo das causas por prioridade

| Prioridade | Causa | Impacto |
|---|---|---|
| 🔴 Alta | `invalidate(allObjectsProvider)` em cascata | Trava a cada ação |
| 🔴 Alta | Sync completo no boot | Trava na abertura |
| 🟠 Média | `_refreshNotificationsFromLocalVault` síncrono | Trava pós-sync |
| 🟡 Baixa | Vault watcher no Android | Pode causar reloads inesperados |