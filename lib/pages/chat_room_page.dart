import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRoomPage extends StatefulWidget {
  final String donationId;
  const ChatRoomPage({super.key, required this.donationId});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _controller = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markMessagesAsSeen();
  }

  /// MARK INCOMING MESSAGES AS SEEN
  Future<void> _markMessagesAsSeen() async {
    final msgs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.donationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: uid)
        .get();

    for (var m in msgs.docs) {
      final data = m.data() as Map<String, dynamic>;
      final seenBy = List<String>.from(data["seenBy"] ?? []);

      if (!seenBy.contains(uid)) {
        await m.reference.update({
          "seenBy": FieldValue.arrayUnion([uid]),
        });
      }
    }
  }

  /// SEND MESSAGE
  Future<void> sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.donationId);

    await chatRef.collection('messages').add({
      'senderId': uid,
      'text': _controller.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': [uid],
    });

    await chatRef.update({
      'lastMessage': _controller.text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.donationId)
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == uid;

                    // 🔥 ANIMATION HERE
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 20),
                            child: child,
                          ),
                        );
                      },
                      child: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xffd4a373)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            msg['text'],
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: const Color(0xffd4a373),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
