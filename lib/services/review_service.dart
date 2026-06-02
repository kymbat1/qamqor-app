import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor_review.dart';
import 'auth_service.dart';

class ReviewService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  ReviewService({
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService();

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('doctor_reviews');

  Stream<List<DoctorReview>> watchDoctorReviews(String doctorId) {
    return _reviews.where('doctorId', isEqualTo: doctorId).snapshots().map(
      (snapshot) {
        final reviews = snapshot.docs
            .map((doc) => DoctorReview.fromJson(doc.data(), doc.id))
            .toList();
        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reviews;
      },
    );
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

    final userData = await _authService.currentUserData() ?? {};
    final patientName = userData['name'] ?? 'Пациент';

    await _reviews.add({
      'doctorId': doctorId,
      'patientId': uid,
      'patientName': patientName,
      'rating': rating,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
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
