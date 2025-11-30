import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============ BACKGROUND MESSAGE HANDLER ============
// Bu fonksiyon main.dart'ta tanımlanmalı (top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Arka plan bildirimi: ${message.messageId}");
}

// ============ BİLDİRİM SERVİSİ ============
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  String? _fcmToken;
  
  // Getter
  String? get fcmToken => _fcmToken;

  // ============ BAŞLATMA ============
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. İzin iste
      await _requestPermission();

      // 2. Local notifications kur
      await _setupLocalNotifications();

      // 3. FCM token al ve kaydet
      await _getAndSaveToken();

      // 4. Foreground bildirimleri dinle
      _setupForegroundListener();

      // 5. Bildirime tıklama dinle
      _setupNotificationTapListener();

      // 6. Token yenilenme dinle
      _setupTokenRefreshListener();

      _isInitialized = true;
      debugPrint("✅ Bildirim servisi başlatıldı");
    } catch (e) {
      debugPrint("❌ Bildirim servisi hatası: $e");
    }
  }

  // ============ İZİN İSTE ============
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint("Bildirim izni: ${settings.authorizationStatus}");

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint("⚠️ Bildirim izni reddedildi");
    }
  }

  // ============ LOCAL NOTIFICATIONS KURULUMU ============
  Future<void> _setupLocalNotifications() async {
    // Android ayarları
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS ayarları
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
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Android bildirim kanalı oluştur
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'mest_notifications', // ID
        'Mest Bildirimleri', // İsim
        description: 'Mest uygulaması bildirimleri',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // ============ FCM TOKEN AL VE KAYDET ============
  Future<void> _getAndSaveToken() async {
    try {
      // APNs token (iOS için gerekli)
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        debugPrint("APNs Token: $apnsToken");
      }

      // FCM Token al
      _fcmToken = await _messaging.getToken();
      debugPrint("FCM Token: $_fcmToken");

      // Firestore'a kaydet
      await _saveTokenToFirestore(_fcmToken);
    } catch (e) {
      debugPrint("Token alma hatası: $e");
    }
  }

  // ============ TOKEN'I FIRESTORE'A KAYDET ============
  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
      debugPrint("✅ FCM Token Firestore'a kaydedildi");
    } catch (e) {
      debugPrint("Token kaydetme hatası: $e");
    }
  }

  // ============ FOREGROUND BİLDİRİMLERİ DİNLE ============
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 Foreground bildirim: ${message.notification?.title}");
      
      // Local notification göster
      _showLocalNotification(message);
      
      // Firestore'a kaydet
      _saveNotificationToFirestore(message);
    });
  }

  // ============ LOCAL BİLDİRİM GÖSTER ============
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'mest_notifications',
      'Mest Bildirimleri',
      channelDescription: 'Mest uygulaması bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['type'] ?? 'general',
    );
  }

  // ============ BİLDİRİME TIKLAMA DİNLE ============
  void _setupNotificationTapListener() {
    // Uygulama kapalıyken bildirime tıklama
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message.data);
      }
    });

    // Uygulama arka plandayken bildirime tıklama
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  // ============ LOCAL BİLDİRİME TIKLAMA ============
  void _onNotificationTap(NotificationResponse response) {
    debugPrint("Local bildirime tıklandı: ${response.payload}");
    _handleNotificationTap({'type': response.payload});
  }

  // ============ BİLDİRİM TIKLAMASI İŞLE ============
  void _handleNotificationTap(Map<String, dynamic> data) {
    String type = data['type'] ?? 'general';
    String? targetId = data['targetId'];

    debugPrint("Bildirim tıklandı - Tip: $type, Hedef: $targetId");

    // NavigatorKey üzerinden yönlendirme yapılabilir
    // Bu kısım main.dart'ta global navigator key ile çalışır
    
    switch (type) {
      case 'match':
        // Eşleşme ekranına git
        debugPrint("Eşleşme ekranına yönlendir: $targetId");
        break;
      case 'message':
        // Chat ekranına git
        debugPrint("Chat ekranına yönlendir: $targetId");
        break;
      case 'test_approved':
        // Testler ekranına git
        debugPrint("Testler ekranına yönlendir");
        break;
      case 'event':
        // Etkinlik ekranına git
        debugPrint("Etkinlik ekranına yönlendir: $targetId");
        break;
      default:
        debugPrint("Ana sayfaya yönlendir");
    }
  }

  // ============ TOKEN YENİLENME DİNLE ============
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 FCM Token yenilendi");
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });
  }

  // ============ BİLDİRİMİ FIRESTORE'A KAYDET ============
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': userId,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'type': message.data['type'] ?? 'general',
        'targetId': message.data['targetId'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Bildirim kaydetme hatası: $e");
    }
  }

  // ============ ÇIKIŞ YAPARKEN TOKEN SİL ============
  Future<void> clearTokenOnLogout() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint("✅ FCM Token silindi");
    } catch (e) {
      debugPrint("Token silme hatası: $e");
    }
  }

  // ============ TOPIC ABONELİKLERİ ============
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint("✅ Topic'e abone olundu: $topic");
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint("✅ Topic aboneliği iptal edildi: $topic");
  }
}

