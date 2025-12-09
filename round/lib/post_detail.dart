import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post; 
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // Controllers
  final _commentController = TextEditingController();
  
  // State
  List<Comment> _comments = [];
  bool _isLoading = true;
  late int _likeCount;
  bool _isLiked = false;
  
  final Dio dio = ApiClient().dio;

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    _fetchPostDetail();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _fetchPostDetail() async {
    try {
      final response = await dio.get('/api/posts/detail', queryParameters: {'post_id': widget.post.id});
      if (response.statusCode == 200) {
        final data = response.data['post'];
        if (mounted) {
          setState(() {
            _likeCount = data['likes'];
            _isLiked = (data['is_liked'] == true); 
          });
        }
      }
    } on DioException catch (e) {
      debugPrint("상세 정보 로딩 실패: ${e.message}");
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await dio.get('/api/comments', queryParameters: {'post_id': widget.post.id});
      final List<dynamic> data = response.data['comments'];
      if (mounted) {
        setState(() {
          _comments = data.map((e) => Comment.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("댓글 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    
    try {
      await dio.post('/api/comments', data: {
        'post_id': widget.post.id,
        'content': text,
      });
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
      _fetchComments(); 
    } on DioException catch (e) {
      debugPrint("댓글 작성 실패: ${e.message}");
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final response = await dio.post('/api/posts/like', data: {'post_id': widget.post.id});
      if (mounted) {
        setState(() {
          _likeCount = response.data['likes'];
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
      debugPrint("좋아요 실패: ${e.message}");
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostHeader(),
                  const SizedBox(height: 20),
                  _buildPostContent(),
                  if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty)
                    _buildPostImage(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const Divider(color: Colors.grey, height: 40),
                  _buildCommentSection(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildPostHeader() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.grey[800],
          backgroundImage: (widget.post.profileImage != null) 
              ? NetworkImage(widget.post.profileImage!) 
              : null,
          child: (widget.post.profileImage == null) 
              ? const Icon(Icons.person, color: Colors.white70) 
              : null,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.post.authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(widget.post.time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.post.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(widget.post.content, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      ],
    );
  }

  Widget _buildPostImage() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(widget.post.imageUrl!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: _toggleLike,
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.redAccent : Colors.white70,
            size: 24,
          ),
        ),
        Text("$_likeCount", style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("댓글", style: TextStyle(color: _lime, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: _lime))
        else if (_comments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("첫 번째 댓글을 남겨보세요!", style: TextStyle(color: Colors.white38))))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (comment.authorImage != null) 
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(radius: 10, backgroundImage: NetworkImage(comment.authorImage!)),
                    ),
                  Text(comment.authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Text(comment.time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.content, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            IconButton(
              onPressed: _submitComment,
              icon: const Icon(Icons.send, color: _lime),
            ),
          ],
        ),
      ),
    );
  }
}