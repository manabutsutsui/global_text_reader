import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../ads/ad_banner.dart';
import 'package:image_picker/image_picker.dart';
import 'image_confirmation_page.dart';
import 'saved_texts_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
    );

    await _controller!.initialize();
    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    '保存したテキスト',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavedTextsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  title: Text(
                    '画像を選択',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);

                    if (image != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ImageConfirmationPage(imagePath: image.path),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  title: Text(
                    'キャンセル',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
              child: Stack(children: [
            CameraPreview(_controller!),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () {
                  _showOptionsSheet(context);
                },
                icon:
                    const Icon(Icons.more_horiz, color: Colors.white, size: 48),
              ),
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 64,
              child: IconButton(
                onPressed: () async {
                  try {
                    final image = await _controller!.takePicture();
                    if (!mounted) return;

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ImageConfirmationPage(imagePath: image.path),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('エラーが発生しました: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.camera, color: Colors.white, size: 48),
              ),
            )
          ])),
          const AdBanner(),
        ],
      ),
    );
  }
}
