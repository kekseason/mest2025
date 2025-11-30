import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Projenin dosya yapısına göre bu importlar gereklidir
import 'play_mest_screen.dart';
import 'category_tests_screen.dart';
import 'popular_mests_screen.dart';
import 'events_screen.dart';
import 'matches_screen.dart';
import 'user_create_test_screen.dart';

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

  // --- YENİ: ÇIKIŞ YAPMA FONKSİYONU (Eski kodundan korundu) ---
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)),
        content: const Text("Hesabından çıkış yapmak istediğine emin misin?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Burada WelcomeScreen'e yönlendirme kodu olmalı
              // Navigator.pushAndRemoveUntil...
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A5F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: const Text(
          "Mestler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
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

            // ============ MENÜ KARTLARI (YENİ TASARIM) ============
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

              if (users.isEmpty) {
                 return const Padding(
                   padding: EdgeInsets.only(left: 20.0),
                   child: Text("Henüz eşleşme yok", style: TextStyle(color: Colors.grey)),
                 );
              }

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
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isOnline ? Colors.green : Colors.transparent,
                                  width: 2,
                                ),
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
                        const SizedBox(height: 4),
                        // İsim isteğe bağlı eklenebilir
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

  // ============ MENÜ KARTLARI (YENİ TASARIM) ============
  Widget _buildMenuCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 1. Satır: Sol Büyük + Sağ İkili
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SOL: Senin İçin Önerilenler (Büyük Dikey Kart)
              Expanded(
                child: _buildBigVerticalCard(
                  title: "Senin için\nönerilenler",
                  icon: Icons.thumb_up_alt_outlined,
                  color: const Color(0xFF1C1C1E),
                  onTap: () => _navigateToRecommendations(),
                ),
              ),
              const SizedBox(width: 12),
              // SAĞ: Kategoriler ve Oluştur (Alt alta)
              Expanded(
                child: Column(
                  children: [
                    _buildSmallHorizontalCard(
                      title: "Mest\nKategorileri",
                      icon: Icons.category_outlined,
                      color: const Color(0xFF1C1C1E),
                      height: 104,
                      onTap: () => _navigateToCategories(),
                    ),
                    const SizedBox(height: 12),
                    _buildSmallHorizontalCard(
                      title: "Mest\nOluştur",
                      icon: Icons.add_circle_outline,
                      color: const Color(0xFF1C1C1E),
                      height: 104,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserCreateTestScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // 2. Satır: Eşleşmeler ve Popüler (Orta Boy Yan Yana)
          Row(
            children: [
              Expanded(
                child: _buildMediumCard(
                  title: "Eşleşmelerin",
                  icon: Icons.people_outline,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MatchesScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediumCard(
                  title: "Popüler\nMestler",
                  icon: Icons.trending_up,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PopularMestsScreen()),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Satır: Topluluk Etkinlikleri (Geniş Kart)
          _buildWideCard(
            title: "Topluluk Etkinlikleri",
            icon: Icons.event,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EventsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // --- YENİ KART WIDGETLARI ---

  Widget _buildBigVerticalCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 15,
              right: 15,
              child: Icon(icon, size: 80, color: const Color(0xFFFF5A5F).withOpacity(0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
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

  Widget _buildSmallHorizontalCard({
    required String title,
    required IconData icon,
    required Color color,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: -5,
              right: -5,
              child: Icon(icon, size: 60, color: const Color(0xFFFF5A5F).withOpacity(0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              right: 10,
              child: Icon(icon, size: 40, color: const Color(0xFFFF5A5F).withOpacity(0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 40, color: const Color(0xFFFF5A5F).withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }


  // ============ TOPLULUK ETKİNLİKLERİ (LİSTE KISMI) ============
  Widget _buildCommunityEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Aktif Etkinlikler", 
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
            List<Map<String, dynamic>> events = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              events = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
            } else {
               // Veri yoksa dummy data (boş görünmemesi için)
               events = [
                 {'title': 'Kimin Türkiye\'de Konser Vermesini İstersin?', 'participants': 150},
                 {'title': 'En İyi Netflix Dizisi Hangisi?', 'participants': 90},
               ];
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
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen()));
            },
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

// ============ KATEGORİLER SAYFASI (Eski koddan korundu) ============
class MestCategoriesScreen extends StatelessWidget {
  const MestCategoriesScreen({super.key});

  // Admin Paneliyle ve Veritabanıyla Uyumlu Kategori ID Çevirici
  String _getCategoryId(String name) {
    String cleanName = name.replaceAll('\n', ' ').trim();
    
    Map<String, String> categoryMap = {
      // Ana Kategoriler (Admin Paneliyle Aynı)
      'Yemek & İçecek': 'yemek_icecek',
      'Spor': 'spor',
      'Sinema & Dizi': 'sinema_dizi',
      'Müzik': 'muzik',
      'Oyun': 'oyun',
      'Fenomenler': 'fenomenler',
      'Teknoloji': 'teknoloji',
      'Markalar': 'markalar',
      'Genel': 'genel',
      'Diğer': 'diger',
      
      // Eski/Alternatif Yazımlar (Hata önlemek için)
      'Yemek İçecek': 'yemek_icecek',
      'Yemek': 'yemek_icecek',
      'Film Dizi': 'sinema_dizi',
      'Film': 'sinema_dizi',
      'Moda': 'moda',
      'Eğlence': 'eglence',
      'Sosyal Medya': 'sosyal_medya',
    };
    
    return categoryMap[cleanName] ?? cleanName.toLowerCase().replaceAll(' & ', '_').replaceAll(' ', '_');
  }

  @override
  Widget build(BuildContext context) {
    // GÜNCELLENMİŞ KATEGORİ LİSTESİ (Admin Paneliyle Birebir Aynı)
    final List<Map<String, dynamic>> categories = [
      {'name': 'Yemek & İçecek', 'icon': Icons.restaurant, 'color': Colors.orange},
      {'name': 'Spor', 'icon': Icons.sports_soccer, 'color': Colors.green},
      {'name': 'Sinema & Dizi', 'icon': Icons.movie, 'color': Colors.red},
      {'name': 'Müzik', 'icon': Icons.music_note, 'color': Colors.purple},
      {'name': 'Oyun', 'icon': Icons.gamepad, 'color': Colors.blue},
      {'name': 'Fenomenler', 'icon': Icons.star, 'color': Colors.pink},
      {'name': 'Teknoloji', 'icon': Icons.computer, 'color': Colors.teal},
      {'name': 'Markalar', 'icon': Icons.shopping_bag, 'color': Colors.amber},
      {'name': 'Genel', 'icon': Icons.public, 'color': Colors.indigo},
      {'name': 'Diğer', 'icon': Icons.category, 'color': Colors.grey},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          // Siyah ekran sorunu için root'a dönüyoruz
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: const Text(
          "Mest Kategorileri",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0, // Kare görünüm
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            var category = categories[index];
            String categoryId = _getCategoryId(category['name']);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryTestsScreen(
                      categoryName: category['name'],
                    ),
                  ),
                );
              },
              // 🔥 DİNAMİK KOLAJ SORGUSU 🔥
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('testler')
                    .where('aktif_mi', isEqualTo: true)
                    .where('kategori', isEqualTo: categoryId)
                    .limit(4) // Kolaj için 4 resim
                    .get(),
                builder: (context, snapshot) {
                  List<String> imageUrls = [];
                  
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      String? img = data['kapakResmi'];
                      if ((img == null || img.isEmpty) && 
                          data['secenekler'] != null && 
                          (data['secenekler'] as List).isNotEmpty) {
                         img = data['secenekler'][0]['resimUrl'];
                      }
                      if (img != null && img.isNotEmpty) {
                        imageUrls.add(img);
                      }
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          // 1. Katman: Kolaj (Varsa)
                          if (imageUrls.isNotEmpty)
                            Positioned.fill(
                              child: _buildCollage(imageUrls),
                            ),

                          // 2. Katman: Karartma
                          if (imageUrls.isNotEmpty)
                            Positioned.fill(
                              child: Container(color: Colors.black.withOpacity(0.6)),
                            ),
                          
                          // 3. Katman: İkon (Resim yoksa sağ altta)
                          if (imageUrls.isEmpty)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Icon(
                                category['icon'],
                                size: 70,
                                color: (category['color'] as Color).withOpacity(0.15),
                              ),
                            ),
                          
                          // 4. Katman: Başlık (Sol üstte)
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Text(
                              category['name'],
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black)
                                ]
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // --- KOLAJ WIDGET ---
  Widget _buildCollage(List<String> images) {
    int count = images.length;

    if (count == 0) return const SizedBox();

    if (count == 1) {
      return Image.network(images[0], fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (count == 2) {
      return Row(
        children: [
          Expanded(child: Image.network(images[0], fit: BoxFit.cover, height: double.infinity)),
          const SizedBox(width: 1),
          Expanded(child: Image.network(images[1], fit: BoxFit.cover, height: double.infinity)),
        ],
      );
    } else if (count == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: Image.network(images[0], fit: BoxFit.cover, height: double.infinity)),
          const SizedBox(width: 1),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: Image.network(images[1], fit: BoxFit.cover, width: double.infinity)),
                const SizedBox(height: 1),
                Expanded(child: Image.network(images[2], fit: BoxFit.cover, width: double.infinity)),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Image.network(images[0], fit: BoxFit.cover, height: double.infinity)),
                const SizedBox(width: 1),
                Expanded(child: Image.network(images[1], fit: BoxFit.cover, height: double.infinity)),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Image.network(images[2], fit: BoxFit.cover, height: double.infinity)),
                const SizedBox(width: 1),
                Expanded(child: Image.network(images[3], fit: BoxFit.cover, height: double.infinity)),
              ],
            ),
          ),
        ],
      );
    }
  }
}

// ============ KATEGORİ DETAY EKRANI (AYNEN KORUNDU) ============
class CategoryTestsScreen extends StatelessWidget {
  final String categoryName;

  const CategoryTestsScreen({
    super.key,
    required this.categoryName,
  });

  String _getCategoryId(String name) {
    String cleanName = name.replaceAll('\n', ' ').trim();
    Map<String, String> categoryMap = {
      'Yemek & İçecek': 'yemek_icecek',
      'Yemek İçecek': 'yemek_icecek',
      'Spor': 'spor',
      'Sinema & Dizi': 'sinema_dizi',
      'Film Dizi': 'sinema_dizi',
      'Müzik': 'muzik',
      'Oyun': 'oyun',
      'Fenomenler': 'fenomenler',
      'Teknoloji': 'teknoloji',
      'Markalar': 'markalar',
      'Genel': 'genel',
      'Moda': 'moda',
      'Diğer': 'diger',
      'Sosyal Medya': 'sosyal_medya',
      'Eğlence': 'eglence',
    };
    return categoryMap[cleanName] ?? cleanName.toLowerCase().replaceAll(' & ', '_').replaceAll(' ', '_');
  }

  @override
  Widget build(BuildContext context) {
    final String categoryId = _getCategoryId(categoryName);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          categoryName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          
          // --- KATEGORİ BAŞLIĞI VE DİNAMİK KAPAK (LİSTE İÇİNDEKİ BAŞLIK) ---
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('testler')
                .where('aktif_mi', isEqualTo: true)
                .where('kategori', isEqualTo: categoryId)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get(),
            builder: (context, snapshot) {
              String? headerImage;
              
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                headerImage = data['kapakResmi'];
                if ((headerImage == null || headerImage.isEmpty) && 
                    data['secenekler'] != null && 
                    (data['secenekler'] as List).isNotEmpty) {
                   headerImage = data['secenekler'][0]['resimUrl'];
                }
              }

              return Container(
                width: double.infinity,
                height: 150,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF1C1C1E),
                  image: headerImage != null 
                      ? DecorationImage(
                          image: NetworkImage(headerImage),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.6), 
                            BlendMode.darken
                          )
                        ) 
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black)]
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "$categoryName kategorisindeki Mestlerden istediğini çözebilirsin!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70, 
                          fontSize: 13,
                          shadows: [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black)]
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 25),

          // --- TEST LİSTESİ (StreamBuilder) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('testler')
                  .where('aktif_mi', isEqualTo: true)
                  .where('kategori', isEqualTo: categoryId)
                  .orderBy('createdAt', descending: true) 
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

                var tests = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    var test = tests[index].data() as Map<String, dynamic>;
                    String testId = tests[index].id;
                    
                    return _buildTestCard(context, testId, test);
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
              Icons.category_outlined,
              size: 50,
              color: Color(0xFFFF5A5F),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Bu kategoride henüz test yok",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "İlk testi sen oluştur!",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, String testId, Map<String, dynamic> test) {
    String baslik = test['baslik'] ?? 'Test';
    String? kapakResmi = test['kapakResmi'];
    
    if (kapakResmi == null || kapakResmi.isEmpty) {
      List secenekler = test['secenekler'] ?? [];
      if (secenekler.isNotEmpty) {
        kapakResmi = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'];
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId)),
        );
      },
      child: Container(
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
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
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
      ),
    );
  }
}

// ============ ÖNERİLEN MESTLER SAYFASI (Eski koddan korundu) ============
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

                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId))),
                      child: Container(
                        height: 100,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(kapakResmi ?? ''),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.5),
                              BlendMode.darken,
                            ),
                            onError: (exception, stackTrace) {}, 
                          ),
                          color: const Color(0xFF1C1C1E),
                        ),
                        child: Center(
                          child: Text(
                            baslik,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
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

// ============ DİĞER EKRANLAR (Bildirimler, Yardım) ============
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Bildirimler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const Center(child: Text("Henüz bildiriminiz yok", style: TextStyle(color: Colors.grey))),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Yardım & Destek", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("Yardım merkezi yakında aktif olacak.", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}