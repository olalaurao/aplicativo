import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quartzo/services/nlp_task_parser.dart';
import 'package:quartzo/models/task_model.dart';
import 'package:quartzo/models/scheduler.dart';

void main() {
  group('NLP Task Parser Tests', () {
    test('Clean empty text', () {
      final parsed = NlpTaskParser.parse('');
      expect(parsed.cleanTitle, '');
      expect(parsed.hasAnyDetection, isFalse);
    });

    test('Parse dates like amanhã', () {
      final parsed = NlpTaskParser.parse('Comprar leite amanhã');
      expect(parsed.cleanTitle, 'Comprar leite');
      expect(parsed.startDate, isNotNull);
      expect(parsed.endDate, isNotNull);
      expect(
        parsed.startDate!.day,
        DateTime.now().add(const Duration(days: 1)).day,
      );
    });

    test('Parse scheduled time like às 10h', () {
      final parsed = NlpTaskParser.parse('Comprar leite amanhã às 10h');
      expect(parsed.cleanTitle, 'Comprar leite');
      expect(parsed.startDate, isNotNull);
      expect(parsed.scheduledTime, const TimeOfDay(hour: 10, minute: 0));
    });

    test('Parse scheduled time like às 15:30', () {
      final parsed = NlpTaskParser.parse('Reunião às 15:30');
      expect(parsed.cleanTitle, 'Reunião');
      expect(parsed.scheduledTime, const TimeOfDay(hour: 15, minute: 30));
    });

    test('Parse priority like alta prioridade', () {
      final parsed = NlpTaskParser.parse('Projeto X alta prioridade');
      expect(parsed.cleanTitle, 'Projeto X');
      expect(parsed.priority, TaskPriority.high);
    });

    test('Parse priority short syntax like !alta', () {
      final parsed = NlpTaskParser.parse('Projeto Y !alta');
      expect(parsed.cleanTitle, 'Projeto Y');
      expect(parsed.priority, TaskPriority.high);
    });

    test('Parse scheduler like todo domingo', () {
      final parsed = NlpTaskParser.parse('Ligar pro João todo domingo');
      expect(parsed.cleanTitle, 'Ligar pro João');
      expect(parsed.scheduler, isNotNull);
      expect(parsed.scheduler!.rules.first.repeatType, RepeatType.daysOfWeek);
      expect(parsed.scheduler!.rules.first.daysOfWeek, contains('Sun'));
    });

    test('Parse complex task description', () {
      final parsed = NlpTaskParser.parse('Terminar relatório amanhã às 14h30 alta prioridade');
      expect(parsed.cleanTitle, 'Terminar relatório');
      expect(parsed.startDate, isNotNull);
      expect(parsed.scheduledTime, const TimeOfDay(hour: 14, minute: 30));
      expect(parsed.priority, TaskPriority.high);
    });
  });
}