// ============ BİLDİRİMLER EKRANI ============
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
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
          "Bildirimler",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
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
            .where('receiverId', isEqualTo: _userId)
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildNotificationCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(String docId, Map<String, dynamic> data) {
    String title = data['title'] ?? 'Bildirim';
    String body = data['body'] ?? '';
    String type = data['type'] ?? 'general';
    bool isRead = data['read'] ?? false;
    DateTime? createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : null;

    return GestureDetector(
      onTap: () => _onNotificationTap(docId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isRead 
              ? const Color(0xFF1C1C1E) 
              : const Color(0xFFFF5A5F).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isRead 
              ? null 
              : Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İkon
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: _getTypeColor(type).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(type),
                color: _getTypeColor(type),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 15,
                          ),
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
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNotificationTap(String docId, Map<String, dynamic> data) async {
    // Okundu olarak işaretle
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'read': true});

    // Yönlendirme yap
    String type = data['type'] ?? 'general';
    String? targetId = data['targetId'];

    if (!mounted) return;

    switch (type) {
      case 'match':
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => ChatScreen(matchId: targetId),
        // ));
        break;
      case 'message':
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => ChatScreen(chatId: targetId),
        // ));
        break;
      case 'test_approved':
      case 'test_rejected':
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => const MestlerTab(),
        // ));
        break;
      case 'event':
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => EventDetailScreen(eventId: targetId),
        // ));
        break;
    }
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;

    QuerySnapshot unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: _userId)
        .where('read', isEqualTo: false)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tüm bildirimler okundu olarak işaretlendi"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 20),
          const Text(
            "Bildirim Yok",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Yeni bildirimler burada görünecek",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'match':
        return Icons.favorite;
      case 'message':
        return Icons.chat_bubble;
      case 'test_approved':
        return Icons.check_circle;
      case 'test_rejected':
        return Icons.cancel;
      case 'event':
        return Icons.event;
      case 'warning':
        return Icons.warning;
      case 'streak':
        return Icons.local_fire_department;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'match':
        return Colors.pink;
      case 'message':
        return Colors.blue;
      case 'test_approved':
        return Colors.green;
      case 'test_rejected':
        return Colors.red;
      case 'event':
        return Colors.purple;
      case 'warning':
        return Colors.orange;
      case 'streak':
        return Colors.orange;
      default:
        return const Color(0xFFFF5A5F);
    }
  }

  String _formatDate(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Şimdi";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} saat önce";
    if (diff.inDays < 7) return "${diff.inDays} gün önce";
    return "${date.day}/${date.month}/${date.year}";
  }
}

// ============ OKUNMAMIŞ BİLDİRİM SAYACI ============
class UnreadNotificationBadge extends StatelessWidget {
  final Widget child;
  
  const UnreadNotificationBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return child;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5A5F),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    count > 99 ? "99+" : "$count",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}