import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'main_navigation.dart';
import 'play_mest_screen.dart';
import 'user_profile_screen.dart';
import 'daily_challenges_screen.dart';
import 'share_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          int currentStreak = data['currentStreak'] ?? 0;
          int totalXP = data['totalXP'] ?? 0;

          // Yaş hesaplama
          String age = "";
          if (data['birthDate'] != null) {
            DateTime birth = (data['birthDate'] as Timestamp).toDate();
            int ageVal = DateTime.now().year - birth.year;
            age = "$ageVal";
          }

          String unvan = _getTitle(testCount);
          int level = (totalXP / 500).floor() + 1;

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
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
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
                  // Günlük Görevler
                  IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange),
                        if (currentStreak > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                "$currentStreak",
                                style: const TextStyle(color: Colors.white, fontSize: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DailyChallengesScreen()),
                    ),
                  ),
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
                        // Seviye rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                          ),
                          child: Text(
                            "Lv.$level",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A5F).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        unvan,
                        style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============ İSTATİSTİKLER ============
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem("Test", "$testCount", Icons.quiz),
                          _buildDivider(),
                          _buildStatItem("Eşleşme", "$matchCount", Icons.favorite),
                          _buildDivider(),
                          _buildStatItem("Streak", "$currentStreak 🔥", Icons.local_fire_department),
                          _buildDivider(),
                          _buildStatItem("XP", "$totalXP", Icons.star),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============ DÜZENLE VE PAYLAŞ BUTONLARI ============
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C1C1E),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                              label: const Text("Düzenle", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A5F),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.share, color: Colors.white, size: 18),
                              label: const Text("Davet Et", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ============ TAB BAR ============
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: const Color(0xFFFF5A5F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        tabs: const [
                          Tab(text: "Favoriler"),
                          Tab(text: "Geçmiş"),
                          Tab(text: "Rozetler"),
                        ],
                      ),
                    ),

                    // ============ TAB İÇERİĞİ ============
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Favoriler Tab
                          _buildFavoritesTab(),
                          // Geçmiş Tab
                          _buildHistoryTab(),
                          // Rozetler Tab
                          _buildBadgesTab(badges),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============ UYUM GRAFİĞİ ============
                    _buildCompatibilitySection(),

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

  Widget _buildDivider() {
    return Container(width: 1, height: 35, color: Colors.white12);
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
        Icon(icon, color: const Color(0xFFFF5A5F), size: 22),
        const SizedBox(height: 6),
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  // ============ FAVORİLER TAB ============
  Widget _buildFavoritesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('tarih', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        // Kazananları grupla ve say
        Map<String, Map<String, dynamic>> favorites = {};
        
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String kazanan = data['kazananIsim'] ?? '';
          String? resim = data['kazananResim'];
          
          if (kazanan.isNotEmpty) {
            if (favorites.containsKey(kazanan)) {
              favorites[kazanan]!['count']++;
            } else {
              favorites[kazanan] = {
                'isim': kazanan,
                'resim': resim,
                'count': 1,
              };
            }
          }
        }

        // Sırala
        List<Map<String, dynamic>> sortedFavorites = favorites.values.toList();
        sortedFavorites.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

        if (sortedFavorites.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border,
            title: "Henüz favori yok",
            subtitle: "Test çözerek favorilerini oluştur!",
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: sortedFavorites.length > 9 ? 9 : sortedFavorites.length,
          itemBuilder: (context, index) {
            var fav = sortedFavorites[index];
            return _buildFavoriteCard(fav, index);
          },
        );
      },
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> fav, int index) {
    Color borderColor = index == 0 ? Colors.amber : (index == 1 ? Colors.grey : (index == 2 ? Colors.orange : Colors.transparent));
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: borderColor != Colors.transparent 
            ? Border.all(color: borderColor, width: 2) 
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sıralama
          if (index < 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                index == 0 ? "👑" : (index == 1 ? "🥈" : "🥉"),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          const SizedBox(height: 8),
          
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: fav['resim'] != null
                ? Image.network(
                    fav['resim'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[800],
                      child: const Icon(Icons.image, color: Colors.grey, size: 24),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[800],
                    child: const Icon(Icons.star, color: Colors.grey, size: 24),
                  ),
          ),
          const SizedBox(height: 8),
          
          // İsim
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              fav['isim'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 4),
          
          // Sayı
          Text(
            "${fav['count']}x seçildi",
            style: const TextStyle(color: Colors.grey, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ============ GEÇMİŞ TAB ============
  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('tarih', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: "Geçmiş boş",
            subtitle: "Çözdüğün testler burada görünecek",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildHistoryCard(data);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    String kazanan = data['kazananIsim'] ?? 'Bilinmiyor';
    String? resim = data['kazananResim'];
    String? testId = data['testId'];
    DateTime? tarih = data['tarih'] != null ? (data['tarih'] as Timestamp).toDate() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: resim != null
                ? Image.network(
                    resim,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[800],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[800],
                    child: const Icon(Icons.quiz, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          
          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Kazanan:",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Text(
                  kazanan,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (tarih != null)
                  Text(
                    _formatDate(tarih),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),
          
          // Tekrar oyna
          if (testId != null)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId)),
                );
              },
              icon: const Icon(Icons.replay, color: Color(0xFFFF5A5F)),
            ),
        ],
      ),
    );
  }

  // ============ ROZETLER TAB ============
  Widget _buildBadgesTab(List<dynamic> badges) {
    // Tüm mümkün rozetler
    List<Map<String, dynamic>> allBadges = [
      {'name': 'İlk Adım', 'icon': Icons.looks_one, 'color': Colors.green, 'desc': 'İlk testini çöz'},
      {'name': 'Hızlı Parmak', 'icon': Icons.bolt, 'color': Colors.blue, 'desc': '5 test çöz'},
      {'name': 'Mest Gurmesi', 'icon': Icons.restaurant, 'color': Colors.orange, 'desc': '10 test çöz'},
      {'name': 'Efsane', 'icon': Icons.auto_awesome, 'color': Colors.purple, 'desc': '20 test çöz'},
      {'name': 'Mest Ustası', 'icon': Icons.military_tech, 'color': Colors.amber, 'desc': '50 test çöz'},
      {'name': 'Efsanevi', 'icon': Icons.emoji_events, 'color': Colors.red, 'desc': '100 test çöz'},
      {'name': '7 Gün Streak 🔥', 'icon': Icons.local_fire_department, 'color': Colors.deepOrange, 'desc': '7 gün üst üste gir'},
      {'name': '30 Gün Streak 💎', 'icon': Icons.diamond, 'color': Colors.cyan, 'desc': '30 gün üst üste gir'},
      {'name': '100 Gün Streak 👑', 'icon': Icons.workspace_premium, 'color': Colors.yellow, 'desc': '100 gün üst üste gir'},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: allBadges.length,
      itemBuilder: (context, index) {
        var badge = allBadges[index];
        bool isUnlocked = badges.contains(badge['name']);
        
        return _buildBadgeCard(badge, isUnlocked);
      },
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, bool isUnlocked) {
    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? badge['color'].withOpacity(0.2) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked ? Border.all(color: badge['color'], width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge['icon'],
            color: isUnlocked ? badge['color'] : Colors.grey[700],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            badge['name'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUnlocked ? Colors.white : Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          if (!isUnlocked)
            Icon(Icons.lock, color: Colors.grey[700], size: 14),
        ],
      ),
    );
  }

  // ============ UYUM GRAFİĞİ BÖLÜMÜ ============
  Widget _buildCompatibilitySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people, color: Color(0xFFFF5A5F)),
              SizedBox(width: 10),
              Text(
                "En Uyumlu Eşleşmelerim",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Uyum listesi
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .where('users', arrayContains: user?.uid)
                .orderBy('compatibility', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "Henüz eşleşme yok",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  List<dynamic> users = data['users'] ?? [];
                  String otherUserId = users.firstWhere((id) => id != user?.uid, orElse: () => '');
                  int compatibility = data['compatibility'] ?? 0;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const SizedBox();

                      var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (userData == null) return const SizedBox();

                      return _buildCompatibilityItem(
                        name: userData['name'] ?? 'Kullanıcı',
                        photoUrl: userData['photoUrl'],
                        compatibility: compatibility,
                        userId: otherUserId,
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityItem({
    required String name,
    String? photoUrl,
    required int compatibility,
    required String userId,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId, userName: name),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Fotoğraf
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[800],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            
            // İsim
            Expanded(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            
            // Uyum çubuğu
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "%$compatibility",
                    style: TextStyle(
                      color: _getCompatibilityColor(compatibility),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: compatibility / 100,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(_getCompatibilityColor(compatibility)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCompatibilityColor(int compatibility) {
    if (compatibility >= 80) return Colors.green;
    if (compatibility >= 60) return Colors.lightGreen;
    if (compatibility >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[700], size: 60),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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

  String _formatDate(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} saat önce";
    if (diff.inDays < 7) return "${diff.inDays} gün önce";
    return "${date.day}/${date.month}/${date.year}";
  }
}