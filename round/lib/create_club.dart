import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'location_search_screen.dart';

class CreateClubScreen extends StatefulWidget {
  final String userId;
  const CreateClubScreen({super.key, required this.userId});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _border = Color(0xFF444444);
  static const Color _primary = Color(0xFFA3E635); // Lime
  static const Color _hint = Colors.white54;

  // Dropdown Options
  final List<String> _sports = const ['볼링', '축구', '풋살', '농구', '3x3 농구', '배드민턴'];
  final List<int> _capacityOptions = const [10, 15, 20, 25, 30, 35, 40, 45, 50];

  // State
  String? _selectedSport;
  int? _selectedCapacity;
  String? _selectedSido;
  String? _selectedSigungu;
  File? _imageFile;
  bool _isLoading = false;

  // Controllers
  final _locationDisplayController = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final Dio dio = ApiClient().dio;

  @override
  void dispose() {
    _locationDisplayController.dispose();
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _removeImage() => setState(() => _imageFile = null);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // FormData 생성
      FormData formData = FormData.fromMap({
        'creator_user_id': widget.userId,
        'sport': _selectedSport,
        'sido': _selectedSido,
        'sigungu': _selectedSigungu,
        'name': _nameCtrl.text.trim(),
        'description': _goalCtrl.text.trim(),
        'max_capacity': _selectedCapacity,
      });

      // 이미지 추가
      if (_imageFile != null) {
        formData.files.add(MapEntry(
          'club_image',
          await MultipartFile.fromFile(_imageFile!.path, filename: _imageFile!.path.split('/').last),
        ));
      }

      await dio.post('/create-club', data: formData);

      // 성공 처리
      if (!mounted) return;
      _showCenterToast();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 팝업 닫기 (있다면)
      Navigator.pushReplacementNamed(context, '/home', arguments: widget.userId);

    } on DioException catch (e) {
      final errorMessage = e.response?.data['error'] ?? "동호회 생성에 실패했습니다.";
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog("알 수 없는 오류가 발생했습니다.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        foregroundColor: Colors.white,
        title: const Text('동호회 개설', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(
                    'Round',
                    style: TextStyle(color: _primary, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),

                // 1. 스포츠 종목
                _buildSectionLabel('스포츠 종목'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSport,
                  items: _sports.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _selectedSport = v),
                  dropdownColor: _panel,
                  iconEnabledColor: Colors.white70,
                  decoration: _inputDecoration('스포츠 종목 선택'),
                  validator: (v) => v == null ? '스포츠 종목을 선택하세요.' : null,
                ),
                const SizedBox(height: 16),

                // 2. 지역 선택
                _buildSectionLabel('지역'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationDisplayController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('모임 지역 선택', hint: '시/군/구로 검색'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '모임 지역을 선택하세요.' : null,
                  onTap: () async {
                    final result = await Navigator.push<LocationData>(
                      context,
                      MaterialPageRoute(builder: (context) => const LocationSearchScreen()),
                    );
                    if (result != null) {
                      setState(() {
                        _selectedSido = result.sido;
                        _selectedSigungu = result.sigungu;
                        _locationDisplayController.text = result.sigungu.isEmpty
                            ? result.sido
                            : "${result.sido} ${result.sigungu}";
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 3. 동호회 이름
                _buildSectionLabel('동호회 이름'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration('모임 이름'),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '동호회 이름을 입력하세요.' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 4. 동호회 목표
                _buildSectionLabel('동호회 목표'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _goalCtrl,
                  decoration: _inputDecoration('모임 목표를 설명해주세요.'),
                  style: const TextStyle(color: Colors.white),
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) => (v == null || v.trim().isEmpty) ? '동호회 목표를 입력하세요.' : null,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 16),

                // 5. 정원
                _buildSectionLabel('정원 (최대 인원)'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedCapacity,
                  items: _capacityOptions.map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _selectedCapacity = v),
                  dropdownColor: _panel,
                  iconEnabledColor: Colors.white70,
                  decoration: _inputDecoration('정원 선택'),
                  validator: (v) => v == null ? '정원을 선택하세요.' : null,
                ),
                const SizedBox(height: 20),

                // 6. 이미지 첨부
                _buildSectionLabel('동호회 이미지'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: _imageFile == null
                            ? const Center(child: Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.white70))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_imageFile!, fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_imageFile != null)
                      TextButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete_outline, color: Colors.white70),
                        label: const Text('이미지 제거', style: TextStyle(color: Colors.white70)),
                      ),
                  ],
                ),

                const SizedBox(height: 28),

                // 7. 완료 버튼
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text(
                            '동호회 만들기',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets & Methods ---

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white));
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: _hint),
      filled: true,
      fillColor: _panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.redAccent),
          SizedBox(width: 10),
          Text('알림', style: TextStyle(color: Colors.white)),
        ]),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCenterToast() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'center_toast',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(color: const Color(0xFF3B3B3B), borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  '새로운 모임이 시작되었어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 16, decoration: TextDecoration.none),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}