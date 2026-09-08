import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads a Google AdMob App Open ad and shows it once it's ready — used
/// once per app launch, triggered a couple of seconds after the Dashboard
/// is already on screen (see DashboardScreen). AdMob's native init (a
/// WebView + Chromium load for ad rendering) is heavy enough to stall the
/// main thread for several seconds; triggering it early — even from the
/// splash screen — measurably blocked the splash-to-dashboard transition,
/// so it now runs after the user is already looking at their data instead.
class AppOpenAdManager {
  AppOpenAdManager._();
  static final instance = AppOpenAdManager._();

  static const _androidAdUnitId = 'ca-app-pub-2955087757761518/7752697582';
  static const _iosAdUnitId = 'ca-app-pub-2955087757761518/5280623084';

  static const _adMaxAge = Duration(hours: 4);

  AppOpenAd? _ad;
  bool _isShowingAd = false;
  bool _shownThisLaunch = false;
  DateTime? _loadTime;

  String get _adUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosAdUnitId
      : _androidAdUnitId;

  bool get _isAdAvailable =>
      _ad != null &&
      _loadTime != null &&
      DateTime.now().difference(_loadTime!) < _adMaxAge;

  /// Loads an ad and shows it automatically once it finishes — a no-op if
  /// one was already shown this app launch.
  void loadAndShowWhenReady() {
    if (_shownThisLaunch) return;
    MobileAds.instance.initialize();
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadTime = DateTime.now();
          debugPrint('[ads] App Open ad loaded');
          _showIfAvailable();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          debugPrint('[ads] App Open ad failed to load: $error');
        },
      ),
    );
  }

  void _showIfAvailable() {
    if (_isShowingAd || _shownThisLaunch || !_isAdAvailable) return;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _isShowingAd = true;
        _shownThisLaunch = true;
      },
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
