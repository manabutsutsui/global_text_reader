import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/voice_data.dart';
import '../utils/device_id.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final textRecognizer = TextRecognizer();
  final TextEditingController _textController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  File? _image;
  bool _isProcessing = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.3);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speak() async {
    if (_textController.text.isNotEmpty) {
      setState(() => _isSpeaking = true);
      await flutterTts.speak(_textController.text);
    }
  }

  Future<void> _stop() async {
    setState(() => _isSpeaking = false);
    await flutterTts.stop();
  }

  @override
  void dispose() {
    textRecognizer.close();
    _textController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _processImage() async {
    if (_image == null) return;

    setState(() {
      _isProcessing = true;
      _textController.text = '';
    });

    try {
      final inputImage = InputImage.fromFile(_image!);
      final recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        _textController.text = recognizedText.text;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _textController.text = '文字認識に失敗しました: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;

      setState(() {
        _image = File(photo.path);
      });
      await _processImage();
    } catch (e) {
      print('Error taking photo: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _image = File(image.path);
      });
      await _processImage();
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<String?> _showTitleDialog() async {
    String title = '';
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter a title'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter a title',
            ),
            onChanged: (value) {
              title = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, title),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToFirestore() async {
    if (_textController.text.isEmpty) return;

    try {
      final title = await _showTitleDialog();
      if (title == null || title.isEmpty) return;

      final deviceId = await DeviceId.getId();
      final voiceData = VoiceData(
        text: _textController.text,
        title: title,
        createdAt: DateTime.now(),
        deviceId: deviceId,
      );

      await FirebaseFirestore.instance
          .collection('voice_data')
          .add(voiceData.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Home',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_image != null)
                SizedBox(
                  height: 300,
                  child: Image.file(_image!),
                ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const CircularProgressIndicator()
              else if (_textController.text.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recognized text:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: _isSpeaking ? _stop : _speak,
                          icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                          tooltip: _isSpeaking ? 'Stop' : 'Speak',
                        ),
                      ],
                    ),
                    const Text(
                      'You can modify the recognized text.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Edit the text',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _saveToFirestore,
                        icon: const Icon(Icons.save),
                        label: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take a photo',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  const Text('or',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select an image',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
