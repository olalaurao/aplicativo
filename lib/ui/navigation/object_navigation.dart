// lib/ui/navigation/object_navigation.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/content_object.dart';
import '../screens/rotation_zone_detail_screen.dart';

/// Navigates to the universal detail view for any [ContentObject].
void navigateToObject(BuildContext context, ContentObject object) {
  context.push('/detail/${object.id}');
}

void navigateToRotationZone(
  BuildContext context, {
  required String projectId,
  required String groupId,
  bool isPreview = false,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RotationZoneDetailScreen(
        projectId: projectId,
        groupId: groupId,
        isPreview: isPreview,
      ),
    ),
  );
}
