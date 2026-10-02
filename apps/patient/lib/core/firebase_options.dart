import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_WEB_API_KEY'] ?? '',
        appId: '1:46162926481:web:4b67b999d3191caf269830',
        messagingSenderId: '46162926481',
        projectId: 'gozai-app',
        authDomain: 'gozai-app.firebaseapp.com',
        storageBucket: 'gozai-app.firebasestorage.app',
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '',
        appId: '1:46162926481:android:e01f0128fa4f0388269830',
        messagingSenderId: '46162926481',
        projectId: 'gozai-app',
        storageBucket: 'gozai-app.firebasestorage.app',
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_IOS_API_KEY'] ?? '',
        appId: '1:46162926481:ios:5842a62c143be9df269830',
        messagingSenderId: '46162926481',
        projectId: 'gozai-app',
        storageBucket: 'gozai-app.firebasestorage.app',
        iosBundleId: 'com.gozai.gozai',
      );
}
