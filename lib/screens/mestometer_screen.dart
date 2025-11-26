import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MestometerScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage; // Opsiyonel, profil fotosu için

  const MestometerScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<MestometerScreen> createState() => _MestometerScreenState();
}

class _MestometerScreenState extends State<MestometerScreen> {
  bool _isLoading = true;
  int _uyumPuani = 0;
  List<String> _ortakZevkler = [];
  List<String> _farkliZevkler = []; // Aynı testi çözüp farklı sonuç çıkanlar

  @override
  void initState() {
    super.initState();
    _hesapla();
  }

  Future<void> _hesapla() async {
    String myId = FirebaseAuth.instance.currentUser!.uid;

    try {
      // 1. Benim Sonuçlarım
      var mySnaps = await FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('userId', isEqualTo: myId)
          .get();

      // 2. Karşı Tarafın Sonuçları
      var otherSnaps = await FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('userId', isEqualTo: widget.otherUserId)
          .get();

      // Verileri İşleme (Test ID'sine göre gruplama yapabilirdik ama şimdilik kazanan isminden gidiyoruz)
      // Not: Daha kesin sonuç için 'testId' kaydetmek gerekir, şimdilik isimden eşleştiriyoruz.
      
      Set<String> myWinners = {};
      Set<String> otherWinners = {};

      for (var doc in mySnaps.docs) {
        myWinners.add(doc['kazananIsim']);
      }
      
      for (var doc in otherSnaps.docs) {
        otherWinners.add(doc['kazananIsim']);
      }

      // Kesişim (Ortak Zevkler)
      List<String> ortaklar = myWinners.intersection(otherWinners).toList();
      
      // Puan Hesaplama Mantığı (Basit bir algoritma)
      // Her ortak zevk 15 puan, taban puan 10. Maksimum 100.
      int puan = 10 + (ortaklar.length * 15);
      if (puan > 100) puan = 100;
      if (ortaklar.isEmpty) puan = 5; // Hiç ortak yoksa

      if (mounted) {
        setState(() {
          _ortakZevkler = ortaklar;
          _uyumPuani = puan;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Mestometre Hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Mestometre", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // --- GÖSTERGE ALANI ---
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dış Halka
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: _uyumPuani / 100,
                            strokeWidth: 15,
                            backgroundColor: Colors.grey[900],
                            color: _getColor(_uyumPuani),
                          ),
                        ),
                        // İç Yazı
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "%$_uyumPuani",
                              style: TextStyle(
                                color: _getColor(_uyumPuani),
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text("UYUM", style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // --- AÇIKLAMA METNİ ---
                  Text(
                    _getComment(_uyumPuani),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${widget.otherUserName} ile senin arandaki mest uyumu.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 40),

                  // --- ORTAK ZEVKLER LİSTESİ ---
                  if (_ortakZevkler.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("💖 Ortak Zevkler (${_ortakZevkler.length})", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _ortakZevkler.map((zevk) => Chip(
                        backgroundColor: const Color(0xFF1C1C1E),
                        side: const BorderSide(color: Color(0xFFFF5A5F)),
                        avatar: const Icon(Icons.check, color: Color(0xFFFF5A5F), size: 18),
                        label: Text(zevk, style: const TextStyle(color: Colors.white)),
                      )).toList(),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                          SizedBox(height: 10),
                          Text(
                            "Henüz ortak bir yönünüzü keşfedemedik.\nDaha fazla test çözerek uyumunuzu artırın!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  ],

                  const SizedBox(height: 40),
                  
                  // Aksiyon Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context), // Sohbete dön
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A5F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("Sohbete Dön", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Puana göre renk
  Color _getColor(int score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return const Color(0xFFFF5A5F); // Ana renk
    return Colors.orange;
  }

  // Puana göre yorum
  String _getComment(int score) {
    if (score >= 85) return "Ruh Eşisin! 🔥";
    if (score >= 60) return "Harika Uyum! ✨";
    if (score >= 40) return "İyi Anlaşırsınız 👍";
    return "Zıt Kutuplar ⚡";
  }
}