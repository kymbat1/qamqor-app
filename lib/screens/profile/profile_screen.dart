import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../auth/login_screen.dart';
import 'access_code_screen.dart';
import 'chart_report_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'my_appointments_screen.dart';
import 'period_ovulation_screen.dart';
import 'reminder_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AuthService authService;

  const ProfileScreen({super.key, required this.authService});

  Future<Map<String, dynamic>> fetchUserData() async {
    final userData = await authService.currentUserData();
    return userData ??
        {
          'name': 'Новый пользователь',
          'email': 'user@auth.com',
        };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: fetchUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = snapshot.data ?? {};
              final name = userData['name']?.toString() ?? 'Ваше имя';
              final contact =
                  userData['email'] ?? userData['phone'] ?? 'user@example.com';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: _profileHero(name, contact.toString(), userData),
                    ),
                    const SizedBox(height: 18),
                    FadeSlideIn(delayMs: 80, child: _menu(context)),
                    const SizedBox(height: 18),
                    FadeSlideIn(delayMs: 120, child: _logoutButton(context)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileHero(
    String name,
    String contact,
    Map<String, dynamic> userData,
  ) {
    final cycleEntries = userData['cycleEntries'];
    final cycleDays = cycleEntries is Map ? cycleEntries.length : 0;
    final city = userData['city']?.toString();
    final role = userData['role'] == 'doctor' ? 'врач' : 'клиент';

    return SoftCard(
      radius: 32,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _metric(cycleDays.toString(), 'дней'),
              _metric(role, 'роль'),
              _metric(
                city?.isNotEmpty == true ? city! : 'не указан',
                'город',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lavender,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final items = [
      _ProfileItem(Icons.edit_outlined, 'Редактировать профиль', () {
        return EditProfileScreen(authService: authService);
      }),
      _ProfileItem(Icons.event_available_outlined, 'Мои записи', () {
        return MyAppointmentsScreen(authService: authService);
      }),
      _ProfileItem(Icons.leaderboard_outlined, 'Графики и отчеты', () {
        return const ChartReportScreen();
      }),
      _ProfileItem(Icons.favorite_border, 'Цикл и овуляция', () {
        return const PeriodOvulationScreen();
      }),
      _ProfileItem(Icons.lock_outline_rounded, 'Код доступа', () {
        return const AccessCodeScreen();
      }),
      _ProfileItem(Icons.notifications_none_rounded, 'Напоминания', () {
        return const ReminderScreen();
      }),
      _ProfileItem(Icons.help_outline, 'Помощь', () {
        return const HelpScreen();
      }),
    ];

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: items.map((item) {
          return ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: AppColors.blush),
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item.builder()),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        await authService.signOut();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(authService: authService),
          ),
          (_) => false,
        );
      },
      icon: const Icon(Icons.logout),
      label: const Text('Выйти'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blush,
        side: BorderSide(color: AppColors.blush.withOpacity(0.28)),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String title;
  final Widget Function() builder;

  const _ProfileItem(this.icon, this.title, this.builder);
}
