import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontOption {
  final String name;
  final String label;
  const FontOption({required this.name, required this.label});
}

class ReadingSettings extends ChangeNotifier {
  static final ReadingSettings _instance = ReadingSettings._internal();
  factory ReadingSettings() => _instance;
  ReadingSettings._internal();

  double _fontSize = 16.0;
  String _fontFamily = 'Pretendard';
  bool _isDarkMode = false;

  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  bool get isDarkMode => _isDarkMode;

  final List<FontOption> fontOptions = const [
    FontOption(name: 'Pretendard', label: '프리텐다드 (기본)'),
    FontOption(name: 'NanumMyeongjo', label: '나눔명조'),
    FontOption(name: 'NanumGothic', label: '나눔고딕'),
    FontOption(name: 'serif', label: '명조체'),
    FontOption(name: 'sans-serif', label: '고딕체'),
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('reading_font_size') ?? 16.0;
    _fontFamily = prefs.getString('reading_font_family') ?? 'Pretendard';
    _isDarkMode = prefs.getBool('reading_dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12.0, 24.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reading_font_size', _fontSize);
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reading_font_family', family);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reading_dark_mode', value);
    notifyListeners();
  }
}
