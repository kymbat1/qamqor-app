import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/forum_post.dart';
import '../../services/forum_service.dart';
import '../../theme/app_design.dart';

const List<String> forumCategories = [
  'Все',
  'Цикл',
  'Беременность',
  'ПМС',
  'Здоровье',
  'Врачи',
  'Поддержка',
  'Общее',
];

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ForumService _forumService = ForumService();
  final TextEditingController _searchController = TextEditingController();
  String _category = 'Все';
  late Future<List<ForumPost>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ForumPost>> _loadPosts() {
    return _forumService.fetchPosts(
      category: _category,
      search: _searchController.text,
    );
  }

  void _refresh() {
    setState(() => _postsFuture = _loadPosts());
  }

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.blush,
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
            children: [
              FadeSlideIn(child: _header()),
              const SizedBox(height: 16),
              FadeSlideIn(delayMs: 70, child: _composerCard()),
              const SizedBox(height: 14),
              FadeSlideIn(delayMs: 110, child: _searchField()),
              const SizedBox(height: 12),
              FadeSlideIn(delayMs: 140, child: _categoryChips()),
              const SizedBox(height: 16),
              FutureBuilder<List<ForumPost>>(
                future: _postsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 42),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _emptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Не удалось загрузить форум',
                      text: 'Проверьте backend и попробуйте обновить страницу.',
                    );
                  }

                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return _emptyState(
                      icon: Icons.forum_outlined,
                      title: 'Пока нет обсуждений',
                      text: 'Станьте первой, кто задаст вопрос или поделится опытом.',
                    );
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < posts.length; i++) ...[
                        FadeSlideIn(
                          delayMs: 40 * i,
                          child: _PostCard(
                            post: posts[i],
                            onTap: () => _openPost(posts[i]),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Форум',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Вопросы, личный опыт и поддержка без осуждения',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: AppColors.blush),
          onPressed: _showCreatePostSheet,
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _composerCard() {
    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      onTap: _showCreatePostSheet,
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_comment_rounded, color: AppColors.blush),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Поделиться опытом или задать вопрос',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _refresh(),
      decoration: InputDecoration(
        hintText: 'Поиск по форуму',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.tune_rounded),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: forumCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = forumCategories[index];
          final selected = category == _category;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _category = category;
                _postsFuture = _loadPosts();
              });
            },
            selectedColor: AppColors.blush,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected ? AppColors.blush : AppColors.lavender,
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: SoftCard(
        child: Column(
          children: [
            Icon(icon, color: AppColors.blush, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreatePostSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(forumService: _forumService),
    );
    if (created == true) {
      _refresh();
    }
  }

  Future<void> _openPost(ForumPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForumPostScreen(post: post, forumService: _forumService),
      ),
    );
    _refresh();
  }
}

class ForumPostScreen extends StatefulWidget {
  final ForumPost post;
  final ForumService forumService;

  const ForumPostScreen({
    super.key,
    required this.post,
    required this.forumService,
  });

  @override
  State<ForumPostScreen> createState() => _ForumPostScreenState();
}

class _ForumPostScreenState extends State<ForumPostScreen> {
  final TextEditingController _commentController = TextEditingController();
  late Future<List<ForumComment>> _commentsFuture;
  String? _replyToId;
  String? _replyToName;
  bool _anonymous = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _commentsFuture = _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<List<ForumComment>> _loadComments() {
    return widget.forumService.fetchComments(widget.post.id);
  }

