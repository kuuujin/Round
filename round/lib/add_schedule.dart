// lib/add_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅용

class AddScheduleScreen extends StatefulWidget {
  final int clubId;
  const AddScheduleScreen({super.key, required this.clubId});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _opponentController = TextEditingController(); // 상대팀 이름 (매치일 경우)

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isMatch = false; // 경기 여부 체크박스
  bool _isLoading = false;

  final Dio dio = ApiClient().dio;
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB7F34D);

  // 날짜 선택
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // 시간 선택
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _lime, onPrimary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _locationController.text.isEmpty || _maxParticipantsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필수 정보를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 날짜와 시간을 합쳐서 DateTime 생성 -> String 변환
      final fullDate = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );
      final dateString = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDate);

      await dio.post('/api/schedules', data: {
        'club_id': widget.clubId,
        'title': _titleController.text,
        'description': _descController.text,
        'location': _locationController.text,
        'schedule_date': dateString,
        'max_participants': int.parse(_maxParticipantsController.text),
        'is_match': _isMatch,
        'opponent_name': _isMatch ? _opponentController.text : null,
      });

      if (!mounted) return;
      Navigator.pop(context, true); // 성공 시 true 반환

    } on DioException catch (e) {
      print("일정 생성 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('일정 생성에 실패했습니다.')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('일정 추가', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: const Text('완료', style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            _buildTextField(_titleController, '일정 제목 (예: 정기모임)', isRequired: true),
            const SizedBox(height: 16),

            // 날짜 및 시간 선택 Row
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.calendar_today,
                    text: DateFormat('yyyy-MM-dd').format(_selectedDate),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.access_time,
                    text: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 장소
            _buildTextField(_locationController, '장소 (예: 정석항공고 운동장)', isRequired: true),
            const SizedBox(height: 16),

            // 최대 인원
            _buildTextField(_maxParticipantsController, '최대 참가 인원 (숫자만)', isNumber: true, isRequired: true),
            const SizedBox(height: 16),

            // 설명
            _buildTextField(_descController, '상세 설명', maxLines: 3),
            const SizedBox(height: 24),

            // 매치 여부 스위치
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('친선 경기(매치) 인가요?', style: TextStyle(color: Colors.white)),
                activeColor: _lime,
                value: _isMatch,
                onChanged: (val) => setState(() => _isMatch = val),
              ),
            ),
            
            // 매치일 경우 상대팀 이름 입력
            if (_isMatch) ...[
              const SizedBox(height: 16),
              _buildTextField(_opponentController, '상대팀 이름'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {bool isNumber = false, int maxLines = 1, bool isRequired = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: isRequired ? '$hint *' : hint,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPickerButton({required IconData icon, required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _lime, size: 20),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}