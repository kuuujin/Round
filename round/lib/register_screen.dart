import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/location_search_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with CodeAutoFill {
  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _lime = Color(0xFFB2F142);
  static const Color _error = Colors.redAccent;

  // Controllers
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderDigitController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _primaryLocationController = TextEditingController();
  final _secondaryLocationController = TextEditingController();

  // Focus Nodes
  final _birthDateFocus = FocusNode();
  final _genderDigitFocus = FocusNode();
  final _phoneFocus = FocusNode();

  // State Variables
  bool _isLoading = false;
  int _step = 0; // 0: 본인인증, 1: 인증번호, 2: 세부정보
  int _infoSubStep = 0; // 0단계의 내부 단계 (0:이름 -> 1:생년월일 -> 2:휴대폰)
  bool _isButtonEnabled = false;
  
  String? _birthDateErrorText;
  String? _genderErrorText;
  
  // Data Variables
  String? _primarySido;
  String? _primarySigungu;
  String? _secondarySido;
  String? _secondarySigungu;
  File? _profileImage;
  
  // Utils
  Timer? _timer;
  int _remainingSeconds = 180;
  final Dio dio = ApiClient().dio;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    listenForCode(); // SMS Autofill

    // 리스너 등록
    final controllers = [
      _nameController, _phoneController, _codeController,
      _idController, _passwordController, _confirmPasswordController,
      _primaryLocationController, _secondaryLocationController
    ];
    for (var c in controllers) {
      c.addListener(_updateButtonState);
    }
    
    // 생년월일 자동 이동 로직
    _birthDateController.addListener(_updateAutomaticSubSteps);
    _genderDigitController.addListener(_updateAutomaticSubSteps);
  }

  @override
  void dispose() {
    cancel(); // SMS Autofill 해제
    _timer?.cancel();
    
    _nameController.dispose();
    _birthDateController.dispose();
    _genderDigitController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _primaryLocationController.dispose();
    _secondaryLocationController.dispose();
    
    _birthDateFocus.dispose();
    _genderDigitFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  void codeUpdated() {
    setState(() {
      _codeController.text = code ?? '';
    });
  }

  // --- Logic Methods ---

  void _updateButtonState() {
    bool isEnabled = false;
    switch (_step) {
      case 0:
        if (_infoSubStep == 0) isEnabled = _nameController.text.isNotEmpty;
        else if (_infoSubStep == 2) isEnabled = _phoneController.text.length == 11;
        break;
      case 1:
        isEnabled = _codeController.text.length == 6;
        break;
      case 2:
        isEnabled = _idController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty &&
            _confirmPasswordController.text.isNotEmpty &&
            _primaryLocationController.text.isNotEmpty &&
            _passwordController.text == _confirmPasswordController.text;
        break;
    }
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  void _updateAutomaticSubSteps() {
    if (_step != 0 || _infoSubStep != 1) return;

    final birth = _birthDateController.text;
    final gender = _genderDigitController.text;

    // 생년월일 유효성
    if (birth.length == 6) {
      final isValid = _validateBirthDate(birth);
      setState(() => _birthDateErrorText = isValid ? null : '올바른 날짜 형식이 아닙니다.');
      
      // 생년월일 완료 시 성별로 포커스
      if (isValid && _birthDateFocus.hasFocus) {
        FocusScope.of(context).requestFocus(_genderDigitFocus);
      }
    } else {
      if (_birthDateErrorText != null) setState(() => _birthDateErrorText = null);
    }

    // 성별 유효성 및 다음 단계 이동
    if (gender.isNotEmpty) {
      if (['1', '2', '3', '4'].contains(gender)) {
        setState(() => _genderErrorText = null);
        if (birth.length == 6 && _birthDateErrorText == null) {
          // 모두 완료되면 다음 서브 스텝(휴대폰)으로
          setState(() => _infoSubStep = 2);
          FocusScope.of(context).requestFocus(_phoneFocus);
        }
      } else {
        setState(() => _genderErrorText = '올바른 성별 코드가 아닙니다.');
      }
    }
  }

  bool _validateBirthDate(String yymmdd) {
    if (yymmdd.length != 6) return false;
    try {
      final m = int.parse(yymmdd.substring(2, 4));
      final d = int.parse(yymmdd.substring(4, 6));
      if (m < 1 || m > 12) return false;
      if (d < 1 || d > 31) return false;
      if ([4, 6, 9, 11].contains(m) && d > 30) return false;
      if (m == 2 && d > 29) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- API Calls ---

  Future<void> _checkPhoneNumber() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post('/check-phone', data: {'phone': _phoneController.text});
      if (response.data['exists'] == true) {
        _showErrorDialogWithAction(
          '이미 가입된 번호입니다. 로그인 화면으로 이동하시겠습니까?',
          () {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/login');
          },
        );
      } else {
        _sendVerificationRequest();
      }
    } on DioException {
      _showErrorDialog('서버 통신 오류');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendVerificationRequest() async {
    try {
      final response = await dio.post('/send-verification', data: {'phone': _phoneController.text});
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _step = 1;
          _isButtonEnabled = false;
        });
        _startTimer();
      }
    } catch (e) {
      _showErrorDialog('인증번호 발송 실패');
    }
  }

  Future<void> _verifyCodeWithServer() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post('/verify-code', data: {'code': _codeController.text});
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _step = 2; // 세부 정보 입력 단계로
          _isButtonEnabled = false;
        });
        _timer?.cancel();
      }
    } on DioException catch (e) {
      _showErrorDialog(e.response?.data['error'] ?? '인증 실패');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    if (_profileImage == null) {
      // (선택 사항) 프로필 이미지가 필수가 아니라면 제거 가능
      // _showErrorDialog("프로필 이미지를 설정해주세요.");
      // return;
    }

    setState(() => _isLoading = true);
    try {
      // 성별 변환
      final g = _genderDigitController.text;
      final gender = (g == '1' || g == '3') ? 'Male' : 'Female';

      FormData formData = FormData.fromMap({
        'name': _nameController.text,
        'birthdate': _birthDateController.text,
        'gender': gender,
        'phone': _phoneController.text,
        'user_id': _idController.text,
        'password': _passwordController.text,
        'primary_sido': _primarySido,
        'primary_sigungu': _primarySigungu,
        'secondary_sido': _secondarySido,
        'secondary_sigungu': _secondarySigungu,
      });

      if (_profileImage != null) {
        formData.files.add(MapEntry(
          'profile_image',
          await MultipartFile.fromFile(_profileImage!.path, filename: _profileImage!.path.split('/').last),
        ));
      }

      await dio.post('/register', data: formData);
      
      if (!mounted) return;
      _showSuccessDialog('회원가입이 완료되었습니다!');

    } on DioException catch (e) {
      _showErrorDialog(e.response?.data['error'] ?? '회원가입 실패');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Utils ---

  void _onButtonPressed() {
    if (_isLoading) return;
    if (_step == 0) {
      _checkPhoneNumber();
    } else if (_step == 1) {
      _verifyCodeWithServer();
    } else if (_step == 2) {
      _registerUser();
    }
  }

  void _startTimer() {
    _remainingSeconds = 180;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
        else _timer?.cancel();
      });
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // 화면 터치 시 키보드 내림
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: _lime, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 40),
              
              // 단계별 UI 전환 애니메이션
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepUI(),
              ),
              
              const SizedBox(height: 40),

              // 하단 버튼 (이름/생년월일 단계에서는 숨김, 나머지 단계에서 표시)
              if (_step != 0 || _infoSubStep == 2)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isButtonEnabled && !_isLoading) ? _onButtonPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lime,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: _lime.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(_getButtonText(), style: const TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    if (_step == 0) return '인증번호 전송';
    if (_step == 1) return '인증번호 확인';
    return '가입';
  }

  Widget _buildStepUI() {
    switch (_step) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      default: return const SizedBox.shrink();
    }
  }

  // --- Step 0: 기본 정보 & 본인인증 ---
  Widget _buildStep0() {
    final headlines = ['이름을 입력해 주세요', '생년월일/성별을 입력해 주세요', '휴대폰번호를 입력해 주세요'];
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('휴대폰 본인확인이 필요합니다', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        const SizedBox(height: 12),
        Text(headlines[_infoSubStep], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
        const SizedBox(height: 30),

        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(hint: '이름'),
        ),

        // 이름 입력 후 '다음' 버튼
        if (_infoSubStep == 0)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isButtonEnabled ? () {
                  setState(() => _infoSubStep = 1);
                  FocusScope.of(context).requestFocus(_birthDateFocus);
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, disabledBackgroundColor: _lime.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('다음', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

        // 생년월일 UI
        if (_infoSubStep >= 1) _buildBirthGenderInput(),

        // 휴대폰 번호 UI
        if (_infoSubStep >= 2) ...[
          const SizedBox(height: 24),
          const Text('휴대폰번호', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.number,
            maxLength: 11,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(hint: '휴대폰번호'),
          ),
        ],
      ],
    );
  }

  Widget _buildBirthGenderInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('생년월일/성별', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _birthDateController,
                focusNode: _birthDateFocus,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: _inputDecoration(hint: '생년월일 6자리').copyWith(
                  helperText: _birthDateErrorText ?? ' ',
                  helperStyle: TextStyle(color: _birthDateErrorText != null ? _error : Colors.transparent, height: 0.8),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(12, 18, 12, 0), child: Text('-', style: TextStyle(color: Colors.white, fontSize: 20))),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _genderDigitController,
                focusNode: _genderDigitFocus,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: TextInputType.number,
                maxLength: 1,
                obscureText: true, // 보안을 위해 가림
                decoration: _inputDecoration().copyWith(
                  helperText: _genderErrorText ?? ' ',
                  helperStyle: TextStyle(color: _genderErrorText != null ? _error : Colors.transparent, height: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Row(
                children: List.generate(6, (i) => const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.circle, color: Colors.grey, size: 8))),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 1: 인증번호 입력 ---
  Widget _buildStep1() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('보내드린 인증번호 6자리를 입력해주세요', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 22, color: Colors.white)),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 16),
                cursorColor: _lime,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () { _sendVerificationRequest(); _startTimer(); },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('재발송'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(90, 50), side: BorderSide(color: Colors.white.withOpacity(0.6))),
            )
          ],
        ),
        const Divider(color: Colors.white54),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text('남은시간', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(width: 8),
            Text('${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}', 
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  // --- Step 2: 세부 정보 입력 ---
  Widget _buildStep2() {
    final bool passwordsMatch = _passwordController.text == _confirmPasswordController.text;
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('몇 가지 정보만 입력하면,\n바로 시작할 수 있어요.', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 22, color: Colors.grey[300])),
        const SizedBox(height: 40),
        
        _buildTextFieldSection('아이디', _idController, '아이디 입력'),
        const SizedBox(height: 24),
        _buildTextFieldSection('비밀번호', _passwordController, '비밀번호 입력', isPassword: true),
        const SizedBox(height: 24),
        
        _buildTextFieldSection('비밀번호 확인', _confirmPasswordController, '비밀번호 재입력', isPassword: true),
        if (_confirmPasswordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(passwordsMatch ? '일치합니다.' : '일치하지 않습니다.', style: TextStyle(color: passwordsMatch ? Colors.greenAccent : _error, fontSize: 12)),
          ),

        const SizedBox(height: 24),
        const Text('주 활동지역 (거주지)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _primaryLocationController,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(hint: '동·읍·면으로 검색'),
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationSearchScreen()));
            if (result != null) {
              setState(() {
                _primarySido = result.sido;
                _primarySigungu = result.sigungu;
                _primaryLocationController.text = "${result.sido} ${result.sigungu}";
              });
            }
          },
        ),

        const SizedBox(height: 24),
        const Text('부 활동지역 (선택)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _secondaryLocationController,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(hint: '동·읍·면으로 검색'),
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationSearchScreen()));
            if (result != null) {
              setState(() {
                _secondarySido = result.sido;
                _secondarySigungu = result.sigungu;
                _secondaryLocationController.text = "${result.sido} ${result.sigungu}";
              });
            }
          },
        ),

        const SizedBox(height: 24),
        const Text('프로필 사진', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
              child: _profileImage == null ? Icon(Icons.add_a_photo, color: Colors.grey[400], size: 40) : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldSection(String label, TextEditingController ctrl, String hint, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime, width: 1.5)),
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('가입 완료', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('로그인하기', style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    _showErrorDialogWithAction(message, () => Navigator.pop(context));
  }

  void _showErrorDialogWithAction(String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Row(children: [Icon(Icons.error_outline, color: _error), SizedBox(width: 10), Text('알림', style: TextStyle(color: Colors.white))]),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: onConfirm, child: const Text('확인', style: TextStyle(color: _lime))),
        ],
      ),
    );
  }
}