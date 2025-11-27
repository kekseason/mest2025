import 'package:flutter/material.dart';
import 'signup_step2.dart';

class SignupStep1 extends StatefulWidget {
  const SignupStep1({super.key});

  @override
  State<SignupStep1> createState() => _SignupStep1State();
}

class _SignupStep1State extends State<SignupStep1> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // 🔒 Şifre gücü göstergesi için
  double _passwordStrength = 0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🔒 Email Validasyonu
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email adresi gerekli';
    }
    value = value.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Geçerli bir email adresi girin';
    }
    if (value.length > 100) {
      return 'Email çok uzun';
    }
    return null;
  }

  // 🔒 Telefon Validasyonu
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Opsiyonel alan
    }
    // Sadece rakam ve + işareti
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Geçerli bir telefon numarası girin';
    }
    return null;
  }

  // 🔒 Şifre Validasyonu
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre gerekli';
    }
    if (value.length < 8) {
      return 'Şifre en az 8 karakter olmalı';
    }
    if (value.length > 50) {
      return 'Şifre çok uzun';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'En az 1 büyük harf gerekli';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'En az 1 küçük harf gerekli';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'En az 1 rakam gerekli';
    }
    return null;
  }

  // 🔒 Şifre Tekrar Validasyonu
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre tekrarı gerekli';
    }
    if (value != _passwordController.text) {
      return 'Şifreler eşleşmiyor';
    }
    return null;
  }

  // 🔒 Şifre Gücü Hesaplama
  void _updatePasswordStrength(String password) {
    double strength = 0;
    
    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.1;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.2;
    
    setState(() {
      _passwordStrength = strength;
      
      if (strength < 0.3) {
        _passwordStrengthText = 'Çok Zayıf';
        _passwordStrengthColor = Colors.red;
      } else if (strength < 0.5) {
        _passwordStrengthText = 'Zayıf';
        _passwordStrengthColor = Colors.orange;
      } else if (strength < 0.7) {
        _passwordStrengthText = 'Orta';
        _passwordStrengthColor = Colors.yellow;
      } else if (strength < 0.9) {
        _passwordStrengthText = 'Güçlü';
        _passwordStrengthColor = Colors.lightGreen;
      } else {
        _passwordStrengthText = 'Çok Güçlü';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  void _devamEt() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 🔒 Şifre gücü kontrolü
    if (_passwordStrength < 0.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen daha güçlü bir şifre seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignupStep2(
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Geri", style: TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İlerleme Çubuğu
              _buildProgressBar(context, 1),
              const SizedBox(height: 20),

              const Text(
                "Tercihleri sizinle benzer insanları bulun",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Mest'e katılın, eğlenceli testleri çözerek yeni insanlarla tanışın.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Email
              const Text("Email *", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Email adresinizi yazınız",
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
                ),
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 20),

              // Telefon Numarası
              const Text("Telefon Numarası", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Telefon numaranızı yazınız (opsiyonel)",
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 20),

              // Şifre
              const Text("Şifre *", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Şifrenizi yazınız",
                  prefixIcon: const Icon(Icons.lock_outlined, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: _updatePasswordStrength,
              ),
              
              // 🔒 Şifre Gücü Göstergesi
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _passwordStrength,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _passwordStrengthText,
                      style: TextStyle(color: _passwordStrengthColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "En az 8 karakter, 1 büyük harf, 1 küçük harf ve 1 rakam gerekli",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
              
              const SizedBox(height: 20),

              // Şifre Tekrar
              const Text("Şifre Tekrar *", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Şifrenizi tekrar yazınız",
                  prefixIcon: const Icon(Icons.lock_outlined, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: _validateConfirmPassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text(
                    "Devam",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                    child: Text(
                      "Giriş Yap",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
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