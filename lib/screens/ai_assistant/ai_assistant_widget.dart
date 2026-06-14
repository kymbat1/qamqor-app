import 'package:flutter/material.dart';

import '../../services/ai_assistant_service.dart';
import '../../theme/app_design.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class AiAssistantWidget extends StatefulWidget {
  const AiAssistantWidget({super.key});

  @override
  State<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends State<AiAssistantWidget> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiAssistantService _assistantService = AiAssistantService();

  static const double _widgetHeight = 420;

  bool _isResponding = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Здравствуйте. Я ассистент Qamqor. Я учитываю ваши отметки цикла из календаря, симптомы и фазу цикла. Спросите, например: “сегодня лучше кардио или силовая?”',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    final value = text.trim();
    if (value.isEmpty || _isResponding) {
      return;
    }

    _textController.clear();
    setState(() {
      _isResponding = true;
      _messages.add(
        ChatMessage(text: value, isUser: true, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();

    try {
      final response = await _assistantService.ask(question: value);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: _friendlyError(error),
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
        _scrollToBottom();
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('user-not-authenticated') ||
        text.contains('missing bearer') ||
        text.contains('после входа')) {
      return 'Я смогу учитывать календарь после входа в аккаунт. Войдите и повторите вопрос.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 28,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: _widgetHeight,
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: AppColors.lavender),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_isResponding ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isResponding && index == _messages.length) {
                    return _typingBubble();
                  }
                  return _messageBubble(_messages[index]);
                },
              ),
            ),
            _textComposer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              color: AppColors.blush,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ИИ-ассистент',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Учитывает календарь цикла и симптомы',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isResponding ? AppColors.coral : AppColors.mint,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final background = message.isError
        ? const Color(0xFFFFE5E5)
        : isUser
            ? AppColors.blush
            : AppColors.lavender;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.ink,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lavender,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.blush,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Анализирую цикл...',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 3,
              enabled: !_isResponding,
              onSubmitted: _handleSubmitted,
              decoration: const InputDecoration(
                hintText: 'Напишите вопрос...',
              ),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isResponding
                ? null
                : () => _handleSubmitted(_textController.text),
            style: IconButton.styleFrom(backgroundColor: AppColors.blush),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
