import 'package:flutter/material.dart';

import '../../theme/app_design.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
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

  static const double _widgetHeight = 400;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Здравствуйте. Я анонимный помощник Qamqor. Могу подсказать, что отметить в календаре, когда лучше записаться к врачу и как подготовиться к приему.',
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

  void _handleSubmitted(String text) {
    final value = text.trim();
    if (value.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: value, isUser: true, timestamp: DateTime.now()),
      );
    });

    _simulateAiResponse(value);
    _scrollToBottom();
  }

  void _simulateAiResponse(String userText) {
    final lower = userText.toLowerCase();
    final response = _responseFor(lower);

    Future.delayed(const Duration(milliseconds: 650), () {
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
      _scrollToBottom();
    });
  }

  String _responseFor(String text) {
    if (text.contains('цикл') ||
        text.contains('месяч') ||
        text.contains('период')) {
      return 'Если вопрос про цикл, лучше отметить первый день месячных, интенсивность, боль, настроение и необычные симптомы. Если цикл резко изменился или боль сильная, стоит записаться к врачу.';
    }
    if (text.contains('овуляц') || text.contains('беремен')) {
      return 'Прогноз овуляции в приложении ориентировочный. На него влияют стресс, сон, болезнь и перелеты. Для точного планирования беременности лучше обсудить ситуацию с гинекологом или репродуктологом.';
    }
    if (text.contains('боль') ||
        text.contains('кров') ||
        text.contains('температур')) {
      return 'Если боль сильная, есть температура, необычное кровотечение или резкое ухудшение самочувствия, не откладывайте консультацию врача. В разделе “Запись” можно выбрать специалиста.';
    }
    if (text.contains('врач') || text.contains('запис')) {
      return 'В разделе “Запись” можно выбрать специалиста по цене, опыту, рейтингу и локации. После записи появится чат с врачом.';
    }
    return 'Я могу помочь с вопросами про цикл, симптомы, подготовку к врачу и записи. Опишите, что вас беспокоит, и я подскажу следующий безопасный шаг.';
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
                itemCount: _messages.length,
                itemBuilder: (_, index) => _messageBubble(_messages[index]),
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
            child: const Icon(Icons.psychology_outlined,
                color: AppColors.blush),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Анонимный ассистент',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Быстрые подсказки по здоровью',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.blush : AppColors.lavender,
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
              onSubmitted: _handleSubmitted,
              decoration: const InputDecoration(
                hintText: 'Напишите вопрос...',
              ),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _handleSubmitted(_textController.text),
            style: IconButton.styleFrom(backgroundColor: AppColors.blush),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
