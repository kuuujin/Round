import 'package:flutter/material.dart';
import 'write_post.dart';
import 'package:dio/dio.dart';
import 'post_detail.dart'; // 파일명 확인
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart'; // Post, Comment 모델

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
  // 팔레트
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);

  bool _isLoading = true;
  List<Post> _posts = [];
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchPosts(widget.clubId);
  }

  Future<void> _fetchPosts(int clubId) async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/posts', queryParameters: {'club_id': clubId});
      final List<dynamic> data = response.data['posts'];
      setState(() {
        _posts = data.map((json) => Post.fromJson(json)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("Error fetching posts: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPostsSilent() async {
    try {
      final response = await dio.get('/api/posts', queryParameters: {'club_id': widget.clubId});
      final List<dynamic> data = response.data['posts'];
      setState(() {
        _posts = data.map((json) => Post.fromJson(json)).toList();
        // _isLoading 건드리지 않음
      });
    } catch (e) {
      print("Silent refresh failed: $e");
    }
  }

  Widget _postCard(Post post) {
    return GestureDetector(
      onTap: () async{
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
        );
        _refreshPostsSilent();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              post.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            // 내용
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),

            // 이미지
            if (post.imageUrl != null)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(post.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ❤️ 좋아요 + 💬 댓글 + 시간
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  post.time,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),

                Row(
                  children: [
                    // ❤️ 좋아요
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${post.likes}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // 💬 댓글
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${post.comments}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // AppBar 제거 (ClubMainScreen에서 관리)
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _lime))
          : _posts.isEmpty
              ? const Center(child: Text("작성된 게시글이 없습니다.", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 80),
                  itemCount: _posts.length,
                  itemBuilder: (context, i) => _postCard(_posts[i]),
                ),

      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_board_write',
        backgroundColor: _lime,
        child: const Icon(Icons.edit, color: Colors.black),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WritePostScreen(clubId: widget.clubId)),
          );
          if (result == true) {
            _fetchPosts(widget.clubId);
          }
        },
      ),
    );
  }
} // 👈 클래스가 여기서 끝나야 합니다!