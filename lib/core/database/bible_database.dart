import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class BibleDatabase {
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
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes);
    }
    return openDatabase(path, readOnly: true);
  }

  static Future<List<Map<String, dynamic>>> getChapter(
      int bookId, int chapter) async {
    final db = await database;
    return db.query(
      'verses',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
      orderBy: 'verse',
    );
  }

  static Future<Map<String, dynamic>?> getBook(int bookId) async {
    final db = await database;
    final result = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  static Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await database;
    return db.query('books', orderBy: 'id');
  }

  static Future<int> getChapterCount(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(chapter) as count FROM verses WHERE book_id = ?',
      [bookId],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}