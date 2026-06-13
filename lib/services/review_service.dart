import '../models/doctor_review.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ReviewService {
  final ApiClient _apiClient;
  final AuthService _authService;

  ReviewService({
    ApiClient? apiClient,
    AuthService? authService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authService = authService ?? AuthService();

  Stream<List<DoctorReview>> watchDoctorReviews(String doctorId) {
    return Stream.fromFuture(_fetchDoctorReviews(doctorId));
  }

  Future<List<DoctorReview>> _fetchDoctorReviews(String doctorId) async {
    final response = await _apiClient.getList(
      '/reviews/doctors/$doctorId',
      auth: false,
    );
    return response
        .whereType<Map>()
        .map((json) => DoctorReview.fromJson(
              Map<String, dynamic>.from(json),
              json['id']?.toString() ?? '',
            ))
        .toList();
  }

  Future<void> addReview({
    required String doctorId,
    required double rating,
    required String text,
  }) async {
    final uid = await _authService.currentUser();
    if (uid == null || uid.isEmpty) {
      throw Exception('user-not-authenticated');
    }

    await _apiClient.post('/reviews/doctors/$doctorId', body: {
      'rating': rating,
      'text': text.trim(),
    });
  }

  double averageRating(List<DoctorReview> reviews, double fallback) {
    if (reviews.isEmpty) {
      return fallback;
    }

    final sum = reviews.fold<double>(0, (total, review) => total + review.rating);
    return sum / reviews.length;
  }
}
