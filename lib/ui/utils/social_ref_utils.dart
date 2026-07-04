// lib/ui/utils/social_ref_utils.dart
// V5: socialRefs removed — all cross-object references now use the universal `links` field.
// This utility is preserved for legacy UI callers but now operates on `ContentObject.links`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';

/// Returns the universal `links` list for any ContentObject.
/// V5: socialRefs is removed — all types use ContentObject.links directly.
List<String> getSocialRefs(ContentObject obj) {
  return obj.links;
}

/// Adds a WikiLink to the universal `links` field of any ContentObject.
Future<void> addSocialRef(
    ContentObject obj, ContentObject target, WidgetRef ref) async {
  final slug = '[[${target.slug}]]';
  final current = List<String>.from(obj.links);
  if (current.contains(slug)) return;
  obj.links = [...current, slug];
  await ref.read(vaultProvider.notifier).updateObject(obj);
}

/// Removes a WikiLink from the universal `links` field of any ContentObject.
Future<void> removeSocialRef(
    ContentObject obj, String slugRef, WidgetRef ref) async {
  obj.links = obj.links.where((r) => r != slugRef).toList();
  await ref.read(vaultProvider.notifier).updateObject(obj);
}
