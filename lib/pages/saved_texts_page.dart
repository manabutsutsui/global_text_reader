import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ads/ad_banner.dart';
import 'text_recognition_page.dart';

class SavedTextsPage extends StatelessWidget {
  const SavedTextsPage({super.key});

  void _showDeleteConfirmation(BuildContext context, String documentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                  title: const Text(
                    '削除',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    FirebaseFirestore.instance
                        .collection('recognized_texts')
                        .doc(documentId)
                        .delete();
                    Navigator.pop(context);
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('保存済みテキスト',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: user == null
                ? const Center(
                    child: Text(
                      'ログインしてください',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('recognized_texts')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('エラーが発生しました: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final documents = snapshot.data?.docs ?? [];

                      if (documents.isEmpty) {
                        return const Center(
                          child: Text(
                            '保存されたテキストはありません',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          final document = documents[index];
                          final data = document.data() as Map<String, dynamic>;
                          final text = data['text'] as String;
                          final timestamp =
                              (data['timestamp'] as Timestamp).toDate();

                          return Card(
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(
                                text,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${timestamp.year}/${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.white),
                                onPressed: () {
                                  _showDeleteConfirmation(context, document.id);
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TextRecognitionPage(
                                      initialText: text,
                                      documentId: document.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
