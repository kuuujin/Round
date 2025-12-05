import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'club_board.dart';
import 'package:round/models/club_models.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post; // 목록에서 넘겨받은 게시글 객체
  const PostDetailScreen({super.key, required this.post});
  

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  final Dio dio = ApiClient().dio;
  late int _likeCount;
  bool _isLiked = false;
  
  // 팔레트
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

  Future<void> _fetchPostDetail() async {
    try {
      final response = await dio.get(
        '/api/posts/detail', 
        queryParameters: {'post_id': widget.post.id}
      );
      
      if (response.statusCode == 200) {
        final data = response.data['post'];
        setState(() {
          _likeCount = data['likes']; // 최신 좋아요 수로 업데이트
          // DB에서 1이면 true, 0이면 false
          _isLiked = (data['is_liked'] == 1); 
        });
      }
    } on DioException catch (e) {
      print("상세 정보 로딩 실패: $e");
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await dio.get('/api/comments', queryParameters: {'post_id': widget.post.id});
      final List<dynamic> data = response.data['comments'];
      setState(() {
        _comments = data.map((e) => Comment.fromJson(e)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("댓글 로딩 실패: $e");
      setState(() => _isLoading = false);
    }
  }


  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) return;
    
    try {
      await dio.post('/api/comments', data: {
        'post_id': widget.post.id,
        'content': _commentController.text,
      });
      _commentController.clear();
      FocusScope.of(context).unfocus(); // 키보드 내리기
      _fetchComments(); // 목록 새로고침
    } on DioException catch (e) {
      print("댓글 작성 실패: $e");
    }
  }

  Future<void> _toggleLike() async {
    // UI 낙관적 업데이트 (반응 속도 향상)
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final response = await dio.post('/api/posts/like', data: {'post_id': widget.post.id});
      
      // 서버의 정확한 값으로 동기화
      setState(() {
        _likeCount = response.data['likes'];
      });
    } on DioException catch (e) {
      // 실패 시 롤백
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      print("좋아요 실패: $e");
    }
  }

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
          // 1. 게시글 본문 (스크롤 가능 영역)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성자 정보
                  Row(
                    children: [
                       CircleAvatar(
                        backgroundColor: Colors.grey,
                        backgroundImage: (widget.post.imageUrl != null) ? NetworkImage(widget.post.imageUrl!) : null, // 작성자 이미지 (Post 모델에 추가 필요, 없다면 기본값)
                        child: (widget.post.imageUrl == null) ? const Icon(Icons.person, color: Colors.white) : null,
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
                  ),
                  const SizedBox(height: 20),
                  // 제목 & 내용 & 좋아요 버튼 Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.post.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(widget.post.content, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                          ],
                        ),
                      ),
                      // 👇👇👇 좋아요 버튼 추가 👇👇👇
                      Column(
                        children: [
                          IconButton(
                            onPressed: _toggleLike,
                            icon: Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              // _isLiked가 true면 빨간색, 아니면 회색
                              color: _isLiked ? Colors.redAccent : Colors.white70,
                              size: 28,
                            ),
                          ),
                          Text("$_likeCount", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  // 게시글 이미지 (있다면)
                  if (widget.post.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(widget.post.imageUrl!),
                    ),
                  
                  const Divider(color: Colors.grey, height: 40),
                  
                  // 2. 댓글 목록
                  const Text("댓글", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: _lime))
                  else if (_comments.isEmpty)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("첫 번째 댓글을 남겨보세요!", style: TextStyle(color: Colors.white38))))
                  else
                    ListView.builder(
                      shrinkWrap: true, // SingleScrollView 안에서 필수
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(comment.authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(comment.time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(comment.content, style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 3. 댓글 입력창 (하단 고정)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _panel,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _submitComment,
                  icon: const Icon(Icons.send, color: _lime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}