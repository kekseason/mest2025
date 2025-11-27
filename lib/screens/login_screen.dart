import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_step1.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    // Boş alan kontrolü
    if (_emailController.text.trim().isEmpty) {
      _showError("Lütfen email adresinizi girin");
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showError("Lütfen şifrenizi girin");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firebase ile giriş yap
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Kullanıcı bilgilerini güncelle (online durumu)
      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        }).catchError((e) {
          // Kullanıcı dökümanı yoksa oluştur
          debugPrint("Kullanıcı dökümanı güncellenemedi: $e");
        });
      }

      // Giriş başarılı - Ana sayfaya git
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false, // Tüm geçmişi temizle
        );
      }

    } on FirebaseAuthException catch (e) {
      // Firebase Auth hataları
      String errorMessage = _getErrorMessage(e.code);
      _showError(errorMessage);
      debugPrint("FirebaseAuthException: ${e.code} - ${e.message}");
      
    } on FirebaseException catch (e) {
      // Genel Firebase hataları
      String errorMessage = _getErrorMessage(e.code);
      _showError(errorMessage);
      debugPrint("FirebaseException: ${e.code} - ${e.message}");
      
    } catch (e) {
      // Diğer hatalar
      debugPrint("Beklenmeyen hata: $e");
      debugPrint("Hata tipi: ${e.runtimeType}");
      
      // Hata mesajından kod çıkarmaya çalış
      String errorStr = e.toString();
      if (errorStr.contains('user-not-found')) {
        _showError("Bu email ile kayıtlı kullanıcı bulunamadı");
      } else if (errorStr.contains('wrong-password') || errorStr.contains('invalid-credential')) {
        _showError("Email veya şifre hatalı");
      } else if (errorStr.contains('invalid-email')) {
        _showError("Geçersiz email adresi");
      } else if (errorStr.contains('user-disabled')) {
        _showError("Bu hesap devre dışı bırakılmış");
      } else if (errorStr.contains('too-many-requests')) {
        _showError("Çok fazla deneme yaptınız. Lütfen biraz bekleyin");
      } else if (errorStr.contains('network')) {
        _showError("İnternet bağlantınızı kontrol edin");
      } else {
        _showError("Giriş yapılamadı. Lütfen tekrar deneyin");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return "Bu email ile kayıtlı kullanıcı bulunamadı";
      case 'wrong-password':
        return "Şifre hatalı";
      case 'invalid-email':
        return "Geçersiz email adresi";
      case 'user-disabled':
        return "Bu hesap devre dışı bırakılmış";
      case 'invalid-credential':
        return "Email veya şifre hatalı";
      case 'too-many-requests':
        return "Çok fazla deneme. Lütfen biraz bekleyin";
      case 'network-request-failed':
        return "İnternet bağlantınızı kontrol edin";
      case 'operation-not-allowed':
        return "Bu giriş yöntemi devre dışı";
      default:
        return "Giriş yapılamadı ($code)";
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Şifremi Unuttum Modalı
  void _showForgotPasswordModal() {
    final forgotController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D11),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tutma çubuğu
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    "Şifreni mi unuttun?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Kayıtlı email adresini gir, şifre sıfırlama bağlantısı gönderelim.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  
                  TextField(
                    controller: forgotController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Email adresinizi yazınız",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              if (forgotController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Email adresi girin")),
                                );
                                return;
                              }

                              setModalState(() => isSending = true);

                              try {
                                await FirebaseAuth.instance.sendPasswordResetEmail(
                                  email: forgotController.text.trim(),
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _showSuccess("Şifre sıfırlama emaili gönderildi!");
                                }
                              } on FirebaseAuthException catch (e) {
                                String msg = e.code == 'user-not-found'
                                    ? "Bu email ile kayıtlı kullanıcı yok"
                                    : "Bir hata oluştu";
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                                );
                              } catch (e) {
                                String errorStr = e.toString();
                                if (errorStr.contains('user-not-found')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Bu email ile kayıtlı kullanıcı yok"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Email gönderilemedi"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setModalState(() => isSending = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A5F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Gönder",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            // Başlık
            const Text(
              "Mest olmaya\nhazır mısın?",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Bizi özledin mi? Giriş yap ve eğlenmeye devam et!",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 40),

            // Email
            const Text(
              "Email",
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Email adresinizi yazınız",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
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

            // Şifre
            const Text(
              "Şifre",
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _girisYap(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Şifrenizi yazınız",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
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

            // Şifreni mi unuttun?
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordModal,
                child: const Text(
                  "Şifreni mi unuttun?",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Giriş Yap Butonu
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _girisYap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A5F),
                  disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFFF5A5F).withOpacity(0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Giriş Yap",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            // Ya da
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.grey)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Ya da", style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider(color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 25),

            // Sosyal Medya Butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialButton(Icons.facebook, "Facebook", () {
                  _showError("Facebook girişi yakında aktif olacak");
                }),
                const SizedBox(width: 15),
                _socialButton(Icons.apple, "Apple", () {
                  _showError("Apple girişi yakında aktif olacak");
                }),
                const SizedBox(width: 15),
                _socialButton(Icons.g_mobiledata, "Google", () {
                  _showError("Google girişi yakında aktif olacak");
                }),
              ],
            ),

            const SizedBox(height: 40),

            // Üye Ol Linki
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Mest'te yeni misin? ",
                  style: TextStyle(color: Colors.grey),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupStep1()),
                    );
                  },
                  child: const Text(
                    "Üye Ol",
                    style: TextStyle(
                      color: Color(0xFFFF5A5F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1C1C1E),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}