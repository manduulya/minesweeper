import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundManager {
  static final AudioPlayer _player = AudioPlayer();
  static bool _soundEnabled = true;
  static bool _vibrationEnabled = true;

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
    await _player.play(AssetSource(asset));
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
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    Vibration.vibrate(
      pattern: [0, 80, 60, 80, 60, 120],
    ); // celebratory triple pulse
  }

  static Future<void> vibrateExplode() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    // Double thud for explosion
    Vibration.vibrate(pattern: [0, 100, 80, 200]);
  }

  static Future<void> playClick() async => _play('sounds/button-click.ogg');
  static Future<void> playReveal() async => _play('sounds/tile-reveal.ogg');
  static Future<void> playFlag() async => _play('sounds/tile-flag.ogg');
  static Future<void> playUnflag() async => _play('sounds/tile-unflag.ogg');
  static Future<void> playExplode() async => _play('sounds/explode.ogg');
  static Future<void> playLost() async => _play('sounds/match-lost.ogg');
  static Future<void> playWon() async => _play('sounds/match-won.ogg');
}
