import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baslikController = TextEditingController();
  final _aciklamaController = TextEditingController();
  
  String _selectedKategori = 'eglence';
  List<Map<String, dynamic>> _secenekler = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  final List<Map<String, String>> _kategoriler = [
    {'id': 'yemek', 'name': 'Yemek İçecek'},
    {'id': 'spor', 'name': 'Spor'},
    {'id': 'muzik', 'name': 'Müzik'},
    {'id': 'eglence', 'name': 'Eğlence'},
    {'id': 'film', 'name': 'Film Dizi'},
    {'id': 'oyun', 'name': 'Oyun'},
    {'id': 'moda', 'name': 'Moda'},
    {'id': 'sosyal', 'name': 'Sosyal Medya'},
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _isAdmin = data['isAdmin'] ?? false;
        });
      }
    }
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mest Oluştur",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============ BİLGİLENDİRME ============
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFF5A5F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Oluşturduğun Mest, onaylandıktan sonra herkes tarafından çözülebilir.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ============ BAŞLIK ============
              const Text(
                "Mest Başlığı",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _baslikController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Örn: En İyi Türk Yemeği",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF5A5F)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Başlık gerekli';
                  }
                  if (value.length < 5) {
                    return 'Başlık en az 5 karakter olmalı';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ============ AÇIKLAMA ============
              const Text(
                "Açıklama (Opsiyonel)",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _aciklamaController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Mest hakkında kısa bir açıklama...",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF5A5F)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============ KATEGORİ ============
              const Text(
                "Kategori",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedKategori,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1C1C1E),
                    style: const TextStyle(color: Colors.white),
                    items: _kategoriler.map((kategori) {
                      return DropdownMenuItem<String>(
                        value: kategori['id'],
                        child: Text(kategori['name']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedKategori = value!;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ============ SEÇENEKLER ============
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Seçenekler",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "${_secenekler.length}/16",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "En az 4, en fazla 16 seçenek ekleyebilirsin",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 15),

              // Seçenek listesi
              ..._secenekler.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> secenek = entry.value;
                return _buildSecenekCard(index, secenek);
              }),

              // Seçenek ekle butonu
              if (_secenekler.length < 16)
                GestureDetector(
                  onTap: _addSecenek,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF5A5F).withOpacity(0.5),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.add_circle_outline, color: Color(0xFFFF5A5F), size: 40),
                        SizedBox(height: 8),
                        Text(
                          "Seçenek Ekle",
                          style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              // ============ OLUŞTUR BUTONU ============
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A5F),
                    disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Mest Oluştur",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildSecenekCard(int index, Map<String, dynamic> secenek) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Resim
          GestureDetector(
            onTap: () => _pickImage(index),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(10),
                image: secenek['resim'] != null
                    ? DecorationImage(
                        image: secenek['resim'].startsWith('http')
                            ? NetworkImage(secenek['resim'])
                            : MemoryImage(base64Decode(secenek['resim'].split(',').last)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: secenek['resim'] == null
                  ? const Icon(Icons.add_photo_alternate, color: Colors.grey, size: 30)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // İsim
          Expanded(
            child: TextFormField(
              initialValue: secenek['isim'],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Seçenek adı",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _secenekler[index]['isim'] = value;
                });
              },
            ),
          ),

          // Sil butonu
          IconButton(
            onPressed: () => _removeSecenek(index),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _addSecenek() {
    if (_secenekler.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("En fazla 16 seçenek ekleyebilirsin"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _secenekler.add({'isim': '', 'resim': null});
    });
  }

  void _removeSecenek(int index) {
    setState(() {
      _secenekler.removeAt(index);
    });
  }

  Future<void> _pickImage(int index) async {
    final ImagePicker picker = ImagePicker();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF5A5F)),
              title: const Text("Kamera", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (image != null) {
                  _processImage(index, image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFF5A5F)),
              title: const Text("Galeri", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (image != null) {
                  _processImage(index, image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Color(0xFFFF5A5F)),
              title: const Text("URL ile ekle", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showUrlDialog(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(int index, XFile image) async {
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      setState(() {
        _secenekler[index]['resim'] = base64Image;
      });
    } catch (e) {
      debugPrint("Resim işleme hatası: $e");
    }
  }

  void _showUrlDialog(int index) {
    final urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Resim URL'si", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "https://...",
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                setState(() {
                  _secenekler[index]['resim'] = urlController.text;
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A5F)),
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTest() async {
    if (!_formKey.currentState!.validate()) return;

    // Seçenek kontrolü
    if (_secenekler.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("En az 4 seçenek eklemelisin"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Boş isim kontrolü
    for (var secenek in _secenekler) {
      if (secenek['isim'] == null || secenek['isim'].toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tüm seçeneklere isim ver"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("Kullanıcı bulunamadı");

      // Kullanıcı bilgilerini al
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      String userName = "Anonim";
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        userName = userData['name'] ?? "Anonim";
      }

      // Seçenekleri hazırla
      List<Map<String, dynamic>> seceneklerData = _secenekler.map((s) {
        return {
          'isim': s['isim'],
          'resimUrl': s['resim'],
        };
      }).toList();

      // Kapak resmi (ilk seçeneğin resmi)
      String? kapakResmi;
      for (var s in _secenekler) {
        if (s['resim'] != null) {
          kapakResmi = s['resim'];
          break;
        }
      }

      // Testi oluştur
      // NOT: isEventTest her zaman false olacak (normal kullanıcılar etkinlik testi oluşturamaz)
      await FirebaseFirestore.instance.collection('testler').add({
        'baslik': _baslikController.text.trim(),
        'aciklama': _aciklamaController.text.trim(),
        'kategori': _selectedKategori,
        'secenekler': seceneklerData,
        'kapakResmi': kapakResmi,
        'olusturanId': userId,
        'olusturanAdi': userName,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
        'aktif_mi': false, // Admin onayı bekliyor
        'isVerified': false,
        'playCount': 0,
        // ETKİNLİK TESTİ DEĞİL - Normal kullanıcılar etkinlik testi oluşturamaz
        'isEventTest': false,
        'eventId': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mest oluşturuldu! Onay bekleniyor."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Test oluşturma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bir hata oluştu: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}