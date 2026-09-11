import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_consent_manager.dart';

/// Loads a Google AdMob Interstitial ad and shows it at natural "revenue
/// moments": every 3rd transaction/transfer save (see maybeShow), and every
/// PIN/biometric unlock (see showMandatory, LockScreen). Only an Android ad
/// unit has been created so far, so this is a no-op on iOS until one
/// exists — never fabricate an ad unit ID.
class InterstitialAdManager {
  InterstitialAdManager._();
  static final instance = InterstitialAdManager._();

  static const _androidAdUnitId = 'ca-app-pub-2955087757761518/8386335987';

  // Google's own published test unit (safe to hardcode — not a secret).
  // Debug/profile builds serve this instead of the real one so testing
  // this app doesn't rack up invalid-traffic clicks against the real
  // AdMob inventory; release builds are unaffected.
  static const _androidTestAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // Showing a full-screen ad after every single save would be hostile in an
  // app people use several times a day to log spending — cap it to every
  // Nth trigger instead of every one. showMandatory() (app-unlock) ignores
  // this and always shows.
  static const _showEveryNTriggers = 3;

  InterstitialAd? _ad;
  bool _isShowingAd = false;
  bool _loading = false;
  int _triggerCount = 0;

  String? get _adUnitId {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    return kReleaseMode ? _androidAdUnitId : _androidTestAdUnitId;
  }

  /// Warms up the next ad so it's ready by the time maybeShow()/
  /// showMandatory() are actually due to display one. Safe to call
  /// repeatedly. Gathers UMP consent first (see AdConsentManager) and
  /// bails out entirely if the user hasn't consented.
  Future<void> preload() async {
    final unitId = _adUnitId;
    if (unitId == null || _ad != null || _loading) return;

    await AdConsentManager.instance.gatherConsent();
    if (!await AdConsentManager.instance.canRequestAds()) return;
    if (_ad != null || _loading) return; // re-check: time passed during consent UI

    _loading = true;
    MobileAds.instance.initialize();
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          debugPrint('[ads] Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
          debugPrint('[ads] Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  /// Call after a natural revenue moment. Only actually shows on every
  /// [_showEveryNTriggers]th call — the calls in between just count and
  /// keep the next ad warm.
  void maybeShow() {
    _triggerCount++;
    if (_triggerCount < _showEveryNTriggers) return;
    _triggerCount = 0;
    unawaited(_show());
  }

  /// Called right after a successful PIN/biometric unlock — always
  /// attempts to show, no frequency cap. Resolves once the ad is dismissed
  /// (or immediately if none was available) so the caller knows when it's
  /// safe to reveal the app underneath. Never blocks access to the user's
  /// own local data — a missing/failed ad (e.g. no internet, which this
  /// app otherwise doesn't need) just means the unlock proceeds without one.
  Future<void> showMandatory() => _show();

  Future<void> _show() async {
    if (_isShowingAd || _ad == null) {
      unawaited(preload());
      return;
    }

    final ad = _ad!;
    _ad = null;
    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _isShowingAd = true,
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        _isShowingAd = false;
        failedAd.dispose();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete();
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        _isShowingAd = false;
        dismissedAd.dispose();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete();
      },
    );
    ad.show();
    return completer.future;
  }
}
