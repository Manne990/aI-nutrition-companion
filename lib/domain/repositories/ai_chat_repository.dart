import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_chat.dart';
import 'persisted_json.dart';

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

    final decoded = decodePersistedJsonList(rawMessages);
    if (decoded == null) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(_messageFromStoredJson)
        .whereType<AiChatMessage>()
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

  AiChatMessage? _messageFromStoredJson(Map<Object?, Object?> item) {
    try {
      return AiChatMessage.fromJson(Map<String, Object?>.from(item));
    } on TypeError {
      return null;
    }
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
