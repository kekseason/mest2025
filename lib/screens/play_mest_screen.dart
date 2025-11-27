import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'sonuc_screen.dart';

class PlayMestScreen extends StatefulWidget {
  final String testId;

  const PlayMestScreen({super.key, required this.testId});

  @override
  State<PlayMestScreen> createState() => _PlayMestScreenState();
}

class _PlayMestScreenState extends State<PlayMestScreen> {
  final Color mainColor = const Color(0xFFFF5A5F);
  List<Secenek> aktifListe = [];
  bool yukleniyor = true;
  String testBasligi = "";
  List<Secenek> gelecekTurListesi = [];
  List<String> secimGecmisiIDleri = [];
  int suankiIndex = 0;
  
  // 🔴 HATA DÜZELTİLDİ: Tur bilgisi eklendi
  int mevcutTur = 1;
  int toplamTur = 0;

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  Future<void> _verileriGetir() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('testler')
          .doc(widget.testId)
          .get();
          
      if (doc.exists) {
        var veri = doc.data()!;
        List<dynamic> hamListe = veri['secenekler'] ?? [];
        List<Secenek> yeniListe = hamListe.map((e) => Secenek.fromMap(e)).toList();
        yeniListe.shuffle();

        // 🔴 HATA DÜZELTİLDİ: Seçenek sayısı kontrolü
        if (yeniListe.length < 2) {
          if (mounted) {
            setState(() {
              testBasligi = "Yetersiz Seçenek";
              yukleniyor = false;
            });
          }
          return;
        }

        // 🔴 YENİ: Seçenek sayısını 2'nin kuvvetine yuvarla (turnuva formatı için)
        int count = yeniListe.length;
        int validCount = 2;
        while (validCount * 2 <= count) {
          validCount *= 2;
        }
        yeniListe = yeniListe.take(validCount).toList();

        // Toplam tur hesapla
        int turSayisi = 0;
        int temp = validCount;
        while (temp > 1) {
          temp ~/= 2;
          turSayisi++;
        }

        if (mounted) {
          setState(() {
            testBasligi = veri['baslik'] ?? "Turnuva";
            aktifListe = yeniListe;
            yukleniyor = false;
            gelecekTurListesi.clear();
            secimGecmisiIDleri.clear();
            suankiIndex = 0;
            mevcutTur = 1;
            toplamTur = turSayisi;
          });
        }

        // 🔴 YENİ: PlayCount artır
        await FirebaseFirestore.instance
            .collection('testler')
            .doc(widget.testId)
            .update({'playCount': FieldValue.increment(1)});
            
      } else {
        if (mounted) {
          setState(() {
            testBasligi = "Test Bulunamadı";
            yukleniyor = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Test yükleme hatası: $e");
      if (mounted) {
        setState(() => yukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void secimYap(Secenek kazanan) {
    setState(() {
      gelecekTurListesi.add(kazanan);
      secimGecmisiIDleri.add(kazanan.id);
      suankiIndex += 2;

      // 🔴 HATA DÜZELTİLDİ: Index kontrolü
      if (suankiIndex >= aktifListe.length) {
        if (gelecekTurListesi.length == 1) {
          // Şampiyon belirlendi!
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SonucScreen(
                sampiyon: gelecekTurListesi[0],
                secimGecmisi: secimGecmisiIDleri,
                testId: widget.testId, // 🔴 YENİ: testId eklendi
              ),
            ),
          );
        } else {
          // Yeni tura geç
          aktifListe = List.from(gelecekTurListesi);
          gelecekTurListesi.clear();
          suankiIndex = 0;
          mevcutTur++;
        }
      }
    });
  }

  // Tur ismi belirleme
  String _getTurIsmi() {
    int kalanKisi = aktifListe.length;
    if (kalanKisi == 2) return "🏆 FİNAL";
    if (kalanKisi == 4) return "Yarı Final";
    if (kalanKisi == 8) return "Çeyrek Final";
    if (kalanKisi == 16) return "Son 16";
    return "Tur $mevcutTur";
  }

  @override
  Widget build(BuildContext context) {
    if (yukleniyor) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: mainColor),
              const SizedBox(height: 20),
              const Text("Test yükleniyor...", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (aktifListe.length < 2) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 80, color: mainColor),
              const SizedBox(height: 20),
              const Text(
                "Bu testte yeterli seçenek yok.",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                "En az 2 seçenek gerekli.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                child: const Text("Geri Dön", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // 🔴 HATA DÜZELTİLDİ: Index sınır kontrolü
    if (suankiIndex + 1 >= aktifListe.length) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        body: Center(
          child: CircularProgressIndicator(color: mainColor),
        ),
      );
    }

    Secenek aday1 = aktifListe[suankiIndex];
    Secenek aday2 = aktifListe[suankiIndex + 1];

    // Maç numarası hesaplama
    int macNo = (suankiIndex ~/ 2) + 1;
    int toplamMac = aktifListe.length ~/ 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: Column(
          children: [
            // Üst Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => _showExitDialog(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          testBasligi,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_getTurIsmi()} • Maç $macNo/$toplamMac",
                          style: TextStyle(color: mainColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      setState(() => yukleniyor = true);
                      _verileriGetir();
                    },
                  ),
                ],
              ),
            ),

            // İlerleme çubuğu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (mevcutTur - 1 + (macNo / toplamMac)) / toplamTur,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                  minHeight: 6,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // "Hangisini tercih edersin?" yazısı
            const Text(
              "Hangisini tercih edersin?",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const SizedBox(height: 10),

            // Kartlar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => secimYap(aday1),
                        child: _buildCard(aday1),
                      ),
                    ),
                    // VS yazısı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mainColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "VS",
                          style: TextStyle(
                            color: mainColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => secimYap(aday2),
                        child: _buildCard(aday2),
                      ),
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

  // Çıkış diyaloğu
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Çıkmak istediğine emin misin?", style: TextStyle(color: Colors.white)),
        content: const Text("İlerlemeniz kaydedilmeyecek.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // Ekrandan çık
            },
            style: ElevatedButton.styleFrom(backgroundColor: mainColor),
            child: const Text("Çık", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Secenek item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Resim
            Image.network(
              item.resimUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: const Color(0xFF1C1C1E),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: mainColor,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (c, e, s) => Container(
                color: const Color(0xFF1C1C1E),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      item.isim,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // İsim
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Text(
                  item.isim,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}