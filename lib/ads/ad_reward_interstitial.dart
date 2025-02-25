import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdRewardInterstitial {
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isAdLoaded = false;
  String? _iosAdUnitId;

  Future<void> loadAd() async {
    if (_isAdLoaded) return;

    try {
      final configString =
          await rootBundle.loadString('assets/configs/config.json');
      final configJson = jsonDecode(configString);
      _iosAdUnitId = configJson['iosRewardInterstitialId'];

      final adUnitId = Platform.isAndroid ? '' : _iosAdUnitId!;

      await RewardedInterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (RewardedInterstitialAd ad) {
            _rewardedInterstitialAd = ad;
            _isAdLoaded = true;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _isAdLoaded = false;
          },
        ),
      );
    } catch (e) {
      _isAdLoaded = false;
    }
  }

  Future<bool> showAd(BuildContext context) async {
    if (!_isAdLoaded || _rewardedInterstitialAd == null) {
      return true;
    }

    bool isRewarded = false;
    final completer = Completer<bool>();

    _rewardedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
        ad.dispose();
        _isAdLoaded = false;
        if (!completer.isCompleted) {
          completer.complete(isRewarded);
        }
      },
      onAdFailedToShowFullScreenContent:
          (RewardedInterstitialAd ad, AdError error) {
        ad.dispose();
        _isAdLoaded = false;
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );

    _rewardedInterstitialAd!.setImmersiveMode(true);
    await _rewardedInterstitialAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        isRewarded = true;
      },
    );

    return await completer.future;
  }

  void dispose() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
    _isAdLoaded = false;
  }
}
