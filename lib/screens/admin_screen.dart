import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;

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

  String _secilenKategori = "Yemek & İçecek"; 
  final List<String> _kategoriler = [
    "Yemek & İçecek", "Spor", "Sinema & Dizi", "Müzik", "Oyun",
    "Fenomenler", "Teknoloji", "Markalar", "Genel", "Diğer"
  ];

  List<Map<String, dynamic>> _eklenenSecenekler = [];
  bool _isLoading = false;

  bool _isEvent = false;
  DateTime? _eventDate;

  @override
  void dispose() {
    _testBaslikController.dispose();
    _secenekIsimController.dispose();
    super.dispose();
  }

  // --- RESİM SEÇME ---
  Future<void> _resimSec() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        var bytes = await image.readAsBytes();
        
        // Boyut kontrolü (5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Resim 5MB'dan küçük olmalı")),
            );
          }
          return;
        }
        
        setState(() => _secilenResimBytes = bytes);
        _resmiStorageYukle(bytes, image.name);
      }
    } catch (e) {
      if (kDebugMode) print("Resim seçme hatası: $e");
    }
  }

  // --- RESİM YÜKLEME ---
  Future<void> _resmiStorageYukle(Uint8List bytes, String dosyaAdi) async { 
    setState(() => _resimYukleniyor = true);
    
    try {
      String temizDosyaAdi = 'resim_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String yol = 'test_resimleri/$temizDosyaAdi';
      Reference ref = FirebaseStorage.instance.ref().child(yol);
      
      String base64String = base64Encode(bytes);
      String dataUrl = 'data:image/jpeg;base64,$base64String';

      UploadTask uploadTask = ref.putString(
        dataUrl, 
        format: PutStringFormat.dataUrl,
        metadata: SettableMetadata(contentType: 'image/jpeg')
      ); 
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _yuklenenResimUrl = downloadUrl;
          _resimYukleniyor = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resim yüklendi! ✅"), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (kDebugMode) print("Yükleme hatası: $e");
      if (mounted) {
        setState(() => _resimYukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- LİSTEYE EKLEME ---
  void _secenekEkle() {
    if (_secenekIsimController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seçenek ismi gerekli")),
      );
      return;
    }
    
    if (_yuklenenResimUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Resim yüklemeniz gerekli")),
      );
      return;
    }

    setState(() {
      _eklenenSecenekler.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'isim': _secenekIsimController.text.trim(),
        // 🔴 DÜZELTİLDİ: Artık 'resimUrl' kullanılıyor (models.dart ile uyumlu)
        'resimUrl': _yuklenenResimUrl,
        'secilmeSayisi': 0,
      });
      _secenekIsimController.clear();
      _secilenResimBytes = null;
      _yuklenenResimUrl = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${_eklenenSecenekler.length}. seçenek eklendi"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- ANAHTAR KELİMELER ---
  List<String> _anahtarKelimeUret(String baslik) {
    List<String> kelimeler = baslik.toLowerCase().split(' ');
    kelimeler.removeWhere((k) => k.isEmpty || k.length < 2);
    kelimeler.add(baslik.toLowerCase());
    return kelimeler.toSet().toList(); // Tekrarları kaldır
  }

  // --- TARİH SEÇİCİ ---
  Future<void> _tarihSec() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF5A5F),
              surface: Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFFF5A5F),
                surface: Color(0xFF1C1C1E),
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (time != null) {
        setState(() {
          _eventDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  // --- TESTİ YAYINLA ---
  Future<void> _testiKaydet() async {
    // Validasyonlar
    if (_testBaslikController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test başlığı gerekli"), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (_eklenenSecenekler.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("En az 2 seçenek eklemelisiniz"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isEvent && _eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Etkinlik tarihini seçmelisiniz!"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> searchKeywords = _anahtarKelimeUret(_testBaslikController.text);
      String kapakResmi = _eklenenSecenekler.isNotEmpty 
          ? _eklenenSecenekler[0]['resimUrl'] ?? ''
          : "";

      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('testler').add({
        'baslik': _testBaslikController.text.trim(),
        'aktif_mi': true,
        'olusturulma_tarihi': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'secenekler': _eklenenSecenekler,
        'category': _secilenKategori,
        'kapakResmi': kapakResmi,
        'playCount': 0,
        'searchKeywords': searchKeywords,
        'createdBy': 'admin',
        'olusturanId': currentUserId,
        'isEvent': _isEvent,
        'eventDate': _isEvent && _eventDate != null 
            ? Timestamp.fromDate(_eventDate!) 
            : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Test başarıyla yayınlandı!"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Formu temizle
        setState(() {
          _testBaslikController.clear();
          _eklenenSecenekler.clear();
          _isEvent = false;
          _eventDate = null;
          _secilenKategori = "Yemek & İçecek";
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TESTİ ONAYLA
  void _testiOnayla(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('testler')
          .doc(docId)
          .update({'aktif_mi': true});
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Test onaylandı ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // TESTİ SİL
  void _testiSil(String docId) async {
    // Onay dialogu
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Testi Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu testi silmek istediğinize emin misiniz?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('testler').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Test silindi"), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        title: const Text("Admin Paneli", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            const Text(
              "Yeni Test Oluştur",
              style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // TEST BAŞLIĞI
            _buildTextField(_testBaslikController, "Test Başlığı"),
            const SizedBox(height: 15),

            // KATEGORİ SEÇİMİ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonFormField<String>(
                value: _secilenKategori,
                dropdownColor: const Color(0xFF1C1C1E),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: "Kategori",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.white),
                items: _kategoriler.map((k) => DropdownMenuItem(
                  value: k, 
                  child: Text(k),
                )).toList(),
                onChanged: (val) => setState(() => _secilenKategori = val!),
              ),
            ),

            const SizedBox(height: 30),
            
            // SEÇENEK EKLEME BÖLÜMÜ
            const Text(
              "Seçenek Ekle",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                // Seçenek ismi
                Expanded(
                  child: _buildTextField(_secenekIsimController, "Seçenek ismi"),
                ),
                const SizedBox(width: 10),
                
                // Resim seçme
                GestureDetector(
                  onTap: _resimSec,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _yuklenenResimUrl != null ? Colors.green : Colors.grey,
                      ),
                      image: _secilenResimBytes != null 
                          ? DecorationImage(image: MemoryImage(_secilenResimBytes!), fit: BoxFit.cover) 
                          : null,
                    ),
                    child: _resimYukleniyor 
                        ? const Center(child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Color(0xFFFF5A5F), strokeWidth: 2),
                          ))
                        : (_secilenResimBytes == null 
                            ? const Icon(Icons.add_a_photo, color: Colors.grey) 
                            : null),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            
            // Listeye Ekle butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_resimYukleniyor || _yuklenenResimUrl == null) ? null : _secenekEkle,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Listeye Ekle", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  disabledBackgroundColor: Colors.grey[900],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // EKLENENLER LİSTESİ
            if (_eklenenSecenekler.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Eklenecekler (${_eklenenSecenekler.length})",
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
                return Card(
                  color: const Color(0xFF1C1C1E),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item['resimUrl'] ?? '',
                        width: 50, height: 50, 
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 50, height: 50,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(item['isim'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text("Seçenek ${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _eklenenSecenekler.removeAt(index)),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 30),

            // ETKİNLİK AYARLARI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isEvent ? Colors.amber : Colors.transparent),
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
                      "Ana sayfada 'Günün Etkinliği' olarak görünür",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    value: _isEvent,
                    onChanged: (val) => setState(() => _isEvent = val),
                  ),
                  if (_isEvent) ...[
                    const Divider(color: Colors.grey),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Colors.amber),
                      title: Text(
                        _eventDate == null 
                            ? "Başlangıç Tarihi Seçiniz" 
                            : "${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year} - ${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2,'0')}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      onTap: _tarihSec,
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // YAYINLA BUTONU
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testiKaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A5F),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "TESTİ YAYINLA",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      ),
              ),
            ),

            // --- ONAY BEKLEYEN TESTLER ---
            const SizedBox(height: 60),
            const Divider(color: Colors.grey),
            const SizedBox(height: 20),
            
            const Text(
              "Onay Bekleyen Testler",
              style: TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('testler')
                  .where('aktif_mi', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 10),
                        Text("Onay bekleyen test yok", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    var secenekler = data['secenekler'] as List? ?? [];
                    String kapak = "";
                    if (secenekler.isNotEmpty) {
                      kapak = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'] ?? "";
                    }

                    return Card(
                      color: const Color(0xFF1C1C1E),
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kapak.isNotEmpty
                                      ? Image.network(
                                          kapak,
                                          width: 60, height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 60, height: 60,
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          ),
                                        )
                                      : Container(
                                          width: 60, height: 60,
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.quiz, color: Colors.grey),
                                        ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['baslik'] ?? 'İsimsiz',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Kategori: ${data['category'] ?? 'Genel'}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      Text(
                                        "Seçenek: ${secenekler.length}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _testiSil(doc.id),
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  label: const Text("Reddet", style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: () => _testiOnayla(doc.id),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                  label: const Text("Onayla", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }
}