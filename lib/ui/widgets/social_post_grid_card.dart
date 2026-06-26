// lib/ui/widgets/social_post_grid_card.dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/social_post.dart';
import '../theme.dart';

class SocialPostGridCard extends StatelessWidget {
  final SocialPost post;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SocialPostGridCard({
    super.key,
    required this.post,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = socialPlatformColor(post.platform);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SocialPostThumbnail(
              post: post,
              iconSize: 40,
              borderRadius: BorderRadius.zero,
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SocialPlatformBadge(platform: post.platform, fontSize: 9),
                      if (post.socialRefs.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.link_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (isMultiSelectMode)
              Positioned(
                top: 8,
                left: 8,
                child: _SelectionBadge(selected: isSelected),
              )
            else if (!post.watched)
              const Positioned(top: 8, right: 8, child: _UnreadDot()),
            if (isSelected && isMultiSelectMode)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _handle {
    final value = post.authorHandle ?? post.authorName ?? post.title;
    return value.startsWith('@') ? value : '@$value';
  }
}

class SocialPostThumbnail extends StatelessWidget {
  final SocialPost post;
  final double iconSize;
  final BorderRadius borderRadius;

  const SocialPostThumbnail({
    super.key,
    required this.post,
    this.iconSize = 28,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final color = socialPlatformColor(post.platform);
    final fallback = ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          socialPlatformIcon(post.platform),
          size: iconSize,
          color: color,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SocialPostImage(
        source: socialPostImageSource(post),
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}

class SocialPostImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final Widget fallback;

  const SocialPostImage({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final imageSource = source?.trim();
    if (imageSource == null || imageSource.isEmpty) return fallback;
    final uri = Uri.tryParse(imageSource);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (isRemote) {
      return Image.network(
        imageSource,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    final filePath = uri?.scheme == 'file' ? uri!.toFilePath() : imageSource;
    return Image.file(
      File(filePath),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

String? socialPostImageSource(SocialPost post) {
  final media = post.mediaUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();
  final thumbnail = post.thumbnailUrl?.trim();
  final candidates = post.platform == SocialPlatform.pinterest
      ? [...media, if (thumbnail != null && thumbnail.isNotEmpty) thumbnail]
      : [if (thumbnail != null && thumbnail.isNotEmpty) thumbnail, ...media];
  return candidates.firstOrNull;
}

class SocialPlatformBadge extends StatelessWidget {
  final SocialPlatform platform;
  final double fontSize;

  const SocialPlatformBadge({
    super.key,
    required this.platform,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: socialPlatformColor(platform),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        platformLabel(platform).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  final bool selected;

  const _SelectionBadge({required this.selected});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 13,
      backgroundColor: selected ? AppColors.primary : AppColors.surface,
      child: Icon(
        selected ? Icons.check_rounded : Icons.circle_outlined,
        size: 17,
        color: selected ? Colors.white : AppColors.textMuted,
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
      ),
    );
  }
}

Color socialPlatformColor(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.tiktok => AppColors.textPrimary,
    SocialPlatform.instagram => AppColors.habitPink,
    SocialPlatform.substack => AppColors.warning,
    SocialPlatform.linkedin => AppColors.info,
    SocialPlatform.pinterest => AppColors.error,
    SocialPlatform.youtube => AppColors.error,
    SocialPlatform.twitter => AppColors.info,
    SocialPlatform.reddit => AppColors.warning,
    SocialPlatform.other => AppColors.primary,
  };
}

IconData socialPlatformIcon(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.youtube => Icons.play_circle_outline_rounded,
    SocialPlatform.substack => Icons.article_outlined,
    SocialPlatform.linkedin => Icons.business_center_outlined,
    SocialPlatform.pinterest => Icons.push_pin_outlined,
    SocialPlatform.instagram => Icons.camera_alt_outlined,
    SocialPlatform.tiktok => Icons.music_note_rounded,
    SocialPlatform.twitter => Icons.alternate_email_rounded,
    SocialPlatform.reddit => Icons.forum_rounded,
    SocialPlatform.other => Icons.link_rounded,
  };
}

String platformLabel(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.tiktok => 'TikTok',
    SocialPlatform.instagram => 'Instagram',
    SocialPlatform.substack => 'Substack',
    SocialPlatform.linkedin => 'LinkedIn',
    SocialPlatform.pinterest => 'Pinterest',
    SocialPlatform.youtube => 'YouTube',
    SocialPlatform.twitter => 'Twitter',
    SocialPlatform.reddit => 'Reddit',
    SocialPlatform.other => 'Outro',
  };
}
