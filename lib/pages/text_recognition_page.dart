import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ads/ad_banner.dart';

class TextRecognitionPage extends StatefulWidget {
  final String? imagePath;
  final String? initialText;
  final String? documentId;

  const TextRecognitionPage({
    super.key,
    this.imagePath,
    this.initialText,
    this.documentId,
  }) : assert(imagePath != null || initialText != null);

  @override
  State<TextRecognitionPage> createState() => _TextRecognitionPageState();
}

class _TextRecognitionPageState extends State<TextRecognitionPage> {
  String _recognizedText = '';
  bool _isLoading = true;
  late TextEditingController _textController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _audioFilePath = '';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();

    if (widget.imagePath != null) {
      _processImage();
    } else {
      setState(() {
        _recognizedText = widget.initialText!;
        _textController.text = _recognizedText;
        _isLoading = false;
      });
    }

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _processImage() async {
    setState(() => _isLoading = true);

    try {
      final String configString =
          await rootBundle.loadString('assets/configs/config.json');
      final Map<String, dynamic> config = json.decode(configString);
      final String apiKey = config['GoogleCloudVisionApiKey'];

      final File imageFile = File(widget.imagePath!);
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(
            'https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'requests': [
            {
              'image': {
                'content': base64Image,
              },
              'features': [
                {
                  'type': 'TEXT_DETECTION',
                }
              ],
              'imageContext': {
                'languageHints': ['ja', 'en'],
              }
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['responses']?[0]?['fullTextAnnotation'] != null) {
          final String detectedText =
              data['responses'][0]['fullTextAnnotation']['text'];
          setState(() {
            _recognizedText = detectedText;
            _textController.text = _recognizedText;
          });
        } else {
          setState(() {
            _recognizedText = 'テキストが検出されませんでした。';
            _textController.text = _recognizedText;
          });
        }
      } else {
        throw Exception('APIリクエストが失敗しました: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _recognizedText = 'エラーが発生しました: $e';
        _textController.text = _recognizedText;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playTTS() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      return;
    }

    if (_audioFilePath.isNotEmpty) {
      await _audioPlayer.play(DeviceFileSource(_audioFilePath));
      setState(() => _isPlaying = true);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final String configString =
          await rootBundle.loadString('assets/configs/config.json');
      final Map<String, dynamic> config = json.decode(configString);
      final String apiKey = config['OpenAiApiKey'];
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': _textController.text,
          'voice': 'alloy',
        }),
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_audio.mp3');
        await tempFile.writeAsBytes(response.bodyBytes);

        _audioFilePath = tempFile.path;
        await _audioPlayer.play(DeviceFileSource(_audioFilePath));

        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() => _isPlaying = false);
        });
      } else {
        throw Exception(
            'TTSリクエストが失敗しました: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('音声の生成に失敗しました: $e')),
      );
    }
  }

  Future<void> _save() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('recognized_texts').add({
        'userId': user?.uid,
        'text': _textController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テキストが保存されました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _updateText() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ユーザーがログインしていません');
      }

      await FirebaseFirestore.instance
          .collection('recognized_texts')
          .doc(widget.documentId)
          .update({
        'text': _textController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テキストが更新されました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('認識されたテキスト',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        actions: [
          if (widget.documentId != null)
            IconButton(
              onPressed: _updateText,
              icon: const Icon(Icons.update, color: Colors.white),
            )
          else
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.black,
                  child: Column(
                    children: [
                      Slider(
                        value: _position.inSeconds.toDouble(),
                        min: 0,
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) async {
                          final position = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(position);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _playTTS,
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const AdBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        fillColor: Colors.white24,
                        filled: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
