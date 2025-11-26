import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final String myId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Liderlik Tablosu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // En çok test çözen 50 kişiyi getir
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('testCount', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henüz veri yok.", style: TextStyle(color: Colors.grey)));
          }

          var docs = snapshot.data!.docs;
          
          // İlk 3 kişi (Podyum)
          var top3 = docs.take(3).toList();
          // Geri kalanlar (Liste)
          var rest = docs.skip(3).toList();

          return Column(
            children: [
              // --- PODYUM ALANI ---
              const SizedBox(height: 20),
              if (top3.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2. Olan (Sol)
                      if (top3.length >= 2) _buildPodiumItem(top3[1], 2),
                      // 1. Olan (Orta - Büyük)
                      _buildPodiumItem(top3[0], 1),
                      // 3. Olan (Sağ)
                      if (top3.length >= 3) _buildPodiumItem(top3[2], 3),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // --- LİSTE ALANI ---
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: rest.length,
                    separatorBuilder: (c, i) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      var doc = rest[index];
                      var data = doc.data() as Map<String, dynamic>;
                      int rank = index + 4;
                      bool isMe = doc.id == myId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        tileColor: isMe ? const Color(0xFFFF5A5F).withOpacity(0.1) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$rank", 
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            const SizedBox(width: 15),
                            CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                              child: data['photoUrl'] == null ? Text((data['name'] ?? "?")[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                            ),
                          ],
                        ),
                        title: Text(
                          data['name'] ?? data['username'] ?? "Kullanıcı",
                          style: TextStyle(color: isMe ? const Color(0xFFFF5A5F) : Colors.white, fontWeight: FontWeight.bold),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            "${data['testCount'] ?? 0} Mest",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // PODYUM WIDGET'I
  Widget _buildPodiumItem(DocumentSnapshot doc, int rank) {
    var data = doc.data() as Map<String, dynamic>;
    bool isFirst = rank == 1;
    double size = isFirst ? 100 : 80;
    Color borderColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade400 : const Color(0xFFCD7F32));
    double height = isFirst ? 160 : 130;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Taç İkonu (Sadece 1. için)
          if (isFirst) 
            const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Icon(Icons.emoji_events, color: Colors.amber, size: 30),
            ),
          
          // Profil Resmi
          Stack(
            children: [
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 3),
                  image: const DecorationImage(
                    image: AssetImage('assets/user_placeholder.png'), // Varsayılan (Profil resmi varsa burayı değiştir)
                    fit: BoxFit.cover
                  ),
                ),
                child: data['photoUrl'] != null 
                  ? ClipOval(child: Image.network(data['photoUrl'], fit: BoxFit.cover))
                  : Center(child: Text((data['name']??"?")[0].toUpperCase(), style: TextStyle(fontSize: size/3, color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                  ),
                  child: Center(child: Text("$rank", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          
          // İsim ve Puan
          Text(
            (data['name'] ?? "User").split(" ")[0], // Sadece ilk isim
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "${data['testCount'] ?? 0} Mest",
            style: TextStyle(color: borderColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          
          // Yükselti Kutusu (Görsel efekt)
          const SizedBox(height: 10),
          Container(
            width: size, 
            height: rank == 1 ? 30 : (rank == 2 ? 20 : 10),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}