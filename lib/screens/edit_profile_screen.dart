import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _selectedCity;
  bool _isLoading = false;
  bool _isSaving = false;

  // Profil Fotoğrafları (max 6)
  List<String?> _photos = List.filled(6, null);
  List<Uint8List?> _pendingPhotos = List.filled(6, null); // Yüklenecek fotoğraflar
  int _uploadingIndex = -1;

  // İlgi Alanları
  List<String> _selectedInterests = [];
  final List<String> _allInterests = [
    "Müzik", "Sinema", "Spor", "Yemek", "Seyahat", "Oyun", "Teknoloji",
    "Kitap", "Sanat", "Fotoğraf", "Dans", "Yoga", "Fitness", "Doğa",
    "Hayvanlar", "Moda", "Komedi", "Podcast", "Anime", "K-Pop",
  ];

  final List<String> _cities = [
    "İstanbul", "Ankara", "İzmir", "Antalya", "Bursa", "Adana",
    "Konya", "Gaziantep", "Mersin", "Diyarbakır", "Kayseri",
    "Eskişehir", "Trabzon", "Samsun", "Denizli", "Diğer",
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      var data = doc.data();

      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? "";
          _bioController.text = data['bio'] ?? "";
          _selectedCity = data['city'];

          // Fotoğrafları yükle
          List<dynamic> photoUrls = data['photos'] ?? [];
          for (int i = 0; i < photoUrls.length && i < 6; i++) {
            _photos[i] = photoUrls[i];
          }

          // Ana profil fotoğrafı yoksa ama photoUrl varsa
          if (_photos[0] == null && data['photoUrl'] != null) {
            _photos[0] = data['photoUrl'];
          }

          // İlgi alanları
          _selectedInterests = List<String>.from(data['interests'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ FOTOĞRAF SEÇME ============
  Future<void> _pickPhoto(int index) async {
    // Seçenekleri göster
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mevcut fotoğraf varsa silme seçeneği
              if (_photos[index] != null) ...[
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Fotoğrafı Sil", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePhoto(index);
                  },
                ),
                const Divider(color: Colors.white10),
              ],
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text("Kamera", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _selectImage(index, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text("Galeri", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _selectImage(index, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectImage(int index, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      Uint8List bytes = await image.readAsBytes();

      // Boyut kontrolü (5MB)
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Fotoğraf 5MB'dan küçük olmalı"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _pendingPhotos[index] = bytes;
        _uploadingIndex = index;
      });

      // Firebase'e yükle
      await _uploadPhoto(index, bytes);
    } catch (e) {
      debugPrint("Fotoğraf seçme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadPhoto(int index, Uint8List bytes) async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      String fileName = 'profile_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String path = 'user_photos/$userId/$fileName';
      Reference ref = FirebaseStorage.instance.ref().child(path);

      String base64String = base64Encode(bytes);
      String dataUrl = 'data:image/jpeg;base64,$base64String';

      UploadTask uploadTask = ref.putString(
        dataUrl,
        format: PutStringFormat.dataUrl,
        metadata: SettableMetadata(contentType: 'image/jpeg'),
      );

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _photos[index] = downloadUrl;
        _pendingPhotos[index] = null;
        _uploadingIndex = -1;
      });

      // Ana fotoğraf güncellendiğinde photoUrl'i de güncelle
      if (index == 0) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'photoUrl': downloadUrl,
        });
      }
    } catch (e) {
      setState(() {
        _pendingPhotos[index] = null;
        _uploadingIndex = -1;
      });
      debugPrint("Yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yükleme hatası: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePhoto(int index) async {
    // Onay dialogu
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Fotoğrafı Sil", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bu fotoğrafı silmek istediğine emin misin?",
          style: TextStyle(color: Colors.grey),
        ),
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

    if (confirm != true) return;

    setState(() => _photos[index] = null);

    // Ana fotoğraf silindiğinde bir sonrakini ana yap
    if (index == 0) {
      String? nextPhoto = _photos.firstWhere((p) => p != null, orElse: () => null);
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'photoUrl': nextPhoto,
        });
      }
    }
  }

  // ============ KAYDET ============
  Future<void> _saveProfile() async {
    // Validasyon
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İsim gerekli"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_nameController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İsim en az 2 karakter olmalı"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Kullanıcı bulunamadı");

      // Fotoğrafları filtrele (null olmayanlar)
      List<String> validPhotos = _photos.where((p) => p != null).cast<String>().toList();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'city': _selectedCity,
        'photos': validPhotos,
        'photoUrl': validPhotos.isNotEmpty ? validPhotos[0] : null,
        'interests': _selectedInterests,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil güncellendi ✓"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D11),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Profili Düzenle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Color(0xFFFF5A5F), strokeWidth: 2),
                  )
                : const Text(
                    "Kaydet",
                    style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ FOTOĞRAFLAR ============
            _buildSectionTitle("Fotoğraflar", "İlk fotoğraf ana profil fotoğrafın olur"),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => _buildPhotoSlot(index),
            ),

            const SizedBox(height: 30),

            // ============ BİLGİLER ============
            _buildSectionTitle("Bilgiler", null),
            const SizedBox(height: 12),

            // İsim
            _buildLabel("Adın"),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              maxLength: 30,
              decoration: _inputDecor("Adını gir"),
            ),

            const SizedBox(height: 15),

            // Bio
            _buildLabel("Hakkında"),
            TextField(
              controller: _bioController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              maxLength: 200,
              decoration: _inputDecor("Kendini kısaca tanıt..."),
            ),

            const SizedBox(height: 15),

            // Şehir
            _buildLabel("Şehir"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  hint: const Text("Şehir seç", style: TextStyle(color: Colors.grey)),
                  dropdownColor: const Color(0xFF1C1C1E),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  items: _cities.map((city) => DropdownMenuItem(
                    value: city,
                    child: Text(city, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCity = val),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ============ İLGİ ALANLARI ============
            _buildSectionTitle("İlgi Alanları", "En az 3 tane seç"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((interest) {
                bool isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (_selectedInterests.length < 10) {
                          _selectedInterests.add(interest);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("En fazla 10 ilgi alanı seçebilirsin")),
                          );
                        }
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFFF5A5F),
                  backgroundColor: const Color(0xFF1C1C1E),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFFF5A5F) : Colors.transparent,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(int index) {
    String? photoUrl = _photos[index];
    Uint8List? pendingPhoto = _pendingPhotos[index];
    bool isUploading = _uploadingIndex == index;
    bool isMainPhoto = index == 0;

    return GestureDetector(
      onTap: isUploading ? null : () => _pickPhoto(index),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMainPhoto ? const Color(0xFFFF5A5F) : Colors.grey.withOpacity(0.3),
            width: isMainPhoto ? 2 : 1,
          ),
          image: pendingPhoto != null
              ? DecorationImage(
                  image: MemoryImage(pendingPhoto),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                )
              : photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: Stack(
          children: [
            // Ana fotoğraf etiketi
            if (isMainPhoto && photoUrl != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A5F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Ana",
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Yükleme göstergesi
            if (isUploading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5A5F), strokeWidth: 2),
              ),

            // Boş slot için + işareti
            if (photoUrl == null && pendingPhoto == null && !isUploading)
              Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A5F).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Color(0xFFFF5A5F), size: 24),
                ),
              ),

            // Düzenleme ikonu (fotoğraf varsa)
            if (photoUrl != null && !isUploading)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      counterStyle: const TextStyle(color: Colors.grey),
    );
  }
}