import '../hive/hive_service.dart';

class DailyChallengeConfig {
  final int rows;
  final int cols;
  final int bombs;
  final int seed;

  const DailyChallengeConfig({
    required this.rows,
    required this.cols,
    required this.bombs,
    required this.seed,
  });
}

class DailyChallengeResult {
  final bool won;
  final int timeSeconds;
  final int hintsUsed;
  final bool cleanWin;

  const DailyChallengeResult({
    required this.won,
    required this.timeSeconds,
    required this.hintsUsed,
    required this.cleanWin,
  });

  Map<String, dynamic> toMap() => {
    'won': won,
    'time_seconds': timeSeconds,
    'hints_used': hintsUsed,
    'clean_win': cleanWin,
  };

  factory DailyChallengeResult.fromMap(Map map) => DailyChallengeResult(
    won: map['won'] as bool? ?? false,
    timeSeconds: map['time_seconds'] as int? ?? 0,
    hintsUsed: map['hints_used'] as int? ?? 0,
    cleanWin: map['clean_win'] as bool? ?? false,
  );
}

class DailyChallengeService {
  static String getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static int getDailySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  static int getChallengeNumber() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }

  static DailyChallengeConfig getDailyConfig() {
    return DailyChallengeConfig(
      rows: 9,
      cols: 9,
      bombs: 12,
      seed: getDailySeed(),
    );
  }

  static DailyChallengeResult? loadTodayResult() {
    final data = HiveService.daily.get(getTodayKey());
    if (data == null) return null;
    return DailyChallengeResult.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> saveResult(DailyChallengeResult result) async {
    await HiveService.daily.put(getTodayKey(), result.toMap());
  }

  static int getDailyStreak() {
    final box = HiveService.daily;
    int streak = 0;
    final now = DateTime.now();

    // If today is already won, start counting from today; otherwise from yesterday.
    final todayKey = _dateKey(now);
    final todayData = box.get(todayKey);
    final todayWon = todayData != null &&
        (Map<String, dynamic>.from(todayData as Map)['won'] as bool? ?? false);

    for (int i = todayWon ? 0 : 1; i < 365; i++) {
      final key = _dateKey(now.subtract(Duration(days: i)));
      final data = box.get(key);
      if (data == null) break;
      if (!(Map<String, dynamic>.from(data as Map)['won'] as bool? ?? false)) break;
      streak++;
    }

    return streak;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Duration timeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  static String formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String buildShareText(DailyChallengeResult result) {
    final now = DateTime.now();
    final dateStr =
        '${_monthName(now.month)} ${now.day}, ${now.year}';
    final challengeNum = getChallengeNumber();
    final timeStr = formatTime(result.timeSeconds);
    final cleanTag = result.cleanWin ? ' | No hints' : '';
    return 'Mine Master — Daily Challenge #$challengeNum\n$dateStr\nTime: $timeStr$cleanTag\nCan you beat it?';
  }

  static String _monthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }
}
