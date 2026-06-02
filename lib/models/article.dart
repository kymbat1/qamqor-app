import 'package:flutter/material.dart';

class Article {
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color accentColor;
  final IconData icon;
  final String content;
  final String author;
  final String date;
  final String imageName;

  const Article({
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.accentColor,
    required this.icon,
    required this.content,
    this.author = 'Qamqor Care',
    this.date = 'Сегодня',
    this.imageName = 'article_header_default.png',
  });
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
