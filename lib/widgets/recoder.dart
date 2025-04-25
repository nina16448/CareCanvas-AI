import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:web/web.dart' as web;
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceRecorderWidget extends StatefulWidget {
  final TextEditingController textController;

  const VoiceRecorderWidget({super.key, required this.textController});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '按下麥克風開始講話';
  double _confidence = 1.0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  /// 這個函式用來啟動/停止語音辨識
  void _listen() async {
    if (!_isListening) {
      // 初始化辨識服務，並設定錯誤及狀態回呼
      bool available = await _speech.initialize(onStatus: (val) => debugPrint('onStatus: $val'), onError: (val) => debugPrint('onError: $val'));
      if (available) {
        setState(() => _isListening = true);
        // 開始聆聽並獲取辨識結果
        _speech.listen(
          onResult: (val) {
            setState(() {
              _recognizedText = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) {
                _confidence = val.confidence;
              }
            });
            widget.textController.text = val.recognizedWords;
            debugPrint("辨識結果: ${val.recognizedWords}");
          },
          localeId: 'zh_TW', // 或者使用 'zh_CN' 依你的需求
        );
      } else {
        setState(() => _isListening = false);
        _speech.stop();
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(_isListening ? Icons.stop_circle : Icons.mic), color: _isListening ? Colors.red : const Color.fromARGB(255, 0, 0, 0), onPressed: _listen);
  }
}
