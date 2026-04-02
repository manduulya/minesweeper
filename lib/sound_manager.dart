import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundManager {
  static final AudioPlayer _player = AudioPlayer();
  static bool _soundEnabled = true;
  static bool _vibrationEnabled = true;

  // Pool of players for sounds that can overlap (e.g. rapid tile reveals).
  static final List<AudioPlayer> _revealPool = [];
  static int _revealPoolIndex = 0;
  static const int _revealPoolSize = 6;

  // Small pool for flag/unflag so rapid flags don't cut each other off.
  static final List<AudioPlayer> _flagPool = [];
  static int _flagPoolIndex = 0;
  static const int _flagPoolSize = 3;

  static void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  static void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  static bool get soundEnabled => _soundEnabled;
  static bool get vibrationEnabled => _vibrationEnabled;

  static Future<void> _play(String asset) async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Player still preparing — skip this instance.
    }
  }

  /// Plays a sound using a round-robin pool so rapid calls overlap correctly
  /// instead of cutting off the previous instance.
  static Future<void> _playPooled(String asset) async {
    if (!_soundEnabled) return;
    if (_revealPool.length < _revealPoolSize) {
      _revealPool.add(AudioPlayer());
    }
    final player = _revealPool[_revealPoolIndex % _revealPool.length];
    _revealPoolIndex++;
    try {
      await player.setVolume(0.4);
      await player.play(AssetSource(asset));
    } catch (_) {
      // Player still preparing from a previous call — skip this instance.
    }
  }

  static Future<void> _vibrate(int duration) async {
    if (!_vibrationEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    Vibration.vibrate(duration: duration);
  }

  static Future<void> vibrateReveal() async => _vibrate(30); // short tap
  static Future<void> vibrateFlag() async => _vibrate(60); // medium pulse
  static Future<void> vibrateUnflag() async => _vibrate(30); // short tap
  static Future<void> vibrateWin() async {
    if (!_vibrationEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    Vibration.vibrate(
      pattern: [0, 80, 60, 80, 60, 120],
    ); // celebratory triple pulse
  }

  static Future<void> vibrateExplode() async {
    if (!_vibrationEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    // Double thud for explosion
    Vibration.vibrate(pattern: [0, 100, 80, 200]);
  }

  static Future<void> playClick() async => _play('sounds/button-click.ogg');
  static Future<void> playReveal() async =>
      _playPooled('sounds/tile-reveal1.ogg');
  static Future<void> _playFlagPooled(String asset) async {
    if (!_soundEnabled) return;
    if (_flagPool.length < _flagPoolSize) {
      _flagPool.add(AudioPlayer());
    }
    final player = _flagPool[_flagPoolIndex % _flagPool.length];
    _flagPoolIndex++;
    try {
      await player.play(AssetSource(asset));
    } catch (_) {
      // Player still preparing from a previous call — skip this instance.
    }
  }

  static Future<void> playFlag() async => _playFlagPooled('sounds/tile-flag.ogg');
  static Future<void> playUnflag() async => _playFlagPooled('sounds/tile-unflag.ogg');
  static Future<void> playExplode() async => _play('sounds/explode.ogg');
  static Future<void> playLost() async => _play('sounds/match-lost.ogg');
  static Future<void> playWon() async => _play('sounds/match-won.ogg');
}
