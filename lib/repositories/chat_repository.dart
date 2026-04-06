import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:happy_plants/db/database_helper.dart';

class PersistedMessage {
  final int? id;
  final String text;
  final bool isUser;
  final bool isContext;
  final DateTime timestamp;

  const PersistedMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.isContext,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'text': text,
        'is_user': isUser ? 1 : 0,
        'is_context': isContext ? 1 : 0,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PersistedMessage.fromMap(Map<String, dynamic> map) => PersistedMessage(
        id: map['id'] as int?,
        text: map['text'] as String,
        isUser: (map['is_user'] as int) == 1,
        isContext: (map['is_context'] as int) == 1,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

class ChatRepository {
  final Database _db;

  ChatRepository._(this._db);

  static Future<ChatRepository> create() async {
    final db = await DatabaseHelper.instance.database;
    return ChatRepository._(db);
  }

  // ── UI messages ────────────────────────────────────────────────────────────

  Future<List<PersistedMessage>> getMessages({int limit = 200}) async {
    final rows = await _db.query(
      'chat_messages',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return rows.map(PersistedMessage.fromMap).toList();
  }

  Future<void> insertMessage(PersistedMessage msg) =>
      _db.insert('chat_messages', msg.toMap());

  Future<void> clearMessages() => _db.delete('chat_messages');

  // ── Gemini API history ─────────────────────────────────────────────────────

  /// Returns conversation turns (role + parts) in insertion order.
  /// Parts with inlineData (images) are excluded since they were not persisted.
  Future<List<Map<String, dynamic>>> getGeminiHistory() async {
    final rows = await _db.query('gemini_history', orderBy: 'id ASC');
    return rows
        .map((r) => {
              'role': r['role'] as String,
              'parts': (jsonDecode(r['parts'] as String) as List)
                  .cast<Map<String, dynamic>>(),
            })
        .toList();
  }

  /// Persists new Gemini turns. Skips turns whose parts are all inlineData.
  Future<void> appendGeminiTurns(
      List<Map<String, dynamic>> turns) async {
    for (final turn in turns) {
      final allParts = (turn['parts'] as List).cast<Map<String, dynamic>>();
      // Drop image data — too large and not needed for context resumption.
      final filtered =
          allParts.where((p) => !p.containsKey('inlineData')).toList();
      if (filtered.isEmpty) continue;
      await _db.insert('gemini_history', {
        'role': turn['role'] as String,
        'parts': jsonEncode(filtered),
      });
    }
  }

  Future<void> clearGeminiHistory() => _db.delete('gemini_history');

  // ── Combined clear ─────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await clearMessages();
    await clearGeminiHistory();
  }
}
