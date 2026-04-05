import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  // Real ad unit — same ID for iOS and Android per AdMob setup.
  static const String _adUnitId = 'ca-app-pub-7775348743322565/3638044050';

  // Swap in test IDs during development:
  // static const String _adUnitId = 'ca-app-pub-3940256099942544/1712485313'; // iOS
  // static const String _adUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Android

  RewardedAd? _ad;

  /// Called whenever the ad load state changes so the UI can rebuild.
  void Function()? onAdLoadStateChanged;

  bool get isLoaded => _ad != null;

  Future<void> preloadAd() async {
    if (kIsWeb) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (_ad != null) return; // already loaded

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          onAdLoadStateChanged?.call();
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          onAdLoadStateChanged?.call();
        },
      ),
    );
  }

  /// Shows the ad. [onRewarded] fires only when the user earns the reward.
  Future<void> showAd({required void Function() onRewarded}) async {
    if (_ad == null) return;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        preloadAd(); // queue the next ad silently
        onAdLoadStateChanged?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
        preloadAd();
        onAdLoadStateChanged?.call();
      },
    );

    await _ad!.show(
      onUserEarnedReward: (_, __) => onRewarded(),
    );
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
    onAdLoadStateChanged = null;
  }
}
