import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carecanvasai/widgets/player.dart';
import 'package:carecanvasai/widgets/recoder.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:waveform_flutter/waveform_flutter.dart';
import 'dart:math';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> with TickerProviderStateMixin {
  bool _isChatCollapsed = true;
  final List<_ChatMessage> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final TextEditingController _controller = TextEditingController();
  // final Stream<Amplitude> _amplitudeStream = createSmoothedAmplitudeStream();
  late final Stream<Amplitude> _amplitudeStream;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  double _soundLevel = 0.0;
  String rec = "";

  void _clearMessages() {
    for (var msg in _messages) {
      msg.animation.dispose(); // 清除動畫資源
    }

    final count = _messages.length;
    for (int i = count - 1; i >= 0; i--) {
      final removedItem = _messages.removeAt(i);
      _listKey.currentState?.removeItem(i, (context, animation) => _buildMessage(removedItem, animation, MediaQuery.of(context).size.width), duration: const Duration(milliseconds: 300));
    }
  }

  void _addMessage(String text, {bool isMe = true, bool typewriter = false}) {
    final animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    final message = _ChatMessage(text: text, isMe: isMe, animation: animation);

    _messages.insert(0, message);
    _listKey.currentState?.insertItem(0);
    animation.forward();
    _controller.clear();
    if (typewriter && !isMe) {
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {
          message.visibleLength += 1;
        });
        if (message.visibleLength >= message.text.length) timer.cancel();
      });
    } else {
      message.visibleLength = text.length;
    }
  }

  void _sendMessage({String text = ""}) async {
    _controller.clear();
    _controller.clear();
    _controller.clear();
    setState(() {
      _controller.clear();
    });
    // String text = _controller.text.trim();
    if (text == "圖片") {
      _addMessage(text);
    } else {
      // text = _controller.text.trim();
      if (text.isEmpty) return;
      setState(() {
        _controller.clear();
        FocusScope.of(context).unfocus();
      });
      _addMessage(text);
    }
    try {
      // 用 HTTP POST 傳送訊息到後端
      final response = await http.post(Uri.parse("http://localhost:8000/chat"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"message": text}));
      if (response.statusCode == 200) {
        // 假設後端回傳 JSON 格式，如：{"reply": "這是LLM回覆"}
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        final reply = data["reply"];
        // 將後端回覆加入對話
        _addMessage(reply, isMe: false, typewriter: true);
      } else {
        _addMessage("Error: ${response.statusCode}", isMe: false);
      }
    } catch (e) {
      _addMessage("發送訊息時發生錯誤", isMe: false);
      debugPrint("Error sending message: $e");
    }
  }

  Widget _buildMessage(_ChatMessage message, Animation<double> animation, double width) {
    final isMe = message.isMe;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? Colors.blue[100] : Colors.grey[300];
    final radius =
        isMe
            ? const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12))
            : const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomRight: Radius.circular(12));

    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0,
      child: FadeTransition(
        opacity: animation,
        child: Column(
          crossAxisAlignment: align,
          children: [
            SizedBox(width: width),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color, borderRadius: radius),
              // 這段改成根據 isImage 顯示 Text 或 Image
              child:
                  message.isImage
                      ? ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width * 0.8, maxHeight: 200),
                        child: Image.network(
                          message.imageUrl!,
                          // 或是 Image.memory(message.imageBytes!),
                          fit: BoxFit.cover,
                        ),
                      )
                      : Text(message.text.substring(0, message.visibleLength)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    _amplitudeStream = createSmoothedAmplitudeStream().asBroadcastStream();
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (err) {
        // 只攔截 “沒有聲音” 的錯誤，不讓它炸整支 App
        if (err.errorMsg == 'no-speech') {
          debugPrint('♪ 沒偵測到聲音，自動停止錄音');
        } else {
          debugPrint('SpeechToText 錯誤: ${err.errorMsg}');
        }
        setState(() => _isListening = false);
      },
    );
    if (!available) debugPrint('Speech recognition unavailable');
  }

  void _startListening() {
    _speech.listen(
      onResult: (val) {
        setState(() => _controller.text = val.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      localeId: 'zh-TW',
      partialResults: true,
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = (level + 50) / 50);
      },
      cancelOnError: true, // 讓錯誤發生時自動停止 listen()
    );
    setState(() => _isListening = true);
  }

  void _stopListening() {
    _speech.cancel();
    rec = _controller.text.trim();
    _controller.clear();
    setState(() => _isListening = false);
    _sendMessage(text: rec);
  }

  @override
  void dispose() {
    _speech.stop();
    for (var msg in _messages) {
      msg.animation.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // 1. 建立 web picker
    final plugin = ImagePickerPlugin();
    // 2. 跳出檔案選擇
    final XFile? file = await plugin.getImageFromSource(source: ImageSource.gallery);
    if (file == null) return; // 使用者取消

    // 3. 取得檔案 bytes
    final bytes = await file.readAsBytes();
    final name = file.name;

    // 5. 上傳到 /scan/callback —— 注意欄位名稱一定要是 "0"
    final uri = Uri.parse('http://127.0.0.1:8000/scan/callback');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          '0', // <- 這裡改成 "0"
          bytes,
          filename: name,
          contentType: MediaType('image', name.split('.').last),
        ),
      );
    final resp = await req.send();
    if (resp.statusCode != 200) {
      debugPrint('上傳失敗：${resp.statusCode}');
    }
    // 不用在這裡再 parse 回傳結果與更新消息，
    // 因為後端會透過 WebSocket 推 scan_image，自動由 WS listener 接手顯示真實 URL
  }

  @override
  Widget build(BuildContext context) {
    final Random _rand = Random();
    const int barCount = 15;
    const double maxBarHeight = 40.0;
    Size screenSize = MediaQuery.of(context).size;
    double width = screenSize.width; // 獲取視窗寬度
    double height = screenSize.height; // 獲取視窗高度
    final chatWidth = width * 0.3;
    final chatHeight = (height - 70) * 0.85;
    final videoHeight = (height - 70) * 0.85;
    final videoWidth = width * 0.6;
    return Column(
      children: [
        Container(
          width: chatWidth + videoWidth + 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: (height - 70) * 0.85,
                width: width * 0.6,
                child: SmartVideoSwitcher(
                  onTriggerMessage: (msg) {
                    _sendMessage(text: msg);
                  },
                ),
              ),
              if (!_isChatCollapsed) ...[
                // 展開狀態：影片 + 間隔 + 聊天側欄
                const SizedBox(width: 10),
                _buildChatPanel(chatWidth, chatHeight),
              ] else ...[
                // 這裡放縮到 48px 的側欄，只顯示 toggle 按鈕
                _buildChatPanel(48, chatHeight),
              ],
            ],
          ),
        ),

        // Row(
        //   mainAxisAlignment: MainAxisAlignment.end,
        // children: [
        // Container(
        //   height: (height - 70) * 0.85,
        //   width: width * 0.6,
        //   child: SmartVideoSwitcher(
        //     onTriggerMessage: (msg) {
        //       _sendMessage(text: msg);
        //     },
        //   ),
        // ),
        //     SizedBox(width: 10),
        //     AnimatedContainer(
        //       duration: const Duration(milliseconds: 300),
        //       width: _isChatCollapsed ? 48 : chatWidth,
        //       height: chatHeight,
        //       decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
        //       child: Container(
        //         alignment: Alignment.center,
        //         decoration: BoxDecoration(color: Color.fromARGB(255, 248, 248, 248), borderRadius: BorderRadius.circular(10)),
        //         padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        //         width: width * 0.3,
        //         height: (height - 70) * 0.85,
        //         child: Stack(
        //           children: [
        //             Offstage(
        //               offstage: _isChatCollapsed,
        //   child:
        //   AnimatedList(
        //     key: _listKey,
        //     reverse: true,
        //     padding: const EdgeInsets.all(8),
        //     initialItemCount: _messages.length,
        //     itemBuilder: (context, index, animation) {
        //       return _buildMessage(_messages[index], animation, chatWidth);
        //     },
        //   ),
        // ),
        //             Container(width: width * 0.3 - 2, height: 50, color: Color.fromARGB(255, 248, 248, 248)),
        // Positioned(
        //   right: 1,
        //   top: 5,
        //   child: IconButton(
        //     icon: Icon(Icons.add),
        //     onPressed: () {
        //       _clearMessages();
        //     },
        //   ),
        // ),
        //             Positioned(
        //               right: 0,
        //               top: 0,
        //               child: IconButton(
        //                 iconSize: 20,
        //                 icon: Icon(
        //                   _isChatCollapsed
        //                       ? Icons
        //                           .arrow_forward_ios // 展開箭頭
        //                       : Icons.arrow_back_ios, // 收合箭頭
        //                   color: Colors.grey[700],
        //                 ),
        //                 onPressed: () {
        //                   setState(() {
        //                     _isChatCollapsed = !_isChatCollapsed;
        //                   });
        //                 },
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
        const Divider(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: Color.fromARGB(255, 248, 248, 248), borderRadius: BorderRadius.circular(100)),
                alignment: Alignment.center,
                padding: EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    _isListening
                        ? Row(
                          children: [
                            // Flexible(child:
                            SizedBox(width: (width * 0.5), height: 50, child: AnimatedWaveList(stream: _amplitudeStream)),

                            // ),
                            IconButton(
                              icon: const Icon(Icons.stop_circle, color: Colors.red),
                              onPressed: () {
                                _stopListening();
                                _controller.clear();
                              },
                            ),
                          ],
                        )
                        : Row(
                          children: [
                            SizedBox(width: 5),
                            IconButton(icon: const Icon(Icons.image), onPressed: _pickImage),

                            Container(
                              alignment: Alignment.center,

                              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                              width: (width * 0.5) - 50,
                              height: 50,
                              child: TextField(
                                controller: _controller,
                                decoration: const InputDecoration.collapsed(hintText: '輸入訊息...'),
                                onSubmitted: (val) {
                                  _sendMessage(text: val);
                                  _controller.clear();
                                },
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.mic), onPressed: _startListening),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () {
                                _sendMessage(text: _controller.text.trim());
                                _controller.clear();
                              },
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel(double width, double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          // 只有在寬度夠大時才顯示列表
          if (!_isChatCollapsed)
            AnimatedList(
              key: _listKey,
              reverse: true,
              padding: const EdgeInsets.all(8),
              initialItemCount: _messages.length,
              itemBuilder: (context, index, animation) {
                return _buildMessage(_messages[index], animation, width);
              },
            ),

          if (!_isChatCollapsed)
            Positioned(
              left: 0,
              top: 0,
              child: IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  _clearMessages();
                },
              ),
            ),

          // 無論哪個狀態，右上都有一個箭頭
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              iconSize: 20,
              icon: Icon(
                _isChatCollapsed
                    ? Icons
                        .arrow_back_ios // 點擊展開
                    : Icons.arrow_forward_ios, // 點擊收起
                color: Colors.grey[700],
              ),
              onPressed: () => setState(() => _isChatCollapsed = !_isChatCollapsed),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isMe;
  final AnimationController animation;
  int visibleLength = 0;
  bool isImage;
  Uint8List? imageBytes; // 本機暫存
  String? imageUrl; // 後端回傳

  _ChatMessage({required this.text, required this.isMe, required this.animation, this.isImage = false, this.imageBytes, this.imageUrl});
}

Stream<Amplitude> createSmoothedAmplitudeStream({
  double sensitivity = 0.3, // 音量縮放因子 (0~1)
  double threshold = 0.05, // 底噪閾值
}) {
  final rnd = Random();
  double prev = 0.0;
  return Stream.periodic(const Duration(milliseconds: 70), (count) {
    // 產生 0~1 的隨機值
    final raw = rnd.nextDouble();
    // 根據靈敏度縮放
    final scaled = raw * sensitivity;
    // 噪聲過濾，下限以下視為靜默
    final filtered = scaled < threshold ? 0.0 : scaled;
    // 平滑處理
    final smoothed = prev * 0.6 + filtered * 0.4;
    prev = smoothed;
    return Amplitude(current: Random().nextDouble() * 100, max: 100);
  });
}
