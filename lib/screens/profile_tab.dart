import 'package:app_1/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'notification_service.dart'; // Eğer bu dosya yoksa hata verebilir, kontrol et
import 'create_test_screen.dart';
import 'main_navigation.dart'; // Ana sayfaya dönmek için gerekli

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text("Profil bulunamadı", style: TextStyle(color: Colors.white)));
          }

          String name = data['name'] ?? "Kullanıcı";
          String city = data['city'] ?? "";
          String? photoUrl = data['photoUrl'];
          String bio = data['bio'] ?? "";
          List<dynamic> photos = data['photos'] ?? [];
          List<dynamic> badges = data['badges'] ?? [];
          List<dynamic> interests = data['interests'] ?? [];
          int testCount = data['testCount'] ?? 0;
          int matchCount = data['matchCount'] ?? 0;

          // Yaş hesaplama
          String age = "";
          if (data['birthDate'] != null) {
            DateTime birth = (data['birthDate'] as Timestamp).toDate();
            int ageVal = DateTime.now().year - birth.year;
            age = "$ageVal";
          }

          // Ünvan
          String unvan = _getTitle(testCount);

          return CustomScrollView(
            slivers: [
              // ============ APP BAR ============
              SliverAppBar(
                backgroundColor: const Color(0xFF0D0D11),
                expandedHeight: 0,
                floating: true,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  onPressed: () {
                    // --- DÜZELTME BURADA ---
                    // Eğer bir alt sayfadaysa geri dön, değilse (Tab ise) Ana Sayfaya git
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      // Ana Navigasyon sayfasına (index 0 ile) yeniden yönlendir
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const MainNavigation()),
                      );
                    }
                  },
                ),
                title: const Text("Profil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                centerTitle: true,
                actions: [
                  // Bildirimler (Senin orijinal kodun)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('receiverId', isEqualTo: user?.uid)
                        .where('read', isEqualTo: false)
                        .snapshots(),
                    builder: (context, notifSnapshot) {
                      int unreadCount = notifSnapshot.data?.docs.length ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: Colors.white),
                            onPressed: () {
                              // Bildirim ekranın varsa buraya bağla
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5A5F),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 9 ? "9+" : unreadCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  // Ayarlar
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
              ),

              // ============ İÇERİK ============
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ============ PROFİL FOTOĞRAFI ============
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF5A5F), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5A5F).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _buildDefaultAvatar(name),
                                  )
                                : _buildDefaultAvatar(name),
                          ),
                        ),
                        // Online göstergesi
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0D0D11), width: 3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // ============ İSİM ============
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        if (data['isVerified'] == true)
                          const Icon(Icons.verified, color: Colors.blue, size: 22),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Yaş ve Şehir
                    if (age.isNotEmpty || city.isNotEmpty)
                      Text(
                        [if (age.isNotEmpty) age, if (city.isNotEmpty) city].join(", "),
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),

                    const SizedBox(height: 5),

                    // Ünvan
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A5F).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        unvan,
                        style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============ BUTONLAR ============
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                              ),
                              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                              label: const Text("Düzenle", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A5F),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateTestScreen()),
                              ),
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: const Text("Test Oluştur", style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ============ İSTATİSTİKLER ============
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem("Testler", testCount.toString(), Icons.quiz_outlined),
                          Container(width: 1, height: 40, color: Colors.white10),
                          _buildStatItem("Rozetler", badges.length.toString(), Icons.emoji_events_outlined),
                          Container(width: 1, height: 40, color: Colors.white10),
                          _buildStatItem("Eşleşmeler", matchCount.toString(), Icons.favorite_outline),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============ HAKKINDA ============
                    if (bio.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_outline, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text("Hakkında", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(bio, style: const TextStyle(color: Colors.grey, height: 1.4)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ============ İLGİ ALANLARI ============
                    if (interests.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.interests, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text("İlgi Alanları", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: interests.map((interest) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5A5F).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
                                ),
                                child: Text(
                                  interest.toString(),
                                  style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ============ ROZETLER ============
                    if (badges.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                                SizedBox(width: 8),
                                Text("Rozetler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: badges.map((badge) => _buildBadgeChip(badge.toString())).toList(),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ============ FOTOĞRAFLAR GALERİSİ ============
                    if (photos.length > 1)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.photo_library, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text("Fotoğraflar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () => _showPhotoViewer(context, photos, index),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        photos[index],
                                        width: 100,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          width: 100,
                                          height: 120,
                                          color: const Color(0xFF1C1C1E),
                                          child: const Icon(Icons.broken_image, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),

                    // ============ MEST+ BANNER ============
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF5A5F).withOpacity(0.8),
                            const Color(0xFFFF8A8E).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Mest+ Premium",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Sınırsız özellikler ve özel rozetler",
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF5A5F), size: 24),
        const SizedBox(height: 8),
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildBadgeChip(String badge) {
    IconData icon;
    Color color;

    if (badge.contains("İlk")) {
      icon = Icons.looks_one;
      color = Colors.green;
    } else if (badge.contains("10") || badge.contains("Mest Aşığı")) {
      icon = Icons.whatshot;
      color = Colors.orange;
    } else if (badge.contains("50") || badge.contains("Ustası")) {
      icon = Icons.military_tech;
      color = Colors.purple;
    } else if (badge.contains("100") || badge.contains("Efsane")) {
      icon = Icons.auto_awesome;
      color = Colors.amber;
    } else {
      icon = Icons.emoji_events;
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(badge, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getTitle(int testCount) {
    if (testCount >= 100) return "Efsanevi Mestçi 👑";
    if (testCount >= 50) return "Mest Ustası 🎯";
    if (testCount >= 20) return "Mest Efsanesi 🏆";
    if (testCount >= 10) return "Mest Gurmesi 🍔";
    if (testCount >= 5) return "Hızlı Parmak ⚡";
    return "Mest Kaşifi 🚀";
  }

  void _showPhotoViewer(BuildContext context, List<dynamic> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(photos: photos.cast<String>(), initialIndex: initialIndex),
      ),
    );
  }
}

// ============ FOTOĞRAF GÖRÜNTÜLEYICI ============
class PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const PhotoViewerScreen({super.key, required this.photos, required this.initialIndex});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${_currentIndex + 1}/${widget.photos.length}",
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.photos[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}