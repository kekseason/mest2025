import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'all'; // 'weekly', 'monthly', 'all'
  String _selectedCategory = 'all'; // 'all', 'Yemek & İçecek', 'Spor', etc.
  String? _currentUserId;
  
  final List<String> _categories = [
    'all',
    'Yemek & İçecek',
    'Spor',
    'Sinema & Dizi',
    'Müzik',
    'Oyun',
    'Teknoloji',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          "Liderlik Tablosu",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            onPressed: _showInfoDialog,
          ),
        ],
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
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "XP"),
                Tab(text: "Test"),
                Tab(text: "Streak"),
              ],
            ),
          ),

          // ============ KATEGORİ FİLTRESİ ============
          _buildCategoryFilter(),

          // ============ TAB İÇERİĞİ ============
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardList('totalXP'),
                _buildLeaderboardList('testCount'),
                _buildLeaderboardList('currentStreak'),
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
          _buildPeriodChip('weekly', 'Bu Hafta', Icons.calendar_view_week),
          const SizedBox(width: 10),
          _buildPeriodChip('monthly', 'Bu Ay', Icons.calendar_month),
          const SizedBox(width: 10),
          _buildPeriodChip('all', 'Tüm Zamanlar', Icons.all_inclusive),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label, IconData icon) {
    bool isSelected = _selectedPeriod == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5A5F) : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          String category = _categories[index];
          bool isSelected = _selectedCategory == category;
          String displayName = category == 'all' ? 'Tümü' : category;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFFF5A5F).withOpacity(0.2) 
                    : const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: isSelected 
                    ? Border.all(color: const Color(0xFFFF5A5F)) 
                    : null,
              ),
              child: Center(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardList(String sortField) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getLeaderboardStream(sortField),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var users = snapshot.data!.docs;

        // Kullanıcının kendi sırasını bul
        int myRank = -1;
        for (int i = 0; i < users.length; i++) {
          if (users[i].id == _currentUserId) {
            myRank = i + 1;
            break;
          }
        }

        return Column(
          children: [
            // Top 3
            if (users.length >= 3) _buildTop3(users.take(3).toList(), sortField),
            
            // Kullanıcının sırası (eğer top 10'da değilse)
            if (myRank > 10) _buildMyRankCard(myRank, sortField),
            
            // Liste
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: users.length > 50 ? 50 : users.length,
                itemBuilder: (context, index) {
                  // Top 3'ü atla
                  if (index < 3) return const SizedBox();
                  
                  var userData = users[index].data() as Map<String, dynamic>;
                  String odaId = users[index].id;
                  bool isMe = odaId == _currentUserId;

                  return _buildLeaderboardItem(
                    rank: index + 1,
                    userId: odaId,
                    name: userData['name'] ?? 'Kullanıcı',
                    photoUrl: userData['photoUrl'],
                    value: _getValue(userData, sortField),
                    sortField: sortField,
                    isMe: isMe,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _getLeaderboardStream(String sortField) {
    Query query = FirebaseFirestore.instance.collection('users');

    // Dönem filtresi (sadece weekly ve monthly için)
    if (_selectedPeriod == 'weekly') {
      DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
      query = query.where('lastActiveDate', isGreaterThan: Timestamp.fromDate(weekAgo));
    } else if (_selectedPeriod == 'monthly') {
      DateTime monthAgo = DateTime.now().subtract(const Duration(days: 30));
      query = query.where('lastActiveDate', isGreaterThan: Timestamp.fromDate(monthAgo));
    }

    // Sıralama
    query = query.orderBy(sortField, descending: true).limit(100);

    return query.snapshots();
  }

  int _getValue(Map<String, dynamic> data, String field) {
    return data[field] ?? 0;
  }

  Widget _buildTop3(List<QueryDocumentSnapshot> top3, String sortField) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2. sıra (sol)
          if (top3.length > 1)
            _buildTop3Item(
              rank: 2,
              userData: top3[1].data() as Map<String, dynamic>,
              userId: top3[1].id,
              sortField: sortField,
              height: 100,
              color: Colors.grey,
            ),
          
          // 1. sıra (orta)
          _buildTop3Item(
            rank: 1,
            userData: top3[0].data() as Map<String, dynamic>,
            userId: top3[0].id,
            sortField: sortField,
            height: 130,
            color: Colors.amber,
          ),
          
          // 3. sıra (sağ)
          if (top3.length > 2)
            _buildTop3Item(
              rank: 3,
              userData: top3[2].data() as Map<String, dynamic>,
              userId: top3[2].id,
              sortField: sortField,
              height: 80,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }

  Widget _buildTop3Item({
    required int rank,
    required Map<String, dynamic> userData,
    required String userId,
    required String sortField,
    required double height,
    required Color color,
  }) {
    String name = userData['name'] ?? 'Kullanıcı';
    String? photoUrl = userData['photoUrl'];
    int value = _getValue(userData, sortField);
    bool isMe = userId == _currentUserId;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId, userName: name),
          ),
        );
      },
      child: Column(
        children: [
          // Taç / Madalya
          Text(
            rank == 1 ? "👑" : (rank == 2 ? "🥈" : "🥉"),
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 8),
          
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: rank == 1 ? 40 : 32,
              backgroundColor: Colors.grey[800],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: rank == 1 ? 28 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          
          // İsim
          Container(
            width: 80,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? const Color(0xFFFF5A5F) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
          
          // Değer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatValue(value, sortField),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          
          // Platform
          Container(
            width: 60,
            height: height,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Center(
              child: Text(
                "#$rank",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String userId,
    required String name,
    String? photoUrl,
    required int value,
    required String sortField,
    required bool isMe,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId, userName: name),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe 
              ? const Color(0xFFFF5A5F).withOpacity(0.15) 
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: isMe ? Border.all(color: const Color(0xFFFF5A5F)) : null,
        ),
        child: Row(
          children: [
            // Sıra
            SizedBox(
              width: 35,
              child: Text(
                "#$rank",
                style: TextStyle(
                  color: isMe ? const Color(0xFFFF5A5F) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[800],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // İsim
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isMe ? const Color(0xFFFF5A5F) : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 5),
                        const Text(
                          "(Sen)",
                          style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Değer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatValue(value, sortField),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRankCard(int rank, String sortField) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(_currentUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        var data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF5A5F).withOpacity(0.3),
                const Color(0xFFFF5A5F).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF5A5F)),
          ),
          child: Row(
            children: [
              Text(
                "#$rank",
                style: const TextStyle(
                  color: Color(0xFFFF5A5F),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 15),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[800],
                backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Kullanıcı',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      "Senin sıran",
                      style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _formatValue(_getValue(data, sortField), sortField),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 20),
          const Text(
            "Henüz veri yok",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Test çözerek sıralamaya katıl!",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatValue(int value, String field) {
    if (field == 'totalXP') return "$value XP";
    if (field == 'testCount') return "$value Test";
    if (field == 'currentStreak') return "$value 🔥";
    return "$value";
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Sıralama Nasıl Çalışır?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(Icons.star, "XP", "Test çözerek ve görevleri tamamlayarak XP kazan"),
            const SizedBox(height: 15),
            _buildInfoItem(Icons.quiz, "Test", "Ne kadar çok test çözersen o kadar üst sıralarda olursun"),
            const SizedBox(height: 15),
            _buildInfoItem(Icons.local_fire_department, "Streak", "Her gün giriş yaparak streak'ini artır"),
            const SizedBox(height: 20),
            const Text(
              "💡 Haftalık ve aylık sıralamalar o dönem aktif olan kullanıcıları gösterir.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Anladım", style: TextStyle(color: Color(0xFFFF5A5F))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFF5A5F), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}