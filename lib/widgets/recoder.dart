import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:waveform_flutter/waveform_flutter.dart';

class ChatInputField extends StatefulWidget {
  final void Function(String) onSubmit;
  const ChatInputField({Key? key, required this.onSubmit}) : super(key: key);

  @override
  _ChatInputFieldState createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final Stream<Amplitude> _amplitudeStream = createSmoothedAmplitudeStream();

  late stt.SpeechToText _speech;
  final TextEditingController _controller = TextEditingController();
  bool _isListening = false;
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(onStatus: (s) => debugPrint('Speech status: $s'), onError: (e) => debugPrint('Speech error: $e'));
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
        // level 範圍大約 -50 (靜音) ~ 0 (最大聲)
        setState(() => _soundLevel = (level + 50) / 50);
      },
    );
    setState(() => _isListening = true);
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    widget.onSubmit(_controller.text);
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Random _rand = Random();
    const int barCount = 15;
    const double maxBarHeight = 40.0;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(100)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _isListening
              ? Row(
                children: [
                  SizedBox(width: 88, height: maxBarHeight, child: AnimatedWaveList(stream: _amplitudeStream)),
                  IconButton(icon: const Icon(Icons.stop_circle, color: Colors.red), onPressed: _stopListening),
                ],
              )
              : IconButton(icon: const Icon(Icons.mic), onPressed: _startListening),
        ],
      ),
    );
  }
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
