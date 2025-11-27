import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; 
import 'models.dart'; 
import 'mestler_screen.dart'; 
import 'chat_screen.dart';

class SonucScreen extends StatefulWidget {
  final Secenek sampiyon;
  final List<String> secimGecmisi;
  final String? testId; // 🔴 YENİ: testId eklendi

  const SonucScreen({
    super.key, 
    required this.sampiyon, 
    required this.secimGecmisi,
    this.testId,
  });

  @override
  State<SonucScreen> createState() => _SonucScreenState();
}

class _SonucScreenState extends State<SonucScreen> with SingleTickerProviderStateMixin {
  bool kaydedildi = false;
  Eslesme? bulunanEsim;
  bool ariyor = true; 
  String durumMesaji = "Sonuçlar analiz ediliyor...";
  String? olusanChatId;
  
  // 🔴 YENİ: Animasyon controller
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animasyon ayarları
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    
    _islemleriBaslat();
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _islemleriBaslat() async {
    await _sonucuKaydetVeRozetVer();
    await Future.delayed(const Duration(seconds: 2)); 
    await _tekEslesmeBul();
    _animController.forward();
  }

  // --- ROZET VE KAYIT SİSTEMİ ---
  Future<void> _sonucuKaydetVeRozetVer() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint("Kullanıcı oturum açmamış");
        return;
      }

      // 1. Test Sonucunu Kaydet
      await FirebaseFirestore.instance.collection('turnuvalar').add({
        'userId': userId,
        'testId': widget.testId, // 🔴 YENİ: testId kaydediliyor
        'kazananID': widget.sampiyon.id,
        'kazananIsim': widget.sampiyon.isim,
        'kazananResim': widget.sampiyon.resimUrl, // 🔴 YENİ: Resim de kaydediliyor
        'secimGecmisi': widget.secimGecmisi,
        'tarih': FieldValue.serverTimestamp(),
      });

      // 2. Kullanıcı İstatistiklerini Güncelle
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        
        if (!snapshot.exists) {
          debugPrint("Kullanıcı dokümanı bulunamadı");
          return;
        }

        Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
        int currentCount = userData['testCount'] ?? 0;
        int newCount = currentCount + 1;
        
        List<dynamic> currentBadges = userData['badges'] ?? [];
        String? newBadge;

        // --- ROZET KURALLARI ---
        if (newCount == 1 && !currentBadges.contains("İlk Adım")) {
          newBadge = "İlk Adım";
        } else if (newCount == 5 && !currentBadges.contains("Hızlı Parmak")) {
          newBadge = "Hızlı Parmak";
        } else if (newCount == 10 && !currentBadges.contains("Mest Gurmesi")) {
          newBadge = "Mest Gurmesi";
        } else if (newCount == 20 && !currentBadges.contains("Efsane")) {
          newBadge = "Efsane";
        } else if (newCount == 50 && !currentBadges.contains("Mest Ustası")) {
          newBadge = "Mest Ustası";
        } else if (newCount == 100 && !currentBadges.contains("Efsanevi")) {
          newBadge = "Efsanevi";
        }

        // Güncelleme
        Map<String, dynamic> updateData = {'testCount': newCount};
        
        if (newBadge != null) {
          updateData['badges'] = FieldValue.arrayUnion([newBadge]);
          transaction.update(userRef, updateData);
          
          // Kullanıcıya Bildir
          if (mounted) {
            _showBadgeNotification(newBadge);
          }
        } else {
          transaction.update(userRef, updateData);
        }
      });

      if (mounted) setState(() => kaydedildi = true);
    } catch (e) {
      debugPrint("Kayıt/Rozet hatası: $e");
    }
  }
  
  // 🔴 YENİ: Rozet bildirimi
  void _showBadgeNotification(String badge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Yeni Rozet Kazandın! 🎉",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    badge,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<String> _sohbetiVeritabaninaKaydet(String otherId, String otherName) async {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    var myDoc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
    String myName = myDoc.data()?['name'] ?? myDoc.data()?['username'] ?? "Kullanıcı";

    // Mevcut sohbet var mı kontrol et
    var chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: myId)
        .get();

    String? mevcutChatId;
    for (var doc in chatQuery.docs) {
      List users = doc['users'];
      if (users.contains(otherId)) {
        mevcutChatId = doc.id;
        break;
      }
    }

    if (mevcutChatId == null) {
      // Yeni sohbet oluştur
      var ref = await FirebaseFirestore.instance.collection('chats').add({
        'users': [myId, otherId],
        'userNames': {
          myId: myName,
          otherId: otherName,
        },
        'lastMessage': '🎉 Yeni Eşleşme!',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'readBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } else {
      return mevcutChatId;
    }
  }

  Future<void> _tekEslesmeBul() async {
    if (mounted) setState(() => durumMesaji = "Ruh eşin aranıyor...");
    
    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) setState(() => ariyor = false);
        return;
      }

      // 🔴 DÜZELTİLDİ: Daha iyi eşleşme algoritması
      var snapshot = await FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('kazananID', isEqualTo: widget.sampiyon.id)
          .orderBy('tarih', descending: true)
          .limit(50)
          .get();

      List<Eslesme> adaylar = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String otherUserId = data['userId'];

        // Kendimizi atla
        if (otherUserId == currentUserId) continue;

        List<dynamic> otherHistory = data['secimGecmisi'] ?? [];
        var mySet = widget.secimGecmisi.toSet();
        var otherSet = otherHistory.map((e) => e.toString()).toSet();
        int ortakSayisi = mySet.intersection(otherSet).length;
        
        // Uyum hesaplama (daha gelişmiş)
        int maxPossible = mySet.length < otherSet.length ? mySet.length : otherSet.length;
        int uyum = maxPossible > 0 
            ? (50 + ((ortakSayisi / maxPossible) * 50)).round()
            : 50;
        if (uyum > 100) uyum = 100;

        // Kullanıcı bilgilerini çek
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
            
        String userName = "Gizli Kullanıcı";
        String userCity = ""; 
        String? photoUrl;
        
        if (userDoc.exists) {
          var userData = userDoc.data()!;
          userName = userData['username'] ?? userData['name'] ?? "Bilinmiyor";
          userCity = userData['city'] ?? "";
          photoUrl = userData['photoUrl'];
        }

        adaylar.add(Eslesme(
          isim: userName, 
          uyumYuzdesi: uyum, 
          userId: otherUserId,
          sehir: userCity,
          photoUrl: photoUrl,
        ));
      }

      if (adaylar.isNotEmpty) {
        // En yüksek uyumlu 3 kişiden birini rastgele seç
        adaylar.sort((a, b) => b.uyumYuzdesi.compareTo(a.uyumYuzdesi));
        int topCount = adaylar.length > 3 ? 3 : adaylar.length;
        int randomIndex = Random().nextInt(topCount);
        
        Eslesme secilenKisi = adaylar[randomIndex];

        await _bildirimGonder(secilenKisi);
        String chatId = await _sohbetiVeritabaninaKaydet(secilenKisi.userId, secilenKisi.isim);

        if (mounted) {
          setState(() {
            bulunanEsim = secilenKisi;
            olusanChatId = chatId;
            ariyor = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            bulunanEsim = null; 
            ariyor = false;
          });
        }
      }

    } catch (e) {
      debugPrint("Eşleşme hatası: $e");
      if (mounted) setState(() => ariyor = false);
    }
  }

  Future<void> _bildirimGonder(Eslesme eslesilenKisi) async {
    try {
      String myId = FirebaseAuth.instance.currentUser?.uid ?? "";
      var myDoc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
      String myName = myDoc.data()?['name'] ?? myDoc.data()?['username'] ?? "Gizli Kullanıcı";

      await FirebaseFirestore.instance.collection('bildirimler').add({
        'aliciId': eslesilenKisi.userId, 
        'gonderenId': myId,              
        'gonderenIsim': myName,          
        'mesaj': "${widget.sampiyon.isim} severler birbirini buldu!",
        'uyum': eslesilenKisi.uyumYuzdesi,
        'okundu': false,                 
        'tarih': FieldValue.serverTimestamp(),
        'tip': 'eslesme',
      });
    } catch (e) {
      debugPrint("Bildirim hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Sonuç", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Şampiyon kartı
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text("🏆 SENİN SEÇİMİN", style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          widget.sampiyon.resimUrl,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 120,
                            width: 120,
                            color: Colors.grey[800],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.sampiyon.isim,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              if (ariyor) ...[
                Container(
                  height: 150, width: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10, width: 2),
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 80, width: 80,
                      child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFFFF5A5F)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(durumMesaji, style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1)),
              
              ] else if (bulunanEsim != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFFFF5A5F), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                    ]
                  ),
                  child: Column(
                    children: [
                      const Text("🎉 EŞLEŞME BULUNDU!", style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                      const SizedBox(height: 15),
                      
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFFFF5A5F),
                        backgroundImage: bulunanEsim!.photoUrl != null 
                            ? NetworkImage(bulunanEsim!.photoUrl!) 
                            : null,
                        child: bulunanEsim!.photoUrl == null
                            ? Text(
                                bulunanEsim!.isim.isNotEmpty ? bulunanEsim!.isim[0].toUpperCase() : "?",
                                style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(height: 15),
                      
                      Text(bulunanEsim!.isim, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      if(bulunanEsim!.sehir.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(bulunanEsim!.sehir, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: Text(
                          "%${bulunanEsim!.uyumYuzdesi} Uyum",
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (olusanChatId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: olusanChatId!,
                                    otherUserId: bulunanEsim!.userId,
                                    otherUserName: bulunanEsim!.isim,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_rounded),
                          label: const Text("Sohbete Başla"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.hourglass_top, size: 60, color: Color(0xFFFF5A5F)),
                      const SizedBox(height: 15),
                      const Text("Havuza Eklendin!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text(
                        "Şu an çevrimiçi bir eşleşme bulamadık ama seni sıraya aldık.\n\nEşleşme olunca bildirim göndereceğiz!", 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: Colors.grey, height: 1.5)
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Ana Sayfa", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                // Mestler sekmesine git
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A5F),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Başka Test Çöz", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}