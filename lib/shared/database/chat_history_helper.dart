import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_history.dart';

class ChatHistoryHelper {
  // 单例模式
  static final ChatHistoryHelper instance = ChatHistoryHelper._init();
  static Database? _database;

  ChatHistoryHelper._init();

  // 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_history.db');
    return _database!;
  }

  // 初始化数据库
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // 创建数据表
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id TEXT NOT NULL,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id)
      )
    ''');
  }

  // 插入新消息
  Future<int> insertMessage(ChatMessage message, int conversationId) async {
    final db = await database;
    return await db.insert('chat_messages', {
      'conversation_id': conversationId,
      'text': message.text,
      'is_user': message.isUser ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 根据对话ID获取所有消息
  Future<List<ChatMessage>> getMessagesByConversationId(
    int conversationId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );

    return maps
        .map(
          (map) => ChatMessage(
            text: map['text'],
            isUser: map['is_user'] == 1,
            timestamp: DateTime.parse(map['timestamp']),
          ),
        )
        .toList();
  }

  // 删除对话的所有消息
  Future<int> deleteMessagesByConversationId(int conversationId) async {
    final db = await database;
    return await db.delete(
      'chat_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  // 关闭数据库
  Future close() async {
    final db = await database;
    db.close();
  }
}
