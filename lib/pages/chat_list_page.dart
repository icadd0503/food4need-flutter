import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_room_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: myUid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(child: Text("No chats yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;

              // ================= AUTO-HIDE LOGIC =================
              final donationStatus = data['donationStatus'];
              if (donationStatus == 'completed') {
                return const SizedBox();
              }
              // ===================================================

              final restaurantId = data["restaurantId"];
              final ngoId = data["ngoId"];
              final otherUserId = myUid == restaurantId ? ngoId : restaurantId;
              final isOtherNgo = otherUserId == ngoId;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>?;

                  final name = userData?["name"] ?? "User";
                  final profileImageUrl = userData?["profileImageUrl"];

                  final avatarColor = isOtherNgo
                      ? Colors.green
                      : const Color(0xffd4a373);

                  // 🔴 UNREAD COUNT STREAM (ADDED)
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chat.id)
                        .collection('messages')
                        .where('senderId', isNotEqualTo: myUid)
                        .snapshots(),
                    builder: (context, msgSnap) {
                      int unreadCount = 0;

                      if (msgSnap.hasData) {
                        for (var m in msgSnap.data!.docs) {
                          final msgData = m.data() as Map<String, dynamic>;
                          final seenBy = List<String>.from(
                            msgData['seenBy'] ?? [],
                          );
                          if (!seenBy.contains(myUid)) {
                            unreadCount++;
                          }
                        }
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          // ✅ MARK AS SEEN (UNCHANGED)
                          final msgs = await FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chat.id)
                              .collection('messages')
                              .where('senderId', isNotEqualTo: myUid)
                              .get();

                          for (var m in msgs.docs) {
                            final msgData = m.data() as Map<String, dynamic>;
                            final seenBy = List<String>.from(
                              msgData["seenBy"] ?? [],
                            );

                            if (!seenBy.contains(myUid)) {
                              await m.reference.update({
                                "seenBy": FieldValue.arrayUnion([myUid]),
                              });
                            }
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomPage(donationId: chat.id),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: avatarColor,
                              backgroundImage: profileImageUrl != null
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                              child: profileImageUrl == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : "?",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              data['lastMessage'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // 🔴 UNREAD BADGE (ADDED)
                            trailing: unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.black45,
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
