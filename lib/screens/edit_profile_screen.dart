import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController(); // "Kısaca kendini anlat"
  String? _selectedCity;
  bool _isLoading = false;
  
  final List<String> _cities = ["İstanbul", "Ankara", "İzmir", "Antalya", "Bursa"];

  @override
  void initState() {
    super.initState();
    _mevcutBilgileriGetir();
  }

  void _mevcutBilgileriGetir() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      var data = doc.data();
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? "";
          _bioController.text = data['bio'] ?? ""; // Veritabanında bio alanı açacağız
          _selectedCity = data['city'];
        });
      }
    }
  }

  Future<void> _kaydet() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'city': _selectedCity,
        });
        if (mounted) Navigator.pop(context); // Geri dön
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Profili Düzenle", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _kaydet,
            child: _isLoading 
              ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Kaydet", style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FOTOĞRAFLAR (Tasarımda 6 kutu var, şimdilik sadece görsel)
            const Text("Profil Fotoğrafları", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
              children: List.generate(6, (index) {
                 // İlk kutu dolu, diğerleri + butonu (Simülasyon)
                 if (index == 0) {
                   return Container(
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(10),
                       image: const DecorationImage(image: AssetImage('assets/user_placeholder.png'), fit: BoxFit.cover), // Placeholder resmi
                       border: Border.all(color: const Color(0xFFFF5A5F)),
                     ),
                   );
                 }
                 return Container(
                   decoration: BoxDecoration(
                     color: const Color(0xFF1C1C1E),
                     borderRadius: BorderRadius.circular(10),
                     border: Border.all(color: Colors.grey.withOpacity(0.3)),
                   ),
                   child: const Icon(Icons.add, color: Colors.white),
                 );
              }),
            ),

            const SizedBox(height: 30),
            const Text("Bilgiler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildLabel("Adınız"),
            TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecor("Adınızı yazınız")),
            
            const SizedBox(height: 20),
            _buildLabel("Kısaca kendini anlat"),
            TextField(controller: _bioController, style: const TextStyle(color: Colors.white), maxLines: 3, decoration: _inputDecor("Kısa tanım")),

            const SizedBox(height: 20),
            _buildLabel("Nerede Yaşıyorsun"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  hint: const Text("Şehir Seç", style: TextStyle(color: Colors.grey)),
                  dropdownColor: const Color(0xFF1C1C1E),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  items: _cities.map((String city) {
                    return DropdownMenuItem<String>(value: city, child: Text(city, style: const TextStyle(color: Colors.white)));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCity = val),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            // Buraya İlgi Alanları ve Sosyal Medya da eklenebilir
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
  
  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(color: Colors.white70)));
}