import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'package:round/add_schedule.dart';

class ClubScheduleScreen extends StatefulWidget {
  final int clubId;
  final String userId;

  const ClubScheduleScreen({
    super.key, 
    required this.clubId, 
    required this.userId
  });

  @override
  State<ClubScheduleScreen> createState() => _ClubScheduleScreenState();
}

class _ClubScheduleScreenState extends State<ClubScheduleScreen> {
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _chipBlue = Color(0xFF60A5FA);
  static const Color _matchChip = Color(0xFFFF5A3C);
  static const Color _panel = Color(0xFF2F2F2F);

  // 날짜 상태
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  final List<int> years = List.generate(10, (i) => DateTime.now().year - 2 + i); // 최근 10년치

  // 데이터 상태
  bool _isLoading = true;
  List<Schedule> _schedules = [];
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  // API 호출: 일정 목록 가져오기
  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/schedules', queryParameters: {
        'club_id': widget.clubId,
        'year': selectedYear,
        'month': selectedMonth,
      });
      
      final List<dynamic> data = response.data['schedules'];
      final List<Schedule> schedules = data.map((json) => Schedule.fromJson(json)).toList();

      setState(() {
        _schedules = data.map((json) => Schedule.fromJson(json)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      print("일정 로딩 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  // 연도/월 변경 시 호출
  void _onDateChanged(int year, int month) {
    setState(() {
      selectedYear = year;
      selectedMonth = month;
    });
    _fetchSchedules(); // 데이터 새로고침
  }

  // ---------------- 연도 선택 BottomSheet ----------------
  void _openYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      builder: (_) => SizedBox(
        height: 300,
        child: ListView(
          children: years.map((y) => InkWell(
            onTap: () {
              Navigator.pop(context);
              _onDateChanged(y, selectedMonth);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Text("$y", style: TextStyle(
                color: selectedYear == y ? Colors.white : Colors.white70,
                fontWeight: selectedYear == y ? FontWeight.w600 : FontWeight.normal,
                fontSize: 18,
              )),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ---------------- 월 선택 BottomSheet ----------------
  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      builder: (_) => SizedBox(
        height: 400,
        child: ListView(
          children: List.generate(12, (i) => i + 1).map((m) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _onDateChanged(selectedYear, m);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                child: Text("$m월", style: TextStyle(
                  color: selectedMonth == m ? Colors.white : Colors.white70,
                  fontWeight: selectedMonth == m ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 18,
                )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------- 데이터 -> UI 매핑 빌더 ----------------
  Widget _buildScheduleItem(Schedule schedule) {
    // 날짜 문자열 파싱 (예: "2023-09-17" -> "9월 17일")
    DateTime dt = DateTime.parse(schedule.startTime);
    final dateDisplay = "${dt.month}월 ${dt.day}일";
    
    // 시간 문자열 생성 (오후 2:30)
    String ampm = dt.hour >= 12 ? '오후' : '오전';
    int hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    if (hour == 0) hour = 12;
    String timeStr = "$hour:${dt.minute.toString().padLeft(2, '0')}";

    // 마감 여부 확인 (현재인원 >= 최대인원)
    final bool isClosed = schedule.currentParticipants >= schedule.maxParticipants;

    if (schedule.isMatch) {
      return _matchCard(
        tag: "동호회 매치",
        date: dateDisplay,
        ap: ampm,       // 수정된 변수 사용
        time: timeStr,  // 수정된 변수 사용
        a: "우리팀",
        b: schedule.opponentName ?? "상대팀",
        place: schedule.location,
        cur: schedule.currentParticipants,
        max: schedule.maxParticipants,
        closed: isClosed,
      );
    } else {
      return _regularCard(
        tag: "정기 모임",
        date: dateDisplay,
        ap: ampm,       // 수정된 변수 사용
        time: timeStr,  // 수정된 변수 사용
        title: schedule.title,
        sub1: schedule.location,
        sub2: schedule.description,
        cur: schedule.currentParticipants,
        max: schedule.maxParticipants,
        closed: isClosed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // AppBar와 BottomNavigationBar는 제거 (부모 화면에서 처리)
      body: Column(
        children: [
          // ---- 연도/월 선택바 ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _dateItem("$selectedYear", _openYearPicker),
                const SizedBox(width: 12),
                _dateItem("$selectedMonth월", _openMonthPicker),
              ],
            ),
          ),

          // ---- 일정 리스트 ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _lime))
                : _schedules.isEmpty
                    ? const Center(
                        child: Text("등록된 일정이 없습니다.", 
                        style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // FAB 공간 확보
                        itemCount: _schedules.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _buildScheduleItem(_schedules[index]);
                        },
                      ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_schedule_add',
        backgroundColor: _lime,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () async {
          // 1. 일정 추가 화면으로 이동
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddScheduleScreen(clubId: widget.clubId)),
          );
          
          // 2. 등록 성공 시(true 반환 시) 목록 새로고침
          if (result == true) {
            _fetchSchedules(); 
          }
        },
      ),
    );
  }

  // ===================== UI Components =====================

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
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _dateTexts(String d, String ap, String t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(d, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        Text(ap, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }

  Widget _leftColumn(Color tagColor, String tagLabel, String d, String ap, String t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tagChip(tagColor, tagLabel),
        const SizedBox(height: 8),
        _dateTexts(d, ap, t),
      ],
    );
  }

  Widget _tagChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  // --- 정기모임 카드 ---
  Widget _regularCard({
    required String tag, required String date, required String ap, required String time,
    required String title, required String sub1, required String sub2,
    required int cur, required int max, required bool closed,
  }) {
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(child: Text(sub1, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _wIconSmall(),
                    const SizedBox(width: 6),
                    Expanded(child: Text(sub2, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("$cur/$max", style: TextStyle(color: closed ? Colors.redAccent : Colors.white70)),
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

  // --- 매치 카드 ---
  Widget _matchCard({
    required String tag, required String date, required String ap, required String time,
    required String a, required String b, required String place,
    required int cur, required int max, required bool closed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tagChip(_matchChip, tag),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 70, child: _dateTexts(date, ap, time)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _teamColumn(a, Colors.orange),
                        const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: Text("VS", style: TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        _teamColumn(b, Colors.cyan),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Flexible(child: Text(place, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("$cur/$max", style: TextStyle(color: closed ? Colors.redAccent : Colors.white70)),
                        const SizedBox(width: 10),
                        _applyButton(closed),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamColumn(String name, Color color) {
    return Column(
      children: [
        CircleAvatar(radius: 18, backgroundColor: color),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _applyButton(bool closed) {
    return InkWell(
      onTap: closed ? null : () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('참가 신청 완료'), duration: Duration(milliseconds: 700)));
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
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _wIconSmall() {
    return Container(
      width: 15, height: 15,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1)),
      child: const Center(child: Text("W", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold))),
    );
  }
}