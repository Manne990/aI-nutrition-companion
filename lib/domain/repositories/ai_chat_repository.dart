import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_chat.dart';

abstract interface class AiChatRepository {
  Future<List<AiChatMessage>> loadMessages();

  Future<void> saveMessages(List<AiChatMessage> messages);

  Future<void> appendMessages(List<AiChatMessage> messages);

  Future<void> clearMessages();
}

class SharedPreferencesAiChatRepository implements AiChatRepository {
  const SharedPreferencesAiChatRepository(this._preferences);

  static const messagesKey = 'ai.chat.messages.v1';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesAiChatRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAiChatRepository(preferences);
  }

  @override
  Future<List<AiChatMessage>> loadMessages() async {
    final rawMessages = _preferences.getString(messagesKey);
    if (rawMessages == null || rawMessages.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(rawMessages);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => AiChatMessage.fromJson(Map<String, Object?>.from(item)))
        .where((message) => message.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> saveMessages(List<AiChatMessage> messages) async {
    await _preferences.setString(
      messagesKey,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  @override
  Future<void> appendMessages(List<AiChatMessage> messages) async {
    final currentMessages = await loadMessages();
    await saveMessages([...currentMessages, ...messages]);
  }

  @override
  Future<void> clearMessages() async {
    await _preferences.remove(messagesKey);
  }
}

class InMemoryAiChatRepository implements AiChatRepository {
  InMemoryAiChatRepository([List<AiChatMessage> seedMessages = const []])
    : _messages = List.of(seedMessages);

  final List<AiChatMessage> _messages;

  @override
  Future<List<AiChatMessage>> loadMessages() async {
    return List.unmodifiable(_messages);
  }

  @override
  Future<void> saveMessages(List<AiChatMessage> messages) async {
    _messages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<void> appendMessages(List<AiChatMessage> messages) async {
    _messages.addAll(messages);
  }

  @override
  Future<void> clearMessages() async {
    _messages.clear();
  }
}
