import 'package:app_1/screens/help_screen.dart';
import 'package:app_1/screens/events_screen.dart';
import 'package:app_1/screens/matches_screen.dart';
import 'package:app_1/screens/popular_mests_screen.dart';
import 'package:app_1/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'play_mest_screen.dart';
import 'create_test_screen.dart'; // Eğer floating button vs eklemek istersen diye importu tuttum
import 'welcome_screen.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
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

  // --- ÇIKIŞ YAPMA FONKSİYONU ---
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
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============ HEADER ============
              _buildHeader(),

              // ============ ARAMA ÇUBUĞU ============
              _buildSearchBar(),

              const SizedBox(height: 20),

              // ============ YENİ EŞLEŞMELER ============
              _buildNewMatches(),

              const SizedBox(height: 25),

              // ============ POPÜLER MESTLER (LİSTE) ============
              // Aradaki kartlar silindi, doğrudan listeye geçiyoruz.
              _buildPopularMests(),

              const SizedBox(height: 25),

              // ============ YAKLAŞAN ETKİNLİKLER ============
              _buildUpcomingEvents(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============ HEADER ============
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset(
            'assets/mest_logo.png',
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (c,e,s) => const Text("Mest", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),

          // Sağ ikonlar
          Row(
            children: [
              _buildIconButton(Icons.notifications_none, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              }),
              const SizedBox(width: 8),
              _buildIconButton(Icons.help_outline, () {
Navigator.push(
    context, 
    MaterialPageRoute(builder: (_) => const HelpScreen())
  );
}),
              const SizedBox(width: 8),
              _buildIconButton(Icons.logout, () {
                _showLogoutDialog();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
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
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isNotEqualTo: currentUserId)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
              }

              var users = snapshot.data!.docs;

              if (users.isEmpty) {
                return const Center(
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

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            userId: users[index].id,
                            userName: name,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isOnline ? Colors.green : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: photoUrl != null && photoUrl.isNotEmpty
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          width: 60,
                                          height: 60,
                                          errorBuilder: (c, e, s) => _buildDefaultAvatar(name),
                                        )
                                      : _buildDefaultAvatar(name),
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
                          const SizedBox(height: 6),
                          Text(
                            name.split(' ').first,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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

  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFF2C2C2E),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ============ POPÜLER MESTLER (YATAY LİSTE) ============
  Widget _buildPopularMests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Popüler Mestler",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PopularMestsScreen()));
                },
                child: const Text(
                  "Hepsini gör",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
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

              var tests = snapshot.data!.docs;

              if (tests.isEmpty) {
                return const Center(
                  child: Text("Henüz test yok", style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId)),
                      );
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF1C1C1E),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Resim
                            if (kapakResmi != null)
                              Image.network(
                                kapakResmi,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: const Icon(Icons.image, color: Colors.grey, size: 40),
                                ),
                              ),

                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),

                            // Başlık
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Text(
                                baslik,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }

  // ============ YAKLAŞAN ETKİNLİKLER ============
  Widget _buildUpcomingEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Yaklaşan Etkinlikler",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen()));
                },
                child: const Text(
                  "Hepsini Gör",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 200,
          child: _buildEventsList(),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    // Burada Firestore'dan da çekebilirsin, şimdilik sabit listeyi tuttum
    List<Map<String, dynamic>> sampleEvents = [
      {
        'title': 'Kimin Türkiye\'de Konser Vermesini İstersin?',
        'description': 'Sen de etkinliğe katıl ve Mest\'i çözen, topluluktaki diğer insanlarla eşleş!',
        'date': 'Şubat 10, 2024',
        'imageUrl': 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?w=400',
        'participants': 5,
      },
      {
        'title': 'En İyi Netflix Dizisi',
        'description': 'Netflix\'in birbirinden özel içeriklerinden sence hangisi en iyisi',
        'date': 'Şubat 11, 2024',
        'imageUrl': 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=400',
        'participants': 4,
      },
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: sampleEvents.length,
      itemBuilder: (context, index) {
        var event = sampleEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    String title = event['title'] ?? 'Etkinlik';
    String description = event['description'] ?? '';
    String date = event['date'] ?? '';
    String? imageUrl = event['imageUrl'];
    int participants = event['participants'] ?? 0;

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1C1C1E),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arka plan resmi
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF1C1C1E)),
              ),

            // Karartma
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.amber[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Başlık
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Açıklama
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Alt kısım: Katılımcılar ve Katıl butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Katılımcı avatarları
                      SizedBox(
                        width: (participants > 4 ? 5 : participants) * 22.0 + 20,
                        height: 30,
                        child: Stack(
                          children: [
                            ...List.generate(
                              participants > 4 ? 4 : participants,
                              (i) => Positioned(
                                left: i * 20.0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.primaries[i % Colors.primaries.length],
                                    border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            if (participants > 4)
                              Positioned(
                                left: 4 * 20.0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2C2C2E),
                                    border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "+${participants - 4}",
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Katıl butonu
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A5F),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Katıl",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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

// ============ YARDIMCI EKRANLAR ============
// Bildirim ve Yardım ekranları headerda buton olarak kaldığı için bu sınıfları tuttum.

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

