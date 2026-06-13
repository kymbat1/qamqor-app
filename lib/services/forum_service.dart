import '../models/forum_post.dart';
import 'api_client.dart';

class ForumService {
  final ApiClient _apiClient;

  ForumService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<ForumPost>> fetchPosts({
    String? category,
    String? search,
  }) async {
    final query = <String, String>{};
    if (category != null && category.isNotEmpty && category != 'Все') {
      query['category'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final path = query.isEmpty
        ? '/forum/posts'
        : '/forum/posts?${Uri(queryParameters: query).query}';
    final response = await _apiClient.getList(path, auth: false);
    return response
        .whereType<Map>()
        .map((item) => ForumPost.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ForumPost> createPost({
    required String title,
    required String body,
    required String category,
    required bool isAnonymous,
  }) async {
    final response = await _apiClient.post('/forum/posts', body: {
      'title': title.trim(),
      'body': body.trim(),
      'category': category.trim(),
      'is_anonymous': isAnonymous,
    });
    return ForumPost.fromJson(response);
  }

  Future<List<ForumComment>> fetchComments(String postId) async {
    final response = await _apiClient.getList('/forum/posts/$postId/comments');
    return response
        .whereType<Map>()
        .map((item) => ForumComment.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ForumComment> createComment({
    required String postId,
    required String body,
    String? parentCommentId,
    required bool isAnonymous,
  }) async {
    final response = await _apiClient.post(
      '/forum/posts/$postId/comments',
      body: {
        'body': body.trim(),
        'parent_comment_id': parentCommentId,
        'is_anonymous': isAnonymous,
      },
    );
    return ForumComment.fromJson(response);
  }
}
