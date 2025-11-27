import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:convert';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _baslikController = TextEditingController();

  String _seciliKategori = "Genel";
  final List<String> _kategoriler = [
    "Genel", "Yemek", "Spor", "Sinema", "Müzik", "Oyun", "Teknoloji"
  ];

  List<Map<String, dynamic>> _secenekler = [];

  // 🔒 Admin kontrolü - server-side'da da kontrol edilecek
  bool _isAdmin = false;
  bool _isEvent = false;
  DateTime? _eventDate;

  bool _yukleniyor = false;
  bool _checkingAdmin = true;

  @override
  void initState() {
    super.initState();
    _adminKontroluYap();
  }

  @override
  void dispose() {
    _baslikController.dispose();
    // TextEditingController'ları temizle
    for (var secenek in _secenekler) {
      (secenek['isim'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  // 🔒 Admin kontrolü - sadece UI için, asıl kontrol Firestore Rules'da
  Future<void> _adminKontroluYap() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (mounted) {
          setState(() {
            _isAdmin = doc.data()?['isAdmin'] == true;
            _checkingAdmin = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _checkingAdmin = false);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Admin kontrol hatası: $e");
      if (mounted) {
        setState(() => _checkingAdmin = false);
      }
    }
  }

  // 🔒 Başlık Validasyonu
  String? _validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Başlık gerekli';
    }
    if (value.length < 3) {
      return 'Başlık en az 3 karakter olmalı';
    }
    if (value.length > 100) {
      return 'Başlık çok uzun (max 100 karakter)';
    }
    // 🔒 XSS koruması
    if (RegExp(r'[<>]').hasMatch(value)) {
      return 'Geçersiz karakterler içeriyor';
    }
    return null;
  }

  // 🔒 Seçenek ismi validasyonu
  String? _validateOptionName(String? value) {
    if (value == null || value.isEmpty) {
      return 'İsim gerekli';
    }
    if (value.length > 50) {
      return 'İsim çok uzun';
    }
    if (RegExp(r'[<>]').hasMatch(value)) {
      return 'Geçersiz karakterler';
    }
    return null;
  }

  Future<void> _resimSec(int index) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        // 🔒 Dosya boyutu kontrolü (max 5MB)
        final bytes = await image.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Resim boyutu 5MB\'dan küçük olmalı'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _secenekler[index]['resimBytes'] = bytes;
          _secenekler[index]['resimPath'] = image.path;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Resim seçme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resim seçilirken hata oluştu')),
        );
      }
    }
  }

  void _secenekEkle() {
    if (_secenekler.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimum 16 seçenek ekleyebilirsiniz')),
      );
      return;
    }

    setState(() {
      _secenekler.add({
        'isim': TextEditingController(),
        'resimBytes': null,
        'resimPath': null,
      });
    });
  }

  Future<String?> _resmiStorageYukle(Uint8List dosyaBytes, String dosyaAdi) async {
    try {
      // 🔒 Güvenli dosya adı oluştur
      String temizAdi = dosyaAdi.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      String uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      String safeFileName = '${uniqueId}_$temizAdi.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('test_resimleri')
          .child(safeFileName);

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      UploadTask uploadTask;

      if (kIsWeb) {
        String base64Image = base64Encode(dosyaBytes);
        String dataUrl = 'data:image/jpeg;base64,$base64Image';
        uploadTask = ref.putString(dataUrl, format: PutStringFormat.dataUrl, metadata: metadata);
      } else {
        uploadTask = ref.putData(dosyaBytes, metadata);
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) print("Resim yükleme hatası: $e");
      return null;
    }
  }

  Future<void> _testiYayinla() async {
    // Form validasyonu
    if (!_formKey.currentState!.validate()) return;

    // Seçenek sayısı kontrolü
    if (_secenekler.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("En az 2 seçenek eklemelisin!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Seçenek isimlerini kontrol et
    for (var secenek in _secenekler) {
      String isim = (secenek['isim'] as TextEditingController).text;
      if (_validateOptionName(isim) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tüm seçeneklerin geçerli isimleri olmalı"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _yukleniyor = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Oturum açmanız gerekiyor");
      }

      List<Map<String, dynamic>> hazirSecenekler = [];
      String? ilkResimUrl;

      for (var i = 0; i < _secenekler.length; i++) {
        var secenek = _secenekler[i];
        Uint8List? bytes = secenek['resimBytes'];
        String isim = (secenek['isim'] as TextEditingController).text.trim();

        if (bytes == null) {
          throw Exception("Tüm seçeneklerin resmi olmalı!");
        }

        String? url = await _resmiStorageYukle(bytes, "secenek_$i");
        if (url != null) {
          if (i == 0) ilkResimUrl = url;
          hazirSecenekler.add({
            'id': i.toString(),
            'isim': isim,
            'resimUrl': url,
            'secilmeSayisi': 0
          });
        } else {
          throw Exception("Resim yüklenemedi");
        }
      }

      // 🔒 Test verisi oluştur
      // NOT: isEvent ve eventDate alanları Firestore Rules tarafından kontrol edilecek
      // Admin olmayan kullanıcılar isEvent=true yapamaz (Firestore Rules'da engellenecek)
      Map<String, dynamic> testData = {
        'baslik': _baslikController.text.trim(),
        'category': _seciliKategori,
        'secenekler': hazirSecenekler,
        'kapakResmi': ilkResimUrl,
        'olusturanId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'aktif_mi': false, // 🔒 Normal kullanıcılar için onay bekleyecek
        'playCount': 0,
        'isEvent': false, // 🔒 Default olarak false
        'eventDate': null,
      };

      // 🔒 Admin ise etkinlik bilgilerini ekle (Firestore Rules kontrol edecek)
      if (_isAdmin && _isEvent && _eventDate != null) {
        testData['isEvent'] = true;
        testData['eventDate'] = Timestamp.fromDate(_eventDate!);
        testData['aktif_mi'] = true; // Admin testleri direkt aktif
      } else if (_isAdmin) {
        testData['aktif_mi'] = true; // Admin testleri direkt aktif
      }

      await FirebaseFirestore.instance.collection('testler').add(testData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isAdmin 
              ? "Test başarıyla yayınlandı! 🚀" 
              : "Test gönderildi! Admin onayından sonra yayınlanacak."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

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
              onPrimary: Colors.white,
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
                onPrimary: Colors.white,
                surface: Color(0xFF1C1C1E),
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (time != null) {
        setState(() {
          _eventDate = DateTime(
            picked.year, picked.month, picked.day, 
            time.hour, time.minute
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Yeni Test Oluştur", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔒 Normal kullanıcılar için bilgi
                    if (!_isAdmin)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Testiniz admin onayından sonra yayınlanacaktır.",
                                style: TextStyle(color: Colors.blue, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Test Başlığı
                    TextFormField(
                      controller: _baslikController,
                      style: const TextStyle(color: Colors.white),
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: "Test Başlığı *",
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.title, color: Color(0xFFFF5A5F)),
                        counterStyle: TextStyle(color: Colors.grey),
                      ),
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: 15),

                    // Kategori
                    DropdownButtonFormField<String>(
                      value: _seciliKategori,
                      dropdownColor: const Color(0xFF1C1C1E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Kategori",
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.category, color: Color(0xFFFF5A5F)),
                      ),
                      items: _kategoriler.map((k) => 
                        DropdownMenuItem(value: k, child: Text(k))
                      ).toList(),
                      onChanged: (v) => setState(() => _seciliKategori = v!),
                    ),

                    const SizedBox(height: 30),

                    // 🔒 SADECE ADMINLERE GÖRÜNEN ETKİNLİK AYARLARI
                    if (_isAdmin) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isEvent ? Colors.amber : Colors.grey.shade800,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.stars, color: Colors.amber),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Bu bir Etkinlik Testi mi?",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _isEvent,
                                  activeColor: Colors.amber,
                                  onChanged: (val) => setState(() => _isEvent = val),
                                ),
                              ],
                            ),
                            if (_isEvent) ...[
                              const Divider(color: Colors.grey),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  _eventDate == null
                                      ? "Başlangıç Tarihi Seç"
                                      : "${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year} - ${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: const Icon(Icons.calendar_today, color: Colors.amber),
                                onTap: _tarihSec,
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],

                    // Seçenekler Başlık
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Seçenekler",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_secenekler.length}/16",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Seçenek Listesi
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _secenekler.length,
                      itemBuilder: (context, index) {
                        var item = _secenekler[index];
                        Uint8List? imgBytes = item['resimBytes'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _resimSec(index),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(10),
                                    image: imgBytes != null
                                        ? DecorationImage(
                                            image: MemoryImage(imgBytes),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: imgBytes == null
                                      ? const Icon(Icons.add_a_photo, color: Colors.grey)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: TextFormField(
                                  controller: item['isim'],
                                  style: const TextStyle(color: Colors.white),
                                  maxLength: 50,
                                  decoration: InputDecoration(
                                    labelText: "${index + 1}. Seçenek Adı",
                                    border: InputBorder.none,
                                    counterText: "",
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () {
                                  (item['isim'] as TextEditingController).dispose();
                                  setState(() => _secenekler.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Seçenek Ekle Butonu
                    Center(
                      child: TextButton.icon(
                        onPressed: _secenekEkle,
                        icon: const Icon(Icons.add, color: Color(0xFFFF5A5F)),
                        label: const Text(
                          "Seçenek Ekle",
                          style: TextStyle(color: Color(0xFFFF5A5F)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Yayınla Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _testiYayinla,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A5F),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isAdmin ? "TESTİ YAYINLA" : "ONAYA GÖNDER",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}