import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';

class CreateClubScreen extends StatefulWidget {
  final String userId;
  const CreateClubScreen({super.key, required this.userId});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();

  // Round 다크 팔레트
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _border = Color(0xFF444444);
  static const Color _primary = Color(0xFFA3E635); // ✅ 톤다운된 라임
  static const Color _hint = Colors.white54;

  // 드롭다운 옵션
  final List<String> _sports = const ['볼링', '축구', '풋살', '농구', '3x3 농구', '배드민턴'];
  final List<int> _capacityOptions = const [10, 15, 20, 25, 30, 35, 40, 45, 50];

  String? _selectedSport;
  int? _selectedCapacity;

  // 입력 컨트롤러
  final _regionCtrl = TextEditingController(); // 시/군/구
  final _nameCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  // 이미지
  File? _imageFile;
  final _picker = ImagePicker();

  bool _isLoading = false;
  final Dio dio = ApiClient().dio;

  @override
  void dispose() {
    _regionCtrl.dispose();
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _removeImage() => setState(() => _imageFile = null);

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
            child: const Text('확인', style: TextStyle(color: Color(0xFFA3E635), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 중앙 토스트 (페이드 + 스케일)
  Future<void> _showCenterToast() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'center_toast',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B3B3B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '새로운 모임이 시작되었어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 제출: 팝업 0.7s 후 홈으로 이동
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. FormData 생성
      FormData formData = FormData.fromMap({
        'creator_user_id': widget.userId,
        'sport': _selectedSport,
        'region': _regionCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'description': _goalCtrl.text.trim(),
        'max_capacity': _selectedCapacity,
      });

      // 2. 이미지가 있으면 FormData에 파일 추가
      if (_imageFile != null) {
        formData.files.add(MapEntry(
          'club_image',
          await MultipartFile.fromFile(_imageFile!.path, filename: _imageFile!.path.split('/').last),
        ));
      }

      // 3. 서버에 POST 요청
      await dio.post('/create-club', data: formData);

      // 4. 성공 시 토스트 팝업 및 화면 이동 (기존 로직 재사용)
      Future.microtask(() => _showCenterToast());
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 팝업 닫기
      Navigator.pushReplacementNamed(context, '/home', arguments: widget.userId);

    } on DioException catch (e) {
      // 5. Dio 에러 처리
      final errorMessage = e.response?.data['error'] ?? "동호회 생성에 실패했습니다.";
      _showErrorDialog(errorMessage);
    } catch (e) {
      // 6. 기타 에러 처리
      _showErrorDialog("알 수 없는 오류가 발생했습니다.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
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
        bottom: false,
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
                    style: TextStyle(color: Color(0xFFB7F34D), fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),

                // 스포츠 종목
                const Text('스포츠 종목', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSport,
                  items: _sports
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSport = v),
                  dropdownColor: _panel,
                  iconEnabledColor: Colors.white70,
                  decoration: _dec('스포츠 종목 선택'),
                  validator: (v) => v == null ? '스포츠 종목을 선택하세요.' : null,
                ),
                const SizedBox(height: 16),

                // 지역
                const Text('지역', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _regionCtrl,
                  decoration: _dec('시/군/구 입력', hint: '예: 인천 미추홀구'),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '시/군/구를 입력하세요.' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 동호회 이름
                const Text('동호회 이름', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _dec('모임 이름'),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '동호회 이름을 입력하세요.' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 동호회 목표
                const Text('동호회 목표', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _goalCtrl,
                  decoration: _dec('모임 목표를 설명해주세요.'),
                  style: const TextStyle(color: Colors.white),
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) => (v == null || v.trim().isEmpty) ? '동호회 목표를 입력하세요.' : null,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 16),

                // 정원 (10~50, 5단위)
                const Text('정원 (최대 인원)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedCapacity,
                  items: _capacityOptions
                      .map((n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text('$n', style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCapacity = v),
                  dropdownColor: _panel,
                  iconEnabledColor: Colors.white70,
                  decoration: _dec('정원 선택'),
                  validator: (v) => v == null ? '정원을 선택하세요.' : null,
                ),
                const SizedBox(height: 20),

                // 이미지 첨부
                const Text('동호회 이미지', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
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
                            ? const Center(
                                child: Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.white70),
                              )
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

                // ✅ 모임 만들기 버튼 (톤다운 라임)
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
              ? const CircularProgressIndicator(color: Colors.black) // 로딩 인디케이터
              : const Text(
                  '동호회 만들기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
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
}
