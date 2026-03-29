import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String _userBox = 'user_cache';
  static const String _statsBox = 'stats_cache';
  static const String _gameBox = 'game_cache';
  static const String _pendingBox = 'pending_results';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_userBox);
    await Hive.openBox(_statsBox);
    await Hive.openBox(_gameBox);
    await Hive.openBox(_pendingBox);
  }

  static Box get user => Hive.box(_userBox);
  static Box get stats => Hive.box(_statsBox);
  static Box get game => Hive.box(_gameBox);
  static Box get pending => Hive.box(_pendingBox);
}
