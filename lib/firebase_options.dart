// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for ios - '
            'you can reconfigure this by running the FlutterFire CLI again.');
      case TargetPlatform.macOS:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for macos - '
            'you can reconfigure this by running the FlutterFire CLI again.');
      case TargetPlatform.windows:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for windows - '
            'you can reconfigure this by running the FlutterFire CLI again.');
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for linux - '
            'you can reconfigure this by running the FlutterFire CLI again.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // --- WEB AYARLARI (Admin Paneli İçin) ---
  static const FirebaseOptions web = FirebaseOptions(
    // Firebase Konsolu -> Project Settings -> Web App (</>) kısmından al:
    apiKey: 'AIzaSyCorDXQMiRHdNDfpWxR5ksjZVRPqIPLlA8', 
    appId: '1:591057821234:web:99501ad594a2320daca62b', 
    messagingSenderId: '591057821234',
    projectId: 'mest-8a3c7', // Proje ID'n
    authDomain: 'mest-8a3c7.firebaseapp.com',
    storageBucket: 'mest-8a3c7.firebasestorage.app', // Çalışan Bucket Adı
  );

  // --- ANDROID AYARLARI (Mobil Uygulama İçin) ---
  static const FirebaseOptions android = FirebaseOptions(
    // Firebase Konsolu -> Project Settings -> Android App (Robot ikonu) kısmından al:
    apiKey: 'AIzaSyCorDXQMiRHdNDfpWxR5ksjZVRPqIPLlA8', // Genelde Web API Key ile aynıdır
    appId: '1:591057821234:web:99501ad594a2320daca62b', // 1:563... ile başlar
    messagingSenderId: '591057821234', // Web ile aynıdır
    projectId: 'mest-8a3c7',
    storageBucket: 'mest-8a3c7.firebasestorage.app',
  );
}