import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// ============ GÜNLÜK GÖREV MODELİ ============
class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int targetCount;
  final int currentCount;
  final int xpReward;
  final String type; // 'test', 'chat', 'match', 'share'
  final bool isCompleted;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetCount,
    required this.currentCount,
    required this.xpReward,
    required this.type,
    required this.isCompleted,
  });

  double get progress => currentCount / targetCount;
}

// ============ GÜNLÜK GÖREVLER EKRANI ============
class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen> with SingleTickerProviderStateMixin {
  String? _userId;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalXP = 0;
  DateTime? _lastActiveDate;
  List<DailyChallenge> _challenges = [];
  bool _isLoading = true;
  
  // Geri sayım
  Duration _timeUntilReset = Duration.zero;
  Timer? _countdownTimer;
  
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    
    _loadData();
    _startCountdown();
  }

  @override
  void dispose() {
    _animController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateTimeUntilReset();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeUntilReset();
    });
  }

  void _updateTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    setState(() {
      _timeUntilReset = tomorrow.difference(now);
    });
  }

  Future<void> _loadData() async {
    if (_userId == null) return;

    try {
      // Kullanıcı verilerini al
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _currentStreak = data['currentStreak'] ?? 0;
          _longestStreak = data['longestStreak'] ?? 0;
          _totalXP = data['totalXP'] ?? 0;
          _lastActiveDate = data['lastActiveDate'] != null 
              ? (data['lastActiveDate'] as Timestamp).toDate() 
              : null;
        });

        // Streak kontrolü
        await _checkAndUpdateStreak();
      }

      // Günlük görevleri yükle
      await _loadDailyChallenges();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndUpdateStreak() async {
    if (_userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastActiveDate != null) {
      final lastDate = DateTime(
        _lastActiveDate!.year, 
        _lastActiveDate!.month, 
        _lastActiveDate!.day
      );
      
      final difference = today.difference(lastDate).inDays;

      if (difference == 0) {
        // Bugün zaten aktif
        return;
      } else if (difference == 1) {
        // Dün aktifti, streak devam ediyor
        _currentStreak++;
        if (_currentStreak > _longestStreak) {
          _longestStreak = _currentStreak;
        }
      } else {
        // Streak kırıldı
        _currentStreak = 1;
      }
    } else {
      // İlk giriş
      _currentStreak = 1;
    }

    // Güncelle
    await FirebaseFirestore.instance.collection('users').doc(_userId).update({
      'currentStreak': _currentStreak,
      'longestStreak': _longestStreak,
      'lastActiveDate': FieldValue.serverTimestamp(),
    });

    // Streak rozetlerini kontrol et
    await _checkStreakBadges();

    setState(() {});
  }

  Future<void> _checkStreakBadges() async {
    if (_userId == null) return;

    List<String> newBadges = [];

    if (_currentStreak >= 7) newBadges.add("7 Gün Streak 🔥");
    if (_currentStreak >= 30) newBadges.add("30 Gün Streak 💎");
    if (_currentStreak >= 100) newBadges.add("100 Gün Streak 👑");

    if (newBadges.isNotEmpty) {
      // Mevcut rozetleri al
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      
      List<dynamic> currentBadges = (doc.data() as Map<String, dynamic>)['badges'] ?? [];
      
      // Yeni rozetleri ekle
      for (var badge in newBadges) {
        if (!currentBadges.contains(badge)) {
          await FirebaseFirestore.instance.collection('users').doc(_userId).update({
            'badges': FieldValue.arrayUnion([badge]),
          });
          _showBadgeNotification(badge);
        }
      }
    }
  }

  void _showBadgeNotification(String badge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white),
            const SizedBox(width: 10),
            Text("Yeni Rozet: $badge", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDailyChallenges() async {
    if (_userId == null) return;

    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month}-${today.day}";

    // Bugünkü görev ilerlemesini al
    DocumentSnapshot progressDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('dailyProgress')
        .doc(todayStr)
        .get();

    Map<String, dynamic> progress = {};
    if (progressDoc.exists) {
      progress = progressDoc.data() as Map<String, dynamic>;
    }

    // Görevleri oluştur
    _challenges = [
      DailyChallenge(
        id: 'solve_tests',
        title: '3 Test Çöz',
        description: 'Bugün 3 farklı test çöz',
        icon: Icons.quiz,
        color: const Color(0xFFFF5A5F),
        targetCount: 3,
        currentCount: progress['testsCompleted'] ?? 0,
        xpReward: 50,
        type: 'test',
        isCompleted: (progress['testsCompleted'] ?? 0) >= 3,
      ),
      DailyChallenge(
        id: 'send_messages',
        title: '5 Mesaj Gönder',
        description: 'Eşleşmelerinle sohbet et',
        icon: Icons.chat_bubble,
        color: Colors.blue,
        targetCount: 5,
        currentCount: progress['messagesSent'] ?? 0,
        xpReward: 30,
        type: 'chat',
        isCompleted: (progress['messagesSent'] ?? 0) >= 5,
      ),
      DailyChallenge(
        id: 'new_match',
        title: 'Yeni Eşleşme',
        description: 'En az 1 kişiyle eşleş',
        icon: Icons.favorite,
        color: Colors.pink,
        targetCount: 1,
        currentCount: progress['newMatches'] ?? 0,
        xpReward: 100,
        type: 'match',
        isCompleted: (progress['newMatches'] ?? 0) >= 1,
      ),
      DailyChallenge(
        id: 'profile_visit',
        title: '3 Profil Ziyaret Et',
        description: 'Diğer kullanıcıların profillerine bak',
        icon: Icons.person_search,
        color: Colors.purple,
        targetCount: 3,
        currentCount: progress['profileVisits'] ?? 0,
        xpReward: 20,
        type: 'profile',
        isCompleted: (progress['profileVisits'] ?? 0) >= 3,
      ),
      DailyChallenge(
        id: 'login_bonus',
        title: 'Giriş Bonusu',
        description: 'Bugün uygulamayı aç',
        icon: Icons.login,
        color: Colors.green,
        targetCount: 1,
        currentCount: 1, // Zaten açtı
        xpReward: 10,
        type: 'login',
        isCompleted: true,
      ),
    ];

    // Giriş bonusunu kaydet (eğer yoksa)
    if (progress['loginBonus'] != true) {
      await _updateProgress('loginBonus', 1);
      await _addXP(10);
    }
  }

  Future<void> _updateProgress(String field, int value) async {
    if (_userId == null) return;

    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month}-${today.day}";

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('dailyProgress')
        .doc(todayStr)
        .set({field: value}, SetOptions(merge: true));
  }

  Future<void> _addXP(int amount) async {
    if (_userId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(_userId).update({
      'totalXP': FieldValue.increment(amount),
    });

    setState(() {
      _totalXP += amount;
    });
  }

  // Görev tamamlama kontrolü için static metodlar (diğer ekranlardan çağrılacak)
  static Future<void> onTestCompleted(String userId) async {
    await _incrementDailyProgress(userId, 'testsCompleted');
  }

  static Future<void> onMessageSent(String userId) async {
    await _incrementDailyProgress(userId, 'messagesSent');
  }

  static Future<void> onNewMatch(String userId) async {
    await _incrementDailyProgress(userId, 'newMatches');
  }

  static Future<void> onProfileVisit(String userId) async {
    await _incrementDailyProgress(userId, 'profileVisits');
  }

  static Future<void> _incrementDailyProgress(String userId, String field) async {
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month}-${today.day}";

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('dailyProgress')
        .doc(todayStr)
        .set({field: FieldValue.increment(1)}, SetOptions(merge: true));

    // XP kontrolü ve ekleme buradan yapılabilir
    await _checkAndRewardChallenge(userId, field);
  }

  static Future<void> _checkAndRewardChallenge(String userId, String field) async {
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month}-${today.day}";

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('dailyProgress')
        .doc(todayStr)
        .get();

    if (!doc.exists) return;

    var data = doc.data() as Map<String, dynamic>;
    int count = data[field] ?? 0;

    // Hedefleri kontrol et
    Map<String, int> targets = {
      'testsCompleted': 3,
      'messagesSent': 5,
      'newMatches': 1,
      'profileVisits': 3,
    };

    Map<String, int> rewards = {
      'testsCompleted': 50,
      'messagesSent': 30,
      'newMatches': 100,
      'profileVisits': 20,
    };

    String rewardedKey = '${field}_rewarded';
    
    if (targets.containsKey(field) && 
        count >= targets[field]! && 
        data[rewardedKey] != true) {
      // XP ekle
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'totalXP': FieldValue.increment(rewards[field]!),
      });

      // Ödül verildi işaretle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dailyProgress')
          .doc(todayStr)
          .update({rewardedKey: true});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))),
      );
    }

    int completedCount = _challenges.where((c) => c.isCompleted).length;
    int totalXPToday = _challenges.where((c) => c.isCompleted).fold(0, (sum, c) => sum + c.xpReward);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFFF5A5F),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ============ STREAK BÖLÜMÜ ============
              _buildStreakSection(),

              // ============ GÜNLÜK ÖZET ============
              _buildDailySummary(completedCount, totalXPToday),

              // ============ GÖREVLER LİSTESİ ============
              _buildChallengesList(),

              // ============ XP SEVİYE BÖLÜMÜ ============
              _buildXPSection(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D11),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "Günlük Görevler",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      actions: [
        // Geri sayım
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Color(0xFFFF5A5F), size: 16),
              const SizedBox(width: 5),
              Text(
                _formatDuration(_timeUntilReset),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.8),
            Colors.deepOrange.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Mevcut Streak",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: const Text(
                          "🔥",
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "$_currentStreak",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        " gün",
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                    const SizedBox(height: 5),
                    Text(
                      "$_longestStreak",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "En Uzun",
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Haftalık streak göstergesi
          _buildWeeklyStreakIndicator(),
        ],
      ),
    );
  }

  Widget _buildWeeklyStreakIndicator() {
    List<String> days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    int todayIndex = DateTime.now().weekday - 1; // 0-6

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        bool isActive = index <= todayIndex && _currentStreak > (todayIndex - index);
        bool isToday = index == todayIndex;

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: isToday ? Border.all(color: Colors.yellow, width: 2) : null,
              ),
              child: Icon(
                isActive ? Icons.check : Icons.circle,
                color: isActive ? Colors.orange : Colors.white30,
                size: isActive ? 20 : 8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              days[index],
              style: TextStyle(
                color: isToday ? Colors.yellow : Colors.white70,
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDailySummary(int completed, int xpEarned) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            icon: Icons.check_circle,
            value: "$completed/${_challenges.length}",
            label: "Tamamlanan",
            color: Colors.green,
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildSummaryItem(
            icon: Icons.star,
            value: "+$xpEarned",
            label: "Bugün XP",
            color: Colors.amber,
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildSummaryItem(
            icon: Icons.diamond,
            value: "$_totalXP",
            label: "Toplam XP",
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildChallengesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 25, 20, 15),
          child: Text(
            "Bugünün Görevleri",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...List.generate(_challenges.length, (index) {
          return _buildChallengeCard(_challenges[index]);
        }),
      ],
    );
  }

  Widget _buildChallengeCard(DailyChallenge challenge) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: challenge.isCompleted
            ? Border.all(color: Colors.green.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // İkon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: challenge.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(challenge.icon, color: challenge.color, size: 26),
          ),
          const SizedBox(width: 15),
          
          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        challenge.title,
                        style: TextStyle(
                          color: challenge.isCompleted ? Colors.green : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: challenge.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (challenge.isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                
                // İlerleme çubuğu
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: challenge.progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            challenge.isCompleted ? Colors.green : challenge.color,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${challenge.currentCount}/${challenge.targetCount}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 10),
          
          // XP Ödül
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: challenge.isCompleted 
                  ? Colors.green.withOpacity(0.2) 
                  : Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  challenge.isCompleted ? Icons.check : Icons.star,
                  color: challenge.isCompleted ? Colors.green : Colors.amber,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  challenge.isCompleted ? "✓" : "+${challenge.xpReward}",
                  style: TextStyle(
                    color: challenge.isCompleted ? Colors.green : Colors.amber,
                    fontSize: 12,
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

  Widget _buildXPSection() {
    // XP'ye göre seviye hesapla
    int level = (_totalXP / 500).floor() + 1;
    int xpForCurrentLevel = _totalXP % 500;
    int xpNeeded = 500;
    double progress = xpForCurrentLevel / xpNeeded;

    String levelTitle = _getLevelTitle(level);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.6),
            Colors.deepPurple.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Seviye $level",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    levelTitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "$level",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // XP İlerleme çubuğu
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$xpForCurrentLevel XP",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    "$xpNeeded XP",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Sonraki seviyeye ${xpNeeded - xpForCurrentLevel} XP kaldı",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLevelTitle(int level) {
    if (level >= 50) return "Efsanevi Mestçi 👑";
    if (level >= 30) return "Usta Mestçi 🏆";
    if (level >= 20) return "Deneyimli Mestçi 💎";
    if (level >= 10) return "Yetenekli Mestçi ⭐";
    if (level >= 5) return "Aktif Mestçi 🎯";
    return "Yeni Mestçi 🌱";
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}

// ============ STREAK SERVİSİ ============
// Diğer ekranlardan çağrılacak helper sınıf
class StreakService {
  static Future<void> recordTestCompletion(String userId) async {
    await _incrementDailyProgress(userId, 'testsCompleted');
  }

  static Future<void> recordMessageSent(String userId) async {
    await _incrementDailyProgress(userId, 'messagesSent');
  }

  static Future<void> recordNewMatch(String userId) async {
    await _incrementDailyProgress(userId, 'newMatches');
  }

  static Future<void> recordProfileVisit(String userId) async {
    await _incrementDailyProgress(userId, 'profileVisits');
  }

  static Future<void> _incrementDailyProgress(String userId, String field) async {
    try {
      String today = DateTime.now().toIso8601String().split('T')[0];
      
      DocumentReference progressRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dailyProgress')
          .doc(today);

      DocumentSnapshot doc = await progressRef.get();
      
      if (doc.exists) {
        await progressRef.update({
          field: FieldValue.increment(1),
        });
      } else {
        await progressRef.set({
          'testsCompleted': field == 'testsCompleted' ? 1 : 0,
          'messagesSent': field == 'messagesSent' ? 1 : 0,
          'newMatches': field == 'newMatches' ? 1 : 0,
          'profileVisits': field == 'profileVisits' ? 1 : 0,
          'loginBonus': false,
          'date': today,
        });
      }

      await _updateStreak(userId);
    } catch (e) {
      debugPrint("StreakService hata ($field): $e");
    }
  }

  static Future<void> _updateStreak(String userId) async {
    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      DocumentSnapshot userDoc = await userRef.get();
      if (!userDoc.exists) return;

      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      
      DateTime? lastActive;
      if (data['lastActiveDate'] != null) {
        lastActive = (data['lastActiveDate'] as Timestamp).toDate();
        lastActive = DateTime(lastActive.year, lastActive.month, lastActive.day);
      }

      int currentStreak = data['currentStreak'] ?? 0;
      int longestStreak = data['longestStreak'] ?? 0;

      if (lastActive == null) {
        currentStreak = 1;
      } else if (lastActive.isBefore(today)) {
        Duration diff = today.difference(lastActive);
        if (diff.inDays == 1) {
          currentStreak++;
        } else if (diff.inDays > 1) {
          currentStreak = 1;
        }
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      await userRef.update({
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActiveDate': Timestamp.fromDate(today),
      });
    } catch (e) {
      debugPrint("Streak güncelleme hata: $e");
    }
  }
}