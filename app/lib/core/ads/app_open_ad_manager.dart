import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads a Google AdMob App Open ad on launch and shows it once, the first
/// time the app is ready to display it after the splash screen.
///
/// The ad unit IDs below are Google's public TEST IDs (safe to ship during
/// development — they always fill and never earn revenue). Replace
/// [_androidAdUnitId] and [_iosAdUnitId] with your own App Open ad unit IDs
/// from the AdMob console before release, alongside the app-level IDs in
/// android/app/src/main/AndroidManifest.xml and ios/Runner/Info.plist.
class AppOpenAdManager {
  AppOpenAdManager._();
  static final instance = AppOpenAdManager._();

  static const _androidAdUnitId = 'ca-app-pub-3940256099942544/9257395921';
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
