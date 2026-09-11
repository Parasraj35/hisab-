package com.hisab.app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's biometric prompt (Security screen's Fingerprint/Face unlock,
// and the app-lock screen) needs a FragmentActivity host to attach its
// BiometricPrompt dialog to — plain FlutterActivity throws
// PlatformException(no_fragment_activity, ...) the moment it's used.
// FlutterFragmentActivity is Flutter's own drop-in replacement for exactly
// this; everything else about the activity is unchanged.
class MainActivity : FlutterFragmentActivity()
