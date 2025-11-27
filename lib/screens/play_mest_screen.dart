import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:async';

class PlayMestScreen extends StatefulWidget {
  final String testId;

  const PlayMestScreen({super.key, required this.testId});

  @override
  State<PlayMestScreen> createState() => _PlayMestScreenState();
}

class _PlayMestScreenState extends State<PlayMestScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> secenekler = [];
  List<Map<String, dynamic>> currentRound = [];
  int currentMatchIndex = 0;
  int roundNumber = 1;
  String testBaslik = "";
  String? testKapakResmi;
  bool isLoading = true;
  Map<String, dynamic>? winner;
  
  // Etkinlik testi kontrolleri
  bool isEventTest = false;
  DateTime? eventEndTime;
  Timer? _countdownTimer;
  Duration? remainingTime;
  
  // Her tur sonuçları
  List<Map<String, dynamic>> roundWinners = [];
  Map<String, int> scores = {};

  // Animasyon
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  int? selectedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _loadTest();
  }

  @override
  void dispose() {
    _animController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTest() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('testler')
          .doc(widget.testId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          _showError("Test bulunamadı");
          Navigator.pop(context);
        }
        return;
      }

      var data = doc.data() as Map<String, dynamic>;
      
      // ============ ETKİNLİK TESTİ KONTROLÜ ============
      isEventTest = data['isEventTest'] ?? false;
      
      if (isEventTest) {
        Timestamp? endTimeStamp = data['eventEndTime'];
        if (endTimeStamp != null) {
          eventEndTime = endTimeStamp.toDate();
          
          // Süre kontrolü
          if (DateTime.now().isAfter(eventEndTime!)) {
            if (mounted) {
              _showError("Bu etkinliğin süresi dolmuş");
              Navigator.pop(context);
            }
            return;
          }
          
          // Geri sayım başlat
          _startCountdown();
        }
        
        // Başlangıç zamanı kontrolü
        Timestamp? startTimeStamp = data['eventStartTime'];
        if (startTimeStamp != null) {
          DateTime startTime = startTimeStamp.toDate();
          if (DateTime.now().isBefore(startTime)) {
            if (mounted) {
              _showError("Bu etkinlik henüz başlamadı");
              Navigator.pop(context);
            }
            return;
          }
        }
      }

      List<dynamic> rawSecenekler = data['secenekler'] ?? [];

      setState(() {
        testBaslik = data['baslik'] ?? 'Test';
        testKapakResmi = data['kapakResmi'];
        secenekler = rawSecenekler.map((s) {
          String isim = s['isim'] ?? s['name'] ?? 'Seçenek';
          String? resim = s['resimUrl'] ?? s['resim'] ?? s['image'];
          return {'isim': isim, 'resim': resim, 'id': isim};
        }).toList();

        // Karıştır
        secenekler.shuffle(Random());

        // İlk turu hazırla
        _prepareRound();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Test yükleme hatası: $e");
      if (mounted) {
        _showError("Test yüklenirken hata oluştu");
        Navigator.pop(context);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (eventEndTime == null) {
        timer.cancel();
        return;
      }
      
      setState(() {
        remainingTime = eventEndTime!.difference(DateTime.now());
      });
      
      // Süre bittiyse
      if (remainingTime!.isNegative) {
        timer.cancel();
        _showTimeUpDialog();
      }
      
      // Son 5 dakika uyarısı
      if (remainingTime!.inMinutes == 5 && remainingTime!.inSeconds % 60 == 0) {
        _showWarning("⏰ Son 5 dakika!");
      }
    });
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text("Süre Doldu!", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Etkinlik süresi sona erdi. Sonuçların kaydedildi.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // Sayfadan çık
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A5F)),
            child: const Text("Tamam", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showWarning(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _prepareRound() {
    if (secenekler.length == 1) {
      setState(() {
        winner = secenekler[0];
      });
      _saveResult();
      return;
    }

    currentRound = List.from(secenekler);
    if (currentRound.length % 2 != 0) {
      roundWinners.add(currentRound.removeLast());
    }

    currentMatchIndex = 0;
    roundWinners = [];
  }

  void _selectOption(int index) async {
    if (selectedIndex != null) return;

    // Süre kontrolü (etkinlik testi ise)
    if (isEventTest && eventEndTime != null) {
      if (DateTime.now().isAfter(eventEndTime!)) {
        _showTimeUpDialog();
        return;
      }
    }

    setState(() => selectedIndex = index);
    await _animController.forward();

    Map<String, dynamic> selected = index == 0 
        ? currentRound[currentMatchIndex * 2]
        : currentRound[currentMatchIndex * 2 + 1];
    
    String selectedId = selected['id'];
    scores[selectedId] = (scores[selectedId] ?? 0) + 1;
    
    roundWinners.add(selected);

    await Future.delayed(const Duration(milliseconds: 400));
    _animController.reset();

    setState(() {
      selectedIndex = null;
      currentMatchIndex++;

      if (currentMatchIndex * 2 >= currentRound.length) {
        secenekler = List.from(roundWinners);
        roundNumber++;
        _prepareRound();
      }
    });
  }

  Future<void> _saveResult() async {
    if (winner == null) return;

    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('turnuvalar').add({
        'odenen': userId,
        'testId': widget.testId,
        'kazanan': winner!['isim'],
        'kazananResim': winner!['resim'],
        'skorlar': scores,
        'tarih': FieldValue.serverTimestamp(),
        'isEventTest': isEventTest,
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'testCount': FieldValue.increment(1),
      });

      // Test play count güncelle
      await FirebaseFirestore.instance.collection('testler').doc(widget.testId).update({
        'playCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("Sonuç kaydetme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
        ),
      );
    }

    if (winner != null) {
      return _buildWinnerScreen();
    }

    if (currentMatchIndex * 2 + 1 >= currentRound.length) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D11),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))),
      );
    }

    Map<String, dynamic> option1 = currentRound[currentMatchIndex * 2];
    Map<String, dynamic> option2 = currentRound[currentMatchIndex * 2 + 1];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => _showExitDialog(),
        ),
        title: const Text("Mestler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Etkinlik testi ise kalan süreyi göster
          if (isEventTest && remainingTime != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: remainingTime!.inMinutes < 5 ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(remainingTime!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Test başlığı
          _buildTestHeader(),

          const SizedBox(height: 20),

          // Soru
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              "Hangisi Daha Güzel?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 25),

          // Seçenekler
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _buildOptionCard(option1, 0)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildOptionCard(option2, 1)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Butonlar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Kaydet", style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentMatchIndex > 0 ? _goBack : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A5F),
                      disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Önceki Soru", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTestHeader() {
    String? imageUrl = testKapakResmi;
    if (imageUrl == null || imageUrl.isEmpty) {
      if (secenekler.isNotEmpty) {
        imageUrl = secenekler[0]['resim'];
      }
    }

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1C1C1E),
        border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF1C1C1E)),
              ),
            Container(color: Colors.black.withOpacity(0.5)),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    testBaslik,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isEventTest)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "ETKİNLİK",
                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildOptionCard(Map<String, dynamic> option, int index) {
    bool isSelected = selectedIndex == index;
    String? imageUrl = option['resim'];

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          double scale = isSelected ? _scaleAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF5A5F) : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.4), blurRadius: 15, spreadRadius: 2)]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildPlaceholder(option['isim']),
                          )
                        : _buildPlaceholder(option['isim']),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 12,
                      right: 12,
                      child: Text(
                        option['isim'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(String name) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildWinnerScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Mestler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildTestHeader(),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
            child: const Text("Kazanan", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.check, color: Color(0xFFFF5A5F), size: 80),
          const SizedBox(height: 20),
          Container(
            width: 250,
            height: 250,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1C1C1E),
              boxShadow: [BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (winner!['resim'] != null)
                    Image.network(winner!['resim'], fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.3)),
                  Center(
                    child: Text(
                      winner!['isim'] ?? 'Kazanan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Geri Dön", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showStatistics(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A5F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("İstatistikler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showStatistics() {
    // İstatistik sayfasına git
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MestStatisticsScreen(
          testId: widget.testId,
          testBaslik: testBaslik,
          testKapakResmi: testKapakResmi,
        ),
      ),
    );
  }

  void _goBack() {
    if (currentMatchIndex > 0) {
      setState(() {
        currentMatchIndex--;
        if (roundWinners.isNotEmpty) {
          roundWinners.removeLast();
        }
      });
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Testten Çık", style: TextStyle(color: Colors.white)),
        content: const Text(
          "İlerlemeniz kaydedilmeyecek. Çıkmak istediğinize emin misiniz?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A5F)),
            child: const Text("Çık", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00";
    
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return "${hours}s ${minutes}dk";
    } else if (minutes > 0) {
      return "${minutes}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "0:${seconds.toString().padLeft(2, '0')}";
    }
  }
}

// ============ İSTATİSTİKLER SAYFASI ============
class MestStatisticsScreen extends StatelessWidget {
  final String testId;
  final String testBaslik;
  final String? testKapakResmi;

  const MestStatisticsScreen({
    super.key,
    required this.testId,
    required this.testBaslik,
    this.testKapakResmi,
  });

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
        title: const Text("İstatistikler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
            child: const Text("En çok kazananlar", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('turnuvalar')
                  .where('testId', isEqualTo: testId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                }

                Map<String, Map<String, dynamic>> winnerStats = {};
                
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String kazanan = data['kazanan'] ?? '';
                  String? resim = data['kazananResim'];
                  
                  if (kazanan.isNotEmpty) {
                    if (winnerStats.containsKey(kazanan)) {
                      winnerStats[kazanan]!['count']++;
                    } else {
                      winnerStats[kazanan] = {'name': kazanan, 'resim': resim, 'count': 1};
                    }
                  }
                }

                List<Map<String, dynamic>> sortedWinners = winnerStats.values.toList();
                sortedWinners.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

                int totalVotes = sortedWinners.fold(0, (sum, item) => sum + (item['count'] as int));

                if (sortedWinners.isEmpty) {
                  return const Center(
                    child: Text("Henüz sonuç yok", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sortedWinners.length > 10 ? 10 : sortedWinners.length,
                  itemBuilder: (context, index) {
                    var winner = sortedWinners[index];
                    double percentage = totalVotes > 0 ? (winner['count'] / totalVotes) * 100 : 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "#${index + 1}",
                            style: TextStyle(
                              color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey : (index == 2 ? Colors.orange : Colors.white)),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  winner['name'],
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "%${percentage.toStringAsFixed(1)} oy",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (winner['resim'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                winner['resim'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A5F),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Başka Bir Mest Çöz", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}