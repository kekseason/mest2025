import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart'; 
import 'welcome_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11), // Tasarımdaki siyah
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Profil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: const Icon(Icons.arrow_back_ios, color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.help_outline, color: Colors.white), onPressed: () {}),
          // ÇIKIŞ BUTONU
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                 Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
              }
            }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          String name = data?['name'] ?? "Kullanıcı";
          String city = data?['city'] ?? "";
          
          // --- YENİ VERİLER ---
          int testCount = data?['testCount'] ?? 0;
          List<dynamic> badges = data?['badges'] ?? [];
          
          // Ünvan Hesaplama
          String unvan = "Mest Kaşifi 🚀";
          if (testCount >= 20) unvan = "Mest Efsanesi 🏆";
          else if (testCount >= 10) unvan = "Mest Gurmesi 🍔";
          else if (testCount >= 5) unvan = "Hızlı Parmak ⚡";

          // Yaş hesaplama
          String age = "";
          if (data?['birthDate'] != null) {
            DateTime birth = (data?['birthDate'] as Timestamp).toDate();
            int ageVal = DateTime.now().year - birth.year;
            age = "$ageVal, ";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // --- AVATAR ---
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: const DecorationImage(
                          image: AssetImage('assets/user_placeholder.png'), 
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                      ),
                      child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white))),
                    ),
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D0D11), width: 3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                
                // İSİM ve TİK
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 5),
                    const Icon(Icons.verified, color: Colors.blue, size: 20)
                  ],
                ),
                
                const SizedBox(height: 5),
                
                // ŞEHİR ve ÜNVAN
                Text("$age$city", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 5),
                Text(unvan, style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 14, fontWeight: FontWeight.w600)),
                
                const SizedBox(height: 15),
                
                // PROFİLİ DÜZENLE BUTONU
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD63D58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text("Profili Düzenle", style: TextStyle(fontSize: 12, color: Colors.white)),
                ),

                const SizedBox(height: 25),

                // --- İSTATİSTİKLER (YENİ) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem("Testler", testCount.toString()),
                    Container(width: 1, height: 30, color: Colors.grey[800]),
                    _buildStatItem("Rozetler", badges.length.toString()),
                    Container(width: 1, height: 30, color: Colors.grey[800]),
                    _buildStatItem("Eşleşmeler", "0"), // İleride bağlanacak
                  ],
                ),

                const SizedBox(height: 25),

                // --- ROZETLER KUTUSU (YENİ) ---
                if (badges.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(15),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Rozetlerim", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: badges.map((b) => Chip(
                            label: Text(b.toString(), style: const TextStyle(fontSize: 11, color: Colors.white)),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            side: BorderSide.none,
                            avatar: const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // --- KARTLAR (Carousel) ---
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildInfoCard("Seni Beğenenler", "Görmek için tıkla", false),
                      const SizedBox(width: 15),
                      _buildInfoCard("Reklamları kaldır", "49,90", true),
                      const SizedBox(width: 15),
                      _buildInfoCard("Sınırsız Kaydırma", "Paketi İncele", false),
                    ],
                  ),
                ),
                
                // Noktalar
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(false),
                    _buildDot(true),
                    _buildDot(false),
                  ],
                ),

                const SizedBox(height: 30),

                // --- MEST+ BUTONU ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF8A90), Color(0xFFFF5A5F)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("Mest+'a Üye Ol 59,99", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- YENİ İSTATİSTİK WIDGET'I ---
  Widget _buildStatItem(String title, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoCard(String title, String subtitle, bool isActive) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(15),
        border: isActive ? Border.all(color: const Color(0xFFFF5A5F), width: 1.5) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? Icons.star : Icons.lock_open, color: Colors.white, size: 28),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 8 : 6,
      height: isActive ? 8 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}