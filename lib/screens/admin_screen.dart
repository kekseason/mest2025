import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _testBaslikController = TextEditingController();
  final _secenekIsimController = TextEditingController();
  
  Uint8List? _secilenResimBytes;
  String? _yuklenenResimUrl;
  bool _resimYukleniyor = false;

  bool _isAiLoading = false;
  
  final String _geminiApiKey = "AIzaSyCPiZt49jTFI-eUFwWe2O4sYFNT02wuuJc"; 
  final String _googleApiKey = "AIzaSyAxE7quwjIzMwWxaabVMN2pkHRNKan_BiU"; 
  final String _searchEngineId = "d542295c561dd4ffc"; 

  int _aiOptionCount = 32;

  String _secilenKategori = "Yemek & İçecek"; 
  final List<String> _kategoriler = [
    "Yemek & İçecek", "Spor", "Sinema & Dizi", "Müzik", "Oyun",
    "Fenomenler", "Teknoloji", "Markalar", "Genel", "Diğer"
  ];

  List<Map<String, dynamic>> _eklenenSecenekler = [];
  bool _isLoading = false;
  bool _isEvent = false;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;

  // Progress tracking
  String _progressText = "";
  Set<String> _usedNames = {}; // Tekrar eden isimleri engelle

  @override
  void dispose() {
    _testBaslikController.dispose();
    _secenekIsimController.dispose();
    super.dispose();
  }

  // --- AI'DAN SEÇENEK LİSTESİ AL ---
  Future<List<Map<String, String>>> _getOptionsFromAI(String konu, int adet, Set<String> excludeNames) async {
    String excludeText = "";
    if (excludeNames.isNotEmpty) {
      excludeText = "\n\nDİKKAT: Şu isimleri KULLANMA (zaten eklendi): ${excludeNames.join(', ')}";
    }

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey');
    
    final prompt = '''
Bana "$konu" konusuyla ilgili EN POPÜLER $adet adet seçenek listele.

ÖNEMLİ KURALLAR:
1. Sadece JSON formatında cevap ver, başka hiçbir şey yazma
2. "arama_terimi" Google Görseller'de KESİNLİKLE sonuç verecek şekilde olsun
3. Genel ve popüler terimler kullan (örn: "Adana Kebab turkish food", "Baklava dessert")
4. Çok niş veya yerel isimler kullanma$excludeText

Format:
[
  {"isim": "Seçenek Adı", "arama_terimi": "arama terimi for google images"},
]
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [{"parts": [{"text": prompt}]}]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("AI Hatası: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);
    String aiText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "";

    if (aiText.isEmpty) throw Exception("AI boş cevap döndürdü");

    String cleanJson = aiText.replaceAll('```json', '').replaceAll('```', '').trim();
    List<dynamic> jsonList = jsonDecode(cleanJson);

    return jsonList.map<Map<String, String>>((item) => {
      'isim': (item['isim'] ?? item['name'] ?? 'Seçenek').toString(),
      'arama': (item['arama_terimi'] ?? item['search_term'] ?? item['isim'] ?? '').toString(),
    }).toList();
  }

  // --- GOOGLE'DAN RESİM BUL ---
  Future<String?> _findImage(String query) async {
    try {
      // Farklı arama varyasyonları dene
      List<String> queries = [
        query,
        "$query photo",
        "$query image",
      ];

      for (String q in queries) {
        final url = Uri.parse(
          'https://www.googleapis.com/customsearch/v1'
          '?q=${Uri.encodeComponent(q)}'
          '&cx=$_searchEngineId'
          '&key=$_googleApiKey'
          '&searchType=image'
          '&num=5'
          '&safe=active'
          '&imgType=photo'
          '&imgSize=large'
        );
        
        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          
          if (data['items'] != null && data['items'].isNotEmpty) {
            for (var item in data['items']) {
              String imageUrl = item['link'] ?? '';
              
              // Geçersiz URL'leri atla
              if (imageUrl.isEmpty) continue;
              if (imageUrl.contains('x-raw-image')) continue;
              if (imageUrl.contains('encrypted-tbn')) continue;
              if (!imageUrl.startsWith('http')) continue;
              
              // URL çalışıyor mu kontrol et
              bool isValid = await _checkImageUrl(imageUrl);
              if (isValid) {
                return imageUrl;
              }
            }
          }
        } else if (response.statusCode == 429) {
          print("Google API kotası doldu!");
          return null;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Resim arama hatası: $e");
    }
    
    return null;
  }

  // --- URL GEÇERLİ Mİ KONTROL ET ---
  Future<bool> _checkImageUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
      String? contentType = response.headers['content-type'];
      return response.statusCode == 200 && (contentType?.contains('image') ?? false);
    } catch (e) {
      return false;
    }
  }

  // --- ANA FONKSİYON: OTOMATİK DOLDUR ---
  Future<void> _otomatikDoldur() async {
    if (_testBaslikController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce bir konu başlığı yazın!"))
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _progressText = "AI'dan seçenekler alınıyor...";
      _usedNames.clear();
    });

    try {
      String konu = _testBaslikController.text.trim();
      int hedefSayi = _aiOptionCount;
      List<Map<String, dynamic>> basariliSecenekler = [];
      int maxDeneme = 3; // Maksimum kaç tur alternatif isteyeceğiz
      int denemeSayisi = 0;

      while (basariliSecenekler.length < hedefSayi && denemeSayisi < maxDeneme) {
        denemeSayisi++;
        int kalanAdet = hedefSayi - basariliSecenekler.length;
        
        // Fazladan seçenek iste (bazıları başarısız olabilir diye)
        int istenenAdet = denemeSayisi == 1 ? kalanAdet : (kalanAdet * 1.5).ceil();
        istenenAdet = istenenAdet.clamp(1, 100); // Max 100

        if (mounted) {
          setState(() {
            _progressText = denemeSayisi == 1 
                ? "AI'dan $istenenAdet seçenek alınıyor..."
                : "Eksik seçenekler için alternatif alınıyor ($kalanAdet kaldı)...";
          });
        }

        // AI'dan seçenek listesi al
        List<Map<String, String>> aiSecenekler = await _getOptionsFromAI(konu, istenenAdet, _usedNames);

        // Her seçenek için resim bul
        for (int i = 0; i < aiSecenekler.length && basariliSecenekler.length < hedefSayi; i++) {
          String isim = aiSecenekler[i]['isim']!;
          String aramaTerimi = aiSecenekler[i]['arama']!;

          // Zaten eklenmişse atla
          if (_usedNames.contains(isim.toLowerCase())) continue;

          if (mounted) {
            setState(() {
              _progressText = "${basariliSecenekler.length + 1}/$hedefSayi: $isim için resim aranıyor...";
            });
          }

          // Resim bul
          String? imageUrl = await _findImage(aramaTerimi);

          if (imageUrl != null) {
            // Başarılı - listeye ekle
            basariliSecenekler.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString() + isim.hashCode.toString(),
              'isim': isim,
              'resimUrl': imageUrl,
              'secilmeSayisi': 0,
            });
            _usedNames.add(isim.toLowerCase());
            
            if (mounted) {
              setState(() {
                _eklenenSecenekler = List.from(basariliSecenekler);
              });
            }
          } else {
            // Başarısız - bu ismi kullanılmış say (tekrar denemesin)
            _usedNames.add(isim.toLowerCase());
            print("❌ Resim bulunamadı: $isim");
          }

          // Rate limit için kısa bekleme
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Yeterli seçenek toplandıysa çık
        if (basariliSecenekler.length >= hedefSayi) break;
      }

      // Sonuç
      if (mounted) {
        setState(() {
          _eklenenSecenekler = basariliSecenekler;
          _progressText = "";
        });

        String mesaj;
        if (basariliSecenekler.length >= hedefSayi) {
          mesaj = "✅ $hedefSayi seçenek başarıyla oluşturuldu!";
        } else {
          mesaj = "⚠️ ${basariliSecenekler.length}/$hedefSayi seçenek oluşturuldu";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mesaj), 
            backgroundColor: basariliSecenekler.length >= hedefSayi ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          )
        );
      }

    } catch (e) {
      print("HATA: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _progressText = "";
        });
      }
    }
  }

  // --- RESİM SEÇME (MANUEL) ---
  Future<void> _resimSec() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 1024, 
        maxHeight: 1024, 
        imageQuality: 80
      );
      if (image != null) {
        var bytes = await image.readAsBytes();
        setState(() => _secilenResimBytes = bytes);
        _resmiStorageYukle(bytes, image.name);
      }
    } catch (e) {
      print("Resim seçme hatası: $e");
    }
  }

  // --- RESİM YÜKLEME ---
  Future<void> _resmiStorageYukle(Uint8List bytes, String dosyaAdi) async { 
    setState(() => _resimYukleniyor = true);
    try {
      String fileName = 'test_resimleri/resim_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      
      UploadTask uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (mounted) {
        setState(() { 
          _yuklenenResimUrl = downloadUrl; 
          _resimYukleniyor = false; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resim yüklendi! ✅"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      print("Resim yükleme hatası: $e");
      if(mounted) {
        setState(() => _resimYukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Resim yüklenemedi: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- MANUEL EKLEME ---
  void _secenekEkle() {
    if (_secenekIsimController.text.trim().isEmpty || _yuklenenResimUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İsim ve Resim gerekli!")));
      return;
    }
    setState(() {
      _eklenenSecenekler.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'isim': _secenekIsimController.text.trim(),
        'resimUrl': _yuklenenResimUrl,
        'secilmeSayisi': 0,
      });
      _secenekIsimController.clear(); 
      _secilenResimBytes = null; 
      _yuklenenResimUrl = null;
    });
  }
  
  // --- ANAHTAR KELİME ---
  List<String> _anahtarKelimeUret(String baslik) {
    List<String> kelimeler = baslik.toLowerCase().split(' ');
    kelimeler.removeWhere((k) => k.isEmpty || k.length < 2);
    kelimeler.add(baslik.toLowerCase());
    return kelimeler.toSet().toList();
  }

  // --- KAYDET ---
  Future<void> _testiKaydet() async {
    if (_testBaslikController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test başlığı gerekli!"), backgroundColor: Colors.orange)
      );
      return;
    }
    
    if (_eklenenSecenekler.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("En az 2 seçenek gerekli!"), backgroundColor: Colors.orange)
      );
      return;
    }

    if (_isEvent && _eventStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Etkinlik için başlangıç tarihi seçin!"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? kapakResmi = _eklenenSecenekler[0]['resimUrl'];

      Map<String, dynamic> testData = {
        'baslik': _testBaslikController.text.trim(),
        'aktif_mi': true,
        'olusturulma_tarihi': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'secenekler': _eklenenSecenekler,
        'category': _secilenKategori,
        'kategori': _secilenKategori.toLowerCase().replaceAll(' & ', '_').replaceAll(' ', '_'),
        'kapakResmi': kapakResmi,
        'playCount': 0,
        'searchKeywords': _anahtarKelimeUret(_testBaslikController.text),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'olusturanAdi': 'Admin',
        'isEventTest': _isEvent,
        'isVerified': true,
      };

      if (_isEvent) {
        testData['eventStartTime'] = Timestamp.fromDate(_eventStartDate!);
        testData['eventEndTime'] = _eventEndDate != null 
            ? Timestamp.fromDate(_eventEndDate!) 
            : Timestamp.fromDate(_eventStartDate!.add(const Duration(hours: 24)));
      }

      DocumentReference docRef = await FirebaseFirestore.instance.collection('testler').add(testData);

      if (_isEvent) {
        await FirebaseFirestore.instance.collection('events').add({
          'title': _testBaslikController.text.trim(),
          'description': '${_eklenenSecenekler.length} seçenekli test',
          'testId': docRef.id,
          'startTime': Timestamp.fromDate(_eventStartDate!),
          'endTime': _eventEndDate != null 
              ? Timestamp.fromDate(_eventEndDate!) 
              : Timestamp.fromDate(_eventStartDate!.add(const Duration(hours: 24))),
          'imageUrl': kapakResmi,
          'participants': [],
          'status': 'active',
          'isConverted': false,
          'notifiedStart': false,
          'notifiedEnding': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEvent ? "✅ Etkinlik testi yayınlandı!" : "✅ Test yayınlandı!"), 
            backgroundColor: Colors.green,
          )
        );
        
        setState(() { 
          _testBaslikController.clear(); 
          _eklenenSecenekler.clear();
          _isEvent = false;
          _eventStartDate = null;
          _eventEndDate = null;
          _usedNames.clear();
        });
      }
    } catch (e) {
      print("Kaydetme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
        );
      }
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  // --- SİLME ---
  void _testiSil(String docId) async {
    bool? confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text("Sil?", style: TextStyle(color: Colors.white)),
      content: const Text("Bu test kalıcı olarak silinecek.", style: TextStyle(color: Colors.grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("İptal")),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true), 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
          child: const Text("Sil", style: TextStyle(color: Colors.white))
        ),
      ],
    ));
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('testler').doc(docId).delete();
    }
  }

  // --- TARİH SEÇİCİLER ---
  Future<void> _baslangicTarihiSec() async {
    DateTime? picked = await showDatePicker(
      context: context, 
      initialDate: DateTime.now(), 
      firstDate: DateTime.now(), 
      lastDate: DateTime(2030),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF5A5F), surface: Color(0xFF1C1C1E))), 
        child: child!
      )
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.now(),
        builder: (c, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF5A5F), surface: Color(0xFF1C1C1E))), 
          child: child!
        )
      );
      if (time != null) {
        setState(() => _eventStartDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  Future<void> _bitisTarihiSec() async {
    if (_eventStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce başlangıç tarihi seçin!")));
      return;
    }
    
    DateTime? picked = await showDatePicker(
      context: context, 
      initialDate: _eventStartDate!.add(const Duration(days: 1)), 
      firstDate: _eventStartDate!, 
      lastDate: DateTime(2030),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF5A5F), surface: Color(0xFF1C1C1E))), 
        child: child!
      )
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(
        context: context, 
        initialTime: const TimeOfDay(hour: 23, minute: 59),
        builder: (c, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF5A5F), surface: Color(0xFF1C1C1E))), 
          child: child!
        )
      );
      if (time != null) {
        setState(() => _eventEndDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  Widget _buildOptionButton(int value) {
    bool isSelected = _aiOptionCount == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _aiOptionCount = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4285F4) : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[800]!),
          ),
          child: Center(child: Text("$value", style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return "Seçilmedi";
    return "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        title: const Text("Admin Paneli", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Yeni Test Oluştur", style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            _buildTextField(_testBaslikController, "Test Başlığı (Örn: En İyi Türk Yemekleri)"),
            const SizedBox(height: 20),

            const Text("Kaç seçenek olsun?", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              _buildOptionButton(16), 
              const SizedBox(width: 10), 
              _buildOptionButton(32), 
              const SizedBox(width: 10), 
              _buildOptionButton(64)
            ]),
            const SizedBox(height: 15),

            // AI Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAiLoading ? null : _otomatikDoldur,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4), 
                  padding: const EdgeInsets.symmetric(vertical: 14), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                icon: _isAiLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isAiLoading ? "Oluşturuluyor..." : "AI ile $_aiOptionCount Seçenek Oluştur 🚀", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
            ),

            // Progress Text
            if (_progressText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_progressText, style: const TextStyle(color: Colors.amber, fontSize: 12)),
              ),

            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonFormField<String>(
                value: _secilenKategori, 
                dropdownColor: const Color(0xFF1C1C1E),
                decoration: const InputDecoration(border: InputBorder.none, labelText: "Kategori", labelStyle: TextStyle(color: Colors.grey)),
                style: const TextStyle(color: Colors.white),
                items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setState(() => _secilenKategori = val!),
              ),
            ),
            const SizedBox(height: 30),

            // --- MANUEL EKLEME ---
            const Text("Manuel Seçenek Ekle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildTextField(_secenekIsimController, "Seçenek ismi")),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _resimSec,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E), 
                      borderRadius: BorderRadius.circular(10), 
                      border: Border.all(color: _yuklenenResimUrl != null ? Colors.green : Colors.grey), 
                      image: _secilenResimBytes != null ? DecorationImage(image: MemoryImage(_secilenResimBytes!), fit: BoxFit.cover) : null
                    ),
                    child: _resimYukleniyor 
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F), strokeWidth: 2)) 
                        : (_secilenResimBytes == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_resimYukleniyor || _yuklenenResimUrl == null) ? null : _secenekEkle,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Listeye Ekle", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(height: 20),

            // --- LİSTE ---
            if (_eklenenSecenekler.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Text("Seçenekler (${_eklenenSecenekler.length}/$_aiOptionCount)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                  TextButton(
                    onPressed: () => setState(() => _eklenenSecenekler.clear()), 
                    child: const Text("Tümünü Sil", style: TextStyle(color: Colors.red))
                  )
                ]
              ),
              const SizedBox(height: 10),
              ...List.generate(_eklenenSecenekler.length, (index) {
                var item = _eklenenSecenekler[index];
                String imageUrl = item['resimUrl'] ?? '';
                
                return Card(
                  color: const Color(0xFF1C1C1E), 
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8), 
                      child: Image.network(
                        imageUrl, 
                        width: 50, 
                        height: 50, 
                        fit: BoxFit.cover, 
                        errorBuilder: (c, e, s) => Container(
                          width: 50, 
                          height: 50, 
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      )
                    ),
                    title: Text(item['isim'], style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red), 
                      onPressed: () => setState(() => _eklenenSecenekler.removeAt(index))
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 30),

            // --- ETKİNLİK AYARLARI ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E), 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: _isEvent ? Colors.amber : Colors.transparent, width: 2)
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber, 
                    contentPadding: EdgeInsets.zero, 
                    title: const Text("Bu bir Etkinlik Testi mi?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                    subtitle: const Text("Belirli saatler arasında çözülebilir", style: TextStyle(color: Colors.grey, fontSize: 12)), 
                    value: _isEvent, 
                    onChanged: (val) => setState(() {
                      _isEvent = val;
                      if (!val) { _eventStartDate = null; _eventEndDate = null; }
                    })
                  ),
                  if (_isEvent) ...[
                    const Divider(color: Colors.grey),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_arrow, color: Colors.green),
                      title: const Text("Başlangıç", style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(_formatDateTime(_eventStartDate), style: TextStyle(color: _eventStartDate != null ? Colors.green : Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      onTap: _baslangicTarihiSec,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop, color: Colors.red),
                      title: const Text("Bitiş", style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(_eventEndDate != null ? _formatDateTime(_eventEndDate) : "Başlangıçtan 24 saat sonra", style: TextStyle(color: _eventEndDate != null ? Colors.red : Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      onTap: _bitisTarihiSec,
                    ),
                  ]
                ]
              ),
            ),
            const SizedBox(height: 30),

            // --- YAYINLA BUTONU ---
            SizedBox(
              width: double.infinity, 
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testiKaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A5F), 
                  disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_isEvent ? "ETKİNLİK TESTİNİ YAYINLA" : "TESTİ YAYINLA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 40), 
            const Divider(color: Colors.grey), 
            const SizedBox(height: 20),
            
            const Text("Yayınlanan Testler", style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 15),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('testler')
                  .where('aktif_mi', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Henüz test yok", style: TextStyle(color: Colors.grey)));
                }
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(), 
                  itemCount: docs.length, 
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isEventTest = data['isEventTest'] ?? false;
                    int secenekSayisi = (data['secenekler'] as List?)?.length ?? 0;
                    
                    return Card(
                      color: const Color(0xFF1C1C1E), 
                      child: ListTile(
                        leading: isEventTest 
                            ? const Icon(Icons.event, color: Colors.amber)
                            : const Icon(Icons.quiz, color: Color(0xFFFF5A5F)),
                        title: Text(data['baslik'] ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text("$secenekSayisi seçenek", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _testiSil(docs[index].id))
                      )
                    );
                  }
                );
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint, 
        hintStyle: const TextStyle(color: Colors.grey), 
        filled: true, 
        fillColor: const Color(0xFF1C1C1E), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
      ),
    );
  }
}