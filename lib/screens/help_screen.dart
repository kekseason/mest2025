import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  int? _expandedIndex;

  final List<Map<String, dynamic>> _faqItems = [
    {
      'category': 'Genel',
      'icon': Icons.info_outline,
      'questions': [
        {
          'q': 'Mest nedir?',
          'a': 'Mest, eğlenceli testler çözerek seninle benzer zevklere sahip insanlarla tanışmanı sağlayan bir sosyal uygulamadır. "En iyi pizza malzemesi hangisi?" gibi testleri çöz, sonuçlarını karşılaştır ve %90+ uyumlu insanlarla eşleş!'
        },
        {
          'q': 'Uygulama ücretsiz mi?',
          'a': 'Evet! Mest\'in temel özellikleri tamamen ücretsizdir. Test çözme, eşleşme ve sohbet özelliklerini ücretsiz kullanabilirsin. Mest+ aboneliği ile sınırsız kaydırma, reklamsız deneyim ve özel rozetler gibi premium özelliklere erişebilirsin.'
        },
        {
          'q': 'Kaç yaşında olmam gerekiyor?',
          'a': 'Mest\'i kullanmak için en az 18 yaşında olmalısın. Kayıt sırasında doğum tarihin doğrulanır.'
        },
      ]
    },
    {
      'category': 'Testler',
      'icon': Icons.quiz_outlined,
      'questions': [
        {
          'q': 'Testler nasıl çalışıyor?',
          'a': 'Her test bir turnuva formatındadır. İki seçenek arasından favori olanı seçersin ve kazanan bir sonraki tura geçer. Final\'e kadar devam eder ve en sevdiğin seçenek belirlenir. Bu sonuç profilinde görünür ve eşleşme algoritmasında kullanılır.'
        },
        {
          'q': 'Kendi testimi oluşturabilir miyim?',
          'a': 'Evet! Profil > Test Oluştur bölümünden kendi testini oluşturabilirsin. En az 4 seçenek eklemelisin. Testler admin onayından sonra yayınlanır.'
        },
        {
          'q': 'Test sonuçlarım kimler görebilir?',
          'a': 'Test sonuçların profilinde görünür. Gizlilik ayarlarından profilini sadece eşleşmelere açık yapabilirsin.'
        },
      ]
    },
    {
      'category': 'Eşleşme',
      'icon': Icons.favorite_outline,
      'questions': [
        {
          'q': 'Eşleşme nasıl çalışıyor?',
          'a': 'Aynı testleri çözen kullanıcılarla sonuçların karşılaştırılır. Ortak seçim oranına göre uyum yüzdesi hesaplanır. %70 ve üzeri uyumlu kullanıcılar önerilir. İkiniz de beğenirseniz eşleşme gerçekleşir!'
        },
        {
          'q': 'Mestometre nedir?',
          'a': 'Mestometre, iki kullanıcı arasındaki uyumu gösteren özelliktir. Ortak çözülen testlerdeki benzerlik, ortak seçimler ve genel uyum analizi gösterilir.'
        },
        {
          'q': 'Eşleşme önerisini beğenmezsem?',
          'a': 'Sola kaydırarak geçebilirsin. O kişi bir daha önerilmez. İstersen ayarlardan engelleme de yapabilirsin.'
        },
      ]
    },
    {
      'category': 'Sohbet',
      'icon': Icons.chat_bubble_outline,
      'questions': [
        {
          'q': 'Kiminle sohbet edebilirim?',
          'a': 'Sadece karşılıklı beğeniyle eşleştiğin kişilerle sohbet edebilirsin. Bu sayede istenmeyen mesajlardan korunursun.'
        },
        {
          'q': 'Co-op test nedir?',
          'a': 'Sohbet içinden bir test davetiyesi gönderebilirsin. Aynı testi birlikte çözer ve sonuçlarınızı anında karşılaştırabilirsiniz. Eğlenceli bir tanışma yöntemi!'
        },
        {
          'q': 'Mesajlarımı silebilir miyim?',
          'a': 'Şu an için mesaj silme özelliği bulunmuyor. Rahatsız edici mesajlar için kullanıcıyı engelleyebilir veya şikayet edebilirsin.'
        },
      ]
    },
    {
      'category': 'Hesap & Güvenlik',
      'icon': Icons.security_outlined,
      'questions': [
        {
          'q': 'Şifremi unuttum, ne yapmalıyım?',
          'a': 'Giriş ekranında "Şifremi Unuttum" butonuna tıkla. E-posta adresine şifre sıfırlama bağlantısı göndereceğiz.'
        },
        {
          'q': 'Hesabımı nasıl silerim?',
          'a': 'Ayarlar > Hesap > Hesabı Sil yolunu takip et. Şifreni girerek onayladığında tüm verilerin kalıcı olarak silinir. Bu işlem geri alınamaz!'
        },
        {
          'q': 'Birini nasıl engellerim?',
          'a': 'Kullanıcının profilinde veya sohbette üç nokta menüsünden "Engelle" seçeneğini kullanabilirsin. Engellenen kişi sana mesaj atamaz ve profilini göremez.'
        },
        {
          'q': 'Birini nasıl şikayet ederim?',
          'a': 'Kullanıcının profilinde veya sohbette üç nokta menüsünden "Şikayet Et" seçeneğini kullanabilirsin. Şikayet nedenini seçerek gönder. Ekibimiz inceleyecektir.'
        },
      ]
    },
    {
      'category': 'Mest+ Premium',
      'icon': Icons.star_outline,
      'questions': [
        {
          'q': 'Mest+ ne gibi avantajlar sunuyor?',
          'a': '• Sınırsız kaydırma hakkı\n• Reklamsız deneyim\n• Seni beğenenleri görme\n• Özel premium rozetler\n• Öncelikli destek\n• Süper beğeni gönderme'
        },
        {
          'q': 'Aboneliği nasıl iptal ederim?',
          'a': 'App Store veya Google Play Store\'dan aboneliklerini yöneterek iptal edebilirsin. İptal sonrası dönem sonuna kadar premium özellikler aktif kalır.'
        },
      ]
    },
  ];

  List<Map<String, dynamic>> get _filteredFaq {
    if (_searchQuery.isEmpty) return _faqItems;

    return _faqItems.map((category) {
      var filteredQuestions = (category['questions'] as List).where((q) {
        return (q['q'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (q['a'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      return {
        ...category,
        'questions': filteredQuestions,
      };
    }).where((category) => (category['questions'] as List).isNotEmpty).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Yardım & SSS",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Arama Kutusu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Soru ara...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Hızlı Destek Butonları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    Icons.mail_outline,
                    "E-posta",
                    () => _launchEmail(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    Icons.chat_outlined,
                    "Canlı Destek",
                    () => _showComingSoon(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    Icons.language,
                    "Web",
                    () => _launchUrl("https://mestapp.com/help"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // FAQ Listesi
          Expanded(
            child: _filteredFaq.isEmpty
                ? _buildNoResults()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredFaq.length,
                    itemBuilder: (context, categoryIndex) {
                      var category = _filteredFaq[categoryIndex];
                      var questions = category['questions'] as List;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kategori Başlığı
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  category['icon'] as IconData,
                                  color: const Color(0xFFFF5A5F),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category['category'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Sorular
                          ...questions.asMap().entries.map((entry) {
                            int globalIndex = _getGlobalIndex(categoryIndex, entry.key);
                            var q = entry.value;
                            bool isExpanded = _expandedIndex == globalIndex;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(12),
                                border: isExpanded
                                    ? Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.5))
                                    : null,
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  title: Text(
                                    q['q'],
                                    style: TextStyle(
                                      color: isExpanded ? const Color(0xFFFF5A5F) : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Icon(
                                    isExpanded ? Icons.remove : Icons.add,
                                    color: isExpanded ? const Color(0xFFFF5A5F) : Colors.grey,
                                  ),
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      _expandedIndex = expanded ? globalIndex : null;
                                    });
                                  },
                                  initiallyExpanded: isExpanded,
                                  children: [
                                    Text(
                                      q['a'],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),

                          const SizedBox(height: 10),
                        ],
                      );
                    },
                  ),
          ),

          // Alt Bilgi
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "Sorunun cevabını bulamadın mı?",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchEmail(),
                    icon: const Icon(Icons.mail_outline, color: Colors.white),
                    label: const Text(
                      "Bize Ulaş",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A5F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getGlobalIndex(int categoryIndex, int questionIndex) {
    int index = 0;
    for (int i = 0; i < categoryIndex; i++) {
      index += (_filteredFaq[i]['questions'] as List).length;
    }
    return index + questionIndex;
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF5A5F), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[700]),
          const SizedBox(height: 15),
          const Text(
            "Sonuç bulunamadı",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Farklı kelimelerle aramayı dene",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Canlı destek yakında aktif olacak! 🚀"),
        backgroundColor: Color(0xFFFF5A5F),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'destek@mestapp.com',
      query: 'subject=Mest Uygulaması Yardım Talebi',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}