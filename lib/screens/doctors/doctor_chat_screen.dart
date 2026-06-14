import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/chat_thread.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_design.dart';

class DoctorChatScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final String senderRole;
  final AuthService authService;

  const DoctorChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.senderRole,
    required this.authService,
  });

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  String? _currentUserId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final id = await widget.authService.currentUser();
    if (!mounted) return;
    setState(() => _currentUserId = id);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    if (text.length > 4000) {
      _showMessage('Сообщение слишком длинное');
      return;
    }
    if (widget.chatId.trim().isEmpty) {
      _showMessage('Чат пока не создан. Обновите страницу записей.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(chatId: widget.chatId, text: text);
      _controller.clear();
    } catch (error) {
      _showMessage('Не удалось отправить сообщение: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _chatService.watchMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _stateMessage(
                        icon: Icons.wifi_off_rounded,
                        title: 'Чат недоступен',
                        text:
                            'Проверьте, что backend запущен и вы вошли в аккаунт.',
                      );
                    }

                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return _stateMessage(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Сообщений пока нет',
                        text:
                            'Напишите первое сообщение. Переписка будет видна только вам и собеседнику.',
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;
                        return _messageBubble(message, isMe);
                      },
                    );
                  },
                ),
              ),
              _input(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final subtitle = widget.senderRole == 'doctor'
        ? 'Чат с пациентом'
        : 'Чат с врачом';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.forum_rounded, color: AppColors.blush),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.isEmpty ? 'Переписка' : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateMessage({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SoftCard(
          radius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.blush, size: 38),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(ChatMessage message, bool isMe) {
    final time = DateFormat('HH:mm', 'ru_RU').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.blush : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 5),
            bottomRight: Radius.circular(isMe ? 5 : 18),
          ),
          boxShadow: isMe ? null : AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.ink,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                color:
                    isMe ? Colors.white.withValues(alpha: 0.78) : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: FrostedPanel(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Написать сообщение',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isSending ? AppColors.muted : AppColors.blush,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
