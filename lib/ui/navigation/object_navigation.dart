// lib/ui/navigation/object_navigation.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/content_object.dart';

/// Navigates to the universal detail view for any [ContentObject].
/// Uses the object's runtime type as the route segment and its id.
void navigateToObject(BuildContext context, ContentObject object) {
  final type = object.runtimeType.toString().toLowerCase();
  final id = object.id;
  // Assuming a GoRouter route pattern: /detail/:type/:id
  context.push('/detail/$type/$id');
}
