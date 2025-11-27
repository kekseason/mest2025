import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'play_mest_screen.dart';

class CategoryTestsScreen extends StatelessWidget {
  final String categoryName;

  const CategoryTestsScreen({
    super.key,
    required this.categoryName,
  });

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
        title: Text(
          categoryName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          
          // Kategori başlığı
          Text(
            categoryName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "$categoryName kategorisindeki Mestlerden istediğini çözebilirsin!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          
          const SizedBox(height: 25),

          // Test listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('testler')
                  .where('aktif_mi', isEqualTo: true)
                  .where('kategori', isEqualTo: _getCategoryId(categoryName))
                  .orderBy('olusturmaTarihi', descending: true)
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
    int playCount = test['playCount'] ?? 0;

    // Kapak resmi yoksa ilk seçenekten al
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
            // Gradient
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
            
            // İçerik
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

            // Oynama sayısı
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      "$playCount",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kategori adından ID'ye çevir
  String _getCategoryId(String name) {
    Map<String, String> categoryMap = {
      'Yemek İçecek': 'yemek',
      'Yemek': 'yemek',
      'Spor': 'spor',
      'Müzik': 'muzik',
      'Eğlence': 'eglence',
      'Film Dizi': 'film',
      'Film': 'film',
      'Oyun': 'oyun',
      'Moda': 'moda',
      'Sosyal Medya': 'sosyal',
    };
    return categoryMap[name] ?? name.toLowerCase();
  }
}