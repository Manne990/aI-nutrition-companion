import 'package:ai_nutrition_companion/domain/models/ai_chat.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final userMessage = AiChatMessage(
    id: 'user-1',
    role: AiChatRole.user,
    content: 'What should I eat next?',
    createdAt: DateTime(2026, 6, 29, 15, 30),
  );
  final assistantMessage = AiChatMessage(
    id: 'assistant-1',
    role: AiChatRole.assistant,
    content: 'Try the skyr bowl.',
    createdAt: DateTime(2026, 6, 29, 15, 31),
    safetyBoundary: AiChatSafetyBoundary.none,
  );

  test('in-memory repository appends and clears messages', () async {
    final repository = InMemoryAiChatRepository();

    await repository.appendMessages([userMessage]);
    await repository.appendMessages([assistantMessage]);

    expect(await repository.loadMessages(), [userMessage, assistantMessage]);

    await repository.clearMessages();

    expect(await repository.loadMessages(), isEmpty);
  });

  test(
    'shared preferences repository preserves serialized chat history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAiChatRepository(preferences);

      await repository.saveMessages([userMessage, assistantMessage]);
      final restored = await repository.loadMessages();

      expect(restored, hasLength(2));
      expect(restored.first.role, AiChatRole.user);
      expect(restored.first.content, 'What should I eat next?');
      expect(restored.last.role, AiChatRole.assistant);
      expect(restored.last.content, 'Try the skyr bowl.');
    },
  );

  test(
    'shared preferences repository ignores corrupt persisted chat JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAiChatRepository.messagesKey: '[not json',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAiChatRepository(preferences);

      expect(await repository.loadMessages(), isEmpty);
    },
  );

  test(
    'shared preferences repository ignores wrong persisted chat shape',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAiChatRepository.messagesKey: '{"messages": []}',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAiChatRepository(preferences);

      expect(await repository.loadMessages(), isEmpty);
    },
  );

  test('shared preferences repository skips malformed chat items', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesAiChatRepository.messagesKey:
          '[{"id":"valid","role":"user","content":"Keep this","createdAt":"2026-06-29T15:30:00.000"},'
          '{"id": 42, "role": "assistant", "content": true, "createdAt": false},'
          '{"id":"empty","role":"assistant","content":"   ","createdAt":"2026-06-29T15:31:00.000"}]',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesAiChatRepository(preferences);

    final restored = await repository.loadMessages();

    expect(restored, hasLength(1));
    expect(restored.single.id, 'valid');
    expect(restored.single.content, 'Keep this');
  });
}
