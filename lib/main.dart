import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';
import 'screens/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


// EKRANLAR
import 'screens/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notification_service.dart';
import 'screens/chat_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_tab.dart';
import 'screens/user_profile_screen.dart';

// ============ GLOBAL NAVIGATOR KEY ============
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============ BACKGROUND MESSAGE HANDLER ============
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Arka plan bildirimi: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Offline persistence etkinleştir
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      debugPrint("Firebase Başlatma Hatası: $e");
    }
  }

  runApp(const MestApp());
}

class MestApp extends StatefulWidget {
  const MestApp({super.key});

  @override
  State<MestApp> createState() => _MestAppState();
}

class _MestAppState extends State<MestApp> with WidgetsBindingObserver {
  // Bağlantı durumu
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setStatus(true);
    _initConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // İnternet bağlantısı kontrolü - 🔴 DÜZELTİLDİ
  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        // connectivity_plus yeni versiyonları List döndürür
        if (result is List) {
          _isOffline = (result as List).contains(ConnectivityResult.none) || (result as List).isEmpty;
        } else {
          _isOffline = result == ConnectivityResult.none;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setStatus(true);
    } else {
      _setStatus(false);
    }
  }

  void _setStatus(bool isOnline) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Status güncelleme hatası: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mest',
      theme: _buildTheme(context),
      
      // 🔴 YENİ: Navigator Key eklendi (bildirimler için)
      navigatorKey: navigatorKey,
      
      // 🔴 YENİ: Named Routes tanımlandı
      routes: {
        '/home': (context) => const MainNavigation(),
        '/matches': (context) => const MatchesScreen(),
        '/profile': (context) => const ProfileTab(),
      },
      
      // 🔴 YENİ: Dinamik route'lar için onGenerateRoute
      onGenerateRoute: (settings) {
        // /chat route'u - arguments ile chatId, otherUserId, otherUserName alır
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: args['chatId'] ?? '',
                otherUserId: args['otherUserId'] ?? '',
                otherUserName: args['otherUserName'] ?? 'Kullanıcı',
              ),
            );
          }
          // Args yoksa ana sayfaya dön
          return MaterialPageRoute(builder: (context) => const MainNavigation());
        }
        
        // /user-profile route'u
        if (settings.name == '/user-profile') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: args['userId'] ?? '',
                userName: args['userName'] ?? 'Kullanıcı',
              ),
            );
          }
        }
        
        // Bilinmeyen route - ana sayfaya yönlendir
        return MaterialPageRoute(builder: (context) => const MainNavigation());
      },
      
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox(),
            // Offline banner
            if (_isOffline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  child: Container(
                    color: Colors.red,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                      bottom: 8,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "İnternet bağlantısı yok",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      home: kIsWeb ? const WebFlow() : const MobileFlow(),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D11),
      primaryColor: const Color(0xFFFF5A5F),
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF5A5F),
        secondary: Color(0xFF00C853),
        surface: Color(0xFF1C1C1E),
        background: Color(0xFF0D0D11),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A5F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 4,
          shadowColor: const Color(0xFFFF5A5F).withOpacity(0.4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF5A5F), width: 1),
        ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ============ WEB AKIŞI ============
class WebFlow extends StatelessWidget {
  const WebFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }

              final isAdmin = userSnapshot.data?.get('isAdmin') == true;
              if (isAdmin) {
                return const AdminScreen();
              } else {
                return const Scaffold(
                  backgroundColor: Color(0xFF0D0D11),
                  body: Center(
                    child: Text(
                      "BU ALAN SADECE ADMİNLER İÇİNDİR!",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}

// ============ MOBİL AKIŞI ============
class MobileFlow extends StatelessWidget {
  const MobileFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          // Kullanıcı giriş yaptı - onboarding kontrolü
          return FutureBuilder<bool>(
            future: OnboardingHelper.shouldShowOnboarding(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }

              // Bildirim servisini başlat
              NotificationService().initialize();

              if (onboardingSnapshot.data == true) {
                return const OnboardingScreen();
              }

              return const NotificationWrapper(child: MainNavigation());
            },
          );
        }

        return const WelcomeScreen();
      },
    );
  }
}

// ============ BİLDİRİM WRAPPER ============
class NotificationWrapper extends StatefulWidget {
  final Widget child;
  const NotificationWrapper({super.key, required this.child});

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Eşleşme bildirimlerini dinle
    FirebaseFirestore.instance
        .collection('bildirimler')
        .where('aliciId', isEqualTo: user.uid)
        .where('okundu', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        var data = doc.data();
        _showMatchPopup(
          data['gonderenIsim'] ?? 'Biri',
          data['gonderenId'] ?? '',  // 🔴 YENİ: gonderenId eklendi
          data['uyum'] ?? 0,
          data['mesaj'] ?? '',
        );
        doc.reference.update({'okundu': true});
      }
    });
  }

  // 🔴 DÜZELTİLDİ: Chat navigation eklendi
  void _showMatchPopup(String isim, String gonderenId, int uyum, String mesaj) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF5A5F), width: 2),
        ),
        title: const Text(
          "💖 YENİ EŞLEŞME!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animasyonlu kalp
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (value * 0.5),
                  child: Opacity(
                    opacity: value,
                    child: const Icon(Icons.favorite, color: Color(0xFFFF5A5F), size: 60),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            Text(
              "$isim seninle eşleşti!",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "%$uyum Uyumlu",
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 15),
            if (mesaj.isNotEmpty)
              Text(
                mesaj,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Sonra", style: TextStyle(color: Colors.grey)),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  // 🔴 DÜZELTİLDİ: Chat'e yönlendirme eklendi
                  onPressed: () {
                    Navigator.pop(context);
                    _openChatWithUser(gonderenId, isim);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A5F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Mesaj At", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔴 YENİ: Chat açma fonksiyonu
  Future<void> _openChatWithUser(String otherUserId, String otherUserName) async {
    if (otherUserId.isEmpty) return;
    
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Chat ID oluştur (alfabetik sıralama ile tutarlılık)
    String chatId = currentUserId.compareTo(otherUserId) < 0
        ? '${currentUserId}_$otherUserId'
        : '${otherUserId}_$currentUserId';

    try {
      // Chat var mı kontrol et, yoksa oluştur
      DocumentSnapshot chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'users': [currentUserId, otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // Chat ekranına git
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Chat açma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ============ LOADING SCREEN ============
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D11),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo yerine
            Text(
              "Mest",
              style: TextStyle(
                color: Color(0xFFFF5A5F),
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(
              color: Color(0xFFFF5A5F),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ERROR HANDLER ============
class ErrorHandler {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: "Tekrar Dene",
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}