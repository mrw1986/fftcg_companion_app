import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD2lD3cjJqBaNqaASxFV0vElTCQC8tq4v0',
    appId: '1:161248420888:android:7c34e06f0756e26f7d4f6d',
    messagingSenderId: '161248420888',
    projectId: 'fftcg-sync-service',
    storageBucket: 'fftcg-sync-service.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB09LjEexKL0fLN0SkZaUCXTOy8v1abgmg',
    appId: '1:161248420888:ios:39fc26c67595ce1d7d4f6d',
    messagingSenderId: '161248420888',
    projectId: 'fftcg-sync-service',
    storageBucket: 'fftcg-sync-service.firebasestorage.app',
    iosClientId: '161248420888-0if3vb5df86cm0b2j48rqis3c6hlkha6.apps.googleusercontent.com',
    iosBundleId: 'com.example.fftcgCompanion',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXKGMnQiCcMockvxvP2jGlnfC4Tj3_X7g',
    appId: '1:423984475949:web:d4e37c7c3ed0e132132da4',
    messagingSenderId: '423984475949',
    projectId: 'fftcg-companion',
    storageBucket: 'fftcg-companion.firebasestorage.app',
    authDomain: 'fftcg-companion.firebaseapp.com',
  );
}