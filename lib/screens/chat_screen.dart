import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'play_mest_screen.dart';
import 'mestometer_screen.dart';
import 'coop_solve_screen.dart';
import 'report_service.dart';
import 'blocked_users_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late String myId;
  bool _isInitialized = false;
  bool _isBlocked = false;
  bool _amIBlocked = false;
  String? _otherUserPhotoUrl;
  bool _isOnline = false;
  DateTime? _lastSeen;

  // Emoji tepkileri
  final List<String> _reactions = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    myId = user.uid;

    // Blok durumunu kontrol et
    await _checkBlockStatus();

    // Karşı tarafın bilgilerini al
    await _loadOtherUserInfo();

    // Mesajları okundu olarak işaretle
    _markAsRead();

    setState(() => _isInitialized = true);
  }

  Future<void> _checkBlockStatus() async {
    _isBlocked = await BlockService.isBlocked(myId, widget.otherUserId);
    _amIBlocked = await BlockService.amIBlocked(myId, widget.otherUserId);
  }

  Future<void> _loadOtherUserInfo() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _otherUserPhotoUrl = data['photoUrl'];
          _isOnline = data['isOnline'] ?? false;
          _lastSeen = (data['lastActive'] as Timestamp?)?.toDate();
        });
      }
    } catch (e) {
      debugPrint("Kullanıcı bilgisi yüklenemedi: $e");
    }
  }

  void _markAsRead() async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'readBy': FieldValue.arrayUnion([myId]),
        'unreadCount_$myId': 0,
      });
    } catch (e) {
      debugPrint("Okundu işaretleme hatası: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============ MESAJ GÖNDERME ============
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_isBlocked || _amIBlocked) return;

    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': myId,
        'text': text,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [myId],
        'reactions': {},
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': myId,
        'readBy': [myId],
        'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
      });

      // Scroll to bottom
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint("Mesaj gönderme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Mesaj gönderilemedi: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============ MESAJ UZUN BASMA MENÜSÜ ============
  void _showMessageOptions(Map<String, dynamic> messageData, String messageId, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji tepkileri
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _reactions.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _addReaction(messageId, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white10),

              // Kopyala
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white),
                title: const Text("Kopyala", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: messageData['text'] ?? ''));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Kopyalandı"), duration: Duration(seconds: 1)),
                  );
                },
              ),

              // Sadece kendi mesajlarını silebilir
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Sil", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(messageId);
                  },
                ),

              // Şikayet et (karşı tarafın mesajı)
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text("Şikayet Et", style: TextStyle(color: Colors.orange)),
                  onTap: () {
                    Navigator.pop(context);
                    ReportService.showReportDialog(
                      context: context,
                      reportedUserId: widget.otherUserId,
                      reportedUserName: widget.otherUserName,
                      messageId: messageId,
                      chatId: widget.chatId,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ MESAJ SİLME ============
  void _deleteMessage(String messageId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Mesajı Sil", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bu mesajı silmek istediğine emin misin?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deleted': true,
        'text': 'Bu mesaj silindi',
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Mesaj silme hatası: $e");
    }
  }

  // ============ EMOJİ TEPKİSİ EKLE ============
  void _addReaction(String messageId, String emoji) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'reactions.$myId': emoji,
      });
    } catch (e) {
      debugPrint("Tepki ekleme hatası: $e");
    }
  }

  // ============ MEST DAVET ============
  void _showMestPicker() {
    if (_isBlocked || _amIBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu kullanıcıya mesaj gönderemezsiniz")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Mest Gönder 🎮",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Birlikte çözmek için bir test seç",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('testler')
                      .where('aktif_mi', isEqualTo: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                    }

                    var tests = snapshot.data!.docs;
                    if (tests.isEmpty) {
                      return const Center(
                        child: Text("Henüz test yok", style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      itemCount: tests.length,
                      itemBuilder: (context, index) {
                        var data = tests[index].data() as Map<String, dynamic>;
                        String testId = tests[index].id;
                        String testName = data['baslik'] ?? 'İsimsiz';
                        String? imageUrl = data['kapakResmi'];

                        if (imageUrl == null || imageUrl.isEmpty) {
                          List secenekler = data['secenekler'] ?? [];
                          if (secenekler.isNotEmpty) {
                            imageUrl = secenekler[0]['resimUrl'] ?? secenekler[0]['resim'];
                          }
                        }

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _buildTestPlaceholder(),
                                  )
                                : _buildTestPlaceholder(),
                          ),
                          title: Text(
                            testName,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            data['category'] ?? 'Genel',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.send, color: Color(0xFFFF5A5F)),
                          onTap: () {
                            Navigator.pop(context);
                            _sendMestInvite(testId, testName, imageUrl ?? '');
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[800],
      child: const Icon(Icons.quiz, color: Colors.grey),
    );
  }

  void _sendMestInvite(String testId, String testName, String testImage) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': myId,
        'text': '🎮 $testName testini çözmek ister misin?',
        'type': 'invite',
        'testId': testId,
        'testName': testName,
        'testImage': testImage,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [myId],
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': '🎮 Test daveti gönderildi',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': myId,
      });
    } catch (e) {
      debugPrint("Davet gönderme hatası: $e");
    }
  }

  // ============ CO-OP OTURUM ============
  void _startCoopSession(String testId, String testName) async {
    String sessionIdentifier = "${widget.chatId}_$testId";

    try {
      DocumentReference sessionRef = FirebaseFirestore.instance
          .collection('coop_sessions')
          .doc(sessionIdentifier);
      DocumentSnapshot sessionSnap = await sessionRef.get();

      if (!sessionSnap.exists) {
        await sessionRef.set({
          'testId': testId,
          'chatId': widget.chatId,
          'users': [myId, widget.otherUserId],
          'otherUserName': widget.otherUserName,
          'currentQuestionIndex': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CoopSolveScreen(
              testId: testId,
              chatId: widget.chatId,
              otherUserId: widget.otherUserId,
              otherUserName: widget.otherUserName,
              sessionId: sessionIdentifier,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Co-op oturum hatası: $e");
    }
  }

  // ============ KULLANICI MENÜSÜ ============
  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mestometre
              ListTile(
                leading: const Icon(Icons.favorite, color: Color(0xFFFF5A5F)),
                title: const Text("Mestometre", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Uyumunuzu görün", style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MestometerScreen(
                        otherUserId: widget.otherUserId,
                        otherUserName: widget.otherUserName,
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white10),

              // Şikayet et
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text("Şikayet Et", style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  ReportService.showReportDialog(
                    context: context,
                    reportedUserId: widget.otherUserId,
                    reportedUserName: widget.otherUserName,
                    chatId: widget.chatId,
                  );
                },
              ),

              // Engelle
              ListTile(
                leading: Icon(
                  _isBlocked ? Icons.check_circle : Icons.block,
                  color: Colors.red,
                ),
                title: Text(
                  _isBlocked ? "Engeli Kaldır" : "Engelle",
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (_isBlocked) {
                    // Engeli kaldır
                    await FirebaseFirestore.instance.collection('users').doc(myId).update({
                      'blockedUsers': FieldValue.arrayRemove([widget.otherUserId])
                    });
                    setState(() => _isBlocked = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Engel kaldırıldı"), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    // Engelle
                    bool blocked = await BlockService.blockUser(
                      myId: myId,
                      targetUserId: widget.otherUserId,
                      targetUserName: widget.otherUserName,
                      context: context,
                    );
                    if (blocked) setState(() => _isBlocked = true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D11),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))),
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
        title: GestureDetector(
          onTap: _showUserMenu,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _otherUserPhotoUrl != null
                        ? NetworkImage(_otherUserPhotoUrl!)
                        : null,
                    child: _otherUserPhotoUrl == null
                        ? Text(
                            widget.otherUserName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  if (_isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0D0D11), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _isOnline ? "Çevrimiçi" : _formatLastSeen(),
                      style: TextStyle(
                        color: _isOnline ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MestometerScreen(
                  otherUserId: widget.otherUserId,
                  otherUserName: widget.otherUserName,
                ),
              ),
            ),
            icon: const Icon(Icons.favorite_border, color: Color(0xFFFF5A5F)),
            tooltip: "Mestometre",
          ),
          IconButton(
            onPressed: _showUserMenu,
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Engel uyarısı
          if (_isBlocked || _amIBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _amIBlocked
                          ? "Bu kullanıcı sizi engelledi"
                          : "Bu kullanıcıyı engellediniz",
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Mesajlar
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
                }

                var docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return _buildEmptyChat();
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == myId;
                    String type = data['type'] ?? 'text';
                    bool isDeleted = data['deleted'] ?? false;

                    return GestureDetector(
                      onLongPress: isDeleted ? null : () => _showMessageOptions(data, doc.id, isMe),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: type == 'invite'
                            ? _buildMestInviteCard(data, isMe)
                            : _buildMessageBubble(data, isMe, isDeleted),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Mesaj yazma alanı
          if (!_amIBlocked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D11),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showMestPicker,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt, color: Color(0xFFFF5A5F), size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white),
                              enabled: !_isBlocked,
                              decoration: InputDecoration(
                                hintText: _isBlocked
                                    ? "Engellendi"
                                    : "Bir mesaj yaz...",
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Icon(
                              Icons.send,
                              color: _isBlocked ? Colors.grey : const Color(0xFFFF5A5F),
                            ),
                          ),
                        ],
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

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[700]),
          ),
          const SizedBox(height: 15),
          const Text("Henüz mesaj yok", style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 5),
          const Text("İlk mesajı sen gönder!", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, bool isDeleted) {
    String text = data['text'] ?? '';
    Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    List<dynamic> readBy = data['readBy'] ?? [];
    bool isRead = readBy.contains(widget.otherUserId);

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey[800],
            backgroundImage: _otherUserPhotoUrl != null ? NetworkImage(_otherUserPhotoUrl!) : null,
            child: _otherUserPhotoUrl == null
                ? Text(widget.otherUserName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10))
                : null,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? Colors.grey[800]
                      : isMe
                          ? const Color(0xFFFF5A5F)
                          : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isDeleted ? Colors.grey : Colors.white,
                    fontSize: 15,
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),

              // Tepkiler
              if (reactions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reactions.values.join(' '),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

              // Okundu bilgisi (sadece kendi mesajlarında)
              if (isMe && !isDeleted)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.blue : Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMestInviteCard(Map<String, dynamic> data, bool isMe) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? "Bir Mest gönderdin 🎮" : "${widget.otherUserName} sana bir Mest gönderdi 🎮",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: (data['testImage'] != null && data['testImage'].toString().isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(data['testImage']),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                        )
                      : null,
                  color: Colors.grey[800],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data['testName'] ?? "Test",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PlayMestScreen(testId: data['testId'] ?? '')),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text("Tek Çöz", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _startCoopSession(data['testId'] ?? '', data['testName'] ?? ''),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A5F),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text("Beraber", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLastSeen() {
    if (_lastSeen == null) return "";
    Duration diff = DateTime.now().difference(_lastSeen!);
    if (diff.inMinutes < 5) return "Az önce aktif";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} saat önce";
    return "${diff.inDays} gün önce";
  }
}