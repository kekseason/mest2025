import 'package:flutter/material.dart';
import 'login_screen.dart'; // Giriş sayfana yönlendirmek için
import 'signup_step1.dart'; // <<< EKSİK OLAN İMPORT BURAYA EKLENDİ

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11), 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // --- LOGO ---
              Image.asset(
                'assets/mest_logo.png',
                height: 120, 
                width: 250,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 20),

              // Kısa Açıklama
              const Text(
                "Tercih et, Eşleş ve Sohbet Et.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              // --- GİRİŞ BUTONU ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // LoginScreen'e yönlendir
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  },
                  child: const Text("Giriş Yap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 15),

              // --- KAYIT BUTONU (Outlined) ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // SignupStep1'e yönlendir
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupStep1()));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: mainColor, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    backgroundColor: Colors.transparent,
                  ),
                  child: Text(
                    "Yeni Hesap Oluştur",
                    style: TextStyle(color: mainColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}