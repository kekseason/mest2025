import 'package:app_1/screens/help_screen.dart';
import 'package:app_1/screens/events_screen.dart';
import 'package:app_1/screens/matches_screen.dart';
import 'package:app_1/screens/popular_mests_screen.dart';
import 'package:app_1/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'play_mest_screen.dart';
import 'welcome_screen.dart';
import 'daily_challenges_screen.dart';
import 'share_service.dart';
import 'personality_analysis_screen.dart';
import 'trends_screen.dart';
import 'leaderboard_screen.dart';
import 'user_create_test_screen.dart';
import 'moderator_panel_screen.dart';


class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final TextEditingController _searchController = TextEditingController();
  String? currentUserId;
  
  // 🔴 YENİ: Arama state'leri
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = "";

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

  // ============ 🔴 YENİ: ARAMA FONKSİYONU ============
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchQuery = "";
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query.toLowerCase();
    });

    try {
      // Firestore'da arama yap
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('testler')
          .where('aktif_mi', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> results = [];

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String baslik = (data['baslik'] ?? '').toString().toLowerCase();
        String kategori = (data['kategori'] ?? '').toString().toLowerCase();
        List<dynamic> anahtarKelimeler = data['anahtarKelimeler'] ?? [];
        List<dynamic> secenekler = data['secenekler'] ?? [];

        // Başlık, kategori veya anahtar kelimede ara
        bool matchFound = baslik.contains(_searchQuery) ||
            kategori.contains(_searchQuery) ||
            anahtarKelimeler.any((k) => k.toString().toLowerCase().contains(_searchQuery));

        // Seçeneklerde de ara
        if (!matchFound) {
          for (var secenek in secenekler) {
            String secenekIsim = (secenek['isim'] ?? '').toString().toLowerCase();
            if (secenekIsim.contains(_searchQuery)) {
              matchFound = true;
              break;
            }
          }
        }

        if (matchFound) {
          results.add({
            'id': doc.id,
            'baslik': data['baslik'] ?? 'Test',
            'kategori': data['kategori'] ?? 'Genel',
            'kapakResmi': _getKapakResmi(data),
            'playCount': data['playCount'] ?? 0,
          });
        }
      }

      // Popülerliğe göre sırala
      results.sort((a, b) => (b['playCount'] as int).compareTo(a['playCount'] as int));

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint("Arama hatası: $e");
      setState(() => _isSearching = false);
    }
  }

  String? _getKapakResmi(Map<String, dynamic> data) {
    String? kapak = data['kapakResmi'];
    if (kapak == null || kapak.isEmpty) {
      List secenekler = data['secenekler'] ?? [];
      if (secenekler.isNotEmpty) {
        kapak = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'];
      }
    }
    return kapak;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchQuery = "";
    });
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
        child: Column(
          children: [
            // ============ HEADER ============
            _buildHeader(),

            // ============ ARAMA ÇUBUĞU ============
            _buildSearchBar(),

            // ============ İÇERİK ============
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults() // 🔴 Arama sonuçları
                  : _buildMainContent(),   // Normal içerik
            ),
          ],
        ),
      ),
    );
  }

  // ============ ANA İÇERİK ============
  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ============ YENİ EŞLEŞMELER ============
          _buildNewMatches(),

          const SizedBox(height: 25),

          // ============ POPÜLER MESTLER ============
          _buildPopularMests(),

          const SizedBox(height: 25),

          // ============ YAKLAŞAN ETKİNLİKLER (DİNAMİK) ============
          _buildUpcomingEvents(),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ============ 🔴 YENİ: ARAMA SONUÇLARI ============
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 20),
            Text(
              '"$_searchQuery" için sonuç bulunamadı',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _clearSearch,
              child: const Text(
                "Aramayı Temizle",
                style: TextStyle(color: Color(0xFFFF5A5F)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_searchResults.length} sonuç bulundu',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              TextButton(
                onPressed: _clearSearch,
                child: const Text("Temizle", style: TextStyle(color: Color(0xFFFF5A5F))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              var test = _searchResults[index];
              return _buildSearchResultCard(test);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> test) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayMestScreen(testId: test['id'])),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Resim
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: test['kapakResmi'] != null
                  ? Image.network(
                      test['kapakResmi'],
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 100,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.quiz, color: Colors.grey),
                    ),
            ),
            
            // Bilgiler
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test['baslik'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A5F).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            test['kategori'],
                            style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.play_arrow, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${test['playCount']}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Ok ikonu
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
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
          // Logo - Text olarak (asset yoksa sorun olmaz)
          const Text(
            "Mest",
            style: TextStyle(
              color: Color(0xFFFF5A5F),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Sağ ikonlar
          Row(
            children: [
              _buildIconButton(Icons.notifications_none, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              }),
              const SizedBox(width: 8),
              _buildIconButton(Icons.help_outline, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
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

  // ============ 🔴 GÜNCELLENMİŞ: ARAMA ÇUBUĞU ============
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _searchQuery.isNotEmpty 
                ? const Color(0xFFFF5A5F) 
                : const Color(0xFFFF5A5F).withOpacity(0.3),
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            // Debounce effect için 300ms bekle
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_searchController.text == value) {
                _performSearch(value);
              }
            });
          },
          onSubmitted: (value) => _performSearch(value),
          decoration: InputDecoration(
            hintText: "Test, kategori veya seçenek ara...",
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
            prefixIcon: Icon(
              Icons.search,
              color: _searchQuery.isNotEmpty ? const Color(0xFFFF5A5F) : Colors.grey[600],
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: _clearSearch,
                  )
                : null,
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

  // ============ POPÜLER MESTLER ============
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
                  String? kapakResmi = _getKapakResmi(test);

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
                            if (kapakResmi != null)
                              Image.network(
                                kapakResmi,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: const Icon(Icons.image, color: Colors.grey, size: 40),
                                ),
                              ),
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

  // ============ 🔴 DİNAMİK: YAKLAŞAN ETKİNLİKLER ============
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
          // 🔴 DİNAMİK: Firestore'dan etkinlikleri çek
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .where('status', isEqualTo: 'active')
                .orderBy('startTime', descending: false)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              // Veri yoksa veya hata varsa sample göster
              List<Map<String, dynamic>> events = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                events = snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }).toList();
              } else {
                // Firestore'da etkinlik yoksa sample göster
                events = _getSampleEvents();
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return _buildEventCard(events[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Sample etkinlikler (Firestore boşsa)
  List<Map<String, dynamic>> _getSampleEvents() {
    DateTime now = DateTime.now();
    return [
      {
        'id': 'sample1',
        'title': 'Kimin Türkiye\'de Konser Vermesini İstersin?',
        'description': 'Sen de etkinliğe katıl ve Mest\'i çözen, topluluktaki diğer insanlarla eşleş!',
        'startTime': Timestamp.fromDate(now),
        'endTime': Timestamp.fromDate(now.add(const Duration(hours: 24))),
        'imageUrl': 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?w=400',
        'participants': ['user1', 'user2', 'user3', 'user4', 'user5'],
      },
      {
        'id': 'sample2',
        'title': 'En İyi Netflix Dizisi',
        'description': 'Netflix\'in birbirinden özel içeriklerinden sence hangisi en iyisi',
        'startTime': Timestamp.fromDate(now.add(const Duration(hours: 2))),
        'endTime': Timestamp.fromDate(now.add(const Duration(hours: 26))),
        'imageUrl': 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=400',
        'participants': ['user1', 'user2', 'user3', 'user4'],
      },
    ];
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    String title = event['title'] ?? 'Etkinlik';
    String description = event['description'] ?? '';
    String? imageUrl = event['imageUrl'];
    List<dynamic> participants = event['participants'] ?? [];

    // Tarih hesaplama
    DateTime? startTime;
    if (event['startTime'] != null) {
      startTime = (event['startTime'] as Timestamp).toDate();
    }

    String dateText = startTime != null
        ? "${startTime.day}/${startTime.month} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}"
        : "";

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
                  if (dateText.isNotEmpty)
                    Text(
                      dateText,
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

                  // Alt kısım
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Katılımcılar
                      _buildParticipantsAvatars(participants),

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

  Widget _buildParticipantsAvatars(List<dynamic> participants) {
    int count = participants.length;
    int showCount = count > 4 ? 4 : count;

    return SizedBox(
      width: (showCount + (count > 4 ? 1 : 0)) * 22.0 + 20,
      height: 30,
      child: Stack(
        children: [
          ...List.generate(
            showCount,
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
          if (count > 4)
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
                    "+${count - 4}",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============ BİLDİRİMLER EKRANI ============
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
        title: const Text("Bildirimler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const Center(
        child: Text("Henüz bildiriminiz yok", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
