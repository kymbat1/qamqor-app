import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/chat_thread.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_design.dart';
import 'doctor_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final AuthService authService;
  final bool isDoctor;

  const ChatListScreen({
    super.key,
    required this.authService,
    required this.isDoctor,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final title = widget.isDoctor ? 'Чаты с пациентами' : 'Чаты с врачами';
    final subtitle = widget.isDoctor
        ? 'Вопросы после записи и консультации'
        : 'Переписки по вашим записям';

    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: StreamBuilder<List<ChatThread>>(
            stream: _chatService.watchChats(),
            builder: (context, snapshot) {
              final chats = snapshot.data ?? [];
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: _Header(
                        title: title,
                        subtitle: subtitle,
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _StateCard(
                        icon: Icons.wifi_off_rounded,
                        title: 'Чаты недоступны',
                        text: 'Проверьте backend и вход в аккаунт.',
                      ),
                    )
                  else if (chats.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _StateCard(
                        icon: Icons.forum_outlined,
                        title: 'Диалогов пока нет',
                        text: widget.isDoctor
                            ? 'Когда пациент запишется к вам, чат появится здесь.'
                            : 'После записи к врачу чат появится здесь.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final chatIndex = index ~/ 2;
                            if (index.isOdd) return const SizedBox(height: 12);
                            return FadeSlideIn(
                              delayMs: chatIndex * 25,
                              child: _chatCard(chats[chatIndex]),
                            );
                          },
                          childCount: chats.length * 2 - 1,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _chatCard(ChatThread chat) {
    final name = widget.isDoctor ? chat.clientName : chat.doctorName;
    final subtitle = widget.isDoctor
        ? (chat.clientContact.isEmpty ? 'Пациент' : chat.clientContact)
        : (chat.doctorSpecialty.isEmpty ? 'Специалист' : chat.doctorSpecialty);
    final appointmentDate = chat.appointmentStartsAt == null
        ? 'Запись'
        : DateFormat('d MMMM, HH:mm', 'ru_RU').format(chat.appointmentStartsAt!);
    final preview = chat.lastMessage.isEmpty
        ? 'Напишите первое сообщение'
        : chat.lastMessage;

    return SoftCard(
      radius: 24,
      onTap: () => _openChat(chat),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              widget.isDoctor
                  ? Icons.person_outline_rounded
                  : Icons.medical_services_rounded,
              color: AppColors.blush,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm', 'ru_RU').format(chat.updatedAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _appointmentChip(appointmentDate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.plum,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _openChat(ChatThread chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorChatScreen(
          chatId: chat.id,
          title: widget.isDoctor ? chat.clientName : chat.doctorName,
          senderRole: widget.isDoctor ? 'doctor' : 'client',
          authService: widget.authService,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
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
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SoftCard(
          radius: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.blush, size: 42),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
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
}
