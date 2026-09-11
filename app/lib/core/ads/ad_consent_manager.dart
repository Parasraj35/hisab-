import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google's User Messaging Platform (UMP) consent flow — required by Google
/// before showing personalized ads to EU/UK/EEA users. Google determines
/// the user's region server-side from `requestConsentInfoUpdate`; nothing
/// here hardcodes which countries need it.
///
/// Both ad managers (App Open, Interstitial) must await gatherConsent()
/// before calling MobileAds.instance.initialize() or loading any ad — that
/// ordering is what actually makes this compliant, not just having the SDK
/// present.
class AdConsentManager {
  AdConsentManager._();
  static final instance = AdConsentManager._();

  Future<void>? _inFlight;

  /// Resolves once the user isn't blocked from seeing ads — either consent
  /// wasn't required for their region, or they've just responded to the
  /// form. Never throws: any failure here (e.g. no network) fails open
  /// rather than permanently blocking ad-supported features of the app.
  Future<void> gatherConsent() {
    return _inFlight ??= _run();
  }

  Future<void> _run() async {
    final params = ConsentRequestParameters(
      // Never directed at children — see canRequestAds() below, this
      // mirrors the actual audience declared in the Play Store listing.
      tagForUnderAgeOfConsent: false,
      consentDebugSettings: kReleaseMode
          ? null
          : ConsentDebugSettings(
              // Lets the EEA consent form actually be exercised from a
              // non-EU test device during development. Compiled out of
              // release builds entirely — never affects real users.
              debugGeography: DebugGeography.debugGeographyEea,
            ),
    );

    final updateCompleter = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () => updateCompleter.complete(),
      (FormError error) {
        debugPrint('[ads] Consent info update failed: ${error.message}');
        updateCompleter.complete();
      },
    );
    await updateCompleter.future;

    bool formAvailable;
    try {
      formAvailable = await ConsentInformation.instance.isConsentFormAvailable();
    } catch (_) {
      formAvailable = false;
    }
    if (!formAvailable) return;

    final formCompleter = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint('[ads] Consent form error: ${error.message}');
      }
      if (!formCompleter.isCompleted) formCompleter.complete();
    });
    await formCompleter.future;
  }

  /// Whether ads can be requested at all right now — false only if consent
  /// is required and the user hasn't granted it (Google's own SDK state,
  /// not tracked separately here).
  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      // Unknown state (e.g. gatherConsent() never ran) — fail open rather
      // than silently disabling ads forever.
      return true;
    }
  }
}
