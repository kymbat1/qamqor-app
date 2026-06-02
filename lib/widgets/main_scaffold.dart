import 'package:flutter/material.dart';

import '../screens/calendar/cycle_calendar_screen.dart';
import '../screens/doctors/doctor_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_design.dart';

class MainScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final AuthService authService;

  MainScaffold({
    super.key,
    required this.body,
    this.currentIndex = 0,
    AuthService? authService,
  }) : authService = authService ?? AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: FrostedPanel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          radius: 28,
          child: Row(
            children: [
              _buildNavItem(context, Icons.home_rounded, 'Главная', 0, () {
                _replace(context, HomeScreen(authService: authService));
              }),
              _buildNavItem(context, Icons.calendar_month_rounded, 'Цикл', 1,
                  () {
                _replace(context, const CycleCalendarScreen());
              }),
              _buildNavItem(context, Icons.event_available_rounded, 'Запись', 2,
                  () {
                _replace(context, const DoctorListScreen());
              }),
              _buildNavItem(context, Icons.person_rounded, 'Профиль', 3, () {
                _replace(context, ProfileScreen(authService: authService));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    VoidCallback onTap,
  ) {
    final isActive = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? AppColors.blush : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? Colors.white : AppColors.muted),
              if (isActive) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _replace(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
