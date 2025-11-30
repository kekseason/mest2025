import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});

  @override
  State<ModeratorPanelScreen> createState() => _ModeratorPanelScreenState();
}

class _ModeratorPanelScreenState extends State<ModeratorPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    bool isAdmin = (doc.data() as Map<String, dynamic>?)?['isAdmin'] == true;
    bool isModerator = (doc.data() as Map<String, dynamic>?)?['isModerator'] == true;

    setState(() {
      _isAdmin = isAdmin || isModerator;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D11),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 80, color: Colors.red[400]),
              const SizedBox(height: 20),
              const Text(
                "Erişim Engellendi",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Bu alana sadece moderatörler erişebilir.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Moderatör Paneli",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // İstatistikler
          _buildStatsRow(),

          // Tab Bar
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Bekleyen"),
                Tab(text: "Raporlar"),
                Tab(text: "Geçmiş"),
              ],
            ),
          ),

          // Tab içeriği
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTestsTab(),
                _buildReportsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            stream: FirebaseFirestore.instance
                .collection('pending_tests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            label: "Bekleyen",
            icon: Icons.pending,
            color: Colors.orange,
          ),
          _buildStatItem(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            label: "Raporlar",
            icon: Icons.flag,
            color: Colors.red,
          ),
          _buildStatItem(
            stream: FirebaseFirestore.instance
                .collection('pending_tests')
                .where('status', isEqualTo: 'approved')
                .snapshots(),
            label: "Onaylanan",
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required Stream<QuerySnapshot> stream,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = snapshot.data?.docs.length ?? 0;
        return Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              "$count",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  // ============ BEKLEYEN TESTLER ============
  Widget _buildPendingTestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_tests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle,
            title: "Bekleyen test yok",
            subtitle: "Tüm testler incelendi",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildPendingTestCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildPendingTestCard(String docId, Map<String, dynamic> data) {
    String title = data['baslik'] ?? 'Test';
    String category = data['kategori'] ?? 'Genel';
    String createdBy = data['createdByName'] ?? 'Bilinmiyor';
    List<dynamic> options = data['secenekler'] ?? [];
    DateTime? createdAt = data['createdAt'] != null 
        ? (data['createdAt'] as Timestamp).toDate() 
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst kısım
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Bekliyor",
                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Başlık
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Bilgiler
          Row(
            children: [
              Icon(Icons.category, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 5),
              Text(category, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(width: 15),
              Icon(Icons.person, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 5),
              Text(createdBy, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(width: 15),
              Icon(Icons.grid_view, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 5),
              Text("${options.length} seçenek", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 15),

          // Seçenek önizleme
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: options.length > 6 ? 6 : options.length,
              itemBuilder: (context, index) {
                var option = options[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: option['resimUrl'] != null && option['resimUrl'].isNotEmpty
                            ? Image.network(
                                option['resimUrl'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.image, color: Colors.grey, size: 16),
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey[800],
                                child: const Icon(Icons.image, color: Colors.grey, size: 16),
                              ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 40,
                        child: Text(
                          option['isim'] ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(docId, data),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: const Text("Reddet", style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveTest(docId, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text("Onayla", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveTest(String docId, Map<String, dynamic> data) async {
    try {
      String? moderatorId = FirebaseAuth.instance.currentUser?.uid;
      
      // Test olarak kaydet
      await FirebaseFirestore.instance.collection('testler').add({
        'baslik': data['baslik'],
        'aciklama': data['aciklama'] ?? '',
        'kategori': data['kategori'],
        'secenekler': data['secenekler'],
        'createdBy': data['createdBy'],
        'createdByName': data['createdByName'],
        'createdAt': data['createdAt'],
        'approvedBy': moderatorId,
        'approvedAt': FieldValue.serverTimestamp(),
        'aktif_mi': true,
        'playCount': 0,
        'isUserGenerated': true,
      });

      // Pending'i güncelle
      await FirebaseFirestore.instance.collection('pending_tests').doc(docId).update({
        'status': 'approved',
        'reviewedBy': moderatorId,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Kullanıcıya bildirim gönder
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': data['createdBy'],
        'type': 'test_approved',
        'title': 'Test Onaylandı!',
        'body': '"${data['baslik']}" testi onaylandı ve yayınlandı!',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Test onaylandı ve yayınlandı!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRejectDialog(String docId, Map<String, dynamic> data) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Testi Reddet",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Reddetme nedenini belirtin:",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Örn: Uygunsuz içerik, yetersiz kalite...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Lütfen bir neden belirtin")),
                );
                return;
              }

              await _rejectTest(docId, data, reasonController.text);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Reddet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectTest(String docId, Map<String, dynamic> data, String reason) async {
    try {
      String? moderatorId = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('pending_tests').doc(docId).update({
        'status': 'rejected',
        'reviewedBy': moderatorId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });

      // Kullanıcıya bildirim
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': data['createdBy'],
        'type': 'test_rejected',
        'title': 'Test Reddedildi',
        'body': '"${data['baslik']}" testi reddedildi. Sebep: $reason',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Test reddedildi"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============ RAPORLAR TAB ============
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.flag,
            title: "Bekleyen rapor yok",
            subtitle: "Tüm raporlar incelendi",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildReportCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildReportCard(String docId, Map<String, dynamic> data) {
    String type = data['type'] ?? 'unknown'; // user, test, message
    String reason = data['reason'] ?? '';
    String reporterName = data['reporterName'] ?? 'Bilinmiyor';
    String? targetId = data['targetId'];
    String? targetName = data['targetName'];

    IconData typeIcon;
    Color typeColor;
    String typeLabel;

    switch (type) {
      case 'user':
        typeIcon = Icons.person;
        typeColor = Colors.red;
        typeLabel = 'Kullanıcı';
        break;
      case 'test':
        typeIcon = Icons.quiz;
        typeColor = Colors.orange;
        typeLabel = 'Test';
        break;
      case 'message':
        typeIcon = Icons.chat;
        typeColor = Colors.purple;
        typeLabel = 'Mesaj';
        break;
      default:
        typeIcon = Icons.flag;
        typeColor = Colors.grey;
        typeLabel = 'Diğer';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, color: typeColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      typeLabel,
                      style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.flag, color: Colors.red, size: 16),
            ],
          ),
          const SizedBox(height: 12),

          if (targetName != null)
            Text(
              "Hedef: $targetName",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 8),

          Text(
            "Sebep: $reason",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),

          Text(
            "Raporlayan: $reporterName",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _dismissReport(docId),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Reddet", style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _takeAction(docId, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("İşlem Yap", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _dismissReport(String docId) async {
    await FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': 'dismissed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  Future<void> _takeAction(String docId, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("İşlem Seç", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text("Uyarı Gönder", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _sendWarning(docId, data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text("Engelle/Sil", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _blockTarget(docId, data);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWarning(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': data['targetId'],
      'type': 'warning',
      'title': 'Uyarı',
      'body': 'İçeriğiniz topluluk kurallarına aykırı bulundu. Lütfen kurallara uyun.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': 'resolved',
      'action': 'warning_sent',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uyarı gönderildi"), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _blockTarget(String docId, Map<String, dynamic> data) async {
    String type = data['type'] ?? '';
    String? targetId = data['targetId'];

    if (type == 'user' && targetId != null) {
      await FirebaseFirestore.instance.collection('users').doc(targetId).update({
        'isBanned': true,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } else if (type == 'test' && targetId != null) {
      await FirebaseFirestore.instance.collection('testler').doc(targetId).update({
        'aktif_mi': false,
        'removedAt': FieldValue.serverTimestamp(),
        'removedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    }

    await FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': 'resolved',
      'action': 'blocked',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İşlem tamamlandı"), backgroundColor: Colors.red),
      );
    }
  }

  // ============ GEÇMİŞ TAB ============
  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_tests')
          .where('status', whereIn: ['approved', 'rejected'])
          .orderBy('reviewedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
        }

        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: "Geçmiş boş",
            subtitle: "İncelenen testler burada görünecek",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildHistoryCard(data);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    bool isApproved = data['status'] == 'approved';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isApproved ? Colors.green : Colors.red).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isApproved ? Icons.check : Icons.close,
              color: isApproved ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['baslik'] ?? 'Test',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  isApproved ? "Onaylandı" : "Reddedildi: ${data['rejectionReason'] ?? ''}",
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.red,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[700]),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} saat önce";
    return "${diff.inDays} gün önce";
  }
}