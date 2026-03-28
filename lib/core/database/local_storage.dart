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

  // ─── 플랜 저장/불러오기 ───────────────────────
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
  }

  // ─── 완료 기록 저장/불러오기 ──────────────────
  static Future<void> markDayComplete(int dayNumber, {String comment = ''}) async {
    final key = 'completed_days';
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

  // ─── Streak 계산 ──────────────────────────────
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

  // ─── 현재 Day 번호 ────────────────────────────
  static int getCurrentDay() {
    final plan = loadPlan();
    if (plan == null) return 1;
    final startDate = DateTime.parse(plan['startDate'] as String);
    final today = DateTime.now();
    final diff = today.difference(startDate).inDays + 1;
    return diff.clamp(1, (plan['totalDays'] as int?) ?? 365);
  }

  // ─── 전체 진행률 ──────────────────────────────
  static double getProgress() {
    final plan = loadPlan();
    if (plan == null) return 0.0;
    final totalDays = (plan['totalDays'] as int?) ?? 1;
    final completed = getCompletedDays().length;
    return (completed / totalDays).clamp(0.0, 1.0);
  }
}