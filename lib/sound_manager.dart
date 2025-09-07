import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final AudioPlayer _player = AudioPlayer();

  /// Plays a short button click sound
  static Future<void> playClick() async {
    await _player.play(AssetSource('sounds/button-click.wav'));
  }

  static Future<void> playReveal() async {
    await _player.play(AssetSource('sounds/tile-reveal.wav'));
  }

  static Future<void> playFlag() async {
    await _player.play(AssetSource('sounds/tile-flag.wav'));
  }

  static Future<void> playUnflag() async {
    await _player.play(AssetSource('sounds/tile-unflag.wav'));
  }

  static Future<void> playExplode() async {
    await _player.play(AssetSource('sounds/explode.wav'));
  }

  static Future<void> playLost() async {
    await _player.play(AssetSource('sounds/match-lost.wav'));
  }

  static Future<void> playWon() async {
    await _player.play(AssetSource('sounds/match-won.wav'));
  }
}
