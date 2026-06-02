import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../models/doctor.dart';
import '../../theme/app_design.dart';
import 'doctor_detail_screen.dart';

const List<String> _specialties = [
  'Все',
  'Гинеколог',
  'Репродуктолог',
  'Акушер',
  'Маммолог',
  'Эндокринолог',
  'УЗИ',
  'Психолог',
  'Дерматолог',
  'Диетолог',
  'Онкогинеколог',
];

enum _SortMode {
  rating,
  priceAsc,
  priceDesc,
  experience,
  nearest,
}

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String _searchQuery = '';
  String _cityQuery = '';
  String _specialty = 'Все';
  RangeValues _priceRange = const RangeValues(0, 30000);
  bool _onlyOnline = false;
  bool _locating = false;
  bool _locationDenied = false;
  Position? _userPosition;
  Doctor? _selectedMapDoctor;
  _SortMode _sortMode = _SortMode.rating;

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Stream<List<Doctor>> _watchDoctors() {
    return FirebaseFirestore.instance
        .collection('doctor_profiles')
        .snapshots()
        .map((snapshot) {
      final profiles = snapshot.docs
          .map((doc) => Doctor.fromJson(doc.data(), doc.id))
          .where((doctor) => doctor.name.trim().isNotEmpty)
          .toList();
      final ids = profiles.map((doctor) => doctor.id).toSet();
      final seeds = dummyDoctors.where((doctor) => !ids.contains(doctor.id));
      return [...profiles, ...seeds];
    });
  }

  List<Doctor> _applyFilters(List<Doctor> doctors) {
    final query = _searchQuery.trim().toLowerCase();
    final city = _cityQuery.trim().toLowerCase();
    final result = doctors.where((doctor) {
      final searchable = [
        doctor.name,
        doctor.specialty,
        doctor.hospital,
        doctor.city,
        doctor.address,
        doctor.description,
      ].join(' ').toLowerCase();

      final matchesQuery = query.isEmpty || searchable.contains(query);
      final matchesCity = city.isEmpty || doctor.city.toLowerCase().contains(city);
      final matchesSpecialty = _specialty == 'Все' ||
          doctor.specialty.toLowerCase().contains(_specialty.toLowerCase());
      final matchesPrice = doctor.consultationFee >= _priceRange.start &&
          doctor.consultationFee <= _priceRange.end;
      final matchesOnline = !_onlyOnline || doctor.isOnline;

      return matchesQuery &&
          matchesCity &&
          matchesSpecialty &&
          matchesPrice &&
          matchesOnline;
    }).toList();

    result.sort((a, b) {
      switch (_sortMode) {
        case _SortMode.priceAsc:
          return a.consultationFee.compareTo(b.consultationFee);
        case _SortMode.priceDesc:
          return b.consultationFee.compareTo(a.consultationFee);
        case _SortMode.experience:
          return b.yearsOfExperience.compareTo(a.yearsOfExperience);
        case _SortMode.nearest:
          final distanceA = _distanceKm(a) ?? double.infinity;
          final distanceB = _distanceKm(b) ?? double.infinity;
          final distanceCompare = distanceA.compareTo(distanceB);
          if (distanceCompare != 0) return distanceCompare;
          return _cityPriority(a).compareTo(_cityPriority(b));
        case _SortMode.rating:
          final ratingCompare = b.rating.compareTo(a.rating);
          if (ratingCompare != 0) return ratingCompare;
          return b.reviewCount.compareTo(a.reviewCount);
      }
    });

    return result;
  }

  int _cityPriority(Doctor doctor) {
    if (_cityQuery.trim().isEmpty) return 1;
    return doctor.city.toLowerCase().contains(_cityQuery.trim().toLowerCase())
        ? 0
        : 1;
  }

  double? _distanceKm(Doctor doctor) {
    final position = _userPosition;
    if (position == null) return null;
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          doctor.latitude,
          doctor.longitude,
        ) /
        1000;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'kk_KZ',
      symbol: '₸',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String get _sortLabel {
    switch (_sortMode) {
      case _SortMode.priceAsc:
        return 'Цена ↑';
      case _SortMode.priceDesc:
        return 'Цена ↓';
      case _SortMode.experience:
        return 'Опыт';
      case _SortMode.nearest:
        return 'Ближе';
      case _SortMode.rating:
        return 'Рейтинг';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: StreamBuilder<List<Doctor>>(
            stream: _watchDoctors(),
            builder: (context, snapshot) {
              final allDoctors = snapshot.data ?? dummyDoctors;
              final doctors = _applyFilters(allDoctors);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeSlideIn(child: _header(allDoctors.length)),
                          const SizedBox(height: 18),
                          FadeSlideIn(delayMs: 70, child: _searchAndFilter()),
                          const SizedBox(height: 12),
                          FadeSlideIn(delayMs: 90, child: _locationPanel()),
                          const SizedBox(height: 14),
                          FadeSlideIn(delayMs: 120, child: _specialtyChips()),
                          const SizedBox(height: 14),
                          FadeSlideIn(delayMs: 160, child: _activeFilters()),
                          const SizedBox(height: 14),
                          FadeSlideIn(delayMs: 190, child: _mapCard(doctors)),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (doctors.isEmpty)
                    SliverFillRemaining(child: _emptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeSlideIn(
                                delayMs: index * 24,
                                child: _doctorCard(doctors[index]),
                              ),
                            );
                          },
                          childCount: doctors.length,
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

  Widget _header(int total) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Запись',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$total специалистов, клиники на карте и онлайн-прием',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _searchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: const InputDecoration(
              hintText: 'Врач, клиника или специализация',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.blush),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _roundAction(
          icon: Icons.tune_rounded,
          tooltip: 'Фильтр',
          onTap: _showFilterSheet,
        ),
      ],
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.soft,
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _locationPanel() {
    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      color: Colors.white.withOpacity(0.94),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => setState(() => _cityQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Укажите город при поиске',
                    prefixIcon:
                        Icon(Icons.location_city_rounded, color: AppColors.blush),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _roundAction(
                icon: _locating
                    ? Icons.hourglass_top_rounded
                    : Icons.my_location_rounded,
                tooltip: 'Определить местоположение',
                onTap: _locating ? () {} : _detectLocation,
              ),
            ],
          ),
          if (_locationDenied)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.plum, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Геолокация не разрешена. Укажите город вручную, чтобы найти ближайших специалистов.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _specialtyChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _specialties.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _specialties[index];
          final selected = item == _specialty;
          return ChoiceChip(
            label: Text(item),
            selected: selected,
            onSelected: (_) => setState(() => _specialty = item),
            selectedColor: AppColors.blush,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: selected ? AppColors.blush : Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _activeFilters() {
    return Row(
      children: [
        Expanded(
          child: _filterToggle(
            icon: Icons.wifi_tethering_rounded,
            label: 'Онлайн',
            value: _onlyOnline,
            onTap: () => setState(() => _onlyOnline = !_onlyOnline),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterToggle(
            icon: Icons.sort_rounded,
            label: _sortLabel,
            value: true,
            onTap: _showFilterSheet,
          ),
        ),
      ],
    );
  }

  Widget _filterToggle({
    required IconData icon,
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: value ? AppColors.lavender : Colors.white.withOpacity(0.9),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: value ? AppColors.blush : AppColors.muted, size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: value ? AppColors.plum : AppColors.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCard(List<Doctor> doctors) {
    final visibleDoctors = _mapDoctors(doctors).take(8).toList();
    if (visibleDoctors.isEmpty) return const SizedBox.shrink();
    final selectedDoctor = _selectedMapDoctor ?? visibleDoctors.first;
    final cities = _availableCities(doctors);

    return SoftCard(
      radius: 28,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Карта клиник',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEmbeddedMap(doctors),
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Развернуть'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _cityMapChips(cities),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _mapBackground()),
                      ...visibleDoctors.map(
                        (doctor) => _clinicMarker(
                          doctor,
                          constraints.maxWidth,
                          190,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _doctorAvatar(selectedDoctor, size: 42, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDoctor.hospital,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${selectedDoctor.city}, ${selectedDoctor.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openDoctor(selectedDoctor),
                child: const Text('Записаться'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _availableCities(List<Doctor> doctors) {
    final cities = doctors
        .map((doctor) => doctor.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Все города', ...cities];
  }

  List<Doctor> _mapDoctors(List<Doctor> doctors) {
    final city = _cityQuery.trim().toLowerCase();
    if (city.isEmpty) return doctors;
    return doctors
        .where((doctor) => doctor.city.toLowerCase().contains(city))
        .toList();
  }

  Widget _cityMapChips(List<String> cities, {VoidCallback? afterChanged}) {
    final current = _cityQuery.trim().isEmpty ? 'Все города' : _cityQuery.trim();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final city = cities[index];
          final selected = city == current ||
              (city != 'Все города' &&
                  current.toLowerCase() == city.toLowerCase());
          return ChoiceChip(
            label: Text(city),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _cityQuery = city == 'Все города' ? '' : city;
                _cityController.text = _cityQuery;
                _selectedMapDoctor = null;
              });
              afterChanged?.call();
            },
            selectedColor: AppColors.blush,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected ? AppColors.blush : AppColors.lavender,
            ),
          );
        },
      ),
    );
  }

  Widget _mapBackground() {
    return CustomPaint(
      painter: _ClinicMapPainter(),
      child: Container(color: const Color(0xFFFFEEF7)),
    );
  }

  Widget _clinicMarker(
    Doctor doctor,
    double width,
    double height, {
    bool compact = false,
  }) {
    final position = _markerOffset(doctor, width, height);
    final selected = doctor.id == (_selectedMapDoctor?.id ?? '');
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: () => setState(() => _selectedMapDoctor = doctor),
        onDoubleTap: compact ? () => _showEmbeddedMap([doctor]) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 44 : 36,
          height: selected ? 44 : 36,
          decoration: BoxDecoration(
            color: selected ? AppColors.plum : AppColors.blush,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Offset _markerOffset(Doctor doctor, double width, double height) {
    final city = _cityQuery.trim().toLowerCase();
    final filteredDoctors = city.isEmpty
        ? dummyDoctors
        : dummyDoctors
            .where((item) => item.city.toLowerCase().contains(city))
            .toList();
    final source = filteredDoctors.isEmpty ? dummyDoctors : filteredDoctors;
    final minLat = source.map((doctor) => doctor.latitude).reduce(math.min);
    final maxLat = source.map((doctor) => doctor.latitude).reduce(math.max);
    final minLng = source.map((doctor) => doctor.longitude).reduce(math.min);
    final maxLng = source.map((doctor) => doctor.longitude).reduce(math.max);
    final latRange = math.max(0.01, maxLat - minLat);
    final lngRange = math.max(0.01, maxLng - minLng);
    final x = ((doctor.longitude - minLng) / lngRange) * (width - 52) + 8;
    final y = ((maxLat - doctor.latitude) / latRange) * (height - 52) + 8;
    return Offset(
      (x.clamp(8, width - 46) as num).toDouble(),
      (y.clamp(8, height - 46) as num).toDouble(),
    );
  }

  void _showEmbeddedMap(List<Doctor> doctors) {
    final allDoctors = doctors.length == 1 ? doctors : _mapDoctors(doctors);
    if (allDoctors.isEmpty) {
      _showMessage('В выбранном городе клиник пока нет');
      return;
    }
    _selectedMapDoctor ??= allDoctors.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentDoctors =
                doctors.length == 1 ? doctors : _mapDoctors(doctors);
            final selectedDoctor = _selectedMapDoctor ??
                (currentDoctors.isNotEmpty ? currentDoctors.first : allDoctors.first);

            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              minChildSize: 0.52,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Встроенная карта',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Выберите город и нажмите на маркер клиники. Карта работает внутри приложения.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (doctors.length != 1)
                        _cityMapChips(
                          _availableCities(doctors),
                          afterChanged: () => setModalState(() {}),
                        ),
                      if (doctors.length != 1) const SizedBox(height: 14),
                      SizedBox(
                        height: 360,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _mapBackground()),
                                  ...currentDoctors.map((doctor) {
                                    final offset = _markerOffset(
                                      doctor,
                                      constraints.maxWidth,
                                      360,
                                    );
                                    return Positioned(
                                      left: offset.dx,
                                      top: offset.dy,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(
                                            () => _selectedMapDoctor = doctor,
                                          );
                                          setModalState(() {});
                                        },
                                        child: _largeMarker(
                                          doctor,
                                          doctor.id == selectedDoctor.id,
                                        ),
                                      ),
                                    );
                                  }),
                                  Positioned(
                                    left: 14,
                                    bottom: 14,
                                    child: _mapLegend(currentDoctors.length),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _mapDoctorPreview(selectedDoctor),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _largeMarker(Doctor doctor, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.plum : AppColors.blush,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 18),
          if (selected) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                doctor.hospital,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapLegend(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_hospital_rounded,
              color: AppColors.blush, size: 17),
          const SizedBox(width: 6),
          Text(
            '$count клиник',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapDoctorPreview(Doctor doctor) {
    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.all(14),
      color: AppColors.lavender,
      child: Row(
        children: [
          _doctorAvatar(doctor, size: 48, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${doctor.hospital} · ${doctor.city}, ${doctor.address}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openDoctor(doctor);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.blush),
            child: const Text('Запись'),
          ),
        ],
      ),
    );
  }

  Widget _doctorCard(Doctor doctor) {
    final distance = _distanceKm(doctor);
    return SoftCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      onTap: () => _openDoctor(doctor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  _doctorAvatar(doctor),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: doctor.isOnline
                            ? const Color(0xFF3FA178)
                            : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doctor.specialty.isEmpty
                          ? 'Специалист'
                          : doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.blush,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 17),
                        const SizedBox(width: 4),
                        Text(
                          '${doctor.rating.toStringAsFixed(1)} · ${doctor.reviewCount} отзывов',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            doctor.hospital.isEmpty ? 'Клиника не указана' : doctor.hospital,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.blush, size: 17),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  distance == null
                      ? '${doctor.city}, ${doctor.address}'
                      : '${doctor.city}, ${distance.toStringAsFixed(1)} км от вас',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.work_outline_rounded,
                  '${doctor.yearsOfExperience} лет опыта'),
              _pill(Icons.payments_outlined,
                  _formatCurrency(doctor.consultationFee)),
              _pill(
                doctor.isOnline
                    ? Icons.video_call_outlined
                    : Icons.local_hospital_outlined,
                doctor.isOnline ? 'Онлайн и клиника' : 'В клинике',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _doctorAvatar(Doctor doctor, {double size = 68, double radius = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: doctor.avatarColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: doctor.avatarColor.withOpacity(0.28)),
      ),
      child: Center(
        child: Text(
          doctor.initials,
          style: TextStyle(
            color: doctor.avatarColor,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lavender.withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.plum, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.plum,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SoftCard(
          radius: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  color: AppColors.blush, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Ничего не найдено',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Сбросить фильтры'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    var range = _priceRange;
    var onlyOnline = _onlyOnline;
    var sortMode = _sortMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    const Text(
                      'Фильтр записи',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Стоимость: ${_formatCurrency(range.start)} - ${_formatCurrency(range.end)}',
                      style: const TextStyle(
                        color: AppColors.plum,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    RangeSlider(
                      values: range,
                      min: 0,
                      max: 30000,
                      divisions: 30,
                      activeColor: AppColors.blush,
                      inactiveColor: AppColors.lavender,
                      onChanged: (value) => setModalState(() => range = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.blush,
                      value: onlyOnline,
                      onChanged: (value) =>
                          setModalState(() => onlyOnline = value),
                      title: const Text('Только онлайн-прием'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Сортировка',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sortTile(
                      icon: Icons.arrow_upward_rounded,
                      title: 'По возрастанию цены',
                      mode: _SortMode.priceAsc,
                      value: sortMode,
                      onChanged: (value) =>
                          setModalState(() => sortMode = value),
                    ),
                    _sortTile(
                      icon: Icons.arrow_downward_rounded,
                      title: 'По убыванию цены',
                      mode: _SortMode.priceDesc,
                      value: sortMode,
                      onChanged: (value) =>
                          setModalState(() => sortMode = value),
                    ),
                    _sortTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'По опыту',
                      mode: _SortMode.experience,
                      value: sortMode,
                      onChanged: (value) =>
                          setModalState(() => sortMode = value),
                    ),
                    _sortTile(
                      icon: Icons.near_me_outlined,
                      title: 'По локации, кто ближе',
                      mode: _SortMode.nearest,
                      value: sortMode,
                      onChanged: (value) =>
                          setModalState(() => sortMode = value),
                    ),
                    _sortTile(
                      icon: Icons.star_outline_rounded,
                      title: 'По рейтингу',
                      mode: _SortMode.rating,
                      value: sortMode,
                      onChanged: (value) =>
                          setModalState(() => sortMode = value),
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      label: 'Применить',
                      icon: Icons.check_rounded,
                      onPressed: () {
                        setState(() {
                          _priceRange = range;
                          _onlyOnline = onlyOnline;
                          _sortMode = sortMode;
                        });
                        Navigator.pop(context);
                        if (_sortMode == _SortMode.nearest &&
                            _userPosition == null &&
                            _cityQuery.trim().isEmpty) {
                          _showMessage(
                            'Разрешите геолокацию или укажите город вручную',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortTile({
    required IconData icon,
    required String title,
    required _SortMode mode,
    required _SortMode value,
    required ValueChanged<_SortMode> onChanged,
  }) {
    final selected = mode == value;
    return RadioListTile<_SortMode>(
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.blush,
      value: mode,
      groupValue: value,
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
      },
      secondary: Icon(icon, color: selected ? AppColors.blush : AppColors.muted),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? AppColors.plum : AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _detectLocation() async {
    setState(() {
      _locating = true;
      _locationDenied = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationDenied = true;
        _showMessage('Геолокация выключена. Укажите город вручную.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationDenied = true;
        _showMessage('Геолокация не разрешена. Укажите город вручную.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final city = _nearestKnownCity(position);

      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _cityQuery = city;
        _cityController.text = city;
        _sortMode = _SortMode.nearest;
      });
      _showMessage('Город определен: $city');
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationDenied = true);
      _showMessage('Не получилось определить город. Укажите его вручную.');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  String _nearestKnownCity(Position position) {
    const cities = {
      'Алматы': Offset(43.238949, 76.889709),
      'Астана': Offset(51.169392, 71.449074),
      'Шымкент': Offset(42.341684, 69.590101),
    };

    var nearest = 'Алматы';
    var nearestDistance = double.infinity;
    cities.forEach((city, point) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.dx,
        point.dy,
      );
      if (distance < nearestDistance) {
        nearest = city;
        nearestDistance = distance;
      }
    });
    return nearest;
  }

  void _openDoctor(Doctor doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: doctor)),
    );
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _cityController.clear();
      _searchQuery = '';
      _cityQuery = '';
      _specialty = 'Все';
      _priceRange = const RangeValues(0, 30000);
      _onlyOnline = false;
      _sortMode = _SortMode.rating;
      _selectedMapDoctor = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ClinicMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final smallRoadPaint = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final parkPaint = Paint()
      ..color = const Color(0xFFE7F8EF)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.12, 96, 58),
        const Radius.circular(22),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.58, 94, 52),
        const Radius.circular(22),
      ),
      parkPaint,
    );

    final mainPath = Path()
      ..moveTo(-20, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.04,
        size.width * 0.55,
        size.height * 0.36,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.68,
        size.width + 20,
        size.height * 0.56,
      );
    canvas.drawPath(mainPath, roadPaint);

    final crossPath = Path()
      ..moveTo(size.width * 0.12, size.height + 10)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.58,
        size.width * 0.78,
        -10,
      );
    canvas.drawPath(crossPath, smallRoadPaint);

    canvas.drawLine(
      Offset(0, size.height * 0.76),
      Offset(size.width, size.height * 0.86),
      smallRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, 0),
      Offset(size.width * 0.08, size.height),
      smallRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
