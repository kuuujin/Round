import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubBoardScreen extends StatefulWidget {
  final String userId;
  const ClubBoardScreen({super.key, required this.userId});

  @override
  State<ClubBoardScreen> createState() => _ClubBoardScreenState();
}

class _ClubBoardScreenState extends State<ClubBoardScreen> {
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _chipBlue = Color(0xFF60A5FA);

  final List<String> clubs = [
    '볼링스테이션',
    '축구스테이션',
    '풋살스테이션',
    '농구스테이션',
    '33스테이션',
    '배민스테이션',
    '부평농구',
  ];

  String selectedClub = "볼링스테이션";

  // 샘플 게시글 데이터
  final List<Map<String, dynamic>> posts = [
    {
      "title": "9월 12일 친선전 선발 명단",
      "content": "1레인: 정석과학, 유니팀\n2레인: 감자팀...",
      "time": "오늘 9:36",
      "likes": 2,
      "comments": 2,
      "image": true,
    },
    {
      "title": "볼 추천 좀 해주십쇼",
      "content": "우레탄 볼 하나 장만하려는데 햄머퍼플말고 괜찮은거 있나요?",
      "time": "어제 11:43",
      "likes": 1,
      "comments": 1,
      "image": true,
    }
  ];

  void _goTab(int i) {
    if (i == 2) return;
    final uid = widget.userId;

    switch (i) {
      case 0:
        Navigator.pushReplacementNamed(context, '/club', arguments: uid);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/clubSchedule', arguments: uid);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/clubMembers', arguments: uid);
        break;
    }
  }

  void _onTapBottom(int i) {
    final uid = widget.userId;
    switch (i) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: uid);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/club', arguments: uid);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/community', arguments: uid);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/mypage', arguments: uid);
        break;
    }
  }

  Widget _tabs() {
    final tabs = ['홈', '일정', '게시판', '클럽정보'];
    const selected = 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(4, (i) {
          final sel = i == selected;
          return Expanded(
            child: InkWell(
              onTap: () => _goTab(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2,
                      width: sel ? 32 : 0,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ================== 게시글 카드 =====================
  Widget _postCard({
    required String title,
    required String content,
    required String time,
    required int likes,
    required int comments,
    required bool hasImage,
  }) {
    return Container(
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
            title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),

          // 내용
          Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // 이미지
          if (hasImage)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.image, color: Colors.white38, size: 30),
              ),
            ),

          const SizedBox(height: 12),

          // ❤️ 좋아요 + 💬 댓글 + 시간
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
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
                        "$likes",
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
                        "$comments",
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
    );
  }

  // ======================= MAIN ==========================
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Round 로고
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  "Round",
                  style: TextStyle(
                    color: _lime,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _tabs(),

              // ========= 동호회 선택 =========
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: DropdownButtonFormField<String>(
                  value: selectedClub,
                  dropdownColor: const Color(0xFF1F2937),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _chipBlue,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  items: clubs
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedClub = v);
                  },
                ),
              ),

              // ========= 게시글 리스트 =========
              Expanded(
                child: posts.isEmpty
                    ? const Center(
                        child: Text("게시판 내용 준비중...",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 14)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: posts.length,
                        itemBuilder: (context, i) {
                          final p = posts[i];
                          return _postCard(
                            title: p["title"],
                            content: p["content"],
                            time: p["time"],
                            likes: p["likes"],
                            comments: p["comments"],
                            hasImage: p["image"],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        // ================= Bottom Nav =================
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _bg,
          currentIndex: 1,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTapBottom,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined), label: 'Club'),
            BottomNavigationBarItem(
                icon: Icon(Icons.groups_2_outlined), label: 'Community'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'My'),
          ],
        ),
      ),
    );
  }
}
