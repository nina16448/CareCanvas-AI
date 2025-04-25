import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InteractiveVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onVideoEnd;

  const InteractiveVideoPlayer({super.key, required this.videoUrl, required this.onVideoEnd});

  @override
  State<InteractiveVideoPlayer> createState() => _InteractiveVideoPlayerState();
}

class _InteractiveVideoPlayerState extends State<InteractiveVideoPlayer> {
  late VideoPlayerController _controller;
  static bool _isFirstPlay = true;

  @override
  void initState() {
    super.initState();
    _initializeController(widget.videoUrl);
  }

  Future<void> _initializeController(String url) async {
    // 建立新的 controller
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller.initialize();
    debugPrint('初始化！');
    if (_isFirstPlay) _controller.setVolume(0);
    _isFirstPlay = false;

    // 在初始化後加入監聽器來追蹤播放器狀態
    _controller.addListener(() {
      final value = _controller.value;
      debugPrint(
        'isPlaying: ${value.isPlaying}, isBuffering: ${value.isBuffering}, '
        'position: ${value.position}, error: ${value.errorDescription}',
      );
    });

    _controller.play().catchError((error) {
      debugPrint('播放時錯誤: $error');
    });

    setState(() {}); // 更新畫面

    // 加入監聽器來檢查是否影片播放完畢
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration && !_controller.value.isPlaying) {
        widget.onVideoEnd();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當 videoUrl 改變時，重新初始化 controller
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.pause();
      _controller.dispose();
      _initializeController(widget.videoUrl);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        ClipRect(
          child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)))),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Row(
            children: [
              // 🔇 音量按鈕
              IconButton(
                icon: Icon(_controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white),
                onPressed: () {
                  _controller.setVolume(_controller.value.volume > 0 ? 0 : 1);
                },
              ),
              // ⏯️ 暫停/播放按鈕
              IconButton(
                icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
