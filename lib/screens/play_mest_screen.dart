import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'sonuc_screen.dart';

class PlayMestScreen extends StatefulWidget {
  final String testId; // Oynanacak testin ID'si

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

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  Future<void> _verileriGetir() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('testler').doc(widget.testId).get();
      if (doc.exists) {
        var veri = doc.data()!;
        List<dynamic> hamListe = veri['secenekler'] ?? [];
        List<Secenek> yeniListe = hamListe.map((e) => Secenek.fromMap(e)).toList();
        yeniListe.shuffle();

        if (mounted) {
          setState(() {
            testBasligi = veri['baslik'] ?? "Turnuva";
            aktifListe = yeniListe;
            yukleniyor = false;
            gelecekTurListesi.clear();
            secimGecmisiIDleri.clear();
            suankiIndex = 0;
          });
        }
      } else {
        if (mounted) setState(() { testBasligi = "Bulunamadı"; yukleniyor = false; });
      }
    } catch (e) {
      if (mounted) setState(() => yukleniyor = false);
    }
  }

  void secimYap(Secenek kazanan) {
    setState(() {
      gelecekTurListesi.add(kazanan);
      secimGecmisiIDleri.add(kazanan.id);
      suankiIndex += 2;

      if (suankiIndex >= aktifListe.length) {
        if (gelecekTurListesi.length == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SonucScreen(
                sampiyon: gelecekTurListesi[0],
                secimGecmisi: secimGecmisiIDleri,
              ),
            ),
          );
        } else {
          aktifListe = List.from(gelecekTurListesi);
          gelecekTurListesi.clear();
          suankiIndex = 0;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (yukleniyor) return Scaffold(backgroundColor: const Color(0xFF0D0D11), body: Center(child: CircularProgressIndicator(color: mainColor)));
    if (aktifListe.length < 2) return const Scaffold(backgroundColor: Color(0xFF0D0D11), body: Center(child: Text("Test verisi eksik.", style: TextStyle(color: Colors.white))));

    Secenek aday1 = aktifListe[suankiIndex];
    Secenek aday2 = aktifListe[suankiIndex + 1];

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
                  IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  Text(testBasligi, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () { setState(() => yukleniyor = true); _verileriGetir(); }),
                ],
              ),
            ),
            // Kartlar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => secimYap(aday1), child: _buildCard(aday1))),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(onTap: () => secimYap(aday2), child: _buildCard(aday2))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Secenek item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(image: NetworkImage(item.resimUrl), fit: BoxFit.cover),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.9)]),
        ),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.all(12),
        child: Text(item.isim, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
    );
  }
}