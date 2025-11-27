import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    if (_myId == null) return;

    try {
      // Kullanıcının blok listesini al
      DocumentSnapshot myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myId)
          .get();

      List<dynamic> blockedIds = (myDoc.data() as Map<String, dynamic>?)?['blockedUsers'] ?? [];

      if (blockedIds.isEmpty) {
        setState(() {
          _blockedUsers = [];
          _isLoading = false;
        });
        return;
      }

      // Engellenen kullanıcıların bilgilerini al
      List<Map<String, dynamic>> users = [];
      
      // Firestore 'in' sorgusu max 10 eleman alır, chunklara böl
      for (var i = 0; i < blockedIds.length; i += 10) {
        var chunk = blockedIds.skip(i).take(10).toList();
        var snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in snapshot.docs) {
          var data = doc.data();
          users.add({
            'id': doc.id,
            'name': data['name'] ?? 'İsimsiz',
            'photoUrl': data['photoUrl'],
            'blockedAt': data['blockedAt'],
          });
        }
      }

      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Blok listesi yüklenemedi: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    // Onay dialogu
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Engeli Kaldır", style: TextStyle(color: Colors.white)),
        content: Text(
          "$userName kullanıcısının engelini kaldırmak istiyor musun?\n\nBu kişi artık sana mesaj atabilir ve profilini görebilir.",
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Engeli Kaldır", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_myId).update({
        'blockedUsers': FieldValue.arrayRemove([userId])
      });

      setState(() {
        _blockedUsers.removeWhere((user) => user['id'] == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$userName artık engelli değil"),
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
          "Engellenen Kullanıcılar",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)))
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Engellenen kimse yok",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Birini engellediğinde burada görünecek",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _blockedUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        var user = _blockedUsers[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[800],
              backgroundImage: user['photoUrl'] != null
                  ? NetworkImage(user['photoUrl'])
                  : null,
              child: user['photoUrl'] == null
                  ? Text(
                      (user['name'] as String)[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              user['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              "Engellendi",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            trailing: TextButton(
              onPressed: () => _unblockUser(user['id'], user['name']),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Kaldır",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============ BLOK SERVİSİ ============
// Bu sınıfı diğer ekranlardan kullanabilirsiniz
class BlockService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcıyı engelle
  static Future<bool> blockUser({
    required String myId,
    required String targetUserId,
    required String targetUserName,
    required BuildContext context,
  }) async {
    // Onay dialogu
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 10),
            Text("$targetUserName Engelle", style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bu kişiyi engellersen:",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildBlockInfo("Sana mesaj atamaz"),
            _buildBlockInfo("Profilini göremez"),
            _buildBlockInfo("Seni aramalarda bulamaz"),
            _buildBlockInfo("Eşleşme önerilerinde çıkmaz"),
            const SizedBox(height: 15),
            const Text(
              "Bu kişi engellendiğini bilmeyecek.",
              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Engelle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    try {
      await _firestore.collection('users').doc(myId).update({
        'blockedUsers': FieldValue.arrayUnion([targetUserId])
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$targetUserName engellendi"),
            backgroundColor: Colors.orange,
          ),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  static Widget _buildBlockInfo(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  // Kullanıcının engellenip engellenmediğini kontrol et
  static Future<bool> isBlocked(String myId, String targetUserId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(myId).get();
    List<dynamic> blockedUsers = (doc.data() as Map<String, dynamic>?)?['blockedUsers'] ?? [];
    return blockedUsers.contains(targetUserId);
  }

  // Karşı tarafın beni engelleyip engellemediğini kontrol et
  static Future<bool> amIBlocked(String myId, String targetUserId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(targetUserId).get();
    List<dynamic> blockedUsers = (doc.data() as Map<String, dynamic>?)?['blockedUsers'] ?? [];
    return blockedUsers.contains(myId);
  }
}