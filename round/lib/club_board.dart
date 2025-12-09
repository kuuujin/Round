import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'write_post.dart';
import 'post_detail.dart';

class ClubBoardScreen extends StatefulWidget {
  final int clubId;
  final String userId;

  const ClubBoardScreen({
    super.key,
    required this.clubId,
    required this.userId,
  });

  @override
  State<ClubBoardScreen> createState() => _ClubBoardScreenState();
}

class _ClubBoardScreenState extends State<ClubBoardScreen> {
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  bool _isLoading = true;
  List<Post> _posts = [];
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/posts', queryParameters: {'club_id': widget.clubId});
      final List<dynamic> data = response.data['posts'];
      
      if (mounted) {
        setState(() {
          _posts = data.map((json) => Post.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("Error fetching posts: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPostsSilent() async {
    try {
      final response = await dio.get('/api/posts', queryParameters: {'club_id': widget.clubId});
      final List<dynamic> data = response.data['posts'];
      
      if (mounted) {
        setState(() {
          _posts = data.map((json) => Post.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint("Silent refresh failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // AppBar는 상위 위젯(ClubMainScreen)에서 처리하므로 생략
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _lime))
          : _posts.isEmpty
              ? const Center(child: Text("작성된 게시글이 없습니다.", style: TextStyle(color: Colors.white38)))
              : RefreshIndicator( // 당겨서 새로고침 기능 추가 (선택사항)
                  color: _lime,
                  backgroundColor: _panel,
                  onRefresh: _fetchPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 80),
                    itemCount: _posts.length,
                    itemBuilder: (context, i) => _buildPostCard(_posts[i]),
                  ),
                ),

      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_board_write',
        backgroundColor: _lime,
        foregroundColor: Colors.black,
        child: const Icon(Icons.edit),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WritePostScreen(clubId: widget.clubId)),
          );
          // 글 작성 완료 후 리스트 새로고침
          if (result == true) {
            _fetchPosts();
          }
        },
      ),
    );
  }

  // 게시글 카드 위젯
  Widget _buildPostCard(Post post) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
        );
        // 상세 화면에서 댓글/좋아요 변경되었을 수 있으므로 조용히 갱신
        _refreshPostsSilent();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 작성자 정보 (선택 사항, 필요시 추가)
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: post.profileImage != null 
                      ? NetworkImage(post.profileImage!) 
                      : null,
                  backgroundColor: Colors.grey[700],
                  child: post.profileImage == null 
                      ? const Icon(Icons.person, size: 14, color: Colors.white) 
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  post.authorName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  post.time,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. 제목
            Text(
              post.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // 3. 내용 (최대 3줄)
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),

            // 4. 이미지 (있을 경우)
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(post.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // 5. 하단 액션 바 (좋아요, 댓글)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildIconText(Icons.favorite_border, "${post.likes}"),
                const SizedBox(width: 16),
                _buildIconText(Icons.chat_bubble_outline, "${post.comments}"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}