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

  const SonucScreen({super.key, required this.sampiyon, required this.secimGecmisi});

  @override
  State<SonucScreen> createState() => _SonucScreenState();
}

class _SonucScreenState extends State<SonucScreen> {
  bool kaydedildi = false;
  Eslesme? bulunanEsim;
  bool ariyor = true; 
  String durumMesaji = "Sonuçlar analiz ediliyor...";
  String? olusanChatId;

  @override
  void initState() {
    super.initState();
    _islemleriBaslat();
  }

  Future<void> _islemleriBaslat() async {
    await _sonucuKaydetVeRozetVer(); // Rozet kontrolü buraya eklendi
    await Future.delayed(const Duration(seconds: 2)); 
    await _tekEslesmeBul();
  }

  // --- ROZET VE KAYIT SİSTEMİ ---
  Future<void> _sonucuKaydetVeRozetVer() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // 1. Test Sonucunu Kaydet
      await FirebaseFirestore.instance.collection('turnuvalar').add({
        'userId': userId,
        'kazananID': widget.sampiyon.id,
        'kazananIsim': widget.sampiyon.isim,
        'secimGecmisi': widget.secimGecmisi,
        'tarih': FieldValue.serverTimestamp(),
      });

      // 2. Kullanıcı İstatistiklerini Güncelle (Test Sayısını Artır)
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        
        if (!snapshot.exists) return;

        int currentCount = (snapshot.data() as Map<String, dynamic>)['testCount'] ?? 0;
        int newCount = currentCount + 1;
        
        List<dynamic> currentBadges = (snapshot.data() as Map<String, dynamic>)['badges'] ?? [];
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
        }

        // Güncelleme
        if (newBadge != null) {
          transaction.update(userRef, {
            'testCount': newCount,
            'badges': FieldValue.arrayUnion([newBadge])
          });
          
          // Kullanıcıya Bildir
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.amber,
                content: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text("Tebrikler! '$newBadge' rozetini kazandın!", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                  ],
                ),
                duration: const Duration(seconds: 4),
              )
            );
          }
        } else {
          transaction.update(userRef, {'testCount': newCount});
        }
      });

      if (mounted) setState(() => kaydedildi = true);
    } catch (e) {
      print("Kayıt/Rozet hatası: $e");
    }
  }

  Future<String> _sohbetiVeritabaninaKaydet(String otherId, String otherName) async {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    var myDoc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
    String myName = myDoc.data()?['name'] ?? myDoc.data()?['username'] ?? "Kullanıcı";

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
      var ref = await FirebaseFirestore.instance.collection('chats').add({
        'users': [myId, otherId],
        'userNames': {
          myId: myName,
          otherId: otherName,
        },
        'lastMessage': 'Yeni Eşleşme! 🎉',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'readBy': [], 
      });
      return ref.id;
    } else {
      return mevcutChatId;
    }
  }

  Future<void> _tekEslesmeBul() async {
    setState(() => durumMesaji = "Ruh eşin aranıyor...");
    
    try {
      String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

      var snapshot = await FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('kazananID', isEqualTo: widget.sampiyon.id)
          .limit(20) 
          .get();

      List<Eslesme> adaylar = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String otherUserId = data['userId'];

        if (otherUserId == currentUserId) continue;

        List<dynamic> otherHistory = data['secimGecmisi'] ?? [];
        var mySet = widget.secimGecmisi.toSet();
        var otherSet = otherHistory.toSet();
        int ortakSayisi = mySet.intersection(otherSet).length;
        
        int uyum = 50 + (ortakSayisi * 10);
        if (uyum > 100) uyum = 100;

        var userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
        String userName = "Gizli Kullanıcı";
        String userCity = ""; 
        
        if (userDoc.exists) {
          userName = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? "Bilinmiyor";
          userCity = userDoc.data()?['city'] ?? "";
        }

        adaylar.add(Eslesme(
          isim: userName, 
          uyumYuzdesi: uyum, 
          userId: otherUserId,
          sehir: userCity
        ));
      }

      if (adaylar.isNotEmpty) {
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
      print("Hata: $e");
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
      });
    } catch (e) {
      print("Bildirim hatası: $e");
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Seçimin: ", style: TextStyle(color: Colors.grey)),
                  Text(widget.sampiyon.isim, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 40),

              if (ariyor) ...[
                Container(
                  height: 200, width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10, width: 2),
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 100, width: 100,
                      child: CircularProgressIndicator(strokeWidth: 8, color: Color(0xFFFF5A5F)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(durumMesaji, style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.2)),
              
              ] else if (bulunanEsim != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFFF5A5F), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                    ]
                  ),
                  child: Column(
                    children: [
                      const Text("🎉 EŞLEŞME BULUNDU! 🎉", style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 20),
                      
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFFF5A5F),
                        child: Text(
                          bulunanEsim!.isim.isNotEmpty ? bulunanEsim!.isim[0].toUpperCase() : "?",
                          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Text(bulunanEsim!.isim, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      if(bulunanEsim!.sehir.isNotEmpty)
                        Text(bulunanEsim!.sehir, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text("Uyum: %${bulunanEsim!.uyumYuzdesi}", style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      
                      const SizedBox(height: 30),
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
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sohbet yükleniyor, bekleyin...")));
                            }
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text("Mesaj Gönder"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      )
                    ],
                  ),
                )
              
              ] else ...[
                const Icon(Icons.hourglass_top, size: 80, color: Color(0xFFFF5A5F)),
                const SizedBox(height: 20),
                const Text("Havuza Eklendin!", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "Şu an çevrimiçi bir eşleşme yok ama seni sıraya aldık. Eşleşme olunca bildirim göndereceğiz!", 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.grey)
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text("Ana Sayfaya Dön"),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}