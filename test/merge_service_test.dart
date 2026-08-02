// test/merge_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quartzo/services/merge_service.dart';
import 'package:quartzo/models/shared_types.dart';
import 'package:quartzo/providers/merge_provider.dart';

void main() {
  group('MergeService', () {
    late ProviderContainer container;
    late MergeService mergeService;

    setUp(() {
      container = ProviderContainer();
      mergeService = container.read(mergeServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('slugMatches handles direct match', () {
      // Test direct slug matching
      expect(mergeService.slugMatches('my-task', 'my-task'), true);
      expect(mergeService.slugMatches('my-task', 'other-task'), false);
    });

    test('slugMatches handles normalized match', () {
      // Test normalized slug matching (underscores, hyphens, slashes)
      expect(mergeService.slugMatches('my_task', 'my-task'), true);
      expect(mergeService.slugMatches('my/task', 'my-task'), true);
      expect(mergeService.slugMatches('my_task', 'my/task'), true);
    });

    test('slugMatches handles case insensitive', () {
      // Test case-insensitive matching
      expect(mergeService.slugMatches('My-Task', 'my-task'), true);
      expect(mergeService.slugMatches('MY-TASK', 'my-task'), true);
    });

    test('repointBodyLinks preserves aliases', () {
      // Test that [[fromSlug|alias]] becomes [[toSlug|alias]]
      final result = mergeService.repointBodyLinks(
        'See [[old-task|My Old Task]] for details',
        'old-task',
        'new-task',
      );
      print('Result: $result');
      expect(result, 'See [[new-task|My Old Task]] for details');
    });

    test('repointBodyLinks handles simple links', () {
      // Test that [[fromSlug]] becomes [[toSlug]]
      final result = mergeService.repointBodyLinks(
        'See [[old-task]] for details',
        'old-task',
        'new-task',
      );
      expect(result, 'See [[new-task]] for details');
    });

    test('repointBodyLinks handles multiple occurrences', () {
      // Test that multiple links are all replaced
      final result = mergeService.repointBodyLinks(
        'See [[old-task]] and [[old-task|also old]] for details',
        'old-task',
        'new-task',
      );
      expect(result, 'See [[new-task]] and [[new-task|also old]] for details');
    });

    // Note: Full integration test for performMerge with alias preservation
    // would require mocking vault provider and other dependencies.
    // The implementation in performMerge already adds aliases from losing objects:
    // 1. Adds losing object slugs as aliases
    // 2. Adds all losing object aliases to survivor  
    // 3. Preserves existing survivor aliases
  });
}