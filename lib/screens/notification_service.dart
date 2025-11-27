import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Arka plan mesaj handler'ı (main.dart'ta çağrılmalı)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Arka plan bildirimi alındı: ${message.notification?.title}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _isInitialized = false;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Bildirim izni iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint("Bildirim izni: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // FCM Token al ve kaydet
        await _saveToken();

        // Token yenilendiğinde
        _messaging.onTokenRefresh.listen(_updateToken);

        // Ön plan bildirimleri
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Bildirime tıklandığında (uygulama arka planda)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Uygulama kapalıyken bildirime tıklandı mı kontrol et
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }

        _isInitialized = true;
        debugPrint("Bildirim servisi başlatıldı ✓");
      }
    } catch (e) {
      debugPrint("Bildirim servisi hatası: $e");
    }
  }

  /// FCM Token'ı kaydet
  Future<void> _saveToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        String? userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint("FCM Token kaydedildi");
        }
      }
    } catch (e) {
      debugPrint("Token kaydetme hatası: $e");
    }
  }

  /// Token yenilendiğinde güncelle
  Future<void> _updateToken(String token) async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("FCM Token güncellendi");
      }
    } catch (e) {
      debugPrint("Token güncelleme hatası: $e");
    }
  }

  /// Ön plandayken gelen bildirimler
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint("Ön plan bildirimi: ${message.notification?.title}");
    
    // Burada bir snackbar veya dialog gösterebilirsin
    // Örnek: Global key kullanarak
    if (navigatorKey.currentContext != null) {
      _showInAppNotification(
        navigatorKey.currentContext!,
        message.notification?.title ?? 'Bildirim',
        message.notification?.body ?? '',
        message.data,
      );
    }
  }

  /// Bildirime tıklandığında
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint("Bildirime tıklandı: ${message.data}");
    
    String? type = message.data['type'];
    
    if (navigatorKey.currentContext != null) {
      switch (type) {
        case 'message':
          String? chatId = message.data['chatId'];
          if (chatId != null) {
            // Chat ekranına git
            Navigator.pushNamed(
              navigatorKey.currentContext!,
              '/chat',
              arguments: {'chatId': chatId},
            );
          }
          break;
        case 'match':
          // Eşleşmeler ekranına git
          Navigator.pushNamed(navigatorKey.currentContext!, '/matches');
          break;
        case 'badge':
          // Profil ekranına git
          Navigator.pushNamed(navigatorKey.currentContext!, '/profile');
          break;
        default:
          // Ana sayfaya git
          Navigator.pushNamed(navigatorKey.currentContext!, '/home');
      }
    }
  }

  /// Uygulama içi bildirim göster (ön plandayken)
  void _showInAppNotification(
    BuildContext context,
    String title,
    String body,
    Map<String, dynamic> data,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (body.isNotEmpty)
              Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Göster',
          textColor: const Color(0xFFFF5A5F),
          onPressed: () {
            // Bildirime tıklandığında
            _handleNotificationTap(context, data);
          },
        ),
      ),
    );
  }

  /// Bildirim tıklama işlemi
  void _handleNotificationTap(BuildContext context, Map<String, dynamic> data) {
    String? type = data['type'];
    
    switch (type) {
      case 'message':
        String? chatId = data['chatId'];
        if (chatId != null) {
          Navigator.pushNamed(context, '/chat', arguments: {'chatId': chatId});
        }
        break;
      case 'match':
        Navigator.pushNamed(context, '/matches');
        break;
      default:
        break;
    }
  }

  /// Belirli bir topic'e abone ol
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint("Topic'e abone olundu: $topic");
    } catch (e) {
      debugPrint("Topic abonelik hatası: $e");
    }
  }

  /// Topic aboneliğini iptal et
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint("Topic aboneliği iptal edildi: $topic");
    } catch (e) {
      debugPrint("Topic iptal hatası: $e");
    }
  }

  /// Token'ı sil (çıkış yaparken)
  Future<void> deleteToken() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      await _messaging.deleteToken();
      debugPrint("FCM Token silindi");
    } catch (e) {
      debugPrint("Token silme hatası: $e");
    }
  }
}

/// Global navigator key (main.dart'ta MaterialApp'e ekle)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============ BİLDİRİM GÖNDERİCİ (Firestore üzerinden) ============
class NotificationSender {
  /// Yeni mesaj bildirimi gönder
  static Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': receiverId,
        'title': '💬 $senderName',
        'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
        'type': 'message',
        'data': {
          'chatId': chatId,
          'senderId': FirebaseAuth.instance.currentUser?.uid,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Bildirim gönderme hatası: $e");
    }
  }

  /// Eşleşme bildirimi gönder
  static Future<void> sendMatchNotification({
    required String receiverId,
    required String matchedUserName,
    required int compatibility,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': receiverId,
        'title': '💖 Yeni Eşleşme!',
        'body': '$matchedUserName ile %$compatibility uyumlusunuz!',
        'type': 'match',
        'data': {
          'senderId': FirebaseAuth.instance.currentUser?.uid,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Bildirim gönderme hatası: $e");
    }
  }

  /// Rozet bildirimi gönder
  static Future<void> sendBadgeNotification({
    required String receiverId,
    required String badgeName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': receiverId,
        'title': '🏆 Yeni Rozet!',
        'body': '"$badgeName" rozetini kazandın!',
        'type': 'badge',
        'data': {'badgeName': badgeName},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Bildirim gönderme hatası: $e");
    }
  }
}

// ============ BİLDİRİMLER SAYFASI ============
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Bildirimler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(userId),
            child: const Text(
              "Tümünü Oku",
              style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notif = notifications[index].data() as Map<String, dynamic>;
              String notifId = notifications[index].id;
              return _buildNotificationCard(context, notifId, notif);
            },
          );
        },
      ),
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
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 50,
              color: Color(0xFFFF5A5F),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Bildirim yok",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Yeni bildirimler burada görünecek",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    String notifId,
    Map<String, dynamic> notif,
  ) {
    String title = notif['title'] ?? 'Bildirim';
    String body = notif['body'] ?? '';
    String type = notif['type'] ?? '';
    bool isRead = notif['read'] ?? false;
    Timestamp? timestamp = notif['createdAt'];

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'message':
        icon = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case 'match':
        icon = Icons.favorite;
        iconColor = const Color(0xFFFF5A5F);
        break;
      case 'badge':
        icon = Icons.emoji_events;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _onNotificationTap(context, notifId, notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: isRead
              ? null
              : Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _formatTime(timestamp.toDate()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5A5F),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onNotificationTap(
    BuildContext context,
    String notifId,
    Map<String, dynamic> notif,
  ) async {
    // Okundu işaretle
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});

    // İlgili sayfaya git
    String type = notif['type'] ?? '';
    Map<String, dynamic> data = notif['data'] ?? {};

    if (context.mounted) {
      switch (type) {
        case 'message':
          String? chatId = data['chatId'];
          if (chatId != null) {
            Navigator.pushNamed(context, '/chat', arguments: {'chatId': chatId});
          }
          break;
        case 'match':
          Navigator.pushNamed(context, '/matches');
          break;
        case 'badge':
          Navigator.pushNamed(context, '/profile');
          break;
      }
    }
  }

  void _markAllAsRead(String? userId) async {
    if (userId == null) return;

    try {
      QuerySnapshot unreadNotifs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadNotifs.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Toplu okundu işaretleme hatası: $e");
    }
  }

  String _formatTime(DateTime date) {
    Duration diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';

    return '${date.day}/${date.month}/${date.year}';
  }
}