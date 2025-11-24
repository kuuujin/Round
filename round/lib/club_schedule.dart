import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubScheduleScreen extends StatefulWidget {
  final String userId;
  const ClubScheduleScreen({super.key, required this.userId});

  @override
  State<ClubScheduleScreen> createState() => _ClubScheduleScreenState();
}

class _ClubScheduleScreenState extends State<ClubScheduleScreen> {
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _chipBlue = Color(0xFF60A5FA);
  static const Color _matchChip = Color(0xFFFF5A3C);
  static const Color _panel = Color(0xFF2F2F2F);

  int selectedYear = 2025;
  int selectedMonth = 9;

  final List<int> years = List.generate(20, (i) => 2018 + i);

  // ---------------- Bottom nav ----------------
  void _onTapBottom(int index) {
    final uid = widget.userId;

    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home', arguments: uid);
        break;
      case 1:
        Navigator.pushNamed(context, '/club', arguments: uid);
        break;
      case 2:
        Navigator.pushNamed(context, '/community', arguments: uid);
        break;
      case 3:
        Navigator.pushNamed(context, '/mypage', arguments: uid);
        break;
    }
  }

  // ---------------- 연도 선택 ----------------
  void _openYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      builder: (_) => SizedBox(
        height: 420,
        child: ListView(
          children: years
              .map(
                (y) => InkWell(
                  onTap: () {
                    setState(() => selectedYear = y);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                    child: Text(
                      "$y",
                      style: TextStyle(
                        color: selectedYear == y
                            ? Colors.white
                            : Colors.white70,
                        fontWeight: selectedYear == y
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ---------------- 월 선택 ----------------
  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      builder: (_) => SizedBox(
        height: 420,
        child: ListView(
          children: List.generate(12, (i) => i + 1).map((m) {
            return InkWell(
              onTap: () {
                setState(() => selectedMonth = m);
                Navigator.pop(context);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                child: Text(
                  "$m월",
                  style: TextStyle(
                    color: selectedMonth == m ? Colors.white : Colors.white70,
                    fontWeight: selectedMonth == m
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------- 탭 ----------------
  Widget _tabs() {
    final tabs = ['홈', '일정', '게시판', '클럽정보'];
    final selected = 1;

    void _go(int i) {
      if (i == selected) return;

      final uid = widget.userId;

      switch (i) {
        case 0:
          Navigator.pushNamed(context, '/club', arguments: uid);
          break;
        case 2:
          Navigator.pushNamed(context, '/clubBoard', arguments: uid);
          break;
        case 3:
          Navigator.pushNamed(context, '/clubMembers', arguments: uid);
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(4, (i) {
          final sel = i == selected;
          return Expanded(
            child: InkWell(
              onTap: () => _go(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
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

  // ---------------- 메인 ----------------
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

              // ---- 연도/월 ----
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _dateItem("$selectedYear", _openYearPicker),
                    const SizedBox(width: 12),
                    _dateItem("$selectedMonth월", _openMonthPicker),
                  ],
                ),
              ),

              // ---- CONTENT ----
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _regularCard(
                        "정기 모임",
                        "9월 17일",
                        "오후",
                        "4 : 30",
                        "9월 3주차 정기모임",
                        "볼링스테이션 볼링장",
                        "Top 3 수상자 상품 지급",
                        5,
                        20,
                        false,
                      ),

                      const SizedBox(height: 16),

                      _matchCard(
                        "동호회 매치",
                        "9월 12일",
                        "오후",
                        "12 : 30",
                        "익스플로전",
                        "스플래쉬",
                        "정석항공과학고 운동장",
                        7,
                        20,
                        false,
                      ),

                      const SizedBox(height: 16),

                      _regularCard(
                        "정기 모임",
                        "9월 10일",
                        "오후",
                        "4 : 30",
                        "9월 2주차 정기모임",
                        "볼링스테이션 볼링장",
                        "패배 팀, 저녁 식사 비용 부담",
                        8,
                        12,
                        true,
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),

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

  // ---------------- 연월 버튼 ----------------
  Widget _dateItem(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ---------------- 날짜 텍스트 ----------------
  Widget _dateTexts(String d, String ap, String t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          d,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ap,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ---------------- 왼쪽 컬럼(정기모임용) ----------------
  Widget _leftColumn(
    Color tagColor,
    String tagLabel,
    String d,
    String ap,
    String t,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tagChip(tagColor, tagLabel),
        const SizedBox(height: 8),
        _dateTexts(d, ap, t),
      ],
    );
  }

  // ---------------- 태그 칩 ----------------
  Widget _tagChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ---------------- 정기모임 카드 ----------------
  Widget _regularCard(
    String tag,
    String date,
    String ap,
    String time,
    String title,
    String sub1,
    String sub2,
    int cur,
    int max,
    bool closed,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leftColumn(_chipBlue, tag, date, ap, time),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sub1,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _wIconSmall(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sub2,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "$cur/$max",
                      style: TextStyle(
                        color: closed ? Colors.redAccent : Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _applyButton(closed),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ---------------- 동호회 매치 (아이콘 위 / 팀이 아래) ----------------
  Widget _matchCard(
    String tag,
    String date,
    String ap,
    String time,
    String a,
    String b,
    String place,
    int cur,
    int max,
    bool closed,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tagChip(_matchChip, tag),
          const SizedBox(height: 10),

          // 메인 Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: _dateTexts(date, ap, time),
              ),

              const SizedBox(width: 14),

              // 가운데 VS + 팀들
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽 팀 — 아이콘 위 / 이름 아래
                        Column(
                          children: [
                            _teamCircle(Colors.orange),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 70,
                              child: Text(
                                a,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // VS
                        const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: Text(
                            "VS",
                            style: TextStyle(
                              color: _lime,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // 오른쪽 팀 — 아이콘 위 / 이름 아래
                        Column(
                          children: [
                            _teamCircle(Colors.cyan),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 70,
                              child: Text(
                                b,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 장소
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            place,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 오른쪽 인원 + 버튼
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$cur/$max",
                    style: TextStyle(
                      color: closed ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _applyButton(closed),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 팀 아이콘 ----------------
  Widget _teamCircle(Color c) {
    return CircleAvatar(radius: 14, backgroundColor: c);
  }

  // ---------------- 참가 버튼 ----------------
  Widget _applyButton(bool closed) {
    return InkWell(
      onTap: closed
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('참가 신청 완료'),
                  duration: Duration(milliseconds: 700),
                ),
              );
            },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: closed ? Colors.redAccent : _chipBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          closed ? '마감' : '참가 신청',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ---------------- W 아이콘 ----------------
  Widget _wIconSmall() {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1),
      ),
      child: const Center(
        child: Text(
          "W",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
