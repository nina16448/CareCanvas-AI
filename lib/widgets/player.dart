import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_dialogs/widgets/buttons/icon_button.dart';
import 'package:material_dialogs/widgets/buttons/icon_outline_button.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:carecanvasai/widgets/video.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:material_dialogs/material_dialogs.dart';

class SmartVideoSwitcher extends StatefulWidget {
  final void Function(String)? onTriggerMessage;
  const SmartVideoSwitcher({super.key, this.onTriggerMessage});

  @override
  State<SmartVideoSwitcher> createState() => _SmartVideoSwitcherState();
}

class _SmartVideoSwitcherState extends State<SmartVideoSwitcher> {
  String? _currentVideoUrl;
  bool _showInteractivePlayer = false;
  late WebSocketChannel _channel;
  late Timer _pingTimer;

  @override
  void initState() {
    super.initState();
    // 建立 WebSocket 連線
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/video'), // 你後端的 WebSocket 路徑
    );

    // 監聽來自後端的影片 URL 訊息
    _channel.stream.listen(
      (message) {
        debugPrint('📡 收到 WebSocket 通知： $message');
        if (message.toString() == "pong") {
          return;
        }
        final isdata = jsonDecode(message);

        if (isdata['type'] == 'scan_image') {
          final imageUrl = isdata['url'];
          debugPrint("收到圖片ㄌ");
          _showScanImageDialog(imageUrl);
          return;
        }

        if (isdata['type'] == 'notify_image') {
          final title = isdata['title'] as String;
          final url = isdata['url'] as String;
          debugPrint("要印的！！");
          _showImageNotification(title, url);
          return;
        }

        setState(() {
          _showInteractivePlayer = false; // 強制先關掉
        });

        Future.delayed(Duration(milliseconds: 100), () {
          setState(() {
            _currentVideoUrl = isdata['url'];
            _showInteractivePlayer = true;
          });
        });
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
        _attemptReconnect();
      },
      onDone: () {
        debugPrint('WebSocket 連線關閉');
        _attemptReconnect();
      },
    );
    // 啟動心跳，每30秒送出 ping (根據你的後端是否處理自訂 ping，這裡也可以送出特定訊息)
    _pingTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (_channel.sink != null) {
        _channel.sink.add('ping');
      }
    });
  }

  void _attemptReconnect() {
    // 停止心跳計時器
    _pingTimer.cancel();
    // 嘗試延遲後重連，這裡可以增加重連次數控制避免無限重連
    Future.delayed(Duration(seconds: 5), () {
      debugPrint('嘗試重連 WebSocket...');
      _connectWebSocket();
    });
  }

  void _onVideoEnd() {
    setState(() {
      _currentVideoUrl = null;
      _showInteractivePlayer = false;
    });
  }

  void _showScanImageDialog(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogWidth = MediaQuery.of(context).size.width * 0.5;
        final pictureHeight = MediaQuery.of(context).size.height * 0.6;
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Image.network(imageUrl, height: pictureHeight), // 扣 padding
                const SizedBox(height: 20),
                Container(
                  width: dialogWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: dialogWidth * 0.4,
                        child: IconsOutlineButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          text: 'Cancel',
                          iconData: Icons.cancel_outlined,
                          textStyle: TextStyle(color: Colors.grey),
                          iconColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: dialogWidth * 0.4,
                        child: IconsButton(
                          onPressed: () {
                            widget.onTriggerMessage?.call("圖片");
                            // _sendImageToGpt(imageUrl);
                            Navigator.pop(context);
                          },
                          text: "Send",
                          iconData: Icons.send,
                          color: const Color.fromARGB(255, 33, 117, 243),
                          textStyle: TextStyle(color: Colors.white),
                          iconColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

void _showImageNotification(String title, String imageUrl) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(title), action: SnackBarAction(label: '查看圖片', onPressed: () => launchUrlString(imageUrl)), duration: const Duration(seconds: 5)));
  }

  @override
  void dispose() {
    _pingTimer.cancel();
    _channel.sink.close();
    super.dispose();
    
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double width = screenSize.width; // 獲取視窗寬度00
    double height = screenSize.height; // 獲取視窗高度
    return Stack(
      children: [
        LoopingVideoPlayer(),
        // Image.asset('assets/loop.gif', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        _showInteractivePlayer && _currentVideoUrl != null
            ? Container(height: (height - 70) * 0.85, width: width * 0.6, child: InteractiveVideoPlayer(videoUrl: _currentVideoUrl!, onVideoEnd: _onVideoEnd))
            : const SizedBox(),
      ],
    );
  }
}

class LoopingVideoPlayer extends StatefulWidget {
  const LoopingVideoPlayer({Key? key}) : super(key: key);

  @override
  State<LoopingVideoPlayer> createState() => _LoopingVideoPlayerState();
}

class _LoopingVideoPlayerState extends State<LoopingVideoPlayer> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // 使用 assets/loop.mp4 作為影片來源
    _controller = VideoPlayerController.asset('assets/videos/loop.mp4')
      ..initialize().then((_) {
        // 設定為無限循環播放
        _controller.setLooping(true);
        // 設定靜音
        _controller.setVolume(0);
        // 開始播放影片
        _controller.play().catchError((error) {
          debugPrint('播放時錯誤: $error');
        });
        // 更新畫面
        setState(() {});
      });
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
    return ClipRect(
      child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)))),
    );
  }
}
