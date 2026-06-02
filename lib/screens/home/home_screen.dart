import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/article.dart';
import '../../models/cycle_entry.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../theme/app_design.dart';
import '../ai_assistant/ai_assistant_widget.dart';
import '../articles/article_screen.dart';
import '../calendar/cycle_calendar_screen.dart';
import '../doctors/all_doctors_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final AuthService authService;
  final bool showBottomNavigation;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenDoctors;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    required this.authService,
    this.showBottomNavigation = true,
    this.onOpenCalendar,
    this.onOpenDoctors,
    this.onOpenProfile,
  });

  List<Article> get _articles => const [
        Article(
          title: 'Питание по фазам цикла',
          subtitle: 'Что добавить в рацион, чтобы поддержать энергию',
          bgColor: Color(0xFFFFEAF6),
          accentColor: AppColors.blush,
          icon: Icons.local_dining_outlined,
          content:
              'Цикл влияет на аппетит, энергию и настроение, поэтому питание лучше подстраивать под фазу.\n\nВ первые дни месячных организму часто нужно больше железа и мягкой, теплой еды: супы, гречка, бобовые, рыба, зелень. В фолликулярную фазу обычно легче возвращаться к активности, поэтому хорошо работают белок, овощи и сложные углеводы.\n\nВо второй половине цикла у многих усиливается тяга к сладкому. Это не повод ругать себя. Попробуйте заранее добавить перекусы с белком: йогурт, творог, яйца, орехи, хумус. Так уровень энергии будет стабильнее.',
          author: 'Qamqor Care',
          date: 'Сегодня',
        ),
        Article(
          title: 'Сон и гормоны',
          subtitle: 'Почему режим сна влияет на цикл и настроение',
          bgColor: Color(0xFFE9F8F1),
          accentColor: Color(0xFF3FA178),
          icon: Icons.nights_stay_outlined,
          content:
              'Сон помогает нервной системе восстановиться, а гормональной системе держать более спокойный ритм.\n\nЕсли ложиться в разное время, чаще появляются усталость, тяга к сладкому, раздражительность и ощущение, что тело живет отдельно от вас. Начните с малого: один стабильный ритуал за 30 минут до сна, меньше яркого экрана и стакан воды рядом.\n\nЕсли бессонница повторяется неделями или резко изменилась вместе с циклом, лучше обсудить это со специалистом.',
          author: 'Qamqor Care',
          date: 'На этой неделе',
        ),
        Article(
          title: 'Когда идти к гинекологу',
          subtitle: 'Симптомы, которые лучше не откладывать',
          bgColor: Color(0xFFEAF4FF),
          accentColor: Color(0xFF3D78C2),
          icon: Icons.medical_services_outlined,
          content:
              'Плановый осмотр обычно нужен раз в год, но есть ситуации, когда ждать не стоит.\n\nЗапишитесь к врачу, если боль мешает обычной жизни, месячные стали намного обильнее, цикл резко сбился, появились необычные выделения, зуд, температура или боль после близости.\n\nПриложение помогает заметить повторяющиеся симптомы, но не заменяет диагностику. Хорошая запись в календаре часто экономит время на приеме: врач быстрее увидит динамику.',
          author: 'Врач-редактор',
          date: 'Обновлено',
        ),
        Article(
          title: 'ПМС без паники',
          subtitle: 'Как мягко снизить раздражительность и отеки',
          bgColor: Color(0xFFFFF4E6),
          accentColor: Color(0xFFD47724),
          icon: Icons.self_improvement_outlined,
          content:
              'ПМС не делает вас “сложной”. Это реакция организма на изменения второй половины цикла.\n\nПомогают простые вещи: сон, регулярная еда, меньше соленого вечером, легкая прогулка, теплый душ и честное снижение нагрузки. Если настроение падает очень сильно, появляется тревога или слезы каждый цикл, это тоже медицинский повод для разговора.\n\nОтмечайте симптомы несколько месяцев подряд. Так легче понять, что повторяется, а что было случайным стрессом.',
          author: 'Qamqor Care',
          date: '5 минут чтения',
        ),
        Article(
          title: 'Овуляция: что нормально',
          subtitle: 'Выделения, ощущения и фертильное окно',
          bgColor: Color(0xFFF4ECFF),
          accentColor: Color(0xFF7357C8),
          icon: Icons.spa_outlined,
          content:
              'В дни вокруг овуляции выделения могут стать более прозрачными и тягучими, а либидо и энергия иногда повышаются. У некоторых появляется легкая боль с одной стороны живота.\n\nСамо по себе это часто нормально. Но сильная боль, температура, кровотечение или резкое ухудшение самочувствия требуют консультации.\n\nКалендарь дает прогноз, но тело может сдвигать овуляцию из-за стресса, болезни, перелетов и недосыпа.',
          author: 'Qamqor Care',
          date: 'Практика',
        ),
        Article(
          title: 'Контрацепция без мифов',
          subtitle: 'Как подготовиться к разговору с врачом',
          bgColor: Color(0xFFFFEEF2),
          accentColor: AppColors.plum,
          icon: Icons.health_and_safety_outlined,
          content:
              'Подбор контрацепции зависит от здоровья, возраста, цикла, мигреней, давления, привычек и планов на беременность.\n\nПеред приемом полезно записать: дату последних месячных, регулярность цикла, хронические заболевания, лекарства, опыт прошлой контрацепции и вопросы, которые хочется задать.\n\nНе выбирайте гормональные препараты по совету знакомых. То, что подошло одному человеку, может не подойти другому.',
          author: 'Врач-редактор',
          date: 'Важно',
        ),
      ];

  Future<Map<String, dynamic>?> fetchUserData() {
    return authService.currentUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GradientPage(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: fetchUserData(),
          builder: (context, snapshot) {
            final rawName = snapshot.data?['name'];
            final name = rawName is String && rawName.trim().isNotEmpty
                ? rawName.trim()
                : 'девушка';
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: AppColors.cream,
                  surfaceTintColor: AppColors.cream,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  toolbarHeight: 88,
                  title: _buildTopBar(context, name),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(child: _buildCycleHero(context)),
                        const SizedBox(height: 14),
                        FadeSlideIn(delayMs: 50, child: _buildTodayPlan(context)),
                        const SizedBox(height: 18),
                        FadeSlideIn(
                          delayMs: 80,
                          child: _buildQuickActions(context),
                        ),
                        const SizedBox(height: 26),
                        FadeSlideIn(
                          delayMs: 120,
                          child: _sectionTitle(
                            'Ассистент',
                            'Можно спросить анонимно и спокойно',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const FadeSlideIn(
                          delayMs: 140,
                          child: AiAssistantWidget(),
                        ),
                        const SizedBox(height: 26),
                        FadeSlideIn(
                          delayMs: 160,
                          child: _sectionTitle(
                            'Полезные статьи',
                            'Коротко, понятно и без лишней тревоги',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delayMs: 190,
                          child: _buildFeaturedArticle(context),
                        ),
                        const SizedBox(height: 14),
                        FadeSlideIn(
                          delayMs: 220,
                          child: _buildArticleGrid(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar:
          showBottomNavigation ? _buildBottomNavigation(context) : null,
    );
  }

  Widget _buildTopBar(BuildContext context, String name) {
    final date = DateFormat('d MMMM', 'ru_RU').format(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Привет, $name',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Сегодня $date · забота о себе без спешки',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Уведомления',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  Widget _buildCycleHero(BuildContext context) {
    return StreamBuilder<Map<DateTime, CycleEntry>>(
      stream: CalendarService().watchEntries(),
      builder: (context, snapshot) {
        final summary = _HomeCycleSummary.fromEntries(snapshot.data ?? {});

        return GestureDetector(
          onTap: onOpenCalendar ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CycleCalendarScreen()),
                );
              },
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blush.withOpacity(0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.water_drop_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        summary.badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  summary.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: summary.progress,
                    minHeight: 9,
                    color: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.26),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _heroMetric(
                        summary.nextPeriodText,
                        'следующие месячные',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _heroMetric(
                        summary.phaseText,
                        'текущая фаза',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroMetric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPlan(BuildContext context) {
    final items = [
      _TodayItem(Icons.edit_calendar_outlined, 'Отметить цикл', '1 минута'),
      _TodayItem(Icons.water_drop_outlined, 'Вода и сон', 'мягкий режим'),
      _TodayItem(Icons.event_available_outlined, 'Запись к врачу', 'при необходимости'),
    ];

    return SoftCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'План на сегодня',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(item.icon, color: AppColors.blush, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    item.note,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            icon: Icons.calendar_month_outlined,
            label: 'Календарь',
            color: AppColors.sky,
            onTap: onOpenCalendar ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CycleCalendarScreen()),
                  );
                },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickAction(
            icon: Icons.event_available_outlined,
            label: 'Запись',
            color: AppColors.lavender,
            onTap: onOpenDoctors ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllDoctorsScreen()),
                  );
                },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickAction(
            icon: Icons.person_outline,
            label: 'Профиль',
            color: AppColors.mint,
            onTap: onOpenProfile ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(authService: authService),
                    ),
                  );
                },
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      radius: 22,
      color: Colors.white.withOpacity(0.94),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.plum),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedArticle(BuildContext context) {
    final article = _articles.first;
    return SoftCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      color: Colors.white,
      onTap: () => _openArticle(context, article),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 96,
            decoration: BoxDecoration(
              color: article.bgColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(article.icon, color: article.accentColor, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выбор редакции',
                  style: TextStyle(
                    color: AppColors.blush,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  article.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

  Widget _buildArticleGrid(BuildContext context) {
    final articles = _articles.skip(1).toList();
    return Column(
      children: articles
          .map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _articleTile(context, article),
            ),
          )
          .toList(),
    );
  }

  Widget _articleTile(BuildContext context, Article article) {
    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.all(16),
      color: article.bgColor,
      onTap: () => _openArticle(context, article),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.76),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(article.icon, color: article.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: article.accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  article.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink.withOpacity(0.66),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.muted, size: 15),
        ],
      ),
    );
  }

  void _openArticle(BuildContext context, Article article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleScreen(article: article)),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: FrostedPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(Icons.home_rounded, true, () {}),
            _navIcon(Icons.calendar_month_rounded, false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CycleCalendarScreen()),
              );
            }),
            _navIcon(Icons.event_available_rounded, false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllDoctorsScreen()),
              );
            }),
            _navIcon(Icons.person_rounded, false, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(authService: authService),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 48,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AppColors.blush : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : AppColors.muted,
        ),
      ),
    );
  }
}

