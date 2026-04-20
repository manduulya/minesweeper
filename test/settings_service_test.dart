import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_master/services/settings_service.dart';
import 'package:mine_master/sound_manager.dart';
import 'package:mine_master/service_utils/constants.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundManager.setSoundEnabled(false);
    SoundManager.setVibrationEnabled(false);
  });

  setUp(() {
    // Fresh SharedPreferences for every test.
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() {
    SoundManager.setSoundEnabled(true);
    SoundManager.setVibrationEnabled(true);
  });

  // ── getCountryFlag (pure conversion, no I/O) ──────────────────────────────

  group('SettingsService.getCountryFlag', () {
    final svc = SettingsService();

    test('converts 2-letter ISO code to correct flag emoji', () {
      // 'US' → 🇺🇸
      final flag = svc.getCountryFlag('us');
      expect(flag.runes.length, 2, reason: 'Flag emoji is two regional indicator symbols');
    });

    test('upper-case and lower-case codes produce the same emoji', () {
      expect(svc.getCountryFlag('ng'), equals(svc.getCountryFlag('NG')));
    });

    test('returns 🌍 for empty string', () {
      expect(svc.getCountryFlag(''), equals('🌍'));
    });

    test('returns 🌍 for the kNoCountry sentinel', () {
      expect(svc.getCountryFlag(ApiConstants.kNoCountry), equals('🌍'));
    });

    test('returns 🌍 for codes that are not exactly 2 characters', () {
      expect(svc.getCountryFlag('GBR'), equals('🌍'));
      expect(svc.getCountryFlag('X'), equals('🌍'));
    });

    test('known codes produce distinct emojis', () {
      final us = svc.getCountryFlag('us');
      final gb = svc.getCountryFlag('gb');
      final ng = svc.getCountryFlag('ng');
      expect({us, gb, ng}.length, 3,
          reason: 'Different country codes must produce different flag emojis');
    });
  });

  // ── initializeSettings ────────────────────────────────────────────────────

  group('SettingsService.initializeSettings', () {
    test('defaults to all-enabled when SharedPreferences is empty', () async {
      final svc = SettingsService();
      await svc.initializeSettings();
      expect(svc.soundEffectsEnabled, isTrue);
      expect(svc.vibrationEnabled, isTrue);
      expect(svc.autoSaveEnabled, isTrue);
    });

    test('restores persisted values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'soundEffectsEnabled': false,
        'vibrationEnabled': false,
        'autoSaveEnabled': false,
        'userCountryFlagCode': 'jp',
      });
      final svc = SettingsService();
      await svc.initializeSettings();
      expect(svc.soundEffectsEnabled, isFalse);
      expect(svc.vibrationEnabled, isFalse);
      expect(svc.autoSaveEnabled, isFalse);
      expect(svc.userCountryFlagCode, 'jp');
    });
  });

  // ── setSoundEffects ───────────────────────────────────────────────────────

  group('SettingsService.setSoundEffects', () {
    test('updates the in-memory value', () async {
      final svc = SettingsService();
      await svc.setSoundEffects(false);
      expect(svc.soundEffectsEnabled, isFalse);
      await svc.setSoundEffects(true);
      expect(svc.soundEffectsEnabled, isTrue);
    });

    test('persists the value to SharedPreferences', () async {
      final svc = SettingsService();
      await svc.setSoundEffects(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('soundEffectsEnabled'), isFalse);
    });

    test('propagates change to SoundManager', () async {
      final svc = SettingsService();
      await svc.setSoundEffects(false);
      expect(SoundManager.soundEnabled, isFalse);
      await svc.setSoundEffects(true);
      expect(SoundManager.soundEnabled, isTrue);
      // Restore for other tests.
      SoundManager.setSoundEnabled(false);
    });
  });

  // ── setVibration ──────────────────────────────────────────────────────────

  group('SettingsService.setVibration', () {
    test('updates the in-memory value', () async {
      final svc = SettingsService();
      await svc.setVibration(false);
      expect(svc.vibrationEnabled, isFalse);
      await svc.setVibration(true);
      expect(svc.vibrationEnabled, isTrue);
    });

    test('persists the value to SharedPreferences', () async {
      final svc = SettingsService();
      await svc.setVibration(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('vibrationEnabled'), isFalse);
    });

    test('propagates change to SoundManager', () async {
      final svc = SettingsService();
      await svc.setVibration(false);
      expect(SoundManager.vibrationEnabled, isFalse);
      await svc.setVibration(true);
      expect(SoundManager.vibrationEnabled, isTrue);
      // Restore for other tests.
      SoundManager.setVibrationEnabled(false);
    });
  });

  // ── setAutoSave ───────────────────────────────────────────────────────────

  group('SettingsService.setAutoSave', () {
    test('updates the in-memory value', () async {
      final svc = SettingsService();
      await svc.setAutoSave(false);
      expect(svc.autoSaveEnabled, isFalse);
    });

    test('persists to SharedPreferences', () async {
      final svc = SettingsService();
      await svc.setAutoSave(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('autoSaveEnabled'), isFalse);
    });
  });

  // ── setCountryFlagFromAuth ────────────────────────────────────────────────

  group('SettingsService.setCountryFlagFromAuth', () {
    test('updates the in-memory flag code', () {
      final svc = SettingsService();
      svc.setCountryFlagFromAuth('de');
      expect(svc.userCountryFlagCode, 'de');
    });
  });

  // ── resetToDefaults ───────────────────────────────────────────────────────

  group('SettingsService.resetToDefaults', () {
    test('restores all settings to enabled/null', () async {
      final svc = SettingsService();
      await svc.setSoundEffects(false);
      await svc.setVibration(false);
      await svc.setAutoSave(false);
      svc.setCountryFlagFromAuth('fr');

      await svc.resetToDefaults();

      expect(svc.soundEffectsEnabled, isTrue);
      expect(svc.vibrationEnabled, isTrue);
      expect(svc.autoSaveEnabled, isTrue);
      expect(svc.userCountryFlagCode, isNull);
    });

    test('clears persisted values from SharedPreferences', () async {
      final svc = SettingsService();
      await svc.setSoundEffects(false);
      await svc.resetToDefaults();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('soundEffectsEnabled'), isNull);
    });
  });
}
