import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/ai_chat.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/meal_suggestion.dart';
import '../../domain/models/onboarding.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../services/adapters/ai_chat_adapter.dart';
import '../../shared/widgets/ai_message_bubble.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/source_chip.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.profile,
    required this.nutritionRepository,
    required this.chatRepository,
    required this.configuration,
    this.currentSuggestion,
    this.adapter = const MockAiChatAdapter(),
    this.initialPrompt,
    this.now,
  });

  final OnboardingProfile profile;
  final NutritionRepository nutritionRepository;
  final AiChatRepository chatRepository;
  final AiAdapterConfiguration configuration;
  final MealSuggestion? currentSuggestion;
  final AiChatAdapter adapter;
  final String? initialPrompt;
  final DateTime? now;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  var _messages = <AiChatMessage>[];
  var _isLoadingHistory = true;
  var _isSending = false;
  var _didSendInitialPrompt = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Companion'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearMessages,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildThread(context)),
            if (_errorMessage != null) _ErrorStrip(message: _errorMessage!),
            _ChatComposer(
              controller: _inputController,
              isSending: _isSending,
              onSubmitted: _submitText,
              onCameraPressed: _recordCameraEntry,
              onVoicePressed: _recordVoiceEntry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThread(BuildContext context) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty && !_isSending) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            'Ask about today',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Meals logged: ${_context.mealsSummary}. Protein left: ${_context.proteinRemainingGrams.round()}g.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AiChoiceChip(
                label: 'What should I eat next?',
                primary: true,
                onPressed: () => _sendPrompt('What should I eat next?'),
              ),
              AiChoiceChip(
                label: 'How can I hit protein today?',
                onPressed: () =>
                    _sendPrompt('How can I hit my protein goal today?'),
              ),
              AiChoiceChip(
                label: 'Explain the suggestion',
                onPressed: widget.currentSuggestion == null
                    ? null
                    : () => _sendPrompt('Explain why this suggestion fits.'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ContextPanel(context: _context),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _ContextPanel(context: _context),
        const SizedBox(height: AppSpacing.md),
        for (final message in _messages) ...[
          _ChatMessageRow(message: message),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_isSending) ...[
          const SizedBox(height: AppSpacing.xs),
          const _ThinkingRow(),
        ],
      ],
    );
  }

  AiChatContext get _context {
    final now = widget.now ?? DateTime.now();
    return AiChatContext(
      preferences: widget.profile.toUserPreferences(),
      summary: widget.nutritionRepository.dailySummary(now),
      configuration: widget.configuration,
      currentSuggestion: widget.currentSuggestion,
    );
  }

  Future<void> _loadMessages() async {
    final messages = await widget.chatRepository.loadMessages();
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = messages;
      _isLoadingHistory = false;
    });
    final initialPrompt = widget.initialPrompt?.trim();
    if (!_didSendInitialPrompt &&
        initialPrompt != null &&
        initialPrompt.isNotEmpty) {
      _didSendInitialPrompt = true;
      await _sendPrompt(initialPrompt);
    }
  }

  Future<void> _submitText() async {
    final prompt = _inputController.text.trim();
    _inputController.clear();
    await _sendPrompt(prompt);
  }

  Future<void> _sendPrompt(String prompt) async {
    if (prompt.trim().isEmpty || _isSending) {
      return;
    }

    final sentAt = DateTime.now();
    final userMessage = AiChatMessage(
      id: 'user-${sentAt.microsecondsSinceEpoch}',
      role: AiChatRole.user,
      content: prompt.trim(),
      createdAt: sentAt,
    );

    setState(() {
      _messages = [..._messages, userMessage];
      _isSending = true;
      _errorMessage = null;
    });
    await widget.chatRepository.appendMessages([userMessage]);
    _scrollToBottom();

    try {
      final response = await widget.adapter.sendMessage(
        prompt: prompt,
        context: _context,
        history: _messages,
      );
      final responseAt = DateTime.now();
      final assistantMessage = AiChatMessage(
        id: 'assistant-${responseAt.microsecondsSinceEpoch}',
        role: AiChatRole.assistant,
        content: response.message,
        createdAt: responseAt,
        safetyBoundary: response.safetyBoundary,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [..._messages, assistantMessage];
        _isSending = false;
      });
      await widget.chatRepository.appendMessages([assistantMessage]);
      _scrollToBottom();
    } on AiProviderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
        _errorMessage = _providerFailureMessage(error.kind);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
        _errorMessage =
            'Companion response unavailable. Try again, check provider settings, or keep planning manually.';
      });
    }
  }

  Future<void> _recordCameraEntry() {
    return _appendAssistantStatus(
      'Camera entry is ready through meal photo logging. I can still use today context here after the meal is saved.',
    );
  }

  Future<void> _recordVoiceEntry() {
    return _appendAssistantStatus(
      'Voice capture is not available in this build. Type the question here and I will answer with the same today context.',
    );
  }

  Future<void> _appendAssistantStatus(String content) async {
    final createdAt = DateTime.now();
    final message = AiChatMessage(
      id: 'assistant-status-${createdAt.microsecondsSinceEpoch}',
      role: AiChatRole.assistant,
      content: content,
      createdAt: createdAt,
    );
    setState(() {
      _messages = [..._messages, message];
      _errorMessage = null;
    });
    await widget.chatRepository.appendMessages([message]);
    _scrollToBottom();
  }

  Future<void> _clearMessages() async {
    await widget.chatRepository.clearMessages();
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = const [];
      _errorMessage = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.context});

  final AiChatContext context;

  @override
  Widget build(BuildContext buildContext) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppChip(
              label: '${context.proteinRemainingGrams.round()}g protein left',
              icon: Icons.fitness_center,
            ),
            AppChip(
              label: '${context.summary.meals.length} meals logged',
              icon: Icons.restaurant,
            ),
            AppChip(
              label: context.configuration.modeLabel,
              icon: Icons.auto_awesome,
              tone: AppChipTone.accent,
            ),
            if (context.currentSuggestion != null)
              SourceChip(source: context.currentSuggestion!.source),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageRow extends StatelessWidget {
  const _ChatMessageRow({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (!message.isUser) {
      return AiMessageBubble(
        message: message.content,
        actions: message.safetyBoundary == AiChatSafetyBoundary.none
            ? const []
            : [
                AppChip(
                  label: _safetyLabel(message.safetyBoundary),
                  icon: Icons.health_and_safety_outlined,
                  tone: AppChipTone.accent,
                ),
              ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.deepGreen,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              message.content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isSending,
    required this.onSubmitted,
    required this.onCameraPressed,
    required this.onVoicePressed,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSubmitted;
  final VoidCallback onCameraPressed;
  final VoidCallback onVoicePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmSurface,
        border: Border(top: BorderSide(color: AppColors.oat)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppIconActionButton(
              icon: Icons.camera_alt_outlined,
              tooltip: 'Camera',
              onPressed: isSending ? null : onCameraPressed,
            ),
            const SizedBox(width: AppSpacing.xs),
            AppIconActionButton(
              icon: Icons.mic_none,
              tooltip: 'Voice',
              onPressed: isSending ? null : onVoicePressed,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmitted(),
                decoration: const InputDecoration(
                  hintText: 'Ask about today',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadii.md),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SizedBox.square(
              dimension: 56,
              child: FilledButton(
                onPressed: isSending ? null : onSubmitted,
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                child: isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: AppSpacing.sm),
        Text('Thinking'),
      ],
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.peach.withValues(alpha: 0.24),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

String _safetyLabel(AiChatSafetyBoundary boundary) {
  return switch (boundary) {
    AiChatSafetyBoundary.medical => 'Medical boundary',
    AiChatSafetyBoundary.eatingDisorder => 'Safety boundary',
    AiChatSafetyBoundary.uncertainty => 'Uncertain estimate',
    AiChatSafetyBoundary.none => 'Companion answer',
  };
}

String _providerFailureMessage(AiProviderFailureKind kind) {
  return switch (kind) {
    AiProviderFailureKind.missingCredential =>
      'Provider token missing. Add a token in Me or keep planning manually.',
    AiProviderFailureKind.timeout =>
      'Provider timed out. Try again or keep planning manually.',
    AiProviderFailureKind.rateLimited =>
      'Provider rate limit reached. Try again later or keep planning manually.',
    AiProviderFailureKind.malformedResponse =>
      'Provider response was unreadable. Try again or keep planning manually.',
    AiProviderFailureKind.providerUnavailable =>
      'Provider unavailable. Check provider settings or keep planning manually.',
    AiProviderFailureKind.providerError =>
      'Companion response unavailable. Try again, check provider settings, or keep planning manually.',
  };
}
