import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    if (_prefs == null) throw Exception('LocalStorage not initialized');
    return _prefs!;
  }

  static Future<void> savePlan(Map<String, dynamic> plan) async {
    await _p.setString('current_plan', jsonEncode(plan));
  }

  static Map<String, dynamic>? loadPlan() {
    final raw = _p.getString('current_plan');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearPlan() async {
    await _p.remove('current_plan');
    await _p.remove('completed_days');
    await _p.setInt('current_streak', 0);
    await _p.setInt('best_streak', 0);
  }

  static Future<void> markDayComplete(int dayNumber,
      {String comment = ''}) async {
    const key = 'completed_days';
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
    final raw = _p.getString('completed_days') ?? '{}';
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static bool isDayComplete(int dayNumber) {
    final data = getCompletedDays();
    return data.containsKey(dayNumber.toString());
  }

  static Future<void> _updateStreak(int dayNumber) async {
    final completed = getCompletedDays();
    int streak = 0;
    int check = dayNumber;
    while (completed.containsKey(check.toString())) {
      streak++;
      check--;
    }
    await _p.setInt('current_streak', streak);
    final best = _p.getInt('best_streak') ?? 0;
    if (streak > best) await _p.setInt('best_streak', streak);
  }

  static int getStreak() => _p.getInt('current_streak') ?? 0;
  static int getBestStreak() => _p.getInt('best_streak') ?? 0;

  static int getCurrentDay() {
    final plan = loadPlan();
    if (plan == null) return 1;
    final startDate = DateTime.parse(plan['startDate'] as String);
    final today = DateTime.now();
    final diff = today.difference(startDate).inDays + 1;
    return diff.clamp(1, (plan['totalDays'] as int?) ?? 365);
  }

  static double getProgress() {
    final plan = loadPlan();
    if (plan == null) return 0.0;
    final totalDays = (plan['totalDays'] as int?) ?? 1;
    final completed = getCompletedDays().length;
    return (completed / totalDays).clamp(0.0, 1.0);
  }

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
}