import 'package:flutter/material.dart';
import 'signup_step2.dart'; // Bir sonraki adım

class SignupStep1 extends StatefulWidget {
  const SignupStep1({super.key});

  @override
  State<SignupStep1> createState() => _SignupStep1State();
}

class _SignupStep1State extends State<SignupStep1> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  void _devamEt() {
    // Basit doğrulama, Firebase Auth işlemleri 3. adımda yapılacak
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurunuz.")));
      return;
    }

    // Bilgileri bir sonraki adıma taşı
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignupStep2(
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text.trim(),
        ),
      ),
    );
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
            // İlerleme Çubuğu
            _buildProgressBar(context, 1),
            const SizedBox(height: 20),

            const Text("Tercihleri sizinle benzer insanları bulun", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Mest'e katılın, eğlenceli testleri çözerek yeni insanlarla tanışın. Ya da...", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            // Email
            const Text("Email", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: "Email adresinizi yazınız"),
            ),
            const SizedBox(height: 20),

            // Telefon Numarası
            const Text("Telefon Numarası", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: "Telefon numaranızı yazınız"),
            ),
            const SizedBox(height: 20),

            // Şifre
            const Text("Şifre", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Şifrenizi yazınız"),
            ),
            const SizedBox(height: 30),

            // Devam Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _devamEt,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Theme.of(context).colorScheme.primary, // Pembe
                ),
                child: const Text("Devam", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),
            // Giriş Yap Linki
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Zaten bir hesabın var mı? ", style: TextStyle(color: Colors.grey)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text("Giriş Yap", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
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