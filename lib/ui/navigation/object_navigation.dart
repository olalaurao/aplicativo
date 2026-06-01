// lib/ui/navigation/object_navigation.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/content_object.dart';

/// Navigates to the universal detail view for any [ContentObject].
void navigateToObject(BuildContext context, ContentObject object) {
  context.push('/detail/${object.id}');
}
