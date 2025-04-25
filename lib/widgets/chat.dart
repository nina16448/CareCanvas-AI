import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carecanvasai/widgets/player.dart';
import 'package:carecanvasai/widgets/recoder.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> with TickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final TextEditingController _controller = TextEditingController();

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

  void _sendMessage({String pictext = ""}) async {
    String text = _controller.text.trim();

    if (pictext == "圖片") {
      text = pictext;
      _addMessage(text);
    } else {
      text = _controller.text.trim();
      if (text.isEmpty) return;
      _controller.clear();
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
              child: Text(message.text.substring(0, message.visibleLength)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var msg in _messages) {
      msg.animation.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double width = screenSize.width; // 獲取視窗寬度
    double height = screenSize.height; // 獲取視窗高度
    return Column(
      children: [
        Row(
          children: [
            Container(
              height: (height - 70) * 0.85,
              width: width * 0.6,
              child: SmartVideoSwitcher(
                onTriggerMessage: (msg) {
                  _sendMessage(pictext: msg);
                },
              ),
            ),
            SizedBox(width: 10),

            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Color.fromARGB(255, 248, 248, 248), borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
              width: width * 0.3,
              height: (height - 70) * 0.85,
              child: Stack(
                children: [
                  AnimatedList(
                    key: _listKey,
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    initialItemCount: _messages.length,
                    itemBuilder: (context, index, animation) {
                      return _buildMessage(_messages[index], animation, width * 0.3);
                    },
                  ),
                  Positioned(
                    right: 1,
                    top: 5,
                    child: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        _clearMessages();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const Divider(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              VoiceRecorderWidget(textController: _controller),
              Container(
                decoration: BoxDecoration(color: Color.fromARGB(255, 248, 248, 248), borderRadius: BorderRadius.circular(100)),
                alignment: Alignment.center,
                padding: EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Container(
                      alignment: Alignment.center,

                      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                      width: (width * 0.5) - 50,
                      height: 50,
                      child: TextField(controller: _controller, decoration: const InputDecoration.collapsed(hintText: '輸入訊息...')),
                    ),
                    IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
                  ],
                ),
              ),

              // IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isMe;
  final AnimationController animation;
  int visibleLength = 0;

  _ChatMessage({required this.text, required this.isMe, required this.animation});
}
