import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/pomodoro_session.dart';
import '../../providers/pomodoro_provider.dart';
import '../theme.dart';

class PomodoroFloatingClock extends ConsumerWidget {
  final Widget child;

  const PomodoroFloatingClock({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoro = ref.watch(pomodoroProvider);
    final showClock = pomodoro.isRunning;

    return Stack(
      children: [
        child,
        if (showClock)
          Positioned(
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: SafeArea(
              child: _ClockChip(
                remainingSeconds: pomodoro.remainingSeconds,
                title: pomodoro.currentItemTitle,
                type: pomodoro.currentType,
                onTap: () => context.push('/pomodoro'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClockChip extends StatelessWidget {
  final int remainingSeconds;
  final String? title;
  final PomodoroType type;
  final VoidCallback onTap;

  const _ClockChip({
    required this.remainingSeconds,
    required this.title,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (title != null && title!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
