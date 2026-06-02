import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_design.dart';
import 'auth/login_screen.dart';
import 'calendar/cycle_calendar_screen.dart';
import 'doctors/doctor_dashboard_screen.dart';
import 'doctors/doctor_list_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

class MainWrapper extends StatefulWidget {
  final AuthService authService;

  const MainWrapper({super.key, required this.authService});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isDoctor = false;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        authService: widget.authService,
        showBottomNavigation: false,
        onOpenCalendar: () => _onItemTapped(1),
        onOpenDoctors: () => _onItemTapped(2),
        onOpenProfile: () => _onItemTapped(3),
      ),
      const CycleCalendarContent(),
      const DoctorListScreen(),
      ProfileScreen(authService: widget.authService),
    ];
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final user = await widget.authService.currentUser();
      final role = await widget.authService.currentUserRole();
      setState(() {
        _isLoggedIn = user?.isNotEmpty ?? false;
        _isDoctor = role == 'doctor';
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: GradientPage(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_isLoggedIn) {
      return LoginScreen(authService: widget.authService);
    }

    if (_isDoctor) {
      return DoctorDashboardScreen(authService: widget.authService);
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: FrostedPanel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          radius: 28,
          child: Row(
            children: [
              _navItem(Icons.home_rounded, 'Главная', 0),
              _navItem(Icons.calendar_month_rounded, 'Цикл', 1),
              _navItem(Icons.event_available_rounded, 'Запись', 2),
              _navItem(Icons.person_rounded, 'Профиль', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blush : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.muted,
                size: 22,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
