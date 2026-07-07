import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';

class SocialNativeVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const SocialNativeVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  State<SocialNativeVideoPlayer> createState() =>
      _SocialNativeVideoPlayerState();
}

class _SocialNativeVideoPlayerState extends State<SocialNativeVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;

  static const _httpHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; SM-A546E) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.tiktok.com/',
  };

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl),
            httpHeaders: _httpHeaders,
          )
          ..addListener(_handlePlaybackError)
          ..initialize()
              .then((_) {
                if (!mounted) return;
                _controller.setLooping(true);
                _controller.play();
                setState(() => _initialized = true);
              })
              .catchError((error) {
                if (!mounted) return;
                setState(() => _failed = true);
              });
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePlaybackError);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _shell(
        context,
        child: const Center(
          child: Text(
            'Não foi possível tocar este vídeo.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (!_initialized) {
      return _shell(
        context,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return _shell(
      context,
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlayback,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _controller.value.isPlaying ? 0 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppTheme.accentColor(context),
                bufferedColor: Colors.white.withValues(alpha: 0.35),
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell(
    BuildContext context, {
    required Widget child,
    double aspectRatio = 9 / 16,
  }) {
    return AspectRatio(
      aspectRatio: aspectRatio <= 0 ? 9 / 16 : aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(color: Colors.black, child: child),
      ),
    );
  }

  void _togglePlayback() {
    if (!_initialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _handlePlaybackError() {
    if (!mounted || _failed || !_controller.value.hasError) return;
    setState(() => _failed = true);
  }
}
