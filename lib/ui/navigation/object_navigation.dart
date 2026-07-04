// lib/ui/navigation/object_navigation.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/content_object.dart';
import '../screens/rotation_overview_screen.dart';
import '../screens/rotation_zone_detail_screen.dart';

/// Navigates to the universal detail view for any [ContentObject].
void navigateToObject(BuildContext context, ContentObject object) {
  context.push('/detail/${object.id}');
}

void navigateToRotationOverview(BuildContext context, String projectId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RotationOverviewScreen(projectId: projectId),
    ),
  );
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
