import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'play_mest_screen.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'week'; // 'today', 'week', 'month'
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _trendingChoices = [];
  List<Map<String, dynamic>> _trendingTests = [];
  Map<String, Map<String, dynamic>> _categoryTrends = {};
  Map<String, dynamic>? _topTrend;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrends() async {
    setState(() => _isLoading = true);

    try {
      // Dönem başlangıcını hesapla
      DateTime startDate;
      if (_selectedPeriod == 'today') {
        startDate = DateTime.now().subtract(const Duration(days: 1));
      } else if (_selectedPeriod == 'week') {
        startDate = DateTime.now().subtract(const Duration(days: 7));
      } else {
        startDate = DateTime.now().subtract(const Duration(days: 30));
      }

      // Turnuva sonuçlarını al
      QuerySnapshot results = await FirebaseFirestore.instance
          .collection('turnuvalar')
          .where('tarih', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      // Seçim sayımları
      Map<String, Map<String, dynamic>> choiceCounts = {};
      Map<String, int> testPlayCounts = {};
      Map<String, Map<String, int>> categoryChoiceCounts = {};

      for (var doc in results.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String? kazanan = data['kazananIsim'];
        String? kazananResim = data['kazananResim'];
        String? testId = data['testId'];

        if (kazanan != null && kazanan.isNotEmpty) {
          if (choiceCounts.containsKey(kazanan)) {
            choiceCounts[kazanan]!['count']++;
          } else {
            choiceCounts[kazanan] = {
              'name': kazanan,
              'image': kazananResim,
              'count': 1,
              'testId': testId,
            };
          }
        }

        if (testId != null) {
          testPlayCounts[testId] = (testPlayCounts[testId] ?? 0) + 1;
        }
      }

      // En trend seçimleri sırala
      _trendingChoices = choiceCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      _trendingChoices = _trendingChoices.take(20).toList();

      // Top trend
      if (_trendingChoices.isNotEmpty) {
        _topTrend = _trendingChoices.first;
      }

      // Trend testleri al
      List<MapEntry<String, int>> sortedTests = testPlayCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      List<Map<String, dynamic>> trendingTestsList = [];
      for (var entry in sortedTests.take(10)) {
        DocumentSnapshot testDoc = await FirebaseFirestore.instance
            .collection('testler')
            .doc(entry.key)
            .get();
        
        if (testDoc.exists) {
          var testData = testDoc.data() as Map<String, dynamic>;
          String? kapakResmi = testData['kapakResmi'];
          if (kapakResmi == null || kapakResmi.isEmpty) {
            List secenekler = testData['secenekler'] ?? [];
            if (secenekler.isNotEmpty) {
              kapakResmi = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'];
            }
          }

          trendingTestsList.add({
            'id': entry.key,
            'title': testData['baslik'] ?? 'Test',
            'category': testData['kategori'] ?? 'Genel',
            'image': kapakResmi,
            'playCount': entry.value,
            'totalPlayCount': testData['playCount'] ?? 0,
          });

          // Kategori trendlerini güncelle
          String category = testData['kategori'] ?? 'Genel';
          if (!_categoryTrends.containsKey(category)) {
            _categoryTrends[category] = {
              'topChoice': null,
              'topChoiceCount': 0,
              'totalPlays': 0,
            };
          }
          _categoryTrends[category]!['totalPlays'] += entry.value;
        }
      }

      _trendingTests = trendingTestsList;

      // Kategori bazlı en popüler seçimleri bul
      for (var choice in _trendingChoices) {
        if (choice['testId'] != null) {
          DocumentSnapshot testDoc = await FirebaseFirestore.instance
              .collection('testler')
              .doc(choice['testId'])
              .get();
          
          if (testDoc.exists) {
            var testData = testDoc.data() as Map<String, dynamic>;
            String category = testData['kategori'] ?? 'Genel';
            
            if (_categoryTrends.containsKey(category)) {
              int currentTopCount = _categoryTrends[category]!['topChoiceCount'] ?? 0;
              if ((choice['count'] as int) > currentTopCount) {
                _categoryTrends[category]!['topChoice'] = choice['name'];
                _categoryTrends[category]!['topChoiceImage'] = choice['image'];
                _categoryTrends[category]!['topChoiceCount'] = choice['count'];
              }
            }
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Trend yükleme hatası: $e");
      setState(() => _isLoading = false);
    }
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
          "Trendler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ============ DÖNEM SEÇİCİ ============
          _buildPeriodSelector(),

          // ============ TAB BAR ============
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFFFF5A5F),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "Popüler Seçimler"),
                Tab(text: "Trend Testler"),
              ],
            ),
          ),

          // ============ İÇERİK ============
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPopularChoicesTab(),
                      _buildTrendingTestsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: Row(
        children: [
          _buildPeriodChip('today', 'Bugün', Icons.today),
          const SizedBox(width: 10),
          _buildPeriodChip('week', 'Bu Hafta', Icons.calendar_view_week),
          const SizedBox(width: 10),
          _buildPeriodChip('month', 'Bu Ay', Icons.calendar_month),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label, IconData icon) {
    bool isSelected = _selectedPeriod == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          _loadTrends();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5A5F) : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularChoicesTab() {
    if (_trendingChoices.isEmpty) {
      return _buildEmptyState("Henüz yeterli veri yok", "Test çözüldükçe trendler burada görünecek");
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Trend
          if (_topTrend != null) _buildTopTrendCard(),

          // Kategori Trendleri
          _buildCategoryTrends(),

          // Tüm Liste
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tüm Popüler Seçimler",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ...List.generate(_trendingChoices.length, (index) {
                  return _buildChoiceItem(_trendingChoices[index], index);
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTrendCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF5A5F).withOpacity(0.8),
            const Color(0xFFFF8A8E).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _topTrend!['image'] != null
                ? Image.network(
                    _topTrend!['image'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.white24,
                      child: const Icon(Icons.trending_up, color: Colors.white, size: 40),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.white24,
                    child: const Icon(Icons.trending_up, color: Colors.white, size: 40),
                  ),
          ),
          const SizedBox(width: 20),
          
          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.yellow, size: 20),
                    SizedBox(width: 5),
                    Text(
                      "EN TREND",
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _topTrend!['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${_topTrend!['count']} kez seçildi",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTrends() {
    if (_categoryTrends.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kategori Bazlı Trendler",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryTrends.length,
              itemBuilder: (context, index) {
                String category = _categoryTrends.keys.elementAt(index);
                var data = _categoryTrends[category]!;
                return _buildCategoryTrendCard(category, data);
              },
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildCategoryTrendCard(String category, Map<String, dynamic> data) {
    Color color = _getCategoryColor(category);
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getCategoryIcon(category), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          
          if (data['topChoice'] != null) ...[
            const Text(
              "En popüler:",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              data['topChoice'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            const Text(
              "Henüz veri yok",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          
          const SizedBox(height: 8),
          Text(
            "${data['totalPlays']} oynanma",
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceItem(Map<String, dynamic> choice, int index) {
    bool isTop3 = index < 3;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: isTop3 ? Border.all(color: _getRankColor(index)) : null,
      ),
      child: Row(
        children: [
          // Sıra
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: _getRankColor(index).withOpacity(isTop3 ? 1 : 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTop3
                  ? Text(
                      index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"),
                      style: const TextStyle(fontSize: 16),
                    )
                  : Text(
                      "${index + 1}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: choice['image'] != null
                ? Image.network(
                    choice['image'],
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 45,
                      height: 45,
                      color: Colors.grey[800],
                      child: const Icon(Icons.star, color: Colors.grey, size: 20),
                    ),
                  )
                : Container(
                    width: 45,
                    height: 45,
                    color: Colors.grey[800],
                    child: const Icon(Icons.star, color: Colors.grey, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          
          // İsim
          Expanded(
            child: Text(
              choice['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Sayı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5A5F).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.how_to_vote, color: Color(0xFFFF5A5F), size: 14),
                const SizedBox(width: 5),
                Text(
                  "${choice['count']}",
                  style: const TextStyle(
                    color: Color(0xFFFF5A5F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingTestsTab() {
    if (_trendingTests.isEmpty) {
      return _buildEmptyState("Henüz trend test yok", "Testler oynanınca burada görünecek");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _trendingTests.length,
      itemBuilder: (context, index) {
        return _buildTestItem(_trendingTests[index], index);
      },
    );
  }

  Widget _buildTestItem(Map<String, dynamic> test, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayMestScreen(testId: test['id'])),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Resim
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: test['image'] != null
                  ? Image.network(
                      test['image'],
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 100,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.quiz, color: Colors.grey, size: 30),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.quiz, color: Colors.grey, size: 30),
                    ),
            ),
            
            // Bilgiler
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sıra badge
                    if (index < 3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          color: _getRankColor(index),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "#${index + 1} Trend",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    
                    Text(
                      test['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A5F).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            test['category'],
                            style: const TextStyle(
                              color: Color(0xFFFF5A5F),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.play_arrow, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          "${test['playCount']} bu hafta",
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Ok
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey;
    if (index == 2) return Colors.orange.shade700;
    return Colors.grey[600]!;
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

  IconData _getCategoryIcon(String category) {
    Map<String, IconData> icons = {
      'Yemek & İçecek': Icons.restaurant,
      'Spor': Icons.sports_soccer,
      'Sinema & Dizi': Icons.movie,
      'Müzik': Icons.music_note,
      'Oyun': Icons.games,
      'Teknoloji': Icons.computer,
      'Seyahat': Icons.flight,
    };
    return icons[category] ?? Icons.category;
  }
}