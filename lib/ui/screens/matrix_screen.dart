// lib/ui/screens/matrix_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/saved_filter.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import 'universal_detail_view.dart';

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
    final filtered = widget.filter.apply<Task>(allTasks);

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
            Expanded(
              child: Row(
                children: cfg.axisXValues.map((v) =>
                  Expanded(
                    child: Center(
                      child: Text(
                        v,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                ).toList(),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: Row(children: [
              // Header eixo Y (rotacionado)
              SizedBox(
                width: 32,
                child: Column(
                  children: cfg.axisYValues.map((v) =>
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            v,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                  ).toList(),
                ),
              ),
              // 4 quadrantes
              Expanded(
                child: Column(
                  children: cfg.axisYValues.map((yVal) =>
                    Expanded(
                      child: Row(
                        children: cfg.axisXValues.map((xVal) =>
                          Expanded(
                            child: _buildQuadrant(context, ref, filtered, cfg, xVal, yVal),
                          )
                        ).toList(),
                      ),
                    )
                  ).toList(),
                ),
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
              child: Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          // Lista de items:
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              children: items.map((t) => _buildMatrixCard(t, ref)).toList(),
            ),
          ),
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
          child: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
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
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: task.stage == TaskStage.finalized,
              onChanged: (_) => ref.read(tasksProvider.notifier)
                  .updateTask(task.copyWith(stage: TaskStage.finalized)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                decoration: task.stage == TaskStage.finalized
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
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
        priority: TaskPriority.values.firstWhere(
          (p) => p.name == xVal,
          orElse: () => task.priority,
        ),
      );
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
