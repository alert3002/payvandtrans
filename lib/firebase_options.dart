// Firebase options. For full config run: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnimplementedError(
      'DefaultFirebaseOptions have not been configured. '
      'Run "flutterfire configure" to generate options, or use Firebase.initializeApp() without options (e.g. from google-services.json).',
    );
  }
}
