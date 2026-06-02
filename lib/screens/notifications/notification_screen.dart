import 'package:flutter/material.dart';

import '../../theme/app_design.dart';

class AppNotification {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const AppNotification({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

final List<AppNotification> dummyNotifications = [
  const AppNotification(
    title: 'Фертильное окно',
    subtitle: 'Сегодня может быть удачный день для отслеживания ощущений.',
    icon: Icons.favorite_border_rounded,
    bgColor: AppColors.lavender,
    iconColor: AppColors.blush,
  ),
  const AppNotification(
    title: 'Пора отметить самочувствие',
    subtitle: 'Добавьте симптомы, настроение или заметку в календарь.',
    icon: Icons.edit_calendar_outlined,
    bgColor: AppColors.sky,
    iconColor: Color(0xFF3D78C2),
  ),
  const AppNotification(
    title: 'Мягкий режим',
    subtitle: 'Сон, вода и спокойная нагрузка помогут пройти день легче.',
    icon: Icons.self_improvement_rounded,
    bgColor: AppColors.mint,
    iconColor: Color(0xFF3FA178),
  ),
];

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientPage(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.cream,
                surfaceTintColor: AppColors.cream,
                elevation: 0,
                pinned: true,
                leading: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: const Text(
                  'Уведомления',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final itemIndex = index ~/ 2;
                      if (index.isOdd) return const SizedBox(height: 12);
                      return _notificationCard(
                        context,
                        dummyNotifications[itemIndex],
                      );
                    },
                    childCount: dummyNotifications.length * 2 - 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationCard(
    BuildContext context,
    AppNotification notification,
  ) {
    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetails(context, notification),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: notification.bgColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(notification.icon, color: notification.iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.25,
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

  void _showDetails(BuildContext context, AppNotification notification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Icon(notification.icon, color: notification.iconColor, size: 34),
                const SizedBox(height: 12),
                Text(
                  notification.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
