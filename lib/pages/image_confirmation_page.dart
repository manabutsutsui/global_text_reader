import 'dart:io';
import 'package:flutter/material.dart';
import 'text_recognition_page.dart';
import '../ads/ad_banner.dart';
import '../ads/ad_reward_interstitial.dart';

class ImageConfirmationPage extends StatefulWidget {
  final String imagePath;

  const ImageConfirmationPage({super.key, required this.imagePath});

  @override
  State<ImageConfirmationPage> createState() => _ImageConfirmationPageState();
}

class _ImageConfirmationPageState extends State<ImageConfirmationPage> {
  final AdRewardInterstitial _adRewardInterstitial = AdRewardInterstitial();

  @override
  void initState() {
    super.initState();
    _adRewardInterstitial.loadAd();
  }

  @override
  void dispose() {
    _adRewardInterstitial.dispose();
    super.dispose();
  }

  Future<void> _onCompleteTap() async {
    final bool canProceed = await _adRewardInterstitial.showAd(context);

    if (canProceed && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TextRecognitionPage(imagePath: widget.imagePath),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: Center(
              child: Image.file(File(widget.imagePath)),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _onCompleteTap,
                    child: const Text(
                      '完了',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
