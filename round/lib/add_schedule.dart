import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:intl/intl.dart';

class AddScheduleScreen extends StatefulWidget {
  final int clubId;
  const AddScheduleScreen({super.key, required this.clubId});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  // State
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  final Dio dio = ApiClient().dio;
  
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F); // 입력 필드 배경
  static const Color _lime = Color(0xFFB7F34D);
  static const Color _textHint = Color(0xFF9CA3AF);

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black, surface: _panel),
            dialogBackgroundColor: _bg,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black, surface: _panel),
            timePickerTheme: TimePickerThemeData(backgroundColor: _bg),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || 
        _locationController.text.trim().isEmpty || 
        _maxParticipantsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목, 장소, 인원은 필수 입력 항목입니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullDate = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );
      final dateString = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDate);

      await dio.post('/api/schedules', data: {
        'club_id': widget.clubId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'schedule_date': dateString,
        'max_participants': int.parse(_maxParticipantsController.text.trim()),
        'is_match': false, // 친선 경기 토글 삭제로 무조건 false (또는 일반 모임)
        'opponent_name': null,
      });

      if (!mounted) return;
      Navigator.pop(context, true);

    } on DioException catch (e) {
      debugPrint("일정 생성 API 오류: ${e.response?.data}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정 생성에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // 화면 터치 시 키보드 내림
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text('일정 만들기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                onPressed: _isLoading ? null : _submit,
                style: TextButton.styleFrom(
                  backgroundColor: _lime,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  minimumSize: const Size(60, 32),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('완료', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 제목 입력 (가장 크게)
              _buildTitleInput(),
              const SizedBox(height: 30),

              // 2. 날짜 및 시간 선택 (카드형)
              _sectionLabel("일시"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDateTimeCard(
                    label: "날짜",
                    value: DateFormat('M월 d일 (E)', 'ko').format(_selectedDate),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDateTimeCard(
                    label: "시간",
                    value: _selectedTime.format(context),
                    icon: Icons.access_time_rounded,
                    onTap: _pickTime,
                  )),
                ],
              ),
              const SizedBox(height: 30),

              // 3. 장소 및 인원 (아이콘이 있는 입력 필드)
              _sectionLabel("상세 정보"),
              const SizedBox(height: 12),
              _buildIconInput(
                controller: _locationController,
                icon: Icons.location_on_outlined,
                hint: "장소 입력 (예: 인하대 운동장)",
              ),
              const SizedBox(height: 12),
              _buildIconInput(
                controller: _maxParticipantsController,
                icon: Icons.people_outline,
                hint: "최대 모집 인원 (숫자만)",
                isNumber: true,
              ),
              const SizedBox(height: 30),

              // 4. 설명 입력 (넓은 영역)
              _sectionLabel("내용"),
              const SizedBox(height: 12),
              Container(
                height: 150,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _descController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: "일정에 대한 상세 내용을 입력해주세요.\n(예: 준비물, 회비, 주의사항 등)",
                    hintStyle: TextStyle(color: _textHint),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              
              // 하단 여백
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  // 대형 제목 입력 필드
  Widget _buildTitleInput() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        hintText: "제목을 입력하세요",
        hintStyle: TextStyle(color: Colors.white24, fontSize: 24, fontWeight: FontWeight.bold),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  // 날짜/시간 선택 카드
  Widget _buildDateTimeCard({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value, 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 아이콘이 포함된 입력 필드
  Widget _buildIconInput({
    required TextEditingController controller, 
    required IconData icon, 
    required String hint, 
    bool isNumber = false
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.white54),
          hintText: hint,
          hintStyle: const TextStyle(color: _textHint),
          border: InputBorder.none,
        ),
      ),
    );
  }
}