import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 플랜/진행 기록을 "활성 소스"(개인 or 특정 그룹) 단위로 네임스페이싱해서 저장.
///
/// - `active_plan_source` = 'personal' | 'group:<groupId>'
/// - 소스별 키: `plan_<src>`, `completed_<src>`, `current_streak_<src>`, `best_streak_<src>`
///
/// 구(旧) 키(`current_plan`, `completed_days`, `current_streak`, `best_streak`)는
/// 앱 최초 기동 시 'personal' 네임스페이스로 한 번 마이그레이션.
class LocalStorage {
  static SharedPreferences? _prefs;

  static const String _sourceKey = 'active_plan_source';
  static const String sourcePersonal = 'personal';

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateLegacyKeysIfNeeded();
  }

  static SharedPreferences get _p {
    if (_prefs == null) throw Exception('LocalStorage not initialized');
    return _prefs!;
  }

  // ─── 활성 소스 ───

  static String getActiveSource() => _p.getString(_sourceKey) ?? sourcePersonal;

  static Future<void> setActiveSource(String source) async {
    await _p.setString(_sourceKey, source);
  }

  static String groupSource(String groupId) => 'group:$groupId';

  static bool isGroupSource([String? source]) =>
      (source ?? getActiveSource()).startsWith('group:');

  static String? activeGroupId() {
    final src = getActiveSource();
    return src.startsWith('group:') ? src.substring(6) : null;
  }

  // ─── 네임스페이스 키 빌더 ───

  static String _planKey(String src) => 'plan_$src';
  static String _completedKey(String src) => 'completed_$src';
  static String _currentStreakKey(String src) => 'current_streak_$src';
  static String _bestStreakKey(String src) => 'best_streak_$src';

  // ─── 플랜 저장/로드 ───

  /// 현재 활성 소스의 플랜 저장
  static Future<void> savePlan(Map<String, dynamic> plan) async {
    await _p.setString(_planKey(getActiveSource()), jsonEncode(plan));
  }

  /// 현재 활성 소스의 플랜 조회
  static Map<String, dynamic>? loadPlan() {
    final raw = _p.getString(_planKey(getActiveSource()));
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 지정 소스의 플랜 조회 (소스 전환 전 조회 용도)
  static Map<String, dynamic>? loadPlanFor(String source) {
    final raw = _p.getString(_planKey(source));
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 지정 소스에 플랜 저장 (그룹 플랜 캐시용)
  static Future<void> savePlanFor(
      String source, Map<String, dynamic> plan) async {
    await _p.setString(_planKey(source), jsonEncode(plan));
  }

  /// 현재 활성 소스의 플랜 및 진행 기록 삭제
  static Future<void> clearPlan() async {
    final src = getActiveSource();
    await _p.remove(_planKey(src));
    await _p.remove(_completedKey(src));
    await _p.setInt(_currentStreakKey(src), 0);
    await _p.setInt(_bestStreakKey(src), 0);
  }

  /// 지정 그룹의 로컬 플랜 캐시 및 진행 기록 삭제 (그룹 탈퇴 시 사용)
  static Future<void> clearGroupPlanCache(String groupId) async {
    final src = groupSource(groupId);
    await _p.remove(_planKey(src));
    await _p.remove(_completedKey(src));
    await _p.remove(_currentStreakKey(src));
    await _p.remove(_bestStreakKey(src));
  }

  // ─── 일별 완료 기록 ───

  static Future<void> markDayComplete(int dayNumber,
      {String comment = ''}) async {
    final key = _completedKey(getActiveSource());
    final raw = _p.getString(key) ?? '{}';
    final Map<String, dynamic> data = jsonDecode(raw);

    data[dayNumber.toString()] = {
      'completedAt': DateTime.now().toIso8601String(),
      'comment': comment,
    };

    await _p.setString(key, jsonEncode(data));
    await _updateStreak(dayNumber);
  }

  static Map<String, dynamic> getCompletedDays() {
    final raw = _p.getString(_completedKey(getActiveSource())) ?? '{}';
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static bool isDayComplete(int dayNumber) {
    final data = getCompletedDays();
    return data.containsKey(dayNumber.toString());
  }

  /// 오늘 완료 시 남긴 한마디
  static String? getTodayComment(int dayNumber) {
    final data = getCompletedDays();
    final entry = data[dayNumber.toString()];
    if (entry is Map && entry['comment'] is String) {
      final s = entry['comment'] as String;
      return s.isEmpty ? null : s;
    }
    return null;
  }

  // ─── 스트릭 ───

  static Future<void> _updateStreak(int dayNumber) async {
    final completed = getCompletedDays();
    int streak = 0;

    int check = dayNumber;
    while (completed.containsKey(check.toString())) {
      streak++;
      check--;
      if (check < 1) break;
    }

    final src = getActiveSource();
    await _p.setInt(_currentStreakKey(src), streak);
    final best = _p.getInt(_bestStreakKey(src)) ?? 0;
    if (streak > best) await _p.setInt(_bestStreakKey(src), streak);
  }

  static int getStreak() =>
      _p.getInt(_currentStreakKey(getActiveSource())) ?? 0;
  static int getBestStreak() =>
      _p.getInt(_bestStreakKey(getActiveSource())) ?? 0;

  // ─── 오늘의 Day / 진도 ───

  static int getCurrentDay() {
    final plan = loadPlan();
    if (plan == null) return 1;

    final completedData = getCompletedDays();
    if (completedData.isEmpty) return 1;

    final completedDays =
        completedData.keys.map((e) => int.parse(e)).toList()..sort();

    final lastCompletedDay = completedDays.last;
    final totalPlanDays = (plan['totalDays'] as int?) ?? 365;
    return (lastCompletedDay + 1).clamp(1, totalPlanDays);
  }

  static double getProgress() {
    final plan = loadPlan();
    if (plan == null) return 0.0;
    final totalDays = (plan['totalDays'] as int?) ?? 1;
    final completed = getCompletedDays().length;
    return (completed / totalDays).clamp(0.0, 1.0);
  }

  // ─── 북마크 (소스 무관, 개인별) ───

  static Future<void> addBookmark({
    required int bookId,
    required String bookName,
    required int chapter,
    required int verse,
    required String text,
  }) async {
    const key = 'bookmarks';
    final raw = _p.getString(key) ?? '[]';
    final List<dynamic> list = jsonDecode(raw);

    final exists = list.any((b) =>
        b['bookId'] == bookId &&
        b['chapter'] == chapter &&
        b['verse'] == verse);

    if (!exists) {
      list.add({
        'bookId': bookId,
        'bookName': bookName,
        'chapter': chapter,
        'verse': verse,
        'text': text,
        'savedAt': DateTime.now().toIso8601String(),
      });
      await _p.setString(key, jsonEncode(list));
    }
  }

  static Future<void> removeBookmark({
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    const key = 'bookmarks';
    final raw = _p.getString(key) ?? '[]';
    final List<dynamic> list = jsonDecode(raw);
    list.removeWhere((b) =>
        b['bookId'] == bookId &&
        b['chapter'] == chapter &&
        b['verse'] == verse);
    await _p.setString(key, jsonEncode(list));
  }

  static bool isBookmarked({
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    final raw = _p.getString('bookmarks') ?? '[]';
    final List<dynamic> list = jsonDecode(raw);
    return list.any((b) =>
        b['bookId'] == bookId &&
        b['chapter'] == chapter &&
        b['verse'] == verse);
  }

  static List<Map<String, dynamic>> getBookmarks() {
    final raw = _p.getString('bookmarks') ?? '[]';
    final List<dynamic> list = jsonDecode(raw);
    return list.cast<Map<String, dynamic>>()
      ..sort((a, b) => b['savedAt'].compareTo(a['savedAt']));
  }

  // ─── 구버전 키 마이그레이션 ───

  static Future<void> _migrateLegacyKeysIfNeeded() async {
    final alreadyMigrated = _p.containsKey(_sourceKey) ||
        _p.containsKey(_planKey(sourcePersonal)) ||
        _p.containsKey(_completedKey(sourcePersonal));
    if (alreadyMigrated) return;

    final legacyPlan = _p.getString('current_plan');
    final legacyCompleted = _p.getString('completed_days');
    final legacyCurStreak = _p.getInt('current_streak');
    final legacyBestStreak = _p.getInt('best_streak');

    if (legacyPlan != null) {
      await _p.setString(_planKey(sourcePersonal), legacyPlan);
      await _p.remove('current_plan');
    }
    if (legacyCompleted != null) {
      await _p.setString(_completedKey(sourcePersonal), legacyCompleted);
      await _p.remove('completed_days');
    }
    if (legacyCurStreak != null) {
      await _p.setInt(_currentStreakKey(sourcePersonal), legacyCurStreak);
      await _p.remove('current_streak');
    }
    if (legacyBestStreak != null) {
      await _p.setInt(_bestStreakKey(sourcePersonal), legacyBestStreak);
      await _p.remove('best_streak');
    }

    await _p.setString(_sourceKey, sourcePersonal);
  }
}
