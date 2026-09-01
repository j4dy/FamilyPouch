import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const String _kKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIza' 'SyA6AjxpLVk9-2gWUWY78fRgMklxXpUiymA',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _kKey,
    appId: '1:377242274293:web:0130960267c77af581f8bc',
    messagingSenderId: '377242274293',
    projectId: 'familypouch-j4dy',
    authDomain: 'familypouch-j4dy.firebaseapp.com',
    storageBucket: 'familypouch-j4dy.firebasestorage.app',
  );
}
