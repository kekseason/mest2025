import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

/// Başka bir kullanıcının profilini görüntülemek için kullanılır
/// (profile_tab.dart kendi profilin için, bu başkalarının profili için)
class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? currentUserId;
  bool isBlocked = false;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }

      // Engel durumunu kontrol et
      if (currentUserId != null) {
        DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();

        if (currentUserDoc.exists) {
          var data = currentUserDoc.data() as Map<String, dynamic>;
          List<dynamic> blockedUsers = data['blockedUsers'] ?? [];
          setState(() {
            isBlocked = blockedUsers.contains(widget.userId);
          });
        }
      }
    } catch (e) {
      debugPrint("Kullanıcı yükleme hatası: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D11),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
        ),
      );
    }

    String name = userData?['name'] ?? widget.userName;
    String? photoUrl = userData?['photoUrl'];
    String? bio = userData?['bio'];
    int age = userData?['age'] ?? 0;
    String city = userData?['city'] ?? '';
    List<dynamic> interests = userData?['interests'] ?? [];
    List<dynamic> photos = userData?['photos'] ?? [];
    bool isOnline = userData?['isOnline'] ?? false;
    int testCount = userData?['testCount'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1C1C1E),
            onSelected: (value) {
              if (value == 'block') _toggleBlock();
              if (value == 'report') _reportUser();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      isBlocked ? Icons.check_circle : Icons.block,
                      color: isBlocked ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isBlocked ? 'Engeli Kaldır' : 'Engelle',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text('Şikayet Et', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ============ PROFİL FOTOĞRAFI ============
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOnline ? Colors.green : const Color(0xFFFF5A5F),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? Image.network(photoUrl, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF1C1C1E),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D0D11), width: 3),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),

            // ============ İSİM VE YAŞ ============
            Text(
              age > 0 ? "$name, $age" : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (city.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Text(city, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ============ İSTATİSTİKLER ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat("Testler", testCount.toString()),
                  Container(width: 1, height: 30, color: Colors.grey[800]),
                  _buildStat("Rozetler", (userData?['badges']?.length ?? 0).toString()),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ============ HAKKINDA ============
            if (bio != null && bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hakkında",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 15),

            // ============ İLGİ ALANLARI ============
            if (interests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "İlgi Alanları",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A5F).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.5)),
                            ),
                            child: Text(
                              interest.toString(),
                              style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 15),

            // ============ FOTOĞRAFLAR ============
            if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Fotoğraflar",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(photos[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 30),

            // ============ BUTONLAR ============
            if (!isBlocked && currentUserId != widget.userId)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A5F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    label: const Text(
                      "Mesaj Gönder",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            if (isBlocked)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: Colors.red),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Bu kullanıcıyı engelledin",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _toggleBlock,
                        child: const Text("Kaldır", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  void _openChat() async {
    if (currentUserId == null) return;

    String chatId = currentUserId!.compareTo(widget.userId) < 0
        ? '${currentUserId}_${widget.userId}'
        : '${widget.userId}_$currentUserId';

    DocumentSnapshot chatDoc =
        await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'users': [currentUserId, widget.userId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: widget.userId,
            otherUserName: widget.userName,
          ),
        ),
      );
    }
  }

  void _toggleBlock() async {
    if (currentUserId == null) return;

    try {
      if (isBlocked) {
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
          'blockedUsers': FieldValue.arrayRemove([widget.userId]),
        });
        setState(() => isBlocked = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Engel kaldırıldı"), backgroundColor: Colors.green),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
          'blockedUsers': FieldValue.arrayUnion([widget.userId]),
        });
        setState(() => isBlocked = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kullanıcı engellendi"), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint("Engelleme hatası: $e");
    }
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Kullanıcıyı Şikayet Et", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption("Uygunsuz içerik"),
            _buildReportOption("Spam"),
            _buildReportOption("Taciz"),
            _buildReportOption("Sahte profil"),
            _buildReportOption("Diğer"),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason, style: const TextStyle(color: Colors.white)),
      onTap: () async {
        Navigator.pop(context);
        try {
          await FirebaseFirestore.instance.collection('reports').add({
            'reporterId': currentUserId,
            'reportedUserId': widget.userId,
            'reportedUserName': widget.userName,
            'reason': reason,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Şikayet gönderildi. İncelenecektir."),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint("Şikayet hatası: $e");
        }
      },
    );
  }
}