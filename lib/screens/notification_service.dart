import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============ BİLDİRİM SERVİSİ ============
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Bildirim kanalı
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mest_notifications',
    'Mest Bildirimleri',
    description: 'Mest uygulaması bildirimleri',
    importance: Importance.high,
    playSound: true,
  );

  // Başlatma
  Future<void> initialize() async {
    // İzin iste
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Bildirim izni: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // FCM token al ve kaydet
      await _saveFCMToken();

      // Local notifications ayarla
      await _setupLocalNotifications();

      // Mesaj dinleyicileri
      _setupMessageHandlers();
    }
  }

  // FCM Token kaydet
  Future<void> _saveFCMToken() async {
    try {
      String? token = await _fcm.getToken();
      String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (token != null && userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM Token kaydedildi');
      }

      // Token yenilendiğinde güncelle
      _fcm.onTokenRefresh.listen((newToken) async {
        if (userId != null) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('FCM Token hatası: $e');
    }
  }

  // Local notifications ayarla
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android kanal oluştur
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // Bildirime tıklanınca
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        Map<String, dynamic> data = jsonDecode(response.payload!);
        _handleNotificationNavigation(data);
      } catch (e) {
        debugPrint('Bildirim payload hatası: $e');
      }
    }
  }

  // Mesaj dinleyicileri
  void _setupMessageHandlers() {
    // Ön planda mesaj
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Ön planda mesaj alındı: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Arka planda bildirime tıklanınca
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Bildirime tıklandı: ${message.notification?.title}');
      _handleNotificationNavigation(message.data);
    });

    // Uygulama kapalıyken bildirime tıklanınca
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationNavigation(message.data);
      }
    });
  }

  // Local bildirim göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFFFF5A5F),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  // Bildirim navigasyonu
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    String? type = data['type'];
    String? targetId = data['targetId'];

    // GlobalKey ile navigator kullanılabilir veya
    // Provider/Riverpod ile state yönetimi yapılabilir
    debugPrint('Navigasyon: type=$type, targetId=$targetId');

    // Burada navigasyon işlemi yapılacak
    // Örnek: Navigator.pushNamed(context, '/chat', arguments: targetId);
  }

  // Token'ı temizle (çıkış yaparken)
  Future<void> clearToken() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
        });
      }
    } catch (e) {
      debugPrint('Token temizleme hatası: $e');
    }
  }
}

// ============ BİLDİRİM GÖNDERİCİ (Cloud Function alternatifi) ============
class NotificationSender {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Yeni mesaj bildirimi
  static Future<void> sendNewMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await _createNotification(
      receiverId: receiverId,
      title: 'Yeni Mesaj 💬',
      body: '$senderName: $message',
      type: 'message',
      data: {'chatId': chatId},
    );
  }

  // Eşleşme bildirimi
  static Future<void> sendMatchNotification({
    required String receiverId,
    required String matchedUserName,
    required int compatibilityPercent,
  }) async {
    await _createNotification(
      receiverId: receiverId,
      title: 'Yeni Eşleşme! 💘',
      body: '$matchedUserName ile %$compatibilityPercent uyumlusunuz!',
      type: 'match',
      data: {'matchedUserName': matchedUserName},
    );
  }

  // Beğeni bildirimi
  static Future<void> sendLikeNotification({
    required String receiverId,
    required String likerName,
  }) async {
    await _createNotification(
      receiverId: receiverId,
      title: 'Birisi Seni Beğendi! ❤️',
      body: '$likerName profilini beğendi',
      type: 'like',
      data: {},
    );
  }

  // Test daveti bildirimi
  static Future<void> sendTestInviteNotification({
    required String receiverId,
    required String senderName,
    required String testName,
    required String chatId,
  }) async {
    await _createNotification(
      receiverId: receiverId,
      title: 'Test Daveti 🎮',
      body: '$senderName seni "$testName" testine davet etti!',
      type: 'test_invite',
      data: {'chatId': chatId, 'testName': testName},
    );
  }

  // Rozet bildirimi
  static Future<void> sendBadgeNotification({
    required String receiverId,
    required String badgeName,
  }) async {
    await _createNotification(
      receiverId: receiverId,
      title: 'Yeni Rozet! 🏆',
      body: '"$badgeName" rozetini kazandın!',
      type: 'badge',
      data: {'badgeName': badgeName},
    );
  }

  // Genel bildirim oluştur
  static Future<void> _createNotification({
    required String receiverId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Kullanıcı ayarlarını kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(receiverId).get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      Map<String, dynamic> settings = userData?['settings'] ?? {};

      // Bildirim tercihlerini kontrol et
      bool shouldSend = true;
      switch (type) {
        case 'message':
          shouldSend = settings['yeniMesajBildirim'] ?? true;
          break;
        case 'match':
        case 'like':
          shouldSend = settings['eslesmeBildirim'] ?? true;
          break;
        case 'test_invite':
        case 'badge':
          shouldSend = settings['yeniTestBildirim'] ?? true;
          break;
      }

      if (!shouldSend) return;

      // Firestore'a bildirim kaydet (Cloud Function tetikleyecek)
      await _firestore.collection('notifications').add({
        'receiverId': receiverId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Bildirim gönderme hatası: $e');
    }
  }
}

// ============ BİLDİRİM LİSTESİ EKRANI ============
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
            child: const Text("Tümünü Oku", style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 12)),
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
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildNotificationItem(context, doc.id, data);
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
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            "Bildirim yok",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Yeni bildirimler burada görünecek",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, String docId, Map<String, dynamic> data) {
    bool isRead = data['read'] ?? false;
    String type = data['type'] ?? '';
    DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();

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
      case 'like':
        icon = Icons.favorite_border;
        iconColor = Colors.pink;
        break;
      case 'test_invite':
        icon = Icons.quiz;
        iconColor = Colors.purple;
        break;
      case 'badge':
        icon = Icons.emoji_events;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return InkWell(
      onTap: () => _onNotificationTap(context, docId, data),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // İkon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['body'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            // Okunmadı göstergesi
            if (!isRead)
              Container(
                width: 10,
                height: 10,
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

  String _formatTime(DateTime dateTime) {
    Duration diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _onNotificationTap(BuildContext context, String docId, Map<String, dynamic> data) {
    // Okundu olarak işaretle
    FirebaseFirestore.instance.collection('notifications').doc(docId).update({'read': true});

    // Navigasyon
    String type = data['type'] ?? '';
    Map<String, dynamic> notifData = data['data'] ?? {};

    // Burada tip'e göre navigasyon yapılabilir
    // Örneğin: Navigator.pushNamed(context, '/chat', arguments: notifData['chatId']);
  }

  static Future<void> _markAllAsRead(String? userId) async {
    if (userId == null) return;

    var batch = FirebaseFirestore.instance.batch();
    var snapshots = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }
}