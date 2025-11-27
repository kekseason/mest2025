import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';

// ============ EŞLEŞMELERİM SAYFASI ============
class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Eşleşmelerim",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('users', arrayContains: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }

          // Eşleşme yoksa
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          var matches = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              var match = matches[index].data() as Map<String, dynamic>;
              List<dynamic> users = match['users'] ?? [];
              String otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => '');

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox.shrink();

                  String name = userData['name'] ?? 'Kullanıcı';
                  String? photoUrl = userData['photoUrl'];
                  int uyum = match['compatibility'] ?? 0;
                  bool isOnline = userData['isOnline'] ?? false;

                  return _buildMatchCard(
                    context: context,
                    matchId: matches[index].id,
                    otherUserId: otherUserId,
                    name: name,
                    photoUrl: photoUrl,
                    uyum: uyum,
                    isOnline: isOnline,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 60,
              color: Color(0xFFFF5A5F),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "Henüz eşleşme yok",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Mestleri çözerek seninle aynı zevklere sahip insanlarla eşleş!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard({
    required BuildContext context,
    required String matchId,
    required String otherUserId,
    required String name,
    String? photoUrl,
    required int uyum,
    required bool isOnline,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))
                  : null,
            ),
            if (isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1C1C1E), width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFFF5A5F), size: 14),
            const SizedBox(width: 4),
            Text(
              "%$uyum Uyumlu",
              style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mesaj butonu
            IconButton(
              onPressed: () {
                // Chat'e git
                _openChat(context, otherUserId, name);
              },
              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF5A5F)),
            ),
            // Profil butonu
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: otherUserId, userName: name),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, String otherUserId, String otherUserName) async {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Mevcut chat'i bul veya oluştur
    String chatId = currentUserId.compareTo(otherUserId) < 0
        ? '${currentUserId}_$otherUserId'
        : '${otherUserId}_$currentUserId';

    DocumentSnapshot chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'users': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
          ),
        ),
      );
    }
  }
}

// ============ IT'S A MATCH POPUP ============
class MatchPopup extends StatelessWidget {
  final String myPhotoUrl;
  final String otherPhotoUrl;
  final String otherUserName;
  final String otherUserId;
  final int compatibility;

  const MatchPopup({
    super.key,
    required this.myPhotoUrl,
    required this.otherPhotoUrl,
    required this.otherUserName,
    required this.otherUserId,
    this.compatibility = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D11),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFF5A5F), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5A5F).withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            const Text(
              "Yeni Bir Eşleşmen Var!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Heyecan verici yeni bir arkadaşlık!",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),

            const SizedBox(height: 35),

            // Profil fotoğrafları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Benim fotoğrafım
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF5A5F), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5A5F).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: myPhotoUrl.isNotEmpty
                        ? Image.network(myPhotoUrl, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(Icons.person, color: Colors.grey, size: 40),
                          ),
                  ),
                ),

                // Örtüşme efekti için negatif margin
                Transform.translate(
                  offset: const Offset(-20, 0),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF5A5F), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5A5F).withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: otherPhotoUrl.isNotEmpty
                          ? Image.network(otherPhotoUrl, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFF1C1C1E),
                              child: const Icon(Icons.person, color: Colors.grey, size: 40),
                            ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Uyum yüzdesi
            if (compatibility > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "%$compatibility Uyumlu",
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 30),

            // Mesaj Gönder butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openChat(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A5F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFFF5A5F).withOpacity(0.5),
                ),
                child: const Text(
                  "Mesaj Gönder",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Profilini Görüntüle butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: otherUserId,
                        userName: otherUserName,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF5A5F)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Profilini Görüntüle",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Geri Dön butonu
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Geri Dön",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context) async {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    String chatId = currentUserId.compareTo(otherUserId) < 0
        ? '${currentUserId}_$otherUserId'
        : '${otherUserId}_$currentUserId';

    DocumentSnapshot chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'users': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
          ),
        ),
      );
    }
  }
}

// ============ MATCH POPUP'I GÖSTERME FONKSİYONU ============
void showMatchPopup({
  required BuildContext context,
  required String myPhotoUrl,
  required String otherPhotoUrl,
  required String otherUserName,
  required String otherUserId,
  int compatibility = 0,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => MatchPopup(
      myPhotoUrl: myPhotoUrl,
      otherPhotoUrl: otherPhotoUrl,
      otherUserName: otherUserName,
      otherUserId: otherUserId,
      compatibility: compatibility,
    ),
  );
}