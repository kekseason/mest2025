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

const String CLOUD_FUNCTION_PROXY = 'https://imageproxy-n5yij6rjfq-ew.a.run.app';

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  // Controllers
  final _testBaslikController = TextEditingController();
  final _secenekIsimController = TextEditingController();
  final _customPromptController = TextEditingController();
  
   // --- ARAMA İÇİN ANAHTAR KELİME ÜRETİCİ ---
  List<String> _anahtarKelimeUret(String baslik) {
    List<String> kelimeler = baslik.toLowerCase().split(' ');
    // Boşlukları temizle ve listeye ekle
    kelimeler.removeWhere((k) => k.isEmpty);
    // Başlığın tamamını da ekle ki tam aramada çıksın
    kelimeler.add(baslik.toLowerCase());
    return kelimeler;
  }

  // Tab Controller
  late TabController _tabController;
  
  // State variables
  Uint8List? _secilenResimBytes;
  String? _yuklenenResimUrl;
  bool _resimYukleniyor = false;
  bool _isAiLoading = false;
  int _aiOptionCount = 32;
  String _secilenKategori = "Yemek & İçecek"; 
  List<Map<String, dynamic>> _eklenenSecenekler = [];
  bool _isLoading = false;
  bool _isEvent = false;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;
  String _progressText = "";
  Set<String> _usedNames = {}; 

  final List<String> _kategoriler = [
    "Yemek & İçecek", "Spor", "Sinema & Dizi", "Müzik", "Oyun",
    "Fenomenler", "Teknoloji", "Markalar", "Genel", "Diğer"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _testBaslikController.dispose();
    _secenekIsimController.dispose();
    _customPromptController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ============ AI TEST OLUŞTURMA ============
  Future<void> _otomatikDoldur() async {
    if (_testBaslikController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce bir konu başlığı yazın!"))
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _progressText = "Sunucu üzerinde AI ve Görsel Arama çalışıyor... (Lütfen bekleyin)";
      _usedNames.clear();
    });

    try {
      const String functionUrl = 'https://europe-west1-mest-8a3c7.cloudfunctions.net/generateAiTest';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "topic": _testBaslikController.text.trim(),
          "count": _aiOptionCount,
          "customPrompt": _customPromptController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> gelenVeri = jsonResponse['data'];
          
          List<Map<String, dynamic>> yeniSecenekler = [];
          
          for (var item in gelenVeri) {
            yeniSecenekler.add(Map<String, dynamic>.from(item));
          }

          setState(() {
            _eklenenSecenekler = yeniSecenekler;
            _progressText = "";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ ${yeniSecenekler.length} seçenek sunucudan geldi! 🚀"), 
              backgroundColor: Colors.green
            )
          );
        } else {
          throw Exception("Sunucu işlemi tamamlayamadı.");
        }
      } else {
        throw Exception("Sunucu Hatası (${response.statusCode}): ${response.body}");
      }

    } catch (e) {
      print("AI HATA: $e");
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

  // ============ RESİM SEÇME ============
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

  // ============ RESİM YÜKLEME ============
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

  // ============ MANUEL SEÇENEK EKLEME ============
  void _secenekEkle() {
    if (_secenekIsimController.text.trim().isEmpty || _yuklenenResimUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İsim ve Resim gerekli!"))
      );
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
      _yuklenenResimUrl = null;
      _secilenResimBytes = null;
    });
  }
