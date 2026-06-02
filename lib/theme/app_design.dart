import 'dart:ui';

import 'package:flutter/material.dart';

class AppColors {
  static const blush = Color(0xFFFF1493);
  static const coral = Color(0xFFFF69B4);
  static const plum = Color(0xFFC71585);
  static const ink = Color(0xFF241B2F);
  static const muted = Color(0xFF837385);
  static const cream = Color(0xFFFFF7FB);
  static const lavender = Color(0xFFFFEAF6);
  static const mint = Color(0xFFE9F8F1);
  static const sky = Color(0xFFEAF4FF);
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: AppColors.blush.withOpacity(0.12),
      blurRadius: 28,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.plum.withOpacity(0.12),
      blurRadius: 36,
      offset: const Offset(0, 20),
    ),
  ];
}

class GradientPage extends StatelessWidget {
  final Widget child;

  const GradientPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: child,
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.soft,
        border: Border.all(color: Colors.white.withOpacity(0.72)),
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
            boxShadow: AppShadows.floating,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.55 : 1,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.blush.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.beginOffset = const Offset(0, 0.08),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 520 + delayMs),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        final eased = Curves.easeOutCubic.transform(value);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * (1 - eased) * 100,
              beginOffset.dy * (1 - eased) * 100,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