class _TodayItem {
  final IconData icon;
  final String title;
  final String note;

  const _TodayItem(this.icon, this.title, this.note);
}

class _HomeCycleSummary {
  static const int cycleLength = 28;
  final int? cycleDay;

  _HomeCycleSummary({required this.cycleDay});

  factory _HomeCycleSummary.fromEntries(Map<DateTime, CycleEntry> entries) {
    final today = CycleEntry.normalizedDay(DateTime.now());
    DateTime? latest;

    for (final entry in entries.values) {
      if (!entry.isPeriodDay) continue;

      final day = CycleEntry.normalizedDay(entry.date);
      if (day.isAfter(today)) continue;
      if (latest == null || day.isAfter(latest)) latest = day;
    }

    return _HomeCycleSummary(
      cycleDay: latest == null ? null : today.difference(latest).inDays + 1,
    );
  }

  String get badge => cycleDay == null ? 'Нет отметок' : 'День $cycleDay';

  String get title {
    if (cycleDay == null) return 'Начните цикл';
    if (cycleDay! <= 5) return 'Месячные';
    if (cycleDay! >= 12 && cycleDay! <= 16) return 'Овуляция';
    if (cycleDay! >= 22) return 'ПМС-фаза';
    return 'Баланс';
  }

  String get subtitle {
    if (cycleDay == null) {
      return 'Отметьте первый день месячных, и приложение начнет считать прогнозы автоматически.';
    }
    if (cycleDay! <= 5) {
      return 'Отмечайте самочувствие, интенсивность и симптомы, чтобы видеть понятную историю цикла.';
    }
    if (cycleDay! >= 12 && cycleDay! <= 16) {
      return 'Вероятно фертильное окно. Отслеживайте ощущения и добавляйте заметки в календарь.';
    }
    if (cycleDay! >= 22) {
      return 'Поддержите себя мягким режимом, водой и сном. Заметки помогут увидеть повторяющиеся симптомы.';
    }
    return 'Цикл идет спокойно. Можно отмечать любые изменения и готовиться к следующей фазе.';
  }

  String get phaseText {
    if (cycleDay == null) return 'не задана';
    if (cycleDay! <= 5) return 'менструальная';
    if (cycleDay! >= 12 && cycleDay! <= 16) return 'овуляция';
    if (cycleDay! >= 22) return 'лютеиновая';
    return 'фолликулярная';
  }

  String get nextPeriodText {
    if (cycleDay == null) return '--';
    final daysLeft = (cycleLength - cycleDay!).clamp(0, cycleLength);
    if (daysLeft == 0) return 'скоро';
    return 'через $daysLeft дн.';
  }

  double get progress {
    if (cycleDay == null) return 0.08;
    return (cycleDay! / cycleLength).clamp(0.0, 1.0).toDouble();
  }
}
