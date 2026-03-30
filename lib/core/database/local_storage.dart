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

  static Future<void> markDayComplete(int dayNumber, {String comment = ''}) async {
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

  // 👉 수정 포인트 1: 실제 완료된 날짜들을 체크하여 연속 기록(Streak) 계산
  static Future<void> _updateStreak(int dayNumber) async {
    final completed = getCompletedDays();
    int streak = 0;
    
    // 현재 완료한 날(dayNumber)부터 역순으로 몇 개가 연속으로 있는지 확인
    int check = dayNumber;
    while (completed.containsKey(check.toString())) {
      streak++;
      check--;
      if (check < 1) break;
    }
    
    await _p.setInt('current_streak', streak);
    final best = _p.getInt('best_streak') ?? 0;
    if (streak > best) await _p.setInt('best_streak', streak);
  }

  static int getStreak() => _p.getInt('current_streak') ?? 0;
  static int getBestStreak() => _p.getInt('best_streak') ?? 0;

  // 👉 수정 포인트 2: 날짜 계산기가 아닌 '내 진도'에 맞춘 오늘의 Day 반환
  static int getCurrentDay() {
    final plan = loadPlan();
    if (plan == null) return 1;
    
    final completedData = getCompletedDays();
    if (completedData.isEmpty) return 1; // 아무것도 안 읽었으면 1일차
    
    // 완료된 Day 번호들 중 가장 큰 값을 찾음
    List<int> completedDays = completedData.keys.map((e) => int.parse(e)).toList();
    completedDays.sort();
    
    int lastCompletedDay = completedDays.last;
    int totalPlanDays = (plan['totalDays'] as int?) ?? 365;

    // 마지막으로 완료한 날의 다음 날을 '오늘 읽을 날'로 지정
    return (lastCompletedDay + 1).clamp(1, totalPlanDays);
  }

  static double getProgress() {
    final plan = loadPlan();
    if (plan == null) return 0.0;
    final totalDays = (plan['totalDays'] as int?) ?? 1;
    final completed = getCompletedDays().length;
    return (completed / totalDays).clamp(0.0, 1.0);
  }

  // --- 북마크 기능 (기존 유지) ---
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