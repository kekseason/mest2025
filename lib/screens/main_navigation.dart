import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_content.dart';
import 'chat_screen.dart';
import 'mestler_tab.dart'; // Veya 'mestler_screen.dart' (Dosya adın neyse)
import 'profile_tab.dart';
import '../widgets/active_users_row.dart'; // Story çubuğu için import

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused) {
      _setOnlineStatus(false);
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Online status güncellenemedi: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeContent(),
          ChatsListScreen(),  // Aynı dosyanın altındaki sınıfı çağırıyor
          MestlerTab(),       // MestlerScreen de olabilir, projendeki ada göre
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D11),
          border: Border(
            top: BorderSide(color: Color(0xFF1C1C1E), width: 1),
          ),
        ),
        child: SafeArea(
          child: Container(
            // DÜZELTME 1: Yükseklik 80 yapıldı (Taşmayı önler)
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              // DÜZELTME 2: SpaceBetween ile yayıyoruz
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // DÜZELTME 3: Expanded ile sarmaladık (Eşit alan kaplasınlar)
                Expanded(child: _buildNavItem(0, "Ana Sayfa", Icons.home_outlined)),
                Expanded(child: _buildNavItem(1, "Sohbetler", Icons.chat_bubble_outline)),
                Expanded(child: _buildNavItem(2, "Mestler", null, isCheck: true)),
                Expanded(child: _buildNavItem(3, "Profil", Icons.person_outline, isProfile: true)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData? icon, {bool isCheck = false, bool isProfile = false}) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      // Davranışın tüm alana yayılması için
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            // DÜZELTME 4: Padding azaltıldı
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
               children: [
                 if (isCheck)
                   _buildCheckIcon(isSelected)
                 else if (isProfile)
                   _buildProfileIcon(isSelected)
                 else
                   Icon(
                     icon,
                     color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey[600],
                     size: 24,
                   ),
               ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey[600],
              fontSize: 10, // DÜZELTME 5: Font küçültüldü
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckIcon(bool isSelected) {
    return Icon(
      Icons.check,
      color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey[600],
      size: 24,
    );
  }

  Widget _buildProfileIcon(bool isSelected) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey[600]!,
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.person_outline,
        color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey[600],
        size: 16,
      ),
    );
  }
}

// ============================================================
// BURASI SENİN KODUNDAKİ İKİNCİ PART (CHATS LİSTESİ)
// BU KISIM AYNI DOSYADA KALDI
// ============================================================

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        title: const Text(
          "Sohbetler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, // Geri butonunu kaldırdık (Ana sekme olduğu için)
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.help_outline, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
           // 1. ARAMA ÇUBUĞU
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

          // 2. YENİ EŞLEŞMELER (Story Modülü Entegre Edildi)
          const ActiveUsersRow(),

          const Divider(color: Colors.white10, height: 20),

          // 3. SOHBET LİSTESİ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('users', arrayContains: currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var chats = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    var chat = chats[index].data() as Map<String, dynamic>;
                    String chatId = chats[index].id;
                    List<dynamic> users = chat['users'] ?? [];
                    String otherUserId = users.firstWhere(
                      (id) => id != currentUserId,
                      orElse: () => '',
                    );

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        String name = userData['username'] ?? userData['name'] ?? 'Kullanıcı';
                        String? photoUrl = userData['photoUrl'];
                        bool isOnline = userData['isOnline'] ?? false;
                        String lastMessage = chat['lastMessage'] ?? '';
                        Timestamp? lastTime = chat['lastMessageTime'];

                        return _buildChatItem(
                          context: context,
                          chatId: chatId,
                          otherUserId: otherUserId,
                          name: name,
                          photoUrl: photoUrl,
                          isOnline: isOnline,
                          lastMessage: lastMessage,
                          lastTime: lastTime,
                        );
                      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Color(0xFFFF5A5F),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Henüz sohbet yok",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Eşleşmelerinden biriyle sohbet başlat!",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem({
    required BuildContext context,
    required String chatId,
    required String otherUserId,
    required String name,
    String? photoUrl,
    required bool isOnline,
    required String lastMessage,
    Timestamp? lastTime,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: name,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2C2C2E),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : "?",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
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
            const SizedBox(width: 12),

            // İsim ve son mesaj
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage.isNotEmpty
                        ? (lastMessage.length > 30
                            ? '${lastMessage.substring(0, 30)}...'
                            : lastMessage)
                        : 'Henüz mesaj yok',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Zaman
            if (lastTime != null)
              Text(
                _formatTime(lastTime.toDate()),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    DateTime now = DateTime.now();
    Duration diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';

    return '${date.day}/${date.month}';
  }
}