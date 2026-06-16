import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../models/social_post.dart';
import '../../models/note_model.dart';
import '../../models/resource_model.dart';
import '../../models/goal_model.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../providers/vault_provider.dart';

Future<void> addSocialRef(
    ContentObject obj, ContentObject target, WidgetRef ref) async {
  final slug = '[[${target.slug}]]';
  final current = getSocialRefs(obj);
  if (current.contains(slug)) return;
  final updated = _withRefs(obj, [...current, slug]);
  await ref.read(vaultProvider.notifier).updateObject(updated);
}

Future<void> removeSocialRef(
    ContentObject obj, String slugRef, WidgetRef ref) async {
  final updated = _withRefs(obj,
      getSocialRefs(obj).where((r) => r != slugRef).toList());
  await ref.read(vaultProvider.notifier).updateObject(updated);
}

List<String> getSocialRefs(ContentObject obj) {
  if (obj is SocialPost) return obj.socialRefs;
  if (obj is Note)       return obj.socialRefs;
  if (obj is Resource)   return obj.socialRefs;
  if (obj is Goal)       return obj.socialRefs;
  if (obj is Task)       return obj.socialRefs;
  if (obj is Habit)      return obj.socialRefs;
  return [];
}

ContentObject _withRefs(ContentObject obj, List<String> refs) {
  if (obj is SocialPost) return obj.copyWith(socialRefs: refs);
  if (obj is Note)       return obj.copyWith(socialRefs: refs);
  if (obj is Resource)   return obj.copyWith(socialRefs: refs);
  if (obj is Goal)       return obj.copyWith(socialRefs: refs);
  if (obj is Task)       return obj.copyWith(socialRefs: refs);
  if (obj is Habit)      return obj.copyWith(socialRefs: refs);
  return obj;
}
