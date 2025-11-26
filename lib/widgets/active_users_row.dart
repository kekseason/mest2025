import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/chat_screen.dart';

class ActiveUsersRow extends StatelessWidget {
  const ActiveUsersRow({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Yeni Eşleşmeler", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              Text("Hepsini gör", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(
          height: 100, 
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('users', arrayContains: myId)
                .orderBy('lastMessageTime', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, chatSnapshot) {
              if (!chatSnapshot.hasData) return const SizedBox(); 
              var chats = chatSnapshot.data!.docs;

              if (chats.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Text("Henüz eşleşme yok.", style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  var chatDoc = chats[index];
                  var chatData = chatDoc.data() as Map<String, dynamic>;
                  List users = chatData['users'] ?? [];
                  String otherUserId = users.firstWhere((id) => id != myId, orElse: () => "");

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return _buildPlaceholder();
                      var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (userData == null) return _buildPlaceholder();

                      String name = userData['username'] ?? userData['name'] ?? "User";
                      String? photoUrl = userData['photoUrl'];
                      bool isOnline = userData['isOnline'] ?? false;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chatDoc.id,
                              otherUserId: otherUserId,
                              otherUserName: name,
                            ),
                          ));
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 15.0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.transparent, width: 0), 
                                    ),
                                    child: ClipOval(
                                      child: photoUrl != null && photoUrl.isNotEmpty
                                          ? Image.network(photoUrl, fit: BoxFit.cover)
                                          : Container(
                                              color: Colors.grey[800],
                                              child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                                            ),
                                    ),
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      bottom: 2, right: 2,
                                      child: Container(
                                        width: 14, height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name.split(' ')[0], 
                                style: const TextStyle(color: Colors.white, fontSize: 12),
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
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(width: 64, height: 64, margin: const EdgeInsets.only(right: 15), decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle));
  }
}