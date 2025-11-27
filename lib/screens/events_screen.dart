import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'play_mest_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String? currentUserId;
  Set<String> joinedEvents = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadJoinedEvents();
    
    // Her dakika kontrol et (süresi biten etkinlikler için)
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkExpiredEvents();
      setState(() {}); // UI'ı güncelle
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadJoinedEvents() async {
    if (currentUserId == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        List<dynamic> events = data['joinedEvents'] ?? [];
        setState(() {
          joinedEvents = events.map((e) => e.toString()).toSet();
        });
      }
    } catch (e) {
      debugPrint("Katılınan etkinlikler yüklenemedi: $e");
    }
  }

  /// Süresi biten etkinlikleri normal teste dönüştür
  Future<void> _checkExpiredEvents() async {
    try {
      QuerySnapshot expiredEvents = await FirebaseFirestore.instance
          .collection('events')
          .where('endTime', isLessThan: Timestamp.now())
          .where('isConverted', isEqualTo: false)
          .get();

      for (var doc in expiredEvents.docs) {
        await _convertEventToNormalTest(doc.id, doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint("Etkinlik kontrol hatası: $e");
    }
  }

  /// Etkinliği normal teste dönüştür
  Future<void> _convertEventToNormalTest(String eventId, Map<String, dynamic> eventData) async {
    try {
      String? testId = eventData['testId'];
      if (testId == null) return;

      // Testi normal test olarak işaretle
      await FirebaseFirestore.instance.collection('testler').doc(testId).update({
        'isEventTest': false,
        'eventId': null,
        'convertedFromEvent': true,
        'convertedAt': FieldValue.serverTimestamp(),
      });

      // Etkinliği dönüştürüldü olarak işaretle
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'isConverted': true,
        'convertedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      debugPrint("Etkinlik normal teste dönüştürüldü: $eventId");
    } catch (e) {
      debugPrint("Dönüştürme hatası: $e");
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
          "Etkinlikler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // Başlık
          const Text(
            "Yaklaşan Etkinlikler",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Topluluk tarafından sevilen popüler Mestleri çözüp daha çok insanla eşleşebilirsin",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),

          const SizedBox(height: 25),

          // Etkinlik listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('status', isEqualTo: 'active')
                  .orderBy('startTime', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
                  );
                }

                List<Map<String, dynamic>> events = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  events = snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return data;
                  }).toList();
                }

                // Örnek etkinlikler (yoksa)
                if (events.isEmpty) {
                  events = _getSampleEvents();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(events[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSampleEvents() {
    DateTime now = DateTime.now();
    return [
      {
        'id': 'sample1',
        'title': 'Kimin Türkiye\'de Konser Vermesini İstersin?',
        'description': 'Sen de etkinliğe katıl ve Mest\'i çözen, topluluktaki diğer insanlarla eşleş!',
        'startTime': Timestamp.fromDate(now),
        'endTime': Timestamp.fromDate(now.add(const Duration(hours: 24))),
        'imageUrl': 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?w=400',
        'participants': ['user1', 'user2', 'user3', 'user4', 'user5'],
        'testId': null,
      },
      {
        'id': 'sample2',
        'title': 'En İyi Netflix Dizisi',
        'description': 'Netflix\'in birbirinden özel içeriklerinden sence hangisi en iyisi',
        'startTime': Timestamp.fromDate(now.add(const Duration(hours: 2))),
        'endTime': Timestamp.fromDate(now.add(const Duration(hours: 26))),
        'imageUrl': 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=400',
        'participants': ['user1', 'user2', 'user3', 'user4'],
        'testId': null,
      },
    ];
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    String eventId = event['id'] ?? '';
    String title = event['title'] ?? 'Etkinlik';
    String description = event['description'] ?? '';
    Timestamp? startTime = event['startTime'];
    Timestamp? endTime = event['endTime'];
    String? imageUrl = event['imageUrl'];
    List<dynamic> participants = event['participants'] ?? [];
    String? testId = event['testId'];
    bool isJoined = joinedEvents.contains(eventId);

    // Zaman kontrolü
    DateTime now = DateTime.now();
    DateTime start = startTime?.toDate() ?? now;
    DateTime end = endTime?.toDate() ?? now.add(const Duration(hours: 24));
    
    bool hasStarted = now.isAfter(start);
    bool hasEnded = now.isAfter(end);
    bool isActive = hasStarted && !hasEnded;
    
    // Kalan süre
    Duration remaining = end.difference(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1C1C1E),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Arka plan resmi
            if (imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: const Color(0xFF1C1C1E)),
                ),
              ),

            // Karartma
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum ve süre
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Durum etiketi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasEnded
                              ? Colors.grey
                              : isActive
                                  ? Colors.green
                                  : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasEnded
                              ? "Bitti"
                              : isActive
                                  ? "🔴 Canlı"
                                  : "Yakında",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Kalan süre
                      if (!hasEnded && isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(remaining),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),

                  // Başlık
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Açıklama
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Başlangıç - Bitiş saatleri
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.amber, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "${_formatDateTime(start)} - ${_formatDateTime(end)}",
                        style: TextStyle(color: Colors.amber[200], fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Alt kısım: Katılımcılar ve buton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Katılımcı avatarları
SizedBox(
                                    // Genişliği katılımcı sayısına göre dinamik ayarlayalım (Max 4 kişi + sayı)
                                    width: (participants.length > 4 ? 5 : participants.length) * 25.0 + 20, 
                                    height: 34,
                                    child: Stack(
                                      children: [
                                        // İlk 4 katılımcıyı çiz
                                        ...List.generate(
                                          participants.length > 4 ? 4 : participants.length,
                                          (i) => Positioned(
                                            left: i * 22.0, // Her biri 22 piksel sağa kayar (Overlap efekti)
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.primaries[i % Colors.primaries.length],
                                                border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                                              ),
                                              child: const Icon(Icons.person, color: Colors.white, size: 18),
                                            ),
                                          ),
                                        ),
                                        
                                        // Eğer 4'ten fazla ise "+X" yuvarlağını ekle
                                        if (participants.length > 4)
                                          Positioned(
                                            left: 4 * 22.0, // 4. sıraya yerleştir
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF2C2C2E),
                                                border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "+${participants.length - 4}",
                                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                      // Buton
                      _buildActionButton(
                        eventId: eventId,
                        testId: testId,
                        isJoined: isJoined,
                        isActive: isActive,
                        hasEnded: hasEnded,
                        hasStarted: hasStarted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String eventId,
    String? testId,
    required bool isJoined,
    required bool isActive,
    required bool hasEnded,
    required bool hasStarted,
  }) {
    // Etkinlik bittiyse
    if (hasEnded) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: const Text("Bitti", style: TextStyle(color: Colors.white)),
      );
    }

    // Henüz başlamadıysa
    if (!hasStarted) {
      return ElevatedButton(
        onPressed: isJoined ? null : () => _joinEvent(eventId, testId),
        style: ElevatedButton.styleFrom(
          backgroundColor: isJoined ? Colors.green : Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Text(
          isJoined ? "Katıldın ✓" : "Hatırlat",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    // Aktif etkinlik
    if (isJoined && testId != null) {
      return ElevatedButton.icon(
        onPressed: () => _playEventTest(testId),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A5F),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
        label: const Text("Çöz", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    return ElevatedButton(
      onPressed: () => _joinEvent(eventId, testId),
      style: ElevatedButton.styleFrom(
        backgroundColor: isJoined ? Colors.green : const Color(0xFFFF5A5F),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child: Text(
        isJoined ? "Katıldın ✓" : "Katıl",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _joinEvent(String eventId, String? testId) async {
    if (currentUserId == null) return;

    // Zaten katıldıysa teste git
    if (joinedEvents.contains(eventId)) {
      if (testId != null) {
        _playEventTest(testId);
      }
      return;
    }

    try {
      // Kullanıcıyı etkinliğe ekle
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'joinedEvents': FieldValue.arrayUnion([eventId]),
      });

      // Etkinliğe katılımcı ekle
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayUnion([currentUserId]),
      });

      setState(() {
        joinedEvents.add(eventId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Etkinliğe katıldın! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Test varsa ve etkinlik aktifse çöz
      if (testId != null) {
        _playEventTest(testId);
      }
    } catch (e) {
      debugPrint("Etkinliğe katılma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bir hata oluştu: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _playEventTest(String testId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayMestScreen(testId: testId),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return "${duration.inDays}g ${duration.inHours % 24}s";
    } else if (duration.inHours > 0) {
      return "${duration.inHours}s ${duration.inMinutes % 60}dk";
    } else {
      return "${duration.inMinutes}dk";
    }
  }

  String _formatDateTime(DateTime date) {
    List<String> months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return "${date.day} ${months[date.month - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}