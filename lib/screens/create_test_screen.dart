import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final List<String> _kategoriler = ["Genel", "Yemek", "Spor", "Sinema", "Müzik", "Oyun", "Teknoloji"];
  
  List<Map<String, dynamic>> _secenekler = []; 

  // --- ETKİNLİK AYARLARI ---
  bool _isAdmin = false; // Kullanıcı Admin mi?
  bool _isEvent = false; 
  DateTime? _eventDate;  

  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _adminKontroluYap();
  }

  // 1. ADIM: KULLANICI ADMİN Mİ KONTROL ET
  Future<void> _adminKontroluYap() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _isAdmin = doc.data()?['isAdmin'] == true;
        });
      }
    }
  }

  Future<void> _resimSec(bool isKapak, [int? index]) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var bytes = await image.readAsBytes();
      setState(() {
        if (index != null) {
          _secenekler[index]['resimBytes'] = bytes;
          _secenekler[index]['resimPath'] = image.path;
        }
      });
    }
  }

  void _secenekEkle() {
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
      final ref = FirebaseStorage.instance
          .ref()
          .child('test_resimleri')
          .child('${DateTime.now().millisecondsSinceEpoch}_$dosyaAdi.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      UploadTask uploadTask;

      if (kIsWeb) {
        String base64Image = base64Encode(dosyaBytes);
        String dataUrl = 'data:image/jpeg;base64,$base64Image';
        uploadTask = ref.putString(dataUrl, format: PutStringFormat.dataUrl, metadata: metadata);
      } else {
        uploadTask = ref.putData(dosyaBytes, metadata);
      }

      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      print("Resim yükleme hatası: $e");
      return null;
    }
  }

  Future<void> _testiYayinla() async {
    if (!_formKey.currentState!.validate()) return;
    if (_secenekler.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("En az 2 seçenek eklemelisin!")));
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      List<Map<String, dynamic>> hazirSecenekler = [];
      String? ilkResimUrl;

      for (var i = 0; i < _secenekler.length; i++) {
        var secenek = _secenekler[i];
        Uint8List? bytes = secenek['resimBytes'];
        String isim = (secenek['isim'] as TextEditingController).text;

        if (bytes == null) throw "Tüm seçeneklerin resmi olmalı!";

        String? url = await _resmiStorageYukle(bytes, "secenek_$i");
        if (url != null) {
          if (i == 0) ilkResimUrl = url;
          hazirSecenekler.add({
            'id': i.toString(),
            'isim': isim,
            'resimUrl': url,
            'secilmeSayisi': 0
          });
        }
      }

      await FirebaseFirestore.instance.collection('testler').add({
        'baslik': _baslikController.text,
        'category': _seciliKategori,
        'secenekler': hazirSecenekler,
        'kapakResmi': ilkResimUrl,
        'olusturanId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'aktif_mi': true,
        'playCount': 0,
        // Eğer admin değilse veya switch kapalıysa etkinlik değildir
        'isEvent': _isAdmin ? _isEvent : false, 
        'eventDate': (_isAdmin && _isEvent) ? _eventDate : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Test Başarıyla Yayınlandı! 🚀")));
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
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
                    TextFormField(
                      controller: _baslikController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Test Başlığı",
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.title, color: Color(0xFFFF5A5F)),
                      ),
                      validator: (v) => v!.isEmpty ? "Başlık giriniz" : null,
                    ),
                    const SizedBox(height: 15),
                    
                    DropdownButtonFormField<String>(
                      value: _seciliKategori,
                      dropdownColor: const Color(0xFF1C1C1E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Kategori",
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.category, color: Color(0xFFFF5A5F)),
                      ),
                      items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                      onChanged: (v) => setState(() => _seciliKategori = v!),
                    ),

                    const SizedBox(height: 30),

                    // --- SADECE ADMINLERE GÖRÜNEN ALAN ---
                    if (_isAdmin) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isEvent ? Colors.amber : Colors.grey.shade800),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.stars, color: Colors.amber),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Bu bir Etkinlik Testi mi?",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                    : "${_eventDate!.day}/${_eventDate!.month} - ${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2,'0')}",
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
                    // ---------------------------------------

                    const Text("Seçenekler", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

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
                                onTap: () => _resimSec(false, index),
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(10),
                                    image: imgBytes != null 
                                      ? DecorationImage(image: MemoryImage(imgBytes), fit: BoxFit.cover)
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
                                  decoration: InputDecoration(
                                    labelText: "${index + 1}. Seçenek Adı",
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => setState(() => _secenekler.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    Center(
                      child: TextButton.icon(
                        onPressed: _secenekEkle,
                        icon: const Icon(Icons.add, color: Color(0xFFFF5A5F)),
                        label: const Text("Seçenek Ekle", style: TextStyle(color: Color(0xFFFF5A5F))),
                      ),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _testiYayinla,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A5F),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("TESTİ YAYINLA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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