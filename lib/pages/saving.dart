import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/voice_data.dart';
import '../utils/device_id.dart';

class SavingPage extends StatefulWidget {
  const SavingPage({super.key});

  @override
  State<SavingPage> createState() => _SavingPageState();
}

class _SavingPageState extends State<SavingPage> {
  final FlutterTts flutterTts = FlutterTts();
  String? _playingId;

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

  Future<void> _speak(String text, String id) async {
    if (_playingId != null) {
      await _stop();
    }
    setState(() => _playingId = id);
    await flutterTts.speak(text);
    flutterTts.setCompletionHandler(() {
      setState(() => _playingId = null);
    });
  }

  Future<void> _stop() async {
    await flutterTts.stop();
    setState(() => _playingId = null);
  }

  Future<void> _deleteVoiceData(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('voice_data')
          .doc(id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Saving',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<String>(
        future: DeviceId.getId(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
      
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('voice_data')
                .where('deviceId', isEqualTo: snapshot.data)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
      
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
      
              final voiceDataList = snapshot.data!.docs.map((doc) {
                return VoiceData.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                );
              }).toList();
      
              if (voiceDataList.isEmpty) {
                return const Center(
                    child: Text('A list of saved data will be displayed here.'));
              }
      
              return ListView.builder(
                itemCount: voiceDataList.length,
                itemBuilder: (context, index) {
                  final voiceData = voiceDataList[index];
                  final docId = snapshot.data!.docs[index].id;
                  final isPlaying = _playingId == docId;
      
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ListTile(
                      title: Text(voiceData.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        voiceData.createdAt.toLocal().toString().split('.')[0],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                            onPressed: () {
                              if (isPlaying) {
                                _stop();
                              } else {
                                _speak(voiceData.text, docId);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteVoiceData(docId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }
}
