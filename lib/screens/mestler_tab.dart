import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'play_mest_screen.dart';
import 'create_test_screen.dart';
import 'category_tests_screen.dart';
import 'popular_mests_screen.dart';
import 'events_screen.dart';
import 'matches_screen.dart';

class MestlerTab extends StatefulWidget {
  const MestlerTab({super.key});

  @override
  State<MestlerTab> createState() => _MestlerTabState();
}

class _MestlerTabState extends State<MestlerTab> {
  final TextEditingController _searchController = TextEditingController();
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mestler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ ARAMA ÇUBUĞU ============
            _buildSearchBar(),

            const SizedBox(height: 20),

            // ============ YENİ EŞLEŞMELER ============
            _buildNewMatches(),

            const SizedBox(height: 25),

            // ============ MENÜ KARTLARI ============
            _buildMenuCards(),

            const SizedBox(height: 25),

            // ============ TOPLULUK ETKİNLİKLERİ ============
            _buildCommunityEvents(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ============ ARAMA ÇUBUĞU ============
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Mest Ara",
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
            suffixIcon: Icon(Icons.search, color: Colors.grey[600]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ============ YENİ EŞLEŞMELER ============
  Widget _buildNewMatches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Yeni Eşleşmeler",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchesScreen()));
                },
                child: const Text(
                  "Hepsini gör",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isNotEqualTo: currentUserId)
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
              }

              var users = snapshot.data!.docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var user = users[index].data() as Map<String, dynamic>;
                  String name = user['name'] ?? 'Kullanıcı';
                  String? photoUrl = user['photoUrl'];
                  bool isOnline = user['isOnline'] ?? false;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Stack(
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(photoUrl, fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0xFF2C2C2E),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                                        style: const TextStyle(color: Colors.white, fontSize: 20),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ============ MENÜ KARTLARI ============
  Widget _buildMenuCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Üst sıra
          Row(
            children: [
              // Senin için öneriler
              Expanded(
                child: _buildMenuCard(
                  title: "Senin için\nönerilenler",
                  icon: Icons.recommend,
                  height: 180,
                  onTap: () => _navigateToRecommendations(),
                ),
              ),
              const SizedBox(width: 12),
              // Sağ sütun
              Expanded(
                child: Column(
                  children: [
                    _buildMenuCard(
                      title: "Mest\nKategorileri",
                      icon: Icons.category,
                      height: 84,
                      onTap: () => _navigateToCategories(),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      title: "Mest Oluştur",
                      icon: Icons.add_circle_outline,
                      height: 84,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateTestScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Alt sıra
          Row(
            children: [
              Expanded(
                child: _buildMenuCard(
                  title: "Eşleşmelerin",
                  icon: Icons.favorite,
                  height: 100,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MatchesScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMenuCard(
                  title: "Popüler\nMestler",
                  icon: Icons.trending_up,
                  height: 100,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PopularMestsScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Topluluk Etkinlikleri - Tam genişlik
          _buildMenuCard(
            title: "Topluluk Etkinlikleri",
            icon: Icons.event,
            height: 100,
            fullWidth: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EventsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required double height,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.4)),
        ),
        child: Stack(
          children: [
            // Arka plan illüstrasyon
            Positioned(
              right: 10,
              bottom: 10,
              child: Icon(
                icon,
                size: height * 0.4,
                color: const Color(0xFFFF5A5F).withOpacity(0.15),
              ),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TOPLULUK ETKİNLİKLERİ ============
  Widget _buildCommunityEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Topluluk Etkinlikleri",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            // Örnek etkinlikler
            List<Map<String, dynamic>> events = [
              {
                'title': 'Kimin Türkiye\'de Konser Vermesini İstersin?',
                'participants': 156,
              },
              {
                'title': 'En İyi Netflix Dizisi',
                'participants': 89,
              },
            ];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              events = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: events.map((event) => _buildEventListItem(event)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventListItem(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event['title'] ?? 'Etkinlik',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A5F),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Katıl",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRecommendations() {
    // Öneriler sayfasına git
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecommendedMestsScreen()),
    );
  }

  void _navigateToCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MestCategoriesScreen()),
    );
  }
}

// ============ KATEGORİLER SAYFASI ============
class MestCategoriesScreen extends StatelessWidget {
  const MestCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {'name': 'Yemek\nİçecek', 'icon': Icons.restaurant, 'color': Colors.orange},
      {'name': 'Spor', 'icon': Icons.sports_soccer, 'color': Colors.green},
      {'name': 'Müzik', 'icon': Icons.music_note, 'color': Colors.purple},
      {'name': 'Eğlence', 'icon': Icons.celebration, 'color': Colors.pink},
      {'name': 'Film\nDizi', 'icon': Icons.movie, 'color': Colors.red},
      {'name': 'Oyun', 'icon': Icons.gamepad, 'color': Colors.blue},
      {'name': 'Moda', 'icon': Icons.checkroom, 'color': Colors.teal},
      {'name': 'Sosyal\nMedya', 'icon': Icons.share, 'color': Colors.indigo},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mest Kategorileri",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.help_outline, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            var category = categories[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryTestsScreen(
                      categoryName: category['name'].toString().replaceAll('\n', ' '),
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.4)),
                ),
                child: Stack(
                  children: [
                    // Arka plan ikon
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Icon(
                        category['icon'],
                        size: 60,
                        color: (category['color'] as Color).withOpacity(0.15),
                      ),
                    ),
                    // Başlık
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        category['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============ ÖNERİLEN MESTLER SAYFASI ============
class RecommendedMestsScreen extends StatelessWidget {
  const RecommendedMestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Mestler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "Mest'e Devam Et",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Kaydettiğin yarıda kalan Mestlerine dilediğin zaman devam edip, bitirebilirsin!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('testler')
                  .where('aktif_mi', isEqualTo: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                }

                var tests = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    var test = tests[index].data() as Map<String, dynamic>;
                    String testId = tests[index].id;
                    String baslik = test['baslik'] ?? 'Test';
                    String? kapakResmi = test['kapakResmi'];

                    if (kapakResmi == null || kapakResmi.isEmpty) {
                      List secenekler = test['secenekler'] ?? [];
                      if (secenekler.isNotEmpty) {
                        kapakResmi = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'];
                      }
                    }

                    return Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: kapakResmi != null
                            ? DecorationImage(
                                image: NetworkImage(kapakResmi),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.5),
                                  BlendMode.darken,
                                ),
                              )
                            : null,
                        color: kapakResmi == null ? const Color(0xFF1C1C1E) : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  baslik,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId)),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5A5F),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    "Çöz",
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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