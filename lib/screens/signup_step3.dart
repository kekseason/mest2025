import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_navigation.dart'; // Başarılı olunca ana sayfaya yönlendirmek için

class SignupStep3 extends StatefulWidget {
  final String email;
  final String phone;
  final String password;
  final String name;
  final DateTime birthDate;
  final String city;
  final String gender;

  const SignupStep3({
    super.key,
    required this.email,
    required this.phone,
    required this.password,
    required this.name,
    required this.birthDate,
    required this.city,
    required this.gender,
  });

  @override
  State<SignupStep3> createState() => _SignupStep3State();
}

class _SignupStep3State extends State<SignupStep3> {
  Set<String> _selectedInterests = {};
  bool _isLoading = false;

  final List<String> interests = [
    "Yemek", "İçecek", "Kahve", "Resim", "Müzik", "Oyun", "Sanat", "Teknoloji", "Moda", "Aktüel",
    "Spor", "Futbol", "Basketbol", "Tenis", "Rap", "Rock", "Klasik", "Seyahat", "Kültür", "Edebiyat",
    "Okuma-Yazma", "Müzik", "Ticaret", "Crypto", "Borsa", "Memes", "Film-Dizi", "Sohbet", "Yazılım",
    "Eğitim", "Fotoğraf", "Outdoor", "Fenomenler", "Astroloji", "Youtuberlar"
  ];

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _kaydiTamamla() async {
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen en az bir ilgi alanı seçiniz.")));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      // 1. Firebase Auth ile kullanıcı oluştur
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final uid = userCredential.user!.uid;

      // 2. Firestore'a detayları kaydet
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': widget.name,
        'email': widget.email,
        'phone': widget.phone,
        'birthDate': Timestamp.fromDate(widget.birthDate),
        'city': widget.city,
        'gender': widget.gender,
        'interests': _selectedInterests.toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'testCount': 0,
        'badges': [],
        'isOnline': true,
      });

      // 3. Başarılı: Ana sayfaya yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (Route<dynamic> route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kayıt Hatası: ${e.message}")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Genel Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Geri", style: TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressBar(context, 3),
            const SizedBox(height: 20),

            const Text("Bize ilgi alanlarından bahset", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Sana sevdiğin konularla ilgili testler önermemiz ve seni seninle benzer konulara ilgi duyan insanlarla eşleştirmemiz için bize ilgi alanlardan bahset", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            const Text("Temperament:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 15),

            // İlgi Alanları (Chips)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: interests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () => _toggleInterest(interest),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.5)),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // Devam Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _kaydiTamamla,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Devam", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, int step) {
    return Row(
      children: List.generate(3, (index) {
        bool isActive = index < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 5 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}