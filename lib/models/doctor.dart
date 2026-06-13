import 'package:flutter/material.dart';

class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String university;
  final String hospital;
  final double rating;
  final int reviewCount;
  final int yearsOfExperience;
  final double consultationFee;
  final String description;
  final bool isOnline;
  final Color statusColor;
  final String gender;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final Color avatarColor;

  const Doctor({
    this.id = '',
    required this.name,
    required this.specialty,
    required this.university,
    required this.hospital,
    required this.rating,
    this.reviewCount = 0,
    required this.yearsOfExperience,
    required this.consultationFee,
    required this.description,
    this.isOnline = true,
    this.statusColor = const Color(0xFF3FA178),
    required this.gender,
    this.city = 'Алматы',
    this.address = '',
    this.latitude = 43.238949,
    this.longitude = 76.889709,
    this.avatarColor = const Color(0xFFFF1493),
  });

  factory Doctor.fromJson(Map<String, dynamic> json, String id) {
    return Doctor(
      id: id,
      name: json['name'] ?? '',
      specialty: json['specialty'] ?? '',
      university: json['university'] ?? '',
      hospital: json['hospital'] ?? '',
      rating: _readDouble(json['rating'], 0),
      reviewCount: _readInt(json['reviewCount'] ?? json['review_count'], 0),
      yearsOfExperience:
          _readInt(json['yearsOfExperience'] ?? json['years_of_experience'], 0),
      consultationFee:
          _readDouble(json['consultationFee'] ?? json['consultation_fee'], 0),
      description: json['description'] ?? '',
      isOnline: json['isOnline'] ?? json['is_online'] ?? true,
      gender: json['gender'] ?? 'female',
      city: json['city'] ?? 'Алматы',
      address: json['address'] ?? '',
      latitude: _readDouble(json['latitude'], 43.238949),
      longitude: _readDouble(json['longitude'], 76.889709),
      avatarColor: _readColor(
        json['avatarColor'] ?? json['avatar_color'],
        const Color(0xFFFF1493),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'specialty': specialty,
      'university': university,
      'hospital': hospital,
      'rating': rating,
      'reviewCount': reviewCount,
      'yearsOfExperience': yearsOfExperience,
      'consultationFee': consultationFee,
      'description': description,
      'isOnline': isOnline,
      'gender': gender,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'avatarColor': avatarColor.value,
    };
  }

  Doctor copyWith({
    double? rating,
    int? reviewCount,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return Doctor(
      id: id,
      name: name,
      specialty: specialty,
      university: university,
      hospital: hospital,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      yearsOfExperience: yearsOfExperience,
      consultationFee: consultationFee,
      description: description,
      isOnline: isOnline,
      statusColor: statusColor,
      gender: gender,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      avatarColor: avatarColor,
    );
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static Color _readColor(dynamic value, Color fallback) {
    if (value is int) return Color(value);
    if (value is String) {
      final clean = value.replaceAll('#', '').replaceAll('0x', '');
      final parsed = int.tryParse(clean, radix: 16);
      if (parsed != null) {
        return Color(clean.length <= 6 ? parsed | 0xFF000000 : parsed);
      }
    }
    return fallback;
  }
}

final List<Doctor> dummyDoctors = [
  const Doctor(
    id: 'asel-satova',
    name: 'Асель Сатова',
    specialty: 'Гинеколог-репродуктолог',
    university: 'КазНМУ им. Асфендиярова',
    hospital: 'Центр женского здоровья «Аяла»',
    rating: 4.9,
    reviewCount: 128,
    yearsOfExperience: 15,
    consultationFee: 7500,
    description:
        'Помогает с планированием беременности, нарушениями цикла и подготовкой к ЭКО. Объясняет спокойно и подробно.',
    isOnline: true,
    gender: 'female',
    city: 'Алматы',
    address: 'ул. Байтурсынова, 96',
    latitude: 43.2389,
    longitude: 76.9287,
    avatarColor: Color(0xFFFF1493),
  ),
  const Doctor(
    id: 'lyazzat-kuanysheva',
    name: 'Ляззат Куанышева',
    specialty: 'Маммолог',
    university: 'Казахстанско-Российский медуниверситет',
    hospital: 'Клиника «Мейірім»',
    rating: 4.8,
    reviewCount: 94,
    yearsOfExperience: 10,
    consultationFee: 6500,
    description:
        'Специализируется на диагностике молочных желез, профилактике и сопровождении после обследований.',
    isOnline: true,
    gender: 'female',
    city: 'Алматы',
    address: 'пр. Абая, 52',
    latitude: 43.2416,
    longitude: 76.9098,
    avatarColor: Color(0xFFFF69B4),
  ),
  const Doctor(
    id: 'amina-omarova',
    name: 'Амина Омарова',
    specialty: 'Эндокринолог',
    university: 'Медицинский университет Астана',
    hospital: 'Qamqor Medical',
    rating: 4.7,
    reviewCount: 73,
    yearsOfExperience: 8,
    consultationFee: 6000,
    description:
        'Работает с гормональным балансом, щитовидной железой, усталостью и изменениями веса.',
    isOnline: true,
    gender: 'female',
    city: 'Астана',
    address: 'пр. Кабанбай батыра, 48',
    latitude: 51.0907,
    longitude: 71.4187,
    avatarColor: Color(0xFFC71585),
  ),
  const Doctor(
    id: 'dana-ergalieva',
    name: 'Дана Ергалиева',
    specialty: 'Акушер-гинеколог',
    university: 'КазНМУ им. Асфендиярова',
    hospital: 'Женская клиника Sana',
    rating: 5.0,
    reviewCount: 61,
    yearsOfExperience: 6,
    consultationFee: 5500,
    description:
        'Принимает по вопросам цикла, контрацепции, беременности и профилактических осмотров.',
    isOnline: false,
    statusColor: Colors.grey,
    gender: 'female',
    city: 'Шымкент',
    address: 'ул. Рыскулова, 18',
    latitude: 42.3417,
    longitude: 69.5901,
    avatarColor: Color(0xFFE8479F),
  ),
  const Doctor(
    id: 'nazgul-temirova',
    name: 'Назгуль Темирова',
    specialty: 'Гинеколог',
    university: 'ЮКМА',
    hospital: 'Femina Clinic',
    rating: 4.9,
    reviewCount: 156,
    yearsOfExperience: 18,
    consultationFee: 9000,
    description:
        'Ведет сложные случаи, хронические воспаления, подбор терапии и второе мнение по обследованиям.',
    isOnline: true,
    gender: 'female',
    city: 'Алматы',
    address: 'ул. Тимирязева, 42',
    latitude: 43.2241,
    longitude: 76.9093,
    avatarColor: Color(0xFFFF1493),
  ),
  const Doctor(
    id: 'zhanna-seidakhmetova',
    name: 'Жанна Сейдахметова',
    specialty: 'Репродуктолог',
    university: 'Astana Medical University',
    hospital: 'ReproLife',
    rating: 4.9,
    reviewCount: 112,
    yearsOfExperience: 13,
    consultationFee: 12000,
    description:
        'Помогает парам с планированием, подготовкой к ЭКО и восстановлением после неудачных попыток.',
    isOnline: true,
    gender: 'female',
    city: 'Астана',
    address: 'ул. Сыганак, 10',
    latitude: 51.1286,
    longitude: 71.4302,
    avatarColor: Color(0xFFFF69B4),
  ),
  const Doctor(
    id: 'aigerim-nurlanova',
    name: 'Айгерим Нурланова',
    specialty: 'УЗИ-специалист',
    university: 'КазНМУ им. Асфендиярова',
    hospital: 'MedLine Diagnostics',
    rating: 4.6,
    reviewCount: 88,
    yearsOfExperience: 9,
    consultationFee: 5000,
    description:
        'Проводит УЗИ органов малого таза, молочных желез и ранних сроков беременности.',
    isOnline: false,
    statusColor: Colors.grey,
    gender: 'female',
    city: 'Алматы',
    address: 'ул. Кабанбай батыра, 83',
    latitude: 43.2494,
    longitude: 76.9458,
    avatarColor: Color(0xFFC71585),
  ),
  const Doctor(
    id: 'meruert-alieva',
    name: 'Меруерт Алиева',
    specialty: 'Психолог',
    university: 'КазНУ им. аль-Фараби',
    hospital: 'Balance Women Center',
    rating: 4.8,
    reviewCount: 79,
    yearsOfExperience: 7,
    consultationFee: 7000,
    description:
        'Работает с тревожностью, ПМС, послеродовым состоянием и эмоциональным выгоранием.',
    isOnline: true,
    gender: 'female',
    city: 'Алматы',
    address: 'ул. Желтоксан, 115',
    latitude: 43.2535,
    longitude: 76.9398,
    avatarColor: Color(0xFFFF1493),
  ),
  const Doctor(
    id: 'saule-bekenova',
    name: 'Сауле Бекенова',
    specialty: 'Дерматолог',
    university: 'Карагандинский медуниверситет',
    hospital: 'Skin & Hormones',
    rating: 4.7,
    reviewCount: 64,
    yearsOfExperience: 11,
    consultationFee: 8000,
    description:
        'Консультирует по акне, выпадению волос, коже во время беременности и гормональным изменениям.',
    isOnline: true,
    gender: 'female',
    city: 'Астана',
    address: 'ул. Достык, 5',
    latitude: 51.1281,
    longitude: 71.4240,
    avatarColor: Color(0xFFFF69B4),
  ),
  const Doctor(
    id: 'inkar-abdrakhmanova',
    name: 'Инкар Абдрахманова',
    specialty: 'Акушер',
    university: 'ЮКМА',
    hospital: 'Mother Care Shymkent',
    rating: 4.8,
    reviewCount: 91,
    yearsOfExperience: 12,
    consultationFee: 6500,
    description:
        'Ведет беременность, помогает подготовиться к родам и восстановлению после них.',
    isOnline: false,
    statusColor: Colors.grey,
    gender: 'female',
    city: 'Шымкент',
    address: 'пр. Тауке хана, 45',
    latitude: 42.3176,
    longitude: 69.5954,
    avatarColor: Color(0xFFC71585),
  ),
  const Doctor(
    id: 'kamilya-rakhimova',
    name: 'Камиля Рахимова',
    specialty: 'Диетолог',
    university: 'КазНМУ им. Асфендиярова',
    hospital: 'NutriMed Women',
    rating: 4.6,
    reviewCount: 53,
    yearsOfExperience: 5,
    consultationFee: 4500,
    description:
        'Составляет питание при СПКЯ, анемии, подготовке к беременности и восстановлении цикла.',
    isOnline: true,
    gender: 'female',
    city: 'Алматы',
    address: 'ул. Навои, 208',
    latitude: 43.2018,
    longitude: 76.8924,
    avatarColor: Color(0xFFFF1493),
  ),
  const Doctor(
    id: 'botagoz-serikova',
    name: 'Ботагоз Серикова',
    specialty: 'Онкогинеколог',
    university: 'Astana Medical University',
    hospital: 'National Women Health',
    rating: 4.9,
    reviewCount: 137,
    yearsOfExperience: 16,
    consultationFee: 11000,
    description:
        'Занимается профилактикой, ранней диагностикой и сопровождением пациенток после лечения.',
    isOnline: true,
    gender: 'female',
    city: 'Астана',
    address: 'пр. Мәңгілік Ел, 20',
    latitude: 51.0989,
    longitude: 71.4475,
    avatarColor: Color(0xFFFF69B4),
  ),
];

class HealthProduct {
  final String name;
  final double price;
  final String imagePath;

  HealthProduct({
    required this.name,
    required this.price,
    required this.imagePath,
  });
}

final List<HealthProduct> dummyProducts = [
  HealthProduct(name: 'Витамины', price: 4500, imagePath: 'assets/bottle.png'),
  HealthProduct(name: 'Капсулы', price: 8500, imagePath: 'assets/capsule.png'),
  HealthProduct(
    name: 'Тест-полоска',
    price: 2000,
    imagePath: 'assets/test.png',
  ),
];
