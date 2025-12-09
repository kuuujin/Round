import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅 필수
import 'package:round/api_client.dart';
import 'package:round/models/club_models.dart';
import 'package:round/add_schedule.dart'; // 파일명 확인

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

  // Date State
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  final List<int> _years = List.generate(10, (i) => DateTime.now().year - 2 + i);

  // Data State
  bool _isLoading = true;
  List<Schedule> _schedules = [];
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get('/api/schedules', queryParameters: {
        'club_id': widget.clubId,
        'year': _selectedYear,
        'month': _selectedMonth,
      });
      
      final List<dynamic> data = response.data['schedules'];
      
      if (mounted) {
        setState(() {
          _schedules = data.map((json) => Schedule.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint("일정 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDateChanged(int year, int month) {
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
    });
    _fetchSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // 1. 연도/월 선택 필터
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildDropdownItem("$_selectedYear", _openYearPicker),
                const SizedBox(width: 12),
                _buildDropdownItem("$_selectedMonth월", _openMonthPicker),
              ],
            ),
          ),

          // 2. 일정 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _lime))
                : _schedules.isEmpty
                    ? const Center(child: Text("등록된 일정이 없습니다.", style: TextStyle(color: Colors.white38)))
                    : RefreshIndicator(
                        color: _lime,
                        backgroundColor: _panel,
                        onRefresh: _fetchSchedules,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _schedules.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 16),
                          itemBuilder: (context, index) => _buildScheduleItem(_schedules[index]),
                        ),
                      ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_schedule_add',
        backgroundColor: _lime,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddScheduleScreen(clubId: widget.clubId)),
          );
          if (result == true) {
            _fetchSchedules(); 
          }
        },
      ),
    );
  }

  // --- Bottom Sheets ---

  void _openYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      builder: (_) => SizedBox(
        height: 300,
        child: ListView(
          children: _years.map((y) => ListTile(
            title: Text("$y년", style: TextStyle(color: _selectedYear == y ? _lime : Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _onDateChanged(y, _selectedMonth);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      builder: (_) => SizedBox(
        height: 400,
        child: ListView.builder(
          itemCount: 12,
          itemBuilder: (context, index) {
            final m = index + 1;
            return ListTile(
              title: Text("$m월", style: TextStyle(color: _selectedMonth == m ? _lime : Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _onDateChanged(_selectedYear, m);
              },
            );
          },
        ),
      ),
    );
  }

  // --- Item Builders ---

  Widget _buildDropdownItem(String text, VoidCallback onTap) {
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

  Widget _buildScheduleItem(Schedule schedule) {
    // DateTime parsing & formatting
    DateTime dt;
    try {
      dt = DateTime.parse(schedule.startTime); // "2023-09-17 14:30:00"
    } catch (e) {
      dt = DateTime.now(); // Fallback
    }

    final dateDisplay = DateFormat('M월 d일').format(dt);
    final ampm = DateFormat('a', 'ko').format(dt); // "오전" or "오후" (로케일 설정 필요할 수 있음)
    final timeStr = DateFormat('h:mm').format(dt);

    final bool isClosed = schedule.currentParticipants >= schedule.maxParticipants;

    if (schedule.isMatch) {
      return _buildMatchCard(
        tag: "동호회 매치",
        date: dateDisplay, ampm: ampm, time: timeStr,
        myTeam: "우리팀", opponent: schedule.opponentName ?? "상대팀",
        location: schedule.location,
        cur: schedule.currentParticipants, max: schedule.maxParticipants,
        isClosed: isClosed,
      );
    } else {
      return _buildRegularCard(
        tag: "정기 모임",
        date: dateDisplay, ampm: ampm, time: timeStr,
        title: schedule.title,
        location: schedule.location, description: schedule.description,
        cur: schedule.currentParticipants, max: schedule.maxParticipants,
        isClosed: isClosed,
      );
    }
  }

  // 정기 모임 카드
  Widget _buildRegularCard({
    required String tag, required String date, required String ampm, required String time,
    required String title, required String location, required String description,
    required int cur, required int max, required bool isClosed,
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
          _buildDateColumn(_chipBlue, tag, date, ampm, time),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _iconText(Icons.location_on_outlined, location),
                const SizedBox(height: 6),
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("$cur/$max", style: TextStyle(color: isClosed ? Colors.redAccent : Colors.white70)),
                    const SizedBox(width: 10),
                    _buildApplyButton(isClosed),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // 매치 카드
  Widget _buildMatchCard({
    required String tag, required String date, required String ampm, required String time,
    required String myTeam, required String opponent, required String location,
    required int cur, required int max, required bool isClosed,
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
              SizedBox(
                width: 60,
                child: Column(
                  children: [
                    Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("$ampm $time", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTeamAvatar(myTeam, Colors.orange),
                        const Text("VS", style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
                        _buildTeamAvatar(opponent, Colors.cyan),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _iconText(Icons.location_on_outlined, location),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("$cur/$max", style: TextStyle(color: isClosed ? Colors.redAccent : Colors.white70)),
                        const SizedBox(width: 10),
                        _buildApplyButton(isClosed),
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

  // Helper Widgets
  Widget _buildDateColumn(Color color, String label, String date, String ampm, String time) {
    return Column(
      children: [
        _tagChip(color, label),
        const SizedBox(height: 8),
        Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(ampm, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _tagChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTeamAvatar(String name, Color color) {
    return Column(
      children: [
        CircleAvatar(radius: 18, backgroundColor: color),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, 
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildApplyButton(bool isClosed) {
    return InkWell(
      onTap: isClosed ? null : () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('참가 신청 완료'), duration: Duration(milliseconds: 700)));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isClosed ? Colors.redAccent : _chipBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(isClosed ? '마감' : '참가 신청', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}