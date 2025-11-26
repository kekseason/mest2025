import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart'; // YENİ EKLENDİ
import 'firebase_options.dart';

// EKRANLAR
import 'screens/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Hata yönetimi (Web'de duplicate app hatası vb. için)
    if (!e.toString().contains('duplicate-app')) {
      print("Firebase Başlatma Hatası: $e");
    }
  }

  runApp(const BenimUygulamam());
}

class BenimUygulamam extends StatefulWidget {
  const BenimUygulamam({super.key});

  @override
  State<BenimUygulamam> createState() => _BenimUygulamamState();
}

class _BenimUygulamamState extends State<BenimUygulamam> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mestler',
      
      // --- YENİLENMİŞ TEMA AYARLARI ---
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D11), // Ana Arka Plan
        primaryColor: const Color(0xFFFF5A5F), // Mest Pembesi
        
        // YENİ: Google Fonts Entegrasyonu (Tüm uygulama için)
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5A5F),
          secondary: Color(0xFF00C853), // Yeşil (Online durumu vb.)
          surface: Color(0xFF1C1C1E), // Kart/Kutu rengi
          background: Color(0xFF0D0D11),
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),

        // Buton Stilleri
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

        // Input (Giriş Kutusu) Stilleri
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5A5F), width: 1)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),

        // Sayfa Geçiş Animasyonları (Daha akıcı)
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // --- AKIŞ KONTROLÜ ---
      home: kIsWeb 
          ? StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))));
                }
                if (snapshot.hasData) {
                  // Admin Kontrolü (Web İçin)
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))));
                      }
                      final isAdmin = userSnapshot.data?.get('isAdmin') == true;
                      if (isAdmin) {
                        return const AdminScreen();
                      } else {
                        return const Scaffold(body: Center(child: Text("BU ALAN SADECE ADMINLER İÇİNDİR!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))));
                      }
                    },
                  );
                }
                return const LoginScreen();
              },
            )
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))));
                }
                if (snapshot.hasData) {
                  return const BildirimDinleyici(child: MainNavigation());
                }
                return const WelcomeScreen();
              },
            ),
    );
  }
}

// --- BİLDİRİM DİNLEYİCİ ---
class BildirimDinleyici extends StatefulWidget {
  final Widget child;
  const BildirimDinleyici({super.key, required this.child});

  @override
  State<BildirimDinleyici> createState() => _BildirimDinleyiciState();
}

class _BildirimDinleyiciState extends State<BildirimDinleyici> {
  @override
  void initState() {
    super.initState();
    _dinlemeyiBaslat();
  }

  void _dinlemeyiBaslat() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('bildirimler')
        .where('aliciId', isEqualTo: user.uid)
        .where('okundu', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      
      for (var doc in snapshot.docs) {
        var data = doc.data();
        _popupGoster(data['gonderenIsim'] ?? 'Biri', data['uyum'] ?? 0, data['mesaj'] ?? '');
        doc.reference.update({'okundu': true});
      }
    });
  }

  void _popupGoster(String isim, int uyum, String mesaj) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFF5A5F), width: 2)),
        title: const Text("💖 YENİ EŞLEŞME!", 
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.white, size: 50),
            const SizedBox(height: 15),
            Text("$isim seninle eşleşti!", 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("Uyum: %$uyum", style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 15),
            Text(mesaj, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Harika!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}