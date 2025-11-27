import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: "Mest'e Hoş Geldin! 🎉",
      description: "Eğlenceli testler çözerek seninle aynı zevklere sahip insanlarla tanış.",
      image: "assets/onboarding_1.png",
      icon: Icons.favorite,
      gradient: [const Color(0xFFFF5A5F), const Color(0xFFFF8A8E)],
    ),
    OnboardingItem(
      title: "Testleri Çöz 🎯",
      description: "En sevdiğin pizza malzemesi? Favori film türün? Turnuva formatında testleri çöz ve tercihlerini keşfet!",
      image: "assets/onboarding_2.png",
      icon: Icons.quiz,
      gradient: [const Color(0xFF6C63FF), const Color(0xFF9D94FF)],
    ),
    OnboardingItem(
      title: "Eşleş & Tanış 💘",
      description: "Benzer sonuçlara sahip kullanıcılarla eşleş. %90+ uyumlu insanlarla sohbet et!",
      image: "assets/onboarding_3.png",
      icon: Icons.people,
      gradient: [const Color(0xFF00C853), const Color(0xFF69F0AE)],
    ),
    OnboardingItem(
      title: "Mestometre ile Uyumunu Gör 📊",
      description: "Eşleştiğin kişilerle ortak zevklerini keşfet. Ne kadar uyumlu olduğunuzu öğren!",
      image: "assets/onboarding_4.png",
      icon: Icons.analytics,
      gradient: [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Onboarding'i tamamlandı olarak işaretle
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: Column(
          children: [
            // Skip Butonu
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    _currentPage == _items.length - 1 ? "" : "Atla",
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _buildPage(_items[index]),
              ),
            ),

            // Alt Kısım
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Sayfa İndikatörleri
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFFFF5A5F)
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Buton
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A5F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFFFF5A5F).withOpacity(0.4),
                      ),
                      child: Text(
                        _currentPage == _items.length - 1 ? "Başla!" : "Devam",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İkon Container
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: item.gradient[0].withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              item.icon,
              size: 80,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 50),

          // Başlık
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 20),

          // Açıklama
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String image;
  final IconData icon;
  final List<Color> gradient;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.image,
    required this.icon,
    required this.gradient,
  });
}

// ============ ONBOARDING KONTROLÜ ============
// main.dart'ta kullanılacak helper
class OnboardingHelper {
  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_completed') ?? false);
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
  }
}