import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'play_mest_screen.dart';
import 'mestometer_screen.dart';
import 'coop_solve_screen.dart'; // <-- YENİ EKLENDİ

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({super.key, required this.chatId, required this.otherUserId, required this.otherUserName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final String myId = FirebaseAuth.instance.currentUser!.uid;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    String message = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': myId,
      'text': message,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  // --- YENİ FONKSİYON: CO-OP OTURUM BAŞLATMA ---
  void _startCoopSession(String testId, String testName) async {
    // Oturum ID'sini belirle: chatId ve testId'yi birleştirerek benzersiz bir ID oluştur.
    // İki kullanıcının da aynı oturumu açması için sıralamayı standart tutmaya gerek yok, 
    // çünkü Firestore'da document ID eşsiz olacağı için aynı ID'yi açacaklar.
    String sessionIdentifier = "${widget.chatId}_$testId";

    // Firestore'da oturum olup olmadığını kontrol et
    DocumentReference sessionRef = FirebaseFirestore.instance.collection('coop_sessions').doc(sessionIdentifier);
    DocumentSnapshot sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) {
      // Oturum yoksa oluştur
      await sessionRef.set({
        'testId': testId,
        'chatId': widget.chatId,
        'users': [myId, widget.otherUserId],
        'otherUserName': widget.otherUserName,
        'currentQuestionIndex': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    }

    // Co-op Çözüm Ekranına git
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CoopSolveScreen(
            testId: testId,
            chatId: widget.chatId,
            otherUserId: widget.otherUserId,
            otherUserName: widget.otherUserName,
            sessionId: sessionIdentifier, // Yeni oluşturulan/bulunan ID
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              child: Text(widget.otherUserName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Text("Çevrimiçi", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => MestometerScreen(
                    otherUserId: widget.otherUserId,
                    otherUserName: widget.otherUserName,
                  )
                )
              );
            },
            icon: const Icon(Icons.favorite_border, color: Color(0xFFFF5A5F)), // Kalp ikonu
            tooltip: "Mestometre",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
            child: const Text("Bugün", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == myId;
                    String type = data['type'] ?? 'text';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(radius: 14, backgroundColor: Colors.grey[800], child: Text(widget.otherUserName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10))),
                            const SizedBox(width: 8),
                          ],
                          type == 'invite' ? _buildMestInviteCard(data, isMe) : _buildMessageBubble(data['text'], isMe),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: "Bir mesaj yaz...", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: _sendMessage),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Flexible(
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if(!isMe) Padding(padding: const EdgeInsets.only(left: 10, bottom: 4), child: Text(widget.otherUserName, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildMestInviteCard(Map<String, dynamic> data, bool isMe) {
    return Flexible(
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if(!isMe) Padding(padding: const EdgeInsets.only(left: 10, bottom: 4), child: Text(widget.otherUserName, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? "Bir Mest gönderdin" : "${widget.otherUserName} sana bir Mest gönderdi", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(data['testImage'] ?? ''), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Text(data['testName'] ?? "Başlıksız", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayMestScreen(testId: data['testId']))),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 10)),
                                child: const Text("Çöz", style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                // BU BUTONUN İŞLEVİ DEĞİŞTİ!
                                onPressed: () {
                                  _startCoopSession(
                                    data['testId'] ?? '', 
                                    data['testName'] ?? ''
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5A5F), 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                                  padding: const EdgeInsets.symmetric(vertical: 10)
                                ),
                                child: const Text("Beraber Çözün", style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}