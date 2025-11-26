import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'play_mest_screen.dart'; // Oyun ekranına gitmek için gerekli

// --- 1. SAYFA: KATEGORİ LİSTESİ (ANA EKRAN) ---
class MestlerScreen extends StatefulWidget {
  const MestlerScreen({super.key});

  @override
  State<MestlerScreen> createState() => _MestlerScreenState();
}

class _MestlerScreenState extends State<MestlerScreen> {
  // Kategoriler için rastgele renkler veya sabit ikonlar atayabiliriz
  final List<Color> cardColors = [
    const Color(0xFFEF5350), // Kırmızımsı
    const Color(0xFFAB47BC), // Mor
    const Color(0xFF42A5F5), // Mavi
    const Color(0xFF26A69A), // Yeşilimsi
    const Color(0xFFFFA726), // Turuncu
    const Color(0xFF78909C), // Gri Mavi
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        title: const Text("Kategoriler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
        automaticallyImplyLeading: false, // Alt menü olduğu için geri butonu yok
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('testler').where('aktif_mi', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var documents = snapshot.data!.docs;
          if (documents.isEmpty) return const Center(child: Text("Henüz hiç test yok.", style: TextStyle(color: Colors.grey)));

          // --- KATEGORİLERİ AYIKLAMA MANTIĞI ---
          // Tüm testleri tarayıp benzersiz kategorileri (Set kullanarak) buluyoruz.
          Set<String> uniqueCategories = {};
          for (var doc in documents) {
            var data = doc.data() as Map<String, dynamic>;
            // Eğer kategori alanı boşsa 'Diğer' olarak adlandır
            uniqueCategories.add(data['category'] ?? 'Genel');
          }
          List<String> categoryList = uniqueCategories.toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Yan yana 2 kutu
              childAspectRatio: 1.2, // Kutuların en/boy oranı
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: categoryList.length,
            itemBuilder: (context, index) {
              String catName = categoryList[index];
              // Karta rastgele bir renk seç (Sıraya göre döngüsel)
              Color boxColor = cardColors[index % cardColors.length];

              return GestureDetector(
                onTap: () {
                  // Kategoriye tıklanınca Detay Sayfasına Git
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryDetailScreen(categoryName: catName),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: boxColor.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: boxColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Kategori Baş harfi ikonu
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: boxColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          catName.isNotEmpty ? catName[0].toUpperCase() : "#",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: boxColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Kategori Adı
                      Text(
                        catName.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- 2. SAYFA: SEÇİLEN KATEGORİDEKİ TESTLER ---
class CategoryDetailScreen extends StatelessWidget {
  final String categoryName;

  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(categoryName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Sadece seçilen kategoriye ait testleri getir
        stream: FirebaseFirestore.instance
            .collection('testler')
            .where('category', isEqualTo: categoryName)
            .where('aktif_mi', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var tests = snapshot.data!.docs;
          if (tests.isEmpty) return const Center(child: Text("Bu kategoride test yok.", style: TextStyle(color: Colors.grey)));

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75, // Test kartları daha uzun (dikey)
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              var data = tests[index].data() as Map<String, dynamic>;
              String title = data['baslik'] ?? 'İsimsiz';
              String testId = tests[index].id;
              
              // Rastgele Görsel Seçimi (Testin içindeki seçeneklerden)
              String imgUrl = "";
              List opts = data['secenekler'] ?? [];
              if (opts.isNotEmpty) {
                imgUrl = opts[Random().nextInt(opts.length)]['resimUrl'] ?? "";
              }

              return GestureDetector(
                onTap: () {
                  // TESTİ OYNAMAYA GİT
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId))
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Test Görseli
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c,e,s) => Container(color: Colors.grey[800], child: const Icon(Icons.image, color: Colors.white24)),
                          ),
                        ),
                      ),
                      // Test Bilgileri
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.play_arrow, size: 12, color: Color(0xFFFF5A5F)),
                                const SizedBox(width: 4),
                                Text(
                                  "${data['playCount'] ?? 0} oynanma",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
            },
          );
        },
      ),
    );
  }
}