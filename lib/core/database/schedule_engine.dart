import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ScheduleEngine {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bible.db');
    if (!await File(path).exists()) {
      final data = await rootBundle.load('assets/db/bible.db');
      await File(path).writeAsBytes(data.buffer.asUint8List());
    }
    return openDatabase(path, readOnly: true);
  }

  /// 통독 플랜 자동 생성
  /// [startBookId] 시작 권 (1=창세기)
  /// [endBookId]   끝 권   (66=요한계시록)
  /// [totalDays]   전체 기간 (일수)
  /// [minutesPerDay] 하루 읽기 시간 (분)
  static Future<List<DayPlan>> generatePlan({
    required int startBookId,
    required int endBookId,
    required int totalDays,
    required int minutesPerDay,
  }) async {
    final db = await database;

    // 1. 범위 내 모든 장의 글자 수 가져오기
    final rows = await db.rawQuery('''
      SELECT book_id, chapter, SUM(char_count) as total_chars
      FROM verses
      WHERE book_id >= ? AND book_id <= ?
      GROUP BY book_id, chapter
      ORDER BY book_id, chapter
    ''', [startBookId, endBookId]);

    // 2. 책 이름 맵 생성
    final bookRows = await db.query(
      'books',
      where: 'id >= ? AND id <= ?',
      whereArgs: [startBookId, endBookId],
    );
    final bookNames = {
      for (var b in bookRows) b['id'] as int: b['name'] as String
    };

    // 3. 하루 목표 글자 수 계산 (분당 270자)
    const readingSpeed = 270;
    final targetCharsPerDay = minutesPerDay * readingSpeed;

    // 4. 장 단위로 날별 배분
    final List<DayPlan> plans = [];
    int dayIndex = 0;
    List<ChapterRef> currentDayChapters = [];
    int currentDayChars = 0;

    for (final row in rows) {
      final bookId = row['book_id'] as int;
      final chapter = row['chapter'] as int;
      final chars = (row['total_chars'] as int?) ?? 0;
      final bookName = bookNames[bookId] ?? '';

      // 현재 날 목표치 초과 시 새 날로 넘기기
      // (단, 최소 1장은 반드시 포함)
      if (currentDayChapters.isNotEmpty &&
          currentDayChars + chars > targetCharsPerDay * 1.3) {
        plans.add(DayPlan(
          dayNumber: dayIndex + 1,
          chapters: List.from(currentDayChapters),
          estimatedMinutes: (currentDayChars / readingSpeed).round(),
        ));
        dayIndex++;
        currentDayChapters = [];
        currentDayChars = 0;
      }

      currentDayChapters.add(ChapterRef(
        bookId: bookId,
        bookName: bookName,
        chapter: chapter,
      ));
      currentDayChars += chars;

      // 목표치 도달 시 날 마감
      if (currentDayChars >= targetCharsPerDay * 0.85) {
        plans.add(DayPlan(
          dayNumber: dayIndex + 1,
          chapters: List.from(currentDayChapters),
          estimatedMinutes: (currentDayChars / readingSpeed).round(),
        ));
        dayIndex++;
        currentDayChapters = [];
        currentDayChars = 0;
      }
    }

    // 마지막 남은 장 처리
    if (currentDayChapters.isNotEmpty) {
      plans.add(DayPlan(
        dayNumber: dayIndex + 1,
        chapters: List.from(currentDayChapters),
        estimatedMinutes: (currentDayChars / readingSpeed).round(),
      ));
    }

    return plans;
  }
}

class DayPlan {
  final int dayNumber;
  final List<ChapterRef> chapters;
  final int estimatedMinutes;

  DayPlan({
    required this.dayNumber,
    required this.chapters,
    required this.estimatedMinutes,
  });

  String get displayRange {
    if (chapters.isEmpty) return '';
    final first = chapters.first;
    final last = chapters.last;
    if (first.bookId == last.bookId) {
      if (first.chapter == last.chapter) {
        return '${first.bookName} ${first.chapter}장';
      }
      return '${first.bookName} ${first.chapter}-${last.chapter}장';
    }
    return '${first.bookName} ${first.chapter}장 - ${last.bookName} ${last.chapter}장';
  }
}

class ChapterRef {
  final int bookId;
  final String bookName;
  final int chapter;

  ChapterRef({
    required this.bookId,
    required this.bookName,
    required this.chapter,
  });
}