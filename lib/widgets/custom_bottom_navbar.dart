import 'package:flutter/material.dart';

import '../theme/app_design.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTabTapped;

  const CustomBottomNavigationBar({
    super.key,
    this.currentIndex = 0,
    this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: FrostedPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        radius: 28,
        child: Row(
          children: [
            _buildNavItem(Icons.home_rounded, 'Главная', 0),
            _buildNavItem(Icons.calendar_month_rounded, 'Цикл', 1),
            _buildNavItem(Icons.event_available_rounded, 'Запись', 2),
            _buildNavItem(Icons.person_rounded, 'Профиль', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabTapped?.call(index),
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
}
