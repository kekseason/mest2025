import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_step1.dart'; // Kayıt sayfasına yönlendirmek için

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _girisYap() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        // Giriş başarılı: Sayfa yığınını temizle ve ana akışı başlat
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = "Kullanıcı bulunamadı veya email hatalı.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Şifre hatalı.";
      } else {
        errorMessage = "Bir hata oluştu: ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Giriş Başarısız: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // Şifremi Unuttum Modalı
  void _showForgotPasswordModal() {
    // Tasarımdaki "Şifremi mi unuttun?" modalını burada açıyoruz
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D11),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final forgotController = TextEditingController();

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Şifreni mi unuttun?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Lütfen kayıtlı mail adresinizi paylaşın.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),
              TextField(
                controller: forgotController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: "Email adresinizi yazınız"),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (forgotController.text.isNotEmpty) {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: forgotController.text.trim());
                      if (context.mounted) {
                        Navigator.pop(context); // Modalı kapat
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre sıfırlama e-postası gönderildi.")));
                      }
                    }
                  },
                  child: const Text("Devam"),
                ),
              ),
            ],
          ),
        );
      },
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mest olmaya hazır mısın?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text("Bizi özledin mi? Giriş yap ve eğlenmeye devam et!", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // Email
            const Text("Email", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: "Email adresinizi yazınız"),
            ),

            const SizedBox(height: 20),
            // Password
            const Text("Password", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Şifrenizi yazınız",
                suffixIcon: Icon(Icons.visibility_off, color: Colors.grey),
              ),
            ),
            
            // Şifreni mi unuttun?
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordModal, 
                child: const Text("Şifreni mi unuttun?", style: TextStyle(color: Colors.grey)),
              ),
            ),

            const SizedBox(height: 20),
            // Giriş Yap Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _girisYap,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Giriş Yap", style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 30),
            const Center(child: Text("Ya da", style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 20),

            // Sosyal Medya Butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialButton(Icons.facebook),
                const SizedBox(width: 20),
                _socialButton(Icons.apple),
                const SizedBox(width: 20),
                _socialButton(Icons.g_mobiledata),
              ],
            ),
            
            const SizedBox(height: 30),
            // Üye Ol Linki
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Mest'te Yeni misin? ", style: TextStyle(color: Colors.grey)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupStep1()));
                  },
                  child: Text("Üye Ol", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1C1C1E),
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }
}