String _generateStandardCategoryId(String categoryName) {
    switch (categoryName) {
      case "Yemek & İçecek": return "yemek_icecek";
      case "Spor": return "spor";
      case "Sinema & Dizi": return "sinema_dizi";
      case "Müzik": return "muzik";
      case "Oyun": return "oyun";
      case "Fenomenler": return "fenomenler";
      case "Teknoloji": return "teknoloji";
      case "Markalar": return "markalar";
      case "Genel": return "genel";
      case "Diğer": return "diger";
      // Listede olmayan bir şey gelirse:
      default: return categoryName.toLowerCase()
          .replaceAll(' & ', '_')
          .replaceAll(' ', '_')
          .replaceAll('ç', 'c')
          .replaceAll('ğ', 'g')
          .replaceAll('ı', 'i')
          .replaceAll('ö', 'o')
          .replaceAll('ş', 's')
          .replaceAll('ü', 'u');
    }
  }
  // ============ TEST KAYDETME ============
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
      String? kapakResmi = _eklenenSecenekler.isNotEmpty ? _eklenenSecenekler[0]['resimUrl'] : null;

      // 🔥 KRİTİK DÜZELTME BURADA 🔥
      // Seçilen kategoriyi (Örn: "Yemek & İçecek") standart ID'ye (Örn: "yemek_icecek") çeviriyoruz.
      String kategoriId = _generateStandardCategoryId(_secilenKategori);

      Map<String, dynamic> testData = {
        'baslik': _testBaslikController.text.trim(),
        'aktif_mi': true,
        'olusturulma_tarihi': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'secenekler': _eklenenSecenekler,
        
        // GÖRÜNEN İSİM (Ekranda düzgün görünsün)
        'category': _secilenKategori, 
        
        // SORGULANAN ID (Kodun çalışması için bu standart olmalı)
        'kategori': kategoriId, 
        
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

  // ============ TARİH SEÇME ============
  Future<void> _baslangicTarihiSec() async {
    final DateTime? tarih = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (tarih != null) {
      final TimeOfDay? saat = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (saat != null) {
        setState(() {
          _eventStartDate = DateTime(
            tarih.year, tarih.month, tarih.day,
            saat.hour, saat.minute,
          );
        });
      }
    }
  }

  Future<void> _bitisTarihiSec() async {
    if (_eventStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce başlangıç tarihi seçin!"))
      );
      return;
    }

    final DateTime? tarih = await showDatePicker(
      context: context,
      initialDate: _eventStartDate!,
      firstDate: _eventStartDate!,
      lastDate: _eventStartDate!.add(const Duration(days: 30)),
    );
    
    if (tarih != null) {
      final TimeOfDay? saat = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (saat != null) {
        setState(() {
          _eventEndDate = DateTime(
            tarih.year, tarih.month, tarih.day,
            saat.hour, saat.minute,
          );
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "Seçilmedi";
    return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // ============ TEST SİLME ============
  Future<void> _testiSil(String testId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Testi Sil", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bu testi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('testler').doc(testId).delete();
        
        // İlişkili etkinliği de sil
        final eventQuery = await FirebaseFirestore.instance
            .collection('events')
            .where('testId', isEqualTo: testId)
            .get();
        
        for (var doc in eventQuery.docs) {
          await doc.reference.delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Test silindi ✅"), backgroundColor: Colors.green)
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silme hatası: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // ============ KULLANICI TESTİ ONAYLAMA ============
  Future<void> _kullaniciTestiniOnayla(String testId, Map<String, dynamic> testData) async {
    try {
      // Testi testler collection'a taşı
      await FirebaseFirestore.instance.collection('testler').add({
        ...testData,
        'aktif_mi': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
        'status': 'approved',
      });

      // pending_tests'ten güncelle
      await FirebaseFirestore.instance.collection('pending_tests').doc(testId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test onaylandı ve yayınlandı! ✅"), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Onaylama hatası: $e"), backgroundColor: Colors.red)
      );
    }
  }

  // ============ KULLANICI TESTİ REDDETME ============
  Future<void> _kullaniciTestiniReddet(String testId) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Testi Reddet", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Red sebebini yazın (kullanıcıya bildirilecek):",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Örn: Resimler uygun değil, başlık çok genel...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text("Reddet", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('pending_tests').doc(testId).update({
          'status': 'rejected',
          'rejectionReason': result,
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Test reddedildi"), backgroundColor: Colors.orange)
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Red hatası: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // ============ KULLANICI TESTİ DETAY ============
  void _kullaniciTestiDetayGoster(Map<String, dynamic> testData) {
    final secenekler = testData['secenekler'] as List<dynamic>? ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      testData['baslik'] ?? 'Test',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${secenekler.length} seçenek",
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Kategori ve Oluşturan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.category, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    testData['kategori'] ?? 'Genel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.person, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(testData['createdBy'])
                        .get(),
                    builder: (context, snapshot) {
                      final userName = snapshot.data?.data() != null
                          ? (snapshot.data!.data() as Map)['name'] ?? 'Bilinmiyor'
                          : 'Bilinmiyor';
                      return Text(
                        userName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            // Seçenekler Listesi
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: secenekler.length,
                itemBuilder: (context, index) {
                  final secenek = secenekler[index];
                  return Card(
                    color: const Color(0xFF2C2C2E),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          secenek['resimUrl'] ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[800],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      title: Text(
                        secenek['isim'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        "#${index + 1}",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Admin Panel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF5A5F),
          labelColor: const Color(0xFFFF5A5F),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: "Oluştur"),
            Tab(icon: Icon(Icons.list_alt), text: "Yayında"),
            Tab(icon: Icon(Icons.pending_actions), text: "Bekleyen"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildPublishedTab(),
          _buildPendingTab(),
        ],
      ),
    );
  }

  // ============ TAB 1: TEST OLUŞTUR ============
  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          const Text(
            "🎯 Yeni Test Oluştur",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Test Başlığı
          _buildTextField(_testBaslikController, "Test Başlığı (örn: En İyi Türk Yemekleri)"),
          const SizedBox(height: 15),

          // Özel Prompt (YENİ)
          TextField(
            controller: _customPromptController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Özel talimat (opsiyonel)\nÖrn: Sadece 2000 sonrası filmler olsun, animasyon hariç",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.auto_awesome, color: Colors.amber),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Kategori Seçimi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _secilenKategori,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white),
                items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setState(() => _secilenKategori = val!),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Seçenek Sayısı
          Row(
            children: [
              const Text("Seçenek Sayısı: ", style: TextStyle(color: Colors.white)),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: _aiOptionCount,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white),
                items: [8, 16, 24, 32, 48, 64]
                    .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
                    .toList(),
                onChanged: (val) => setState(() => _aiOptionCount = val!),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // AI Doldur Butonu
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isAiLoading ? null : _otomatikDoldur,
              icon: _isAiLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                _isAiLoading ? "AI Çalışıyor..." : "🤖 AI ile Otomatik Doldur",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_progressText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_progressText, style: const TextStyle(color: Colors.amber, fontSize: 12)),
          ],

          const SizedBox(height: 30),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),

          // Manuel Ekleme
          const Text("📝 Manuel Seçenek Ekle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(_secenekIsimController, "Seçenek İsmi"),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _resimSec,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: _resimYukleniyor
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F), strokeWidth: 2))
                      : _secilenResimBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(_secilenResimBytes!, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.add_a_photo, color: Colors.grey),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Eklenen Seçenekler Listesi
          if (_eklenenSecenekler.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Seçenekler (${_eklenenSecenekler.length}/$_aiOptionCount)",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _eklenenSecenekler.clear()),
                  child: const Text("Tümünü Sil", style: TextStyle(color: Colors.red)),
                ),
              ],
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
                      ),
                    ),
                  ),
                  title: Text(item['isim'], style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _eklenenSecenekler.removeAt(index)),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 30),

          // Etkinlik Ayarları
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEvent ? Colors.amber : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: Colors.amber,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Bu bir Etkinlik Testi mi?",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Belirli saatler arasında çözülebilir",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _isEvent,
                  onChanged: (val) => setState(() {
                    _isEvent = val;
                    if (!val) {
                      _eventStartDate = null;
                      _eventEndDate = null;
                    }
                  }),
                ),
                if (_isEvent) ...[
                  const Divider(color: Colors.grey),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow, color: Colors.green),
                    title: const Text("Başlangıç", style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      _formatDateTime(_eventStartDate),
                      style: TextStyle(color: _eventStartDate != null ? Colors.green : Colors.grey),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: _baslangicTarihiSec,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop, color: Colors.red),
                    title: const Text("Bitiş", style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      _eventEndDate != null ? _formatDateTime(_eventEndDate) : "Başlangıçtan 24 saat sonra",
                      style: TextStyle(color: _eventEndDate != null ? Colors.red : Colors.grey),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: _bitisTarihiSec,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Yayınla Butonu
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _testiKaydet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A5F),
                disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _isEvent ? "ETKİNLİK TESTİNİ YAYINLA" : "TESTİ YAYINLA",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // ============ TAB 2: YAYINDA OLAN TESTLER ============
  Widget _buildPublishedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('testler')
          .where('aktif_mi', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[700]),
                const SizedBox(height: 16),
                const Text(
                  "Henüz yayında test yok",
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bool isEventTest = data['isEventTest'] ?? false;
            final int secenekSayisi = (data['secenekler'] as List?)?.length ?? 0;
            final int oynayanSayisi = data['oynayanSayisi'] ?? 0;
            final Timestamp? createdAt = data['createdAt'];

            return Card(
              color: const Color(0xFF1C1C1E),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isEventTest ? Colors.amber.withOpacity(0.5) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () => _kullaniciTestiDetayGoster(data),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // İkon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isEventTest 
                              ? Colors.amber.withOpacity(0.2)
                              : const Color(0xFFFF5A5F).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEventTest ? Icons.event : Icons.quiz,
                          color: isEventTest ? Colors.amber : const Color(0xFFFF5A5F),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bilgiler
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['baslik'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.grid_view, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  "$secenekSayisi seçenek",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  "$oynayanSayisi oynayan",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(createdAt.toDate()),
                                style: TextStyle(color: Colors.grey[700], fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Sil Butonu
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _testiSil(doc.id),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============ TAB 3: BEKLEYEN KULLANICI TESTLERİ ============
  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_tests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pending_actions_outlined, size: 80, color: Colors.grey[700]),
                const SizedBox(height: 16),
                const Text(
                  "Bekleyen test yok",
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Kullanıcılar test oluşturduğunda\nburada görünecek",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final int secenekSayisi = (data['secenekler'] as List?)?.length ?? 0;
            final String createdBy = data['createdBy'] ?? '';
            final Timestamp? createdAt = data['createdAt'];

            return Card(
              color: const Color(0xFF1C1C1E),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.withOpacity(0.5), width: 1),
              ),
              child: InkWell(
                onTap: () => _kullaniciTestiDetayGoster(data),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık ve Bilgiler
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.pending, color: Colors.orange, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['baslik'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.grid_view, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$secenekSayisi seçenek",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.category, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      data['kategori'] ?? 'Genel',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Oluşturan Kullanıcı
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(createdBy).get(),
                        builder: (context, userSnapshot) {
                          String userName = 'Bilinmiyor';
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            userName = userData['name'] ?? 'Bilinmiyor';
                          }
                          return Row(
                            children: [
                              Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                userName,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              const Spacer(),
                              if (createdAt != null)
                                Text(
                                  _formatDateTime(createdAt.toDate()),
                                  style: TextStyle(color: Colors.grey[700], fontSize: 10),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Aksiyon Butonları
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _kullaniciTestiniReddet(doc.id),
                              icon: const Icon(Icons.close, color: Colors.red, size: 18),
                              label: const Text("Reddet", style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _kullaniciTestiniOnayla(doc.id, data),
                              icon: const Icon(Icons.check, color: Colors.white, size: 18),
                              label: const Text("Onayla", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}