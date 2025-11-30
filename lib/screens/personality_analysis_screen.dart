import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

// ============ KİŞİLİK TİPLERİ ============
class PersonalityType {
  final String name;
  final String emoji;
  final String description;
  final Color color;
  final List<String> traits;
  final List<String> compatibleTypes;

  PersonalityType({
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    required this.traits,
    required this.compatibleTypes,
  });
}

// ============ KİŞİLİK ANALİZİ EKRANI ============
class PersonalityAnalysisScreen extends StatefulWidget {
  const PersonalityAnalysisScreen({super.key});

  @override
  State<PersonalityAnalysisScreen> createState() => _PersonalityAnalysisScreenState();
}

class _PersonalityAnalysisScreenState extends State<PersonalityAnalysisScreen> 
    with SingleTickerProviderStateMixin {
  String? _userId;
  bool _isLoading = true;
  Map<String, double> _categoryScores = {};
  Map<String, int> _categoryCounts = {};
  int _totalTests = 0;
  PersonalityType? _dominantType;
  List<Map<String, dynamic>> _topChoices = [];
  
  late AnimationController _animController;

  // Kişilik tipleri tanımları
  final Map<String, PersonalityType> _personalityTypes = {
    'Gurme': PersonalityType(
      name: 'Gurme',
      emoji: '🍽️',
      description: 'Yemek ve içecek konusunda tutkulu, lezzet avcısı',
      color: Colors.orange,
      traits: ['Keşifçi', 'Damak tadı gelişmiş', 'Sosyal', 'Deneyimci'],
      compatibleTypes: ['Kaşif', 'Sosyal Kelebek'],
    ),
    'Sporcu': PersonalityType(
      name: 'Sporcu',
      emoji: '⚽',
      description: 'Aktif yaşamı seven, rekabetçi ruh',
      color: Colors.green,
      traits: ['Enerjik', 'Disiplinli', 'Takım oyuncusu', 'Azimli'],
      compatibleTypes: ['Maceraperest', 'Stratejist'],
    ),
    'Sinefil': PersonalityType(
      name: 'Sinefil',
      emoji: '🎬',
      description: 'Film ve dizi tutkunu, hikaye aşığı',
      color: Colors.purple,
      traits: ['Hayal gücü geniş', 'Detaycı', 'Empatik', 'Kültürlü'],
      compatibleTypes: ['Müzisyen', 'Oyuncu'],
    ),
    'Müzisyen': PersonalityType(
      name: 'Müzisyen',
      emoji: '🎵',
      description: 'Müzik ruhunun gıdası, melodi aşığı',
      color: Colors.pink,
      traits: ['Duygusal', 'Yaratıcı', 'Ritim duygusu güçlü', 'İfade gücü yüksek'],
      compatibleTypes: ['Sinefil', 'Sanatçı'],
    ),
    'Oyuncu': PersonalityType(
      name: 'Oyuncu',
      emoji: '🎮',
      description: 'Oyun dünyasının kahramanı, stratejist',
      color: Colors.blue,
      traits: ['Stratejik', 'Rekabetçi', 'Problem çözücü', 'Teknoloji meraklısı'],
      compatibleTypes: ['Teknolojist', 'Sporcu'],
    ),
    'Teknolojist': PersonalityType(
      name: 'Teknolojist',
      emoji: '💻',
      description: 'Teknoloji gurusu, yenilik takipçisi',
      color: Colors.cyan,
      traits: ['Analitik', 'Meraklı', 'Yenilikçi', 'Pratik'],
      compatibleTypes: ['Oyuncu', 'Stratejist'],
    ),
    'Kaşif': PersonalityType(
      name: 'Kaşif',
      emoji: '🌍',
      description: 'Dünyayı keşfetmeye aç, macera tutkunu',
      color: Colors.teal,
      traits: ['Meraklı', 'Cesur', 'Açık fikirli', 'Adaptif'],
      compatibleTypes: ['Gurme', 'Maceraperest'],
    ),
    'Dengeli': PersonalityType(
      name: 'Dengeli',
      emoji: '⚖️',
      description: 'Her alandan biraz, çok yönlü kişilik',
      color: Colors.amber,
      traits: ['Uyumlu', 'Esnek', 'Çok yönlü', 'Meraklı'],
      compatibleTypes: ['Herkes'],
    ),
  };

  // Kategori -> Kişilik tipi eşleştirmesi
  final Map<String, String> _categoryToPersonality = {
    'Yemek & İçecek': 'Gurme',
    'Spor': 'Sporcu',
    'Sinema & Dizi': 'Sinefil',
    'Müzik': 'Müzisyen',
    'Oyun': 'Oyuncu',
    'Teknoloji': 'Teknolojist',
    'Seyahat': 'Kaşif',
  };

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadAnalysis();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    if (_userId == null) return;

    try {
      // Kullanıcının tüm test sonuçlarını al
      QuerySnapshot results = await FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('userId', isEqualTo: _userId)
          .get();

      Map<String, int> categoryCounts = {};
      Map<String, List<String>> categoryChoices = {};
      Map<String, int> choiceCounts = {};

      for (var doc in results.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        // Test bilgilerini al
        String? testId = data['testId'];
        String? kazanan = data['kazananIsim'];
        String? kazananResim = data['kazananResim'];

        if (testId != null) {
          // Test kategorisini al
          DocumentSnapshot testDoc = await FirebaseFirestore.instance
              .collection('testler')
              .doc(testId)
              .get();
          
          if (testDoc.exists) {
            var testData = testDoc.data() as Map<String, dynamic>;
            String category = testData['kategori'] ?? 'Genel';
            
            categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
            
            if (kazanan != null) {
              categoryChoices[category] ??= [];
              categoryChoices[category]!.add(kazanan);
              
              // Seçim sayısını kaydet
              String key = kazanan;
              choiceCounts[key] = (choiceCounts[key] ?? 0) + 1;
            }
          }
        }
      }

      // Toplam test sayısı
      _totalTests = results.docs.length;

      // Kategori yüzdelerini hesapla
      if (_totalTests > 0) {
        categoryCounts.forEach((category, count) {
          _categoryScores[category] = (count / _totalTests) * 100;
          _categoryCounts[category] = count;
        });
      }

      // En çok seçilen 5 şeyi bul
      var sortedChoices = choiceCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      _topChoices = sortedChoices.take(5).map((e) => {
        'name': e.key,
        'count': e.value,
      }).toList();

      // Baskın kişilik tipini belirle
      _dominantType = _calculateDominantType();

      setState(() => _isLoading = false);
      _animController.forward();
    } catch (e) {
      debugPrint("Analiz hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  PersonalityType _calculateDominantType() {
    if (_categoryScores.isEmpty) {
      return _personalityTypes['Dengeli']!;
    }

    // En yüksek skoru bul
    String? topCategory;
    double topScore = 0;
    
    _categoryScores.forEach((category, score) {
      if (score > topScore) {
        topScore = score;
        topCategory = category;
      }
    });

    // Eğer baskın kategori %40'ın altındaysa "Dengeli"
    if (topScore < 40) {
      return _personalityTypes['Dengeli']!;
    }

    // Kategoriyi kişilik tipine çevir
    String? personalityName = _categoryToPersonality[topCategory];
    return _personalityTypes[personalityName] ?? _personalityTypes['Dengeli']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Kişilik Analizi",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.grey),
            onPressed: _shareAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)))
          : _totalTests < 5
              ? _buildNotEnoughData()
              : _buildAnalysisContent(),
    );
  }

  Widget _buildNotEnoughData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, size: 100, color: Colors.grey[700]),
            const SizedBox(height: 25),
            const Text(
              "Daha Fazla Test Çöz!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Kişilik analizin için en az 5 test çözmen gerekiyor.\n\nŞu ana kadar $_totalTests test çözdün.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A5F),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text("Test Çözmeye Git", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ============ ANA KİŞİLİK TİPİ ============
          _buildMainPersonalityCard(),

          const SizedBox(height: 25),

          // ============ KATEGORİ DAĞILIMI ============
          _buildCategoryDistribution(),

          const SizedBox(height: 25),

          // ============ ÖZELLİKLER ============
          _buildTraitsSection(),

          const SizedBox(height: 25),

          // ============ EN SEVDİKLERİN ============
          _buildTopChoicesSection(),

          const SizedBox(height: 25),

          // ============ UYUMLU TİPLER ============
          _buildCompatibleTypes(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMainPersonalityCard() {
    if (_dominantType == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _dominantType!.color.withOpacity(0.6),
            _dominantType!.color.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _dominantType!.color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Emoji
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (_animController.value * 0.2),
                child: Text(
                  _dominantType!.emoji,
                  style: const TextStyle(fontSize: 70),
                ),
              );
            },
          ),
          const SizedBox(height: 15),

          // Tip adı
          Text(
            _dominantType!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Açıklama
          Text(
            _dominantType!.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 20),

          // İstatistik
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              "$_totalTests test analiz edildi",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, color: Color(0xFFFF5A5F)),
              SizedBox(width: 10),
              Text(
                "İlgi Alanı Dağılımı",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Radar/Pie chart benzeri görsel
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _CategoryChartPainter(_categoryScores),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${_categoryScores.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Kategori",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Kategori listesi
          ...(_categoryScores.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
              .map((entry) => _buildCategoryBar(entry.key, entry.value))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String category, double percentage) {
    Color color = _getCategoryColor(category);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text(
                "%${percentage.toStringAsFixed(1)}",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    Map<String, Color> colors = {
      'Yemek & İçecek': Colors.orange,
      'Spor': Colors.green,
      'Sinema & Dizi': Colors.purple,
      'Müzik': Colors.pink,
      'Oyun': Colors.blue,
      'Teknoloji': Colors.cyan,
      'Seyahat': Colors.teal,
    };
    return colors[category] ?? const Color(0xFFFF5A5F);
  }

  Widget _buildTraitsSection() {
    if (_dominantType == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Color(0xFFFF5A5F)),
              SizedBox(width: 10),
              Text(
                "Kişilik Özelliklerin",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _dominantType!.traits.map((trait) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _dominantType!.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _dominantType!.color.withOpacity(0.5)),
                ),
                child: Text(
                  trait,
                  style: TextStyle(
                    color: _dominantType!.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopChoicesSection() {
    if (_topChoices.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite, color: Color(0xFFFF5A5F)),
              SizedBox(width: 10),
              Text(
                "En Çok Seçtiklerin",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ...List.generate(_topChoices.length, (index) {
            var choice = _topChoices[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Sıra
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: index == 0 
                          ? Colors.amber 
                          : (index == 1 ? Colors.grey : Colors.orange.shade700),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  
                  // İsim
                  Expanded(
                    child: Text(
                      choice['name'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                  
                  // Sayı
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A5F).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${choice['count']}x",
                      style: const TextStyle(
                        color: Color(0xFFFF5A5F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompatibleTypes() {
    if (_dominantType == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people, color: Color(0xFFFF5A5F)),
              SizedBox(width: 10),
              Text(
                "Uyumlu Olduğun Tipler",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Bu kişilik tiplerine sahip insanlarla daha iyi anlaşabilirsin:",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 15),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _dominantType!.compatibleTypes.map((typeName) {
              PersonalityType? type = _personalityTypes[typeName];
              if (type == null) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeName,
                    style: const TextStyle(color: Colors.green),
                  ),
                );
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: type.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      type.name,
                      style: TextStyle(color: type.color, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _shareAnalysis() {
    if (_dominantType == null) return;
    
    String shareText = "🎭 Mest Kişilik Analizim:\n\n"
        "${_dominantType!.emoji} ${_dominantType!.name}\n"
        "${_dominantType!.description}\n\n"
        "Özelliklerim: ${_dominantType!.traits.join(', ')}\n\n"
        "Sen de kişiliğini keşfet! 👉 mest.app";
    
    // Share fonksiyonu çağrılacak
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Paylaşılacak: $shareText"),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// ============ KATEGORİ GRAFİĞİ ============
class _CategoryChartPainter extends CustomPainter {
  final Map<String, double> scores;

  _CategoryChartPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    
    double startAngle = -math.pi / 2;
    
    List<Color> colors = [
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.pink,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.red,
    ];

    int colorIndex = 0;
    
    scores.forEach((category, percentage) {
      final sweepAngle = (percentage / 100) * 2 * math.pi;
      
      final paint = Paint()
        ..color = colors[colorIndex % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.05, // Küçük boşluk
        false,
        paint,
      );

      startAngle += sweepAngle;
      colorIndex++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}