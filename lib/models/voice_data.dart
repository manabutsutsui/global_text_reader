import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceData {
  final String text;
  final String title;
  final DateTime createdAt;
  final String deviceId;

  VoiceData({
    required this.text,
    required this.title,
    required this.createdAt,
    required this.deviceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'title': title,
      'createdAt': createdAt,
      'deviceId': deviceId,
    };
  }

  factory VoiceData.fromMap(String id, Map<String, dynamic> map) {
    return VoiceData(
      text: map['text'] as String,
      title: map['title'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      deviceId: map['deviceId'] as String,
    );
  }
}
