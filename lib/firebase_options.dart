import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBMNTgZrhZ1TtlgZI3F4WyZf1Z6gexZriQ',
    appId: '1:282853549882:web:0649e3b8fb1c4996f9d203',
    messagingSenderId: '282853549882',
    projectId: 'logistica-barraca',
    authDomain: 'logistica-barraca.firebaseapp.com',
    storageBucket: 'logistica-barraca.firebasestorage.app',
    measurementId: 'G-4W8MJWFRKT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB89d7M91-KlLzJ_g6L-HjT8RipTsN_vLw',
    appId: '1:282853549882:android:4f7d85c71eb86519f9d203',
    messagingSenderId: '282853549882',
    projectId: 'logistica-barraca',
    storageBucket: 'logistica-barraca.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBb6N1UOGAYrS7w6MI2De-L7BYa5WOxH2g',
    appId: '1:282853549882:ios:f1b3ab94ebd0e727f9d203',
    messagingSenderId: '282853549882',
    projectId: 'logistica-barraca',
    storageBucket: 'logistica-barraca.firebasestorage.app',
    iosClientId: '282853549882-5tbbppbb95pj6osgdo4bbrsij9is73d9.apps.googleusercontent.com',
    iosBundleId: 'com.example.logisticaBarracaMvp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBb6N1UOGAYrS7w6MI2De-L7BYa5WOxH2g',
    appId: '1:282853549882:ios:f1b3ab94ebd0e727f9d203',
    messagingSenderId: '282853549882',
    projectId: 'logistica-barraca',
    storageBucket: 'logistica-barraca.firebasestorage.app',
    iosClientId: '282853549882-5tbbppbb95pj6osgdo4bbrsij9is73d9.apps.googleusercontent.com',
    iosBundleId: 'com.example.logisticaBarracaMvp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBMNTgZrhZ1TtlgZI3F4WyZf1Z6gexZriQ',
    appId: '1:282853549882:web:cec074df7f92c258f9d203',
    messagingSenderId: '282853549882',
    projectId: 'logistica-barraca',
    authDomain: 'logistica-barraca.firebaseapp.com',
    storageBucket: 'logistica-barraca.firebasestorage.app',
    measurementId: 'G-Z75E0140JE',
  );

}