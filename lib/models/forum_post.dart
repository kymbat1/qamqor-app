class ForumPost {
  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final String category;
  final bool isAnonymous;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.category,
    required this.isAnonymous,
    required this.commentsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Пользователь',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Общее',
      isAnonymous: json['is_anonymous'] == true,
      commentsCount: _readInt(json['comments_count']),
      createdAt: _readDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _readDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class ForumComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? parentCommentId;
  final String body;
  final bool isAnonymous;
  final DateTime createdAt;

  const ForumComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.parentCommentId,
    required this.body,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    return ForumComment(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Пользователь',
      parentCommentId: json['parent_comment_id']?.toString(),
      body: json['body']?.toString() ?? '',
      isAnonymous: json['is_anonymous'] == true,
      createdAt: ForumPost._readDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
