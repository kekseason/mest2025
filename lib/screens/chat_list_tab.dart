import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart'; 
import '../widgets/active_users_row.dart';

class ChatListTab extends StatelessWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return const Center(child: Text("Giriş yapmalısın"));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        title: const Text("Sohbetler", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.help_outline, color: Colors.white), onPressed: () {}),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Ara",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                suffixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          const ActiveUsersRow(),
          const Divider(color: Colors.white10, height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('users', arrayContains: myId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Henüz sohbet yok", style: TextStyle(color: Colors.grey)));

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1, indent: 80),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    List users = data['users'] ?? [];
                    String otherUserId = users.firstWhere((id) => id != myId, orElse: () => "");
                    Map<String, dynamic> userNames = data['userNames'] ?? {};
                    String otherUserName = userNames[otherUserId] ?? "İsimsiz";
                    String lastMessage = data['lastMessage'] ?? "";
                    
                    String time = "";
                    if (data['lastMessageTime'] != null) {
                      DateTime date = (data['lastMessageTime'] as Timestamp).toDate();
                      time = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: doc.id, otherUserId: otherUserId, otherUserName: otherUserName))),
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        radius: 28,
                        child: Text(otherUserName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20)),
                      ),
                      title: Text(otherUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ),
                      trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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