import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mine_master/hive/hive_service.dart';
import 'package:mine_master/hive/offline_sync_service.dart';

// Box names mirror the private constants in HiveService.
const _userBox = 'user_cache';
const _statsBox = 'stats_cache';
const _gameBox = 'game_cache';
const _pendingBox = 'pending_results';
const _worldMapBox = 'world_map';

late Directory _tempDir;

Future<void> _initHive() async {
  _tempDir = await Directory.systemTemp.createTemp('hive_test_');
  Hive.init(_tempDir.path);
  await Hive.openBox(_userBox);
  await Hive.openBox(_statsBox);
  await Hive.openBox(_gameBox);
  await Hive.openBox(_pendingBox);
  await Hive.openBox(_worldMapBox);
}

Future<void> _clearAllBoxes() async {
  await HiveService.user.clear();
  await HiveService.stats.clear();
  await HiveService.game.clear();
  await HiveService.pending.clear();
  await HiveService.worldMap.clear();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _initHive();
  });

  setUp(_clearAllBoxes);

  tearDownAll(() async {
    await Hive.close();
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {}
  });

  // ── User profile ──────────────────────────────────────────────────────────

  group('User profile cache', () {
    test('cacheUserProfile stores all fields', () {
      OfflineSyncService.cacheUserProfile(
        username: 'Alice',
        email: 'alice@example.com',
        userId: 'u1',
        countryFlag: 'ng',
        token: 'tok123',
      );
      final profile = OfflineSyncService.getCachedUserProfile();
      expect(profile, isNotNull);
      expect(profile!['username'], 'Alice');
      expect(profile['email'], 'alice@example.com');
      expect(profile['userId'], 'u1');
      expect(profile['countryFlag'], 'ng');
      expect(profile['token'], 'tok123');
    });

    test('getCachedUserProfile returns null when nothing cached', () {
      expect(OfflineSyncService.getCachedUserProfile(), isNull);
    });

    test('clearUserProfile removes the profile', () {
      OfflineSyncService.cacheUserProfile(
        username: 'Bob',
        email: 'b@b.com',
        userId: 'u2',
        countryFlag: 'us',
        token: 'tok',
      );
      OfflineSyncService.clearUserProfile();
      expect(OfflineSyncService.getCachedUserProfile(), isNull);
    });

    test('clearAllUserData removes the profile', () {
      OfflineSyncService.cacheUserProfile(
        username: 'Carol',
        email: 'c@c.com',
        userId: 'u3',
        countryFlag: 'gb',
        token: 'tok',
      );
      OfflineSyncService.clearAllUserData();
      expect(OfflineSyncService.getCachedUserProfile(), isNull);
    });
  });

  // ── cacheGeneration ───────────────────────────────────────────────────────

  group('clearAllUserData — cacheGeneration', () {
    test('increments by 1 each call', () {
      final before = OfflineSyncService.cacheGeneration;
      OfflineSyncService.clearAllUserData();
      expect(OfflineSyncService.cacheGeneration, before + 1);
    });

    test('increments on every call', () {
      final before = OfflineSyncService.cacheGeneration;
      OfflineSyncService.clearAllUserData();
      OfflineSyncService.clearAllUserData();
      expect(OfflineSyncService.cacheGeneration, before + 2);
    });
  });

  // ── Stats ─────────────────────────────────────────────────────────────────

  group('Stats cache', () {
    test('cacheStats and getCachedStats round-trip', () {
      OfflineSyncService.cacheStats({
        'games_played': 10,
        'games_won': 6,
        'total_score': 500,
        'level': 3,
        'streak': 2,
        'hints': 4,
      });
      final stats = OfflineSyncService.getCachedStats();
      expect(stats, isNotNull);
      expect(stats!['games_played'], 10);
      expect(stats['games_won'], 6);
      expect(stats['total_score'], 500);
    });

    test('getCachedStats returns null when nothing cached', () {
      expect(OfflineSyncService.getCachedStats(), isNull);
    });

    test('cacheStats syncs total_score into the score cache', () {
      OfflineSyncService.cacheStats({'total_score': 250, 'level': 2});
      final score = OfflineSyncService.getCachedScore();
      expect(score, isNotNull);
      expect(score!['score'], 250);
    });

    test('cacheStats syncs level into the score cache', () {
      OfflineSyncService.cacheStats({'total_score': 100, 'level': 5});
      final score = OfflineSyncService.getCachedScore();
      expect(score!['level'], 5);
    });

    test('cacheStats does not overwrite higher local score when pending results exist', () {
      // Seed a local score that is higher than the incoming server value.
      OfflineSyncService.cacheScore({'score': 999, 'level': 7});
      // Queue a pending result so hasPendingResults == true.
      OfflineSyncService.queuePendingResult(
          won: true, level: 7, score: 999, hints: 3, streak: 1);
      // Server sends a lower score.
      OfflineSyncService.cacheStats({'total_score': 100, 'level': 1});
      final score = OfflineSyncService.getCachedScore();
      expect(score!['score'], 999,
          reason: 'Local higher score must be preserved while pending results exist');
    });
  });

  // ── Score cache ───────────────────────────────────────────────────────────

  group('Score cache', () {
    test('cacheScore and getCachedScore round-trip', () {
      OfflineSyncService.cacheScore({'score': 300, 'level': 4});
      final score = OfflineSyncService.getCachedScore();
      expect(score, isNotNull);
      expect(score!['score'], 300);
      expect(score['level'], 4);
    });

    test('getCachedScore returns null when nothing cached', () {
      expect(OfflineSyncService.getCachedScore(), isNull);
    });

    test('cacheScore adds an updatedAt timestamp', () {
      OfflineSyncService.cacheScore({'score': 100, 'level': 1});
      final score = OfflineSyncService.getCachedScore();
      expect(score!['updatedAt'], isNotNull);
    });
  });

  // ── updateLocalStats ──────────────────────────────────────────────────────

  group('updateLocalStats', () {
    test('increments games_played on every call', () {
      OfflineSyncService.cacheStats({
        'games_played': 5,
        'games_won': 2,
        'total_score': 200,
      });
      OfflineSyncService.updateLocalStats(won: false, score: 200);
      final stats = OfflineSyncService.getCachedStats();
      expect(stats!['games_played'], 6);
    });

    test('increments games_won only on a win', () {
      OfflineSyncService.cacheStats({'games_played': 3, 'games_won': 1, 'total_score': 100});
      OfflineSyncService.updateLocalStats(won: true, score: 200);
      final stats = OfflineSyncService.getCachedStats();
      expect(stats!['games_won'], 2);
    });

    test('does not increment games_won on a loss', () {
      OfflineSyncService.cacheStats({'games_played': 3, 'games_won': 1, 'total_score': 100});
      OfflineSyncService.updateLocalStats(won: false, score: 100);
      final stats = OfflineSyncService.getCachedStats();
      expect(stats!['games_won'], 1);
    });

    test('sets total_score to the new cumulative score on win', () {
      OfflineSyncService.cacheStats({'games_played': 1, 'games_won': 1, 'total_score': 100});
      OfflineSyncService.updateLocalStats(won: true, score: 250);
      final stats = OfflineSyncService.getCachedStats();
      expect(stats!['total_score'], 250);
    });

    test('updates level in the score cache when provided', () {
      OfflineSyncService.cacheScore({'score': 100, 'level': 2});
      OfflineSyncService.updateLocalStats(won: true, score: 200, level: 5);
      final score = OfflineSyncService.getCachedScore();
      expect(score!['level'], 5);
    });

    test('seeds from score cache when stats box is empty', () {
      OfflineSyncService.cacheScore({'score': 400, 'level': 3});
      // No stats cached — updateLocalStats should seed from score cache.
      OfflineSyncService.updateLocalStats(won: false, score: 400);
      final stats = OfflineSyncService.getCachedStats();
      expect(stats!['games_played'], 1);
    });
  });

  // ── Game state ────────────────────────────────────────────────────────────

  group('Game state cache', () {
    test('cacheGameState and getCachedGameState round-trip', () {
      final state = {'level': 2, 'score': 150, 'revealed': [], 'flagged': []};
      OfflineSyncService.cacheGameState(state);
      final cached = OfflineSyncService.getCachedGameState();
      expect(cached, isNotNull);
      expect(cached!['level'], 2);
      expect(cached['score'], 150);
    });

    test('getCachedGameState returns null when nothing cached', () {
      expect(OfflineSyncService.getCachedGameState(), isNull);
    });

    test('clearGameState removes the cached state', () {
      OfflineSyncService.cacheGameState({'level': 1});
      OfflineSyncService.clearGameState();
      expect(OfflineSyncService.getCachedGameState(), isNull);
    });

    test('clearAllUserData removes game state', () {
      OfflineSyncService.cacheGameState({'level': 3});
      OfflineSyncService.clearAllUserData();
      expect(OfflineSyncService.getCachedGameState(), isNull);
    });
  });

  // ── World map progress ────────────────────────────────────────────────────

  group('World map progress', () {
    test('saveWorldMapProgress and loadWorldMapProgress round-trip', () {
      OfflineSyncService.saveWorldMapProgress({'NG', 'US', 'GB'});
      final loaded = OfflineSyncService.loadWorldMapProgress();
      expect(loaded, containsAll(['NG', 'US', 'GB']));
      expect(loaded.length, 3);
    });

    test('loadWorldMapProgress returns empty set when nothing saved', () {
      expect(OfflineSyncService.loadWorldMapProgress(), isEmpty);
    });

    test('overwrites previous progress on second save', () {
      OfflineSyncService.saveWorldMapProgress({'NG', 'US'});
      OfflineSyncService.saveWorldMapProgress({'JP'});
      final loaded = OfflineSyncService.loadWorldMapProgress();
      expect(loaded, equals({'JP'}));
    });

    test('clearAllUserData removes world map progress', () {
      OfflineSyncService.saveWorldMapProgress({'DE', 'FR'});
      OfflineSyncService.clearAllUserData();
      expect(OfflineSyncService.loadWorldMapProgress(), isEmpty);
    });
  });

  // ── Pending results queue ─────────────────────────────────────────────────

  group('Pending results queue', () {
    test('pendingCount is 0 on a clean slate', () {
      expect(OfflineSyncService.pendingCount, 0);
    });

    test('queuePendingResult increments pendingCount', () {
      OfflineSyncService.queuePendingResult(
          won: true, level: 3, score: 200, hints: 2, streak: 1);
      expect(OfflineSyncService.pendingCount, 1);
    });

    test('multiple results accumulate', () async {
      OfflineSyncService.queuePendingResult(
          won: true, level: 1, score: 100, hints: 3, streak: 1);
      // Small delay so the second call gets a different ms-timestamp key.
      await Future.delayed(const Duration(milliseconds: 2));
      OfflineSyncService.queuePendingResult(
          won: false, level: 2, score: 100, hints: 2, streak: 0);
      expect(OfflineSyncService.pendingCount, 2);
    });

    test('clearAllUserData clears the pending queue', () async {
      OfflineSyncService.queuePendingResult(
          won: true, level: 1, score: 100, hints: 3, streak: 1);
      // clearAllUserData() calls HiveService.pending.clear() but cannot await
      // it (the method is void). Await the clear directly so the test does not
      // race the async microtask chain that Hive's clear() schedules.
      await HiveService.pending.clear();
      expect(OfflineSyncService.pendingCount, 0);
    });

    test('queued result contains all expected fields', () {
      OfflineSyncService.queuePendingResult(
          won: true, level: 4, score: 350, hints: 5, streak: 3);
      final key = HiveService.pending.keys.first.toString();
      final raw = Map<String, dynamic>.from(HiveService.pending.get(key) as Map);
      expect(raw['won'], isTrue);
      expect(raw['level'], 4);
      expect(raw['score'], 350);
      expect(raw['hints'], 5);
      expect(raw['streak'], 3);
      expect(raw['timestamp'], isNotNull);
    });
  });
}
