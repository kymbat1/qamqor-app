import 'package:flutter/material.dart';

import '../../theme/app_design.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<Map<String, String>> _faqItems = [
    {
      'question': 'Как правильно начать цикл?',
      'answer':
          'Открой вкладку “Цикл”, выбери первый день месячных и нажми “Отметить”. После этого приложение начнет считать день цикла и прогнозы.',
    },
    {
      'question': 'Почему прогнозы могут отличаться?',
      'answer':
          'Прогноз строится по твоим отметкам. Чем больше циклов отмечено, тем понятнее становятся средняя длина, симптомы и повторяющиеся дни.',
    },
    {
      'question': 'Как изменить данные профиля?',
      'answer':
          'Открой “Редактировать профиль”, измени имя, город, дату рождения или заметки и нажми “Сохранить”.',
    },
    {
      'question': 'Как связаться с врачом?',
      'answer':
          'После записи к врачу чат появится в разделе “Мои записи”. Оттуда можно открыть переписку.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  title: 'Помощь',
                  subtitle: 'Ответы и поддержка',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(child: _supportHero(context)),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 80, child: _faqCard(context)),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 130, child: _contacts(context)),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'Qamqor Care v1.0.0',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _supportHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Если что-то не получается, начни с быстрых ответов ниже.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqCard(BuildContext context) {
    return SoftCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: _faqItems.map((item) {
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.help_outline_rounded, color: AppColors.blush),
              iconColor: AppColors.blush,
              collapsedIconColor: AppColors.muted,
              title: Text(
                item['question']!,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    item['answer']!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _contacts(BuildContext context) {
    return Column(
      children: [
        _contactCard(
          icon: Icons.email_outlined,
          title: 'Email поддержка',
          subtitle: 'Ответим на вопрос по приложению',
          onTap: () => _showMessage(context, 'support@qamqor.app'),
        ),
        const SizedBox(height: 12),
        _contactCard(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Чат поддержки',
          subtitle: 'Скоро будет доступен внутри приложения',
          onTap: () => _showMessage(context, 'Чат поддержки в разработке'),
        ),
      ],
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SoftCard(
      radius: 26,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.blush),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
