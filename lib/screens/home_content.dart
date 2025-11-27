import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_test_screen.dart';
import 'play_mest_screen.dart';
import 'leaderboard_screen.dart';
import 'chat_screen.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String _aramaMetni = "";
  final String myId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. APP BAR
              _buildAppBar(),

              const SizedBox(height: 16),

              // 2. ARAMA ÇUBUĞU
              _buildSearchBar(),

              const SizedBox(height: 24),

              // 3. YENİ EŞLEŞMELER (Story tarzı)
              _buildSectionHeader("Yeni Eşleşmeler", "Hepsini gör", () {}),
              const SizedBox(height: 12),
              _buildNewMatchesRow(),

              const SizedBox(height: 24),

              // 4. POPÜLER MESTLER (Yatay kaydırmalı)
              _buildSectionHeader("Popüler Mestler", "Hepsini gör", () {}),
              const SizedBox(height: 12),
              _buildPopularMestsRow(),

              const SizedBox(height: 24),

              // 5. YAKLAŞAN ETKİNLİKLER
              _buildSectionHeader("Yaklaşan Etkinlikler", "Hepsini Gör", () {}),
              const SizedBox(height: 12),
              _buildEventsRow(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== APP BAR ====================
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "mes",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.5,
                      ),
                    ),
                    TextSpan(
                      text: "t",
                      style: TextStyle(
                        color: Color(0xFFFF5A5F),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(-2, -6),
                child: const Icon(Icons.check, color: Color(0xFFFF5A5F), size: 18),
              ),
            ],
          ),

          // Sağ ikonlar
          Row(
            children: [
              _buildAppBarIcon(Icons.notifications_none_outlined, () {}),
              const SizedBox(width: 8),
              _buildAppBarIcon(Icons.help_outline, () {}),
              const SizedBox(width: 8),
              _buildAppBarIcon(Icons.logout_outlined, () {
                FirebaseAuth.instance.signOut();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ==================== ARAMA ÇUBUĞU ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          onChanged: (val) => setState(() => _aramaMetni = val.toLowerCase()),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: "Ara",
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            suffixIcon: Icon(Icons.search, color: Colors.grey, size: 22),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ==================== SECTION HEADER ====================
  Widget _buildSectionHeader(String title, String actionText, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== YENİ EŞLEŞMELER (Story Row) ====================
  Widget _buildNewMatchesRow() {
    return SizedBox(
      height: 90,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: myId)
            .orderBy('lastMessageTime', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, chatSnapshot) {
          if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text("Henüz eşleşme yok.", style: TextStyle(color: Colors.grey)),
            );
          }

          var chats = chatSnapshot.data!.docs;

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
                  if (!userSnapshot.hasData) return _buildStoryPlaceholder();
                  
                  var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return _buildStoryPlaceholder();

                  String name = userData['username'] ?? userData['name'] ?? "User";
                  String? photoUrl = userData['photoUrl'];
                  bool isOnline = userData['isOnline'] ?? false;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatDoc.id,
                            otherUserId: otherUserId,
                            otherUserName: name,
                          ),
                        ),
                      );
                    },
                    child: _buildStoryItem(name, photoUrl, isOnline),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoryItem(String name, String? photoUrl, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              // Profil resmi
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade800, width: 2),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                ),
              ),
              // Online göstergesi
              if (isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name.split(' ')[0].length > 8 ? "${name.split(' ')[0].substring(0, 8)}..." : name.split(' ')[0],
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
    );
  }

  // ==================== POPÜLER MESTLER (Yatay Liste) ====================
  Widget _buildPopularMestsRow() {
    return SizedBox(
      height: 180,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('testler')
            .where('aktif_mi', isEqualTo: true)
            .orderBy('playCount', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }

          var documents = snapshot.data!.docs;

          if (documents.isEmpty) {
            return const Center(child: Text("Test bulunamadı.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              var doc = documents[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildPopularMestCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularMestCard(String id, Map<String, dynamic> data) {
    String title = data['baslik'] ?? "Başlıksız";
    String imageUrl = data['kapakResmi'] ?? '';
    bool isVerified = (data['playCount'] ?? 0) > 50;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayMestScreen(testId: id)),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: imageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
              : null,
          color: imageUrl.isEmpty ? Colors.grey[800] : null,
        ),
        child: Stack(
          children: [
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            // İçerik
            Positioned(
              bottom: 12,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, color: Colors.blue, size: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== YAKLAŞAN ETKİNLİKLER ====================
  Widget _buildEventsRow() {
    return SizedBox(
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('testler')
            .where('isEvent', isEqualTo: true)
            .where('eventDate', isGreaterThan: Timestamp.now())
            .orderBy('eventDate')
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Etkinlikler yüklenemedi", style: TextStyle(color: Colors.red)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text("Şu an planlanmış bir etkinlik yok.", style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          var events = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              var doc = events[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildEventCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(String id, Map<String, dynamic> data) {
    // Tarih formatlama
    String dateStr = "Tarih Belirtilmemiş";
    if (data['eventDate'] != null) {
      DateTime date = (data['eventDate'] as Timestamp).toDate();
      List<String> aylar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
      dateStr = "${date.day} ${aylar[date.month - 1]}, ${date.year}";
    }

    String title = data['baslik'] ?? "Etkinlik";
    String imageUrl = data['kapakResmi'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayMestScreen(testId: id)),
      ),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1C1C1E),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - Görsel
            Expanded(
              child: Stack(
                children: [
                  // Arka plan resmi
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      image: imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: imageUrl.isEmpty ? Colors.grey[800] : null,
                    ),
                  ),
                  // Gradient
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF1C1C1E),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Alt kısım - Bilgiler
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Başlık
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFFF5A5F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Açıklama
                  const Text(
                    "Sen de etkinliğe katıl ve Mest'i çözen, topluluktaki diğer insanlarla eşleş!",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Alt satır - Avatarlar ve Katıl butonu
                  Row(
                    children: [
                      // Avatar stack
                      SizedBox(
                        width: 80,
                        height: 28,
                        child: Stack(
                          children: List.generate(4, (i) {
                            if (i == 3) {
                              return Positioned(
                                left: i * 18.0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2E),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF1C1C1E), width: 2),
                                  ),
                                  child: const Icon(Icons.more_horiz, size: 14, color: Colors.white),
                                ),
                              );
                            }
                            return Positioned(
                              left: i * 18.0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF1C1C1E), width: 2),
                                ),
                                child: const Icon(Icons.person, size: 14, color: Colors.white),
                              ),
                            );
                          }),
                        ),
                      ),
                      const Spacer(),
                      // Katıl butonu
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Katıl",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}