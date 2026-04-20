import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InterstitialAdService {
  static const String _roundCountKey = 'rounds_since_last_ad';
  static const int _roundsPerAd = 5;

  // kReleaseMode is true only when built with --release (Play Store / App Store).
  // Debug and profile builds use Google's official test IDs so clicks are safe.
  static String get _adUnitId {
    if (kReleaseMode) {
      return Platform.isIOS
          ? 'ca-app-pub-7775348743322565/8718307892'   // production iOS
          : 'ca-app-pub-7775348743322565/9700217077';  // production Android
    }
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/4411468910'     // test iOS
        : 'ca-app-pub-3940256099942544/1033173712';    // test Android
  }

  InterstitialAd? _interstitialAd;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> preloadAd() async {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Call this at the end of every round (win or loss).
  /// Shows the interstitial every 5 rounds, then preloads the next one.
  Future<void> onRoundComplete() async {
    if (kIsWeb) return;

    final prefs = await _sharedPrefs;
    final count = (prefs.getInt(_roundCountKey) ?? 0) + 1;

    if (count >= _roundsPerAd) {
      await prefs.setInt(_roundCountKey, 0);
      _showAd();
    } else {
      await prefs.setInt(_roundCountKey, count);
    }
  }

  /// Shows the ad immediately, bypassing the round counter.
  /// Use this for events that should always trigger an ad (e.g. country reveal).
  void showAdNow() => _showAd();

  void _showAd() {
    if (_interstitialAd == null) {
      preloadAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        preloadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        preloadAd();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
