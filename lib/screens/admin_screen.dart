import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

  // SENİN KATEGORİLERİN (AYNEN KORUNDU)
  String _secilenKategori = "Yemek & İçecek"; 
  final List<String> _kategoriler = [
    "Yemek & İçecek", "Spor", "Sinema & Dizi", "Müzik", "Oyun",
    "Fenomenler", "Teknoloji", "Markalar", "Diğer"
  ];

  List<Map<String, dynamic>> _eklenenSecenekler = [];
  bool _isLoading = false;

  // --- YENİ EKLENEN: ETKİNLİK AYARLARI ---
  bool _isEvent = false;
  DateTime? _eventDate;

  // --- RESİM SEÇME ---
  Future<void> _resimSec() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var bytes = await image.readAsBytes();
      setState(() => _secilenResimBytes = bytes);
      _resmiStorageYukle(bytes, image.name);
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resim yüklendi! ✅")));
      }

    } catch (e) {
      print("Yükleme hatası: $e");
      if (mounted) {
          setState(() => _resimYukleniyor = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  // --- LİSTEYE EKLEME ---
  void _secenekEkle() {
    if (_secenekIsimController.text.isEmpty || _yuklenenResimUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İsim ve resim gerekli")));
      return;
    }

    setState(() {
      _eklenenSecenekler.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'isim': _secenekIsimController.text.trim(),
        'resim': _yuklenenResimUrl,
      });
      _secenekIsimController.clear();
      _secilenResimBytes = null;
      _yuklenenResimUrl = null;
    });
  }

  // --- ANAHTAR KELİMELER ---
  List<String> _anahtarKelimeUret(String baslik) {
    List<String> kelimeler = baslik.toLowerCase().split(' ');
    kelimeler.removeWhere((k) => k.isEmpty);
    kelimeler.add(baslik.toLowerCase());
    return kelimeler;
  }

  // --- YENİ: TARİH SEÇİCİ ---
  Future<void> _tarihSec() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _eventDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  // --- TESTİ YAYINLA ---
  Future<void> _testiKaydet() async {
    if (_testBaslikController.text.isEmpty || _eklenenSecenekler.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eksik bilgi (Başlık veya en az 2 seçenek)")));
      return;
    }

    // Etkinlik kontrolü
    if (_isEvent && _eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Etkinlik tarihini seçmelisiniz!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> searchKeywords = _anahtarKelimeUret(_testBaslikController.text);

      // Kapak resmi ilk seçeneğin resmi olsun
      String kapakResmi = _eklenenSecenekler.isNotEmpty ? _eklenenSecenekler[0]['resim'] : "";

      await FirebaseFirestore.instance.collection('testler').add({
        'baslik': _testBaslikController.text.trim(),
        'aktif_mi': true, // Admin eklediği için direkt aktif
        'olusturulma_tarihi': FieldValue.serverTimestamp(),
        'secenekler': _eklenenSecenekler,
        'category': _secilenKategori,
        'kapakResmi': kapakResmi,
        'playCount': 0,
        'searchKeywords': searchKeywords,
        'createdBy': 'admin',
        
        // --- ETKİNLİK ALANLARI ---
        'isEvent': _isEvent,
        'eventDate': _isEvent ? _eventDate : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Test ve Etkinlik Yayında!")));
        setState(() {
          _testBaslikController.clear();
          _eklenenSecenekler.clear();
          _isEvent = false;
          _eventDate = null;
        });
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TESTİ ONAYLA
  void _testiOnayla(String docId) {
    FirebaseFirestore.instance.collection('testler').doc(docId).update({'aktif_mi': true});
  }

  // TESTİ SİL
  void _testiSil(String docId) {
    FirebaseFirestore.instance.collection('testler').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        title: const Text("Admin Paneli", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TEST OLUŞTURMA BÖLÜMÜ ---
            const Text("Yeni Test Oluştur", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            _buildTextField(_testBaslikController, "Test Başlığı"),
            const SizedBox(height: 20),
            
            // KATEGORİ SEÇİMİ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _secilenKategori,
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) => setState(() => _secilenKategori = v!),
                ),
              ),
            ),

            const SizedBox(height: 30),
            
            // SEÇENEK GİRİŞİ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTextField(_secenekIsimController, "Seçenek İsmi")),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: _resimSec,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      image: _secilenResimBytes != null ? DecorationImage(image: MemoryImage(_secilenResimBytes!), fit: BoxFit.cover) : null,
                    ),
                    child: _resimYukleniyor 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))) 
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
                icon: const Icon(Icons.add),
                label: const Text("Listeye Ekle"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // EKLENENLER LİSTESİ
            if (_eklenenSecenekler.isNotEmpty) ...[
              Text("Eklenecekler (${_eklenenSecenekler.length})", style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              ..._eklenenSecenekler.map((item) => Card(
                color: const Color(0xFF1C1C1E),
                child: ListTile(
                  leading: Image.network(item['resim'], width: 40, height: 40, fit: BoxFit.cover),
                  title: Text(item['isim'], style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: (){
                    setState(() => _eklenenSecenekler.remove(item));
                  }),
                ),
              )),
            ],

            const SizedBox(height: 30),

            // --- YENİ: ETKİNLİK AYARLARI (ÖZEL TASARIM) ---
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
                    title: const Text("Bu bir Etkinlik Testi mi?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Ana sayfada 'Günün Etkinliği' olarak en üstte görünür.", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                          : "Seçilen: ${_eventDate!.day}/${_eventDate!.month} - ${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2,'0')}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      onTap: _tarihSec,
                    ),
                  ]
                ],
              ),
            ),
            // ----------------------------------------------

            const SizedBox(height: 30),
            
            // YAYINLA BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testiKaydet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A5F)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("TESTİ YAYINLA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),

            // --- ONAY BEKLEYEN TESTLER ---
            const SizedBox(height: 60),
            const Divider(color: Colors.grey),
            const SizedBox(height: 20),
            const Text("Onay Bekleyen Kullanıcı Testleri", style: TextStyle(color: Colors.orange, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('testler').where('aktif_mi', isEqualTo: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                var docs = snapshot.data!.docs;
                
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(10)),
                    child: const Text("Şu an onay bekleyen test yok.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    var secenekler = data['secenekler'] as List;
                    String kapak = secenekler.isNotEmpty ? secenekler[0]['resim'] : "";

                    return Card(
                      color: const Color(0xFF1C1C1E),
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(kapak, width: 60, height: 60, fit: BoxFit.cover)),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['baslik'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text("Kategori: ${data['category']}", style: const TextStyle(color: Colors.grey)),
                                      Text("Seçenek Sayısı: ${secenekler.length}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _testiSil(doc.id),
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  label: const Text("Reddet / Sil", style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: () => _testiOnayla(doc.id),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  icon: const Icon(Icons.check, color: Colors.white),
                                  label: const Text("Onayla & Yayınla", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            )
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }
}