import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads a Google AdMob App Open ad on launch and shows it once, the first
/// time the app is ready to display it after the splash screen.
///
/// The Android ID is HISAB's real AdMob App Open ad unit. [_iosAdUnitId] is
/// still Google's public TEST ID — replace it with HISAB's real iOS App
/// Open ad unit once that AdMob app/ad unit is created, alongside the
/// app-level ID in ios/Runner/Info.plist.
class AppOpenAdManager {
  AppOpenAdManager._();
  static final instance = AppOpenAdManager._();

  static const _androidAdUnitId = 'ca-app-pub-2955087757761518/7752697582';
  static const _iosAdUnitId = 'ca-app-pub-3940256099942544/5575463023';

  static const _adMaxAge = Duration(hours: 4);

  AppOpenAd? _ad;
  bool _isShowingAd = false;
  DateTime? _loadTime;

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosAdUnitId : _androidAdUnitId;

  bool get _isAdAvailable =>
      _ad != null &&
      _loadTime != null &&
      DateTime.now().difference(_loadTime!) < _adMaxAge;

  /// Starts loading an ad in the background. Call once, early (e.g. from
  /// `main()`), so the ad is ready by the time the splash screen finishes.
  void loadAd() {
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadTime = DateTime.now();
        },
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  /// Shows the ad if one finished loading in time; otherwise does nothing —
  /// launch is never blocked waiting on an ad.
  void showAdIfAvailable() {
    if (_isShowingAd || !_isAdAvailable) return;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _isShowingAd = true,
      onAdFailedToShowFullScreenContent: (ad, _) {
        _isShowingAd = false;
        ad.dispose();
        _ad = null;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _ad = null;
      },
    );
    _ad!.show();
  }
}
