import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'play_mest_screen.dart';

// ============ MEST KATEGORİLERİ EKRANI (KOLAJ ARKA PLANLI) ============
class MestCategoriesScreen extends StatelessWidget {
  const MestCategoriesScreen({super.key});

  // Admin Paneliyle Uyumlu Kategori ID Çevirici
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
    // Sabit Kategori Listesi
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
          // Siyah ekran sorunu için pop yerine ana sayfaya dön
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
            childAspectRatio: 1.1,
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
              // 🔥 DİNAMİK KOLAJ RESİM SORGUSU 🔥
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('testler')
                    .where('aktif_mi', isEqualTo: true)
                    .where('kategori', isEqualTo: categoryId)
                    .orderBy('createdAt', descending: true) // En yeni testleri al
                    .limit(4) // Kolaj için en fazla 4 resim al
                    .get(),
                builder: (context, snapshot) {
                  List<String> imageUrls = [];
                  
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      String? bgImage = data['kapakResmi'];
                      // Kapak yoksa seçeneklerden al
                      if ((bgImage == null || bgImage.isEmpty) && 
                          data['secenekler'] != null && 
                          (data['secenekler'] as List).isNotEmpty) {
                         bgImage = data['secenekler'][0]['resimUrl'];
                      }
                      if (bgImage != null && bgImage.isNotEmpty) {
                        imageUrls.add(bgImage);
                      }
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.4)),
                    ),
                    // Kolajı ve üzerindeki katmanları tutan Stack
                    child: Stack(
                      children: [
                        // 1. Katman: Kolaj Arka Planı (Eğer resim varsa)
                        if (imageUrls.isNotEmpty)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildCollageBackground(imageUrls),
                            ),
                          ),

                        // 2. Katman: Karartma (Kolaj varsa ekle)
                        if (imageUrls.isNotEmpty)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.black.withOpacity(0.6), // Yazı okunsun diye karartma
                              ),
                            ),
                          ),
                        
                        // 3. Katman: İkon (Sadece hiç resim yoksa göster)
                        if (imageUrls.isEmpty)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Icon(
                              category['icon'],
                              size: 60,
                              color: (category['color'] as Color).withOpacity(0.15),
                            ),
                          ),
                        
                        // 4. Katman: Kategori İsmi (Her zaman ortada)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              category['name'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black)
                                ]
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // Kolajı oluşturan yardımcı fonksiyon
  Widget _buildCollageBackground(List<String> imageUrls) {
    int count = imageUrls.length;

    if (count == 1) {
      return Image.network(imageUrls[0], fit: BoxFit.cover);
    } else if (count == 2) {
      return Row(
        children: [
          Expanded(child: Image.network(imageUrls[0], fit: BoxFit.cover, height: double.infinity)),
          Expanded(child: Image.network(imageUrls[1], fit: BoxFit.cover, height: double.infinity)),
        ],
      );
    } else if (count == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: Image.network(imageUrls[0], fit: BoxFit.cover, height: double.infinity)),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: Image.network(imageUrls[1], fit: BoxFit.cover, width: double.infinity)),
                Expanded(child: Image.network(imageUrls[2], fit: BoxFit.cover, width: double.infinity)),
              ],
            ),
          ),
        ],
      );
    } else {
      // 4 veya daha fazla resim için 2x2 grid
      return GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Image.network(imageUrls[0], fit: BoxFit.cover),
          Image.network(imageUrls[1], fit: BoxFit.cover),
          Image.network(imageUrls[2], fit: BoxFit.cover),
          Image.network(imageUrls[3], fit: BoxFit.cover),
        ],
      );
    }
  }
}

// ============ KATEGORİ DETAY EKRANI (İÇ SAYFA - AYNEN KORUNDU) ============
class CategoryTestsScreen extends StatelessWidget {
  final String categoryName;

  const CategoryTestsScreen({
    super.key,
    required this.categoryName,
  });

  // Kategori ID Çevirici (Aynı mantık)
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
          
          // --- KATEGORİ BAŞLIĞI VE DİNAMİK KAPAK ---
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