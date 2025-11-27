import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'play_mest_screen.dart';

class PopularMestsScreen extends StatelessWidget {
  const PopularMestsScreen({super.key});

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
        title: const Text(
          "Popüler Mestler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('testler')
            .where('aktif_mi', isEqualTo: true)
            .orderBy('playCount', descending: true)
            .limit(50)
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
            padding: const EdgeInsets.all(16),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              var test = tests[index].data() as Map<String, dynamic>;
              String testId = tests[index].id;
              
              return _buildTestCard(context, testId, test, index + 1);
            },
          );
        },
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
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up,
              size: 50,
              color: Color(0xFFFF5A5F),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Henüz popüler test yok",
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

  Widget _buildTestCard(BuildContext context, String testId, Map<String, dynamic> test, int rank) {
    String baslik = test['baslik'] ?? 'Test';
    String? kapakResmi = test['kapakResmi'];
    int playCount = test['playCount'] ?? 0;
    bool isVerified = test['isVerified'] ?? false;
    String olusturanAdi = test['olusturanAdi'] ?? 'Anonim';

    // Kapak resmi yoksa ilk seçenekten al
    if (kapakResmi == null || kapakResmi.isEmpty) {
      List secenekler = test['secenekler'] ?? [];
      if (secenekler.isNotEmpty) {
        kapakResmi = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'];
      }
    }

    // Sıralama rengi
    Color rankColor;
    IconData? rankIcon;
    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.orange[700]!;
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = Colors.grey;
      rankIcon = null;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayMestScreen(testId: testId)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: rank <= 3 
                ? rankColor.withOpacity(0.5) 
                : const Color(0xFFFF5A5F).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Sıralama
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (rankIcon != null)
                    Icon(rankIcon, color: rankColor, size: 20),
                  Text(
                    "#$rank",
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Resim
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: kapakResmi != null
                    ? DecorationImage(
                        image: NetworkImage(kapakResmi),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: kapakResmi == null ? const Color(0xFF2C2C2E) : null,
              ),
              child: kapakResmi == null
                  ? const Icon(Icons.image, color: Colors.grey, size: 30)
                  : null,
            ),

            const SizedBox(width: 12),

            // Bilgiler
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            baslik,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified, color: Colors.blue, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      olusturanAdi,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.play_arrow, color: Color(0xFFFF5A5F), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "$playCount oynama",
                          style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Ok
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}