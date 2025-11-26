import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_test_screen.dart';
import 'play_mest_screen.dart';
import 'leaderboard_screen.dart'; // <--- EKLENDİ
import '../widgets/active_users_row.dart';
import 'package:intl/intl.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String _aramaMetni = "";
  String _seciliKategori = "Tümü";
  final List<String> _kategoriler = ["Tümü", "Yemek", "Spor", "Sinema", "Müzik", "Oyun", "Teknoloji"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(text: "mes", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                  TextSpan(text: "t", style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(-2, -5),
              child: const Icon(Icons.check, color: Color(0xFFFF5A5F), size: 20),
            ),
          ],
        ),
        actions: [
          // --- YENİ EKLENEN KUPA İKONU ---
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.amber), // Sarı Kupa
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
            },
          ),
          
          IconButton(icon: const Icon(Icons.notifications_none_outlined, color: Colors.white), onPressed: () {}),
          
          // + Butonu
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTestScreen())),
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF5A5F))),
              child: const Icon(Icons.add, color: Color(0xFFFF5A5F), size: 18),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ARAMA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: (val) => setState(() => _aramaMetni = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Test veya Etkinlik Ara...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  suffixIcon: const Icon(Icons.search, color: Colors.grey, size: 24),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 15),

            // 2. STORY ALANI
            const ActiveUsersRow(),

            const SizedBox(height: 20),

            // 3. YAKLAŞAN ETKİNLİKLER
            _buildEventSection(),

            const SizedBox(height: 20),

            // 4. KATEGORİLER
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _kategoriler.length,
                itemBuilder: (context, index) {
                  String k = _kategoriler[index];
                  bool isActive = _seciliKategori == k;
                  return GestureDetector(
                    onTap: () => setState(() => _seciliKategori = k),
                    child: Container(
                      margin: const EdgeInsets.only(left: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFFF5A5F) : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        border: isActive ? null : Border.all(color: Colors.white10),
                      ),
                      child: Text(k, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // 5. POPÜLER TESTLER
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text("Popüler Mestler", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 15),

            // TEST GRID
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('testler').where('aktif_mi', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                
                var documents = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String baslik = (data['baslik'] ?? "").toString().toLowerCase();
                  String kategori = (data['category'] ?? "Tümü").toString();
                  bool arama = _aramaMetni.isEmpty || baslik.contains(_aramaMetni);
                  bool kat = _seciliKategori == "Tümü" || kategori == _seciliKategori;
                  return arama && kat;
                }).toList();

                if (documents.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Test bulunamadı.", style: TextStyle(color: Colors.grey))));

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 15, mainAxisSpacing: 15
                  ),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    var doc = documents[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildTestCard(doc.id, data);
                  },
                );
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- ETKİNLİK KARTI ---
  Widget _buildEventSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text("Yaklaşan Etkinlikler", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('testler')
              .where('isEvent', isEqualTo: true)
              .where('eventDate', isGreaterThan: Timestamp.now())
              .orderBy('eventDate') 
              .limit(1) 
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(padding: EdgeInsets.all(16), child: Text("Etkinlikler yüklenemedi", style: TextStyle(color: Colors.red, fontSize: 10)));
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text("Şu an planlanmış bir etkinlik yok.", style: TextStyle(color: Colors.grey))),
              );
            }

            var doc = snapshot.data!.docs.first;
            var data = doc.data() as Map<String, dynamic>;
            
            String dateStr = "Tarih Belirtilmemiş";
            if (data['eventDate'] != null) {
              DateTime date = (data['eventDate'] as Timestamp).toDate();
              List<String> aylar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
              dateStr = "${date.day} ${aylar[date.month - 1]}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
            }

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayMestScreen(testId: doc.id))),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(data['kapakResmi'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.95)], 
                          stops: const [0.3, 1.0]
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFF1C1C1E).withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFFFF5A5F), size: 12),
                                const SizedBox(width: 5),
                                Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data['baslik'] ?? "Etkinlik",
                            style: const TextStyle(color: Color(0xFFFFC107), fontSize: 22, fontWeight: FontWeight.bold, height: 1.1),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Sen de etkinliğe katıl ve Mest'i çözen, topluluktaki diğer insanlarla eşleş!",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              SizedBox(
                                width: 80, height: 30,
                                child: Stack(
                                  children: [
                                    for (int i = 0; i < 3; i++)
                                      Positioned(
                                        left: i * 18.0,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(0xFF1C1C1E),
                                          child: const Icon(Icons.person, size: 14, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayMestScreen(testId: doc.id))),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(color: Color(0xFFFF5A5F)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0)
                                ),
                                child: const Text("Katıl", style: TextStyle(color: Colors.white, fontSize: 13)),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- TEST KARTI ---
  Widget _buildTestCard(String id, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayMestScreen(testId: id))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(data['kapakResmi'] ?? ''),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)], stops: const [0.5, 1.0]
                ),
              ),
            ),
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(data['baslik'] ?? "Başlık", maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.1))),
                  if(data['playCount'] != null && (data['playCount'] > 50))
                    const Padding(padding: EdgeInsets.only(left: 4, bottom: 2), child: Icon(Icons.verified, color: Colors.blue, size: 16))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}