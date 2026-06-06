import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase options are not configured for web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAiMbwtZX0aexMAEe49raQO9mr3b4GRFIw',
    appId: '1:1041131617769:android:317eb9308564d9a6d35f78',
    messagingSenderId: '1041131617769',
    projectId: 'smart-lms-a0c3c',
    storageBucket: 'smart-lms-a0c3c.firebasestorage.app',
  );
}
