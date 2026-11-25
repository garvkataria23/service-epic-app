// File generated for Epic Infocus (Firebase project: traveltourism-32d7d).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return android;
      case TargetPlatform.macOS:
        return web;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBMyrFUiBrIvOGNHfO0uATegHJd5C88VQ8',
    appId: '1:75010608480:web:559e5da4ecf0c7bcd76205',
    messagingSenderId: '75010608480',
    projectId: 'traveltourism-32d7d',
    authDomain: 'traveltourism-32d7d.firebaseapp.com',
    storageBucket: 'traveltourism-32d7d.firebasestorage.app',
    measurementId: 'G-970PMDXGM4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRviYRMkow4X2Eyv_yOT_I7oXhsiM_sjs',
    appId: '1:75010608480:android:bb9dfe04044446b6d76205',
    messagingSenderId: '75010608480',
    projectId: 'traveltourism-32d7d',
    storageBucket: 'traveltourism-32d7d.firebasestorage.app',
  );
}