  void _refreshComments() {
    setState(() => _commentsFuture = _loadComments());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text('Обсуждение'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              children: [
                _PostCard(post: widget.post),
                const SizedBox(height: 14),
                const Text(
                  'Комментарии',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<ForumComment>>(
                  future: _commentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Text(
                        'Не получилось загрузить комментарии.',
                        style: TextStyle(color: AppColors.muted),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return const SoftCard(
                        child: Text(
                          'Пока нет комментариев. Можно поддержать автора первой.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return Column(children: _commentTiles(comments));
                  },
                ),
              ],
            ),
          ),
          _commentComposer(),
        ],
      ),
    );
  }

  List<Widget> _commentTiles(List<ForumComment> comments) {
    final roots = comments.where((item) => item.parentCommentId == null).toList();
    final replies = <String, List<ForumComment>>{};
    for (final comment in comments.where((item) => item.parentCommentId != null)) {
      replies.putIfAbsent(comment.parentCommentId!, () => []).add(comment);
    }

    final tiles = <Widget>[];
    for (final comment in roots) {
      tiles.add(_CommentTile(
        comment: comment,
        onReply: () => _replyTo(comment),
      ));
      for (final reply in replies[comment.id] ?? <ForumComment>[]) {
        tiles.add(Padding(
          padding: const EdgeInsets.only(left: 28),
          child: _CommentTile(
            comment: reply,
            isReply: true,
            onReply: () => _replyTo(reply),
          ),
        ));
      }
      tiles.add(const SizedBox(height: 10));
    }
    return tiles;
  }

  Widget _commentComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ответ для $_replyToName',
                        style: const TextStyle(
                          color: AppColors.plum,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      }),
                      child: const Icon(Icons.close_rounded, color: AppColors.plum),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Написать комментарий',
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.blush),
                  onPressed: _isSending ? null : _sendComment,
                  icon: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _anonymous,
                  activeColor: AppColors.blush,
                  onChanged: (value) {
                    setState(() => _anonymous = value ?? false);
                  },
                ),
                const Text(
                  'Анонимно',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _replyTo(ForumComment comment) {
    setState(() {
      _replyToId = comment.id;
      _replyToName = comment.authorName;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _isSending = true);
    try {
      await widget.forumService.createComment(
        postId: widget.post.id,
        body: text,
        parentCommentId: _replyToId,
        isAnonymous: _anonymous,
      );
      _commentController.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
      _refreshComments();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось отправить комментарий')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}

class _PostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback? onTap;

  const _PostCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 22,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: post.authorName, anonymous: post.isAnonymous),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _dateLabel(post.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CategoryBadge(category: post.category),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            maxLines: onTap == null ? null : 4,
            overflow: onTap == null ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.mode_comment_outlined,
                  color: AppColors.blush, size: 18),
              const SizedBox(width: 6),
              Text(
                '${post.commentsCount} комментариев',
                style: const TextStyle(
                  color: AppColors.plum,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final ForumComment comment;
  final VoidCallback onReply;
  final bool isReply;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReply ? AppColors.lavender : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lavender),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                name: comment.authorName,
                anonymous: comment.isAnonymous,
                size: 34,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  comment.authorName,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _dateLabel(comment.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.body,
            style: const TextStyle(color: AppColors.ink, height: 1.35),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onReply,
            child: const Text(
              'Ответить',
              style: TextStyle(
                color: AppColors.blush,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final ForumService forumService;

  const _CreatePostSheet({required this.forumService});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _category = 'Общее';
  bool _anonymous = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Новая публикация',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _sheetField(
                controller: _titleController,
                hint: 'Короткий заголовок',
                maxLines: 1,
              ),
              const SizedBox(height: 10),
              _sheetField(
                controller: _bodyController,
                hint: 'Расскажите подробнее',
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: _inputDecoration('Категория'),
                items: forumCategories
                    .where((item) => item != 'Все')
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _category = value ?? 'Общее';
                }),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _anonymous,
                activeColor: AppColors.blush,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Опубликовать анонимно',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onChanged: (value) => setState(() => _anonymous = value),
              ),
              const SizedBox(height: 8),
              GradientButton(
                label: 'Опубликовать',
                icon: Icons.send_rounded,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.length < 4 || body.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте заголовок и текст публикации')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.forumService.createPost(
        title: title,
        body: body,
        category: _category,
        isAnonymous: _anonymous,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось опубликовать')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool anonymous;
  final double size;

  const _Avatar({
    required this.name,
    required this.anonymous,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final letter = anonymous || name.isEmpty ? '?' : name.substring(0, 1);
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: anonymous ? AppColors.ink : AppColors.blush,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: AppColors.plum,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  return DateFormat('d MMM, HH:mm', 'ru_RU').format(date.toLocal());
}
