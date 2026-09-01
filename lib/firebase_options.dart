import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA6AjxpLVk9-2gWUWY78fRgMklxXpUiymA',
    appId: '1:377242274293:web:0130960267c77af581f8bc',
    messagingSenderId: '377242274293',
    projectId: 'familypouch-j4dy',
    authDomain: 'familypouch-j4dy.firebaseapp.com',
    storageBucket: 'familypouch-j4dy.firebasestorage.app',
  );
}
