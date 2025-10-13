import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- 상태 변수 ---
  int _step = 0; // 주 단계 (0: 본인인증, 1: 인증번호, 2: 세부정보)
  int _infoSubStep = 0; // 0단계의 하위 단계 (0: 이름, 1: 생년월일, 2: 휴대폰)
  bool _isButtonEnabled = false;

  final List<String> _subStepHeadlines = [
    '이름을 입력해 주세요',      // 0단계의 하위 0단계
    '생년월일/성별을 입력해 주세요', // 0단계의 하위 1단계
    '휴대폰번호를 입력해 주세요',   // 0단계의 하위 2단계
  ];

  // --- 컨트롤러 ---
  // (컨트롤러 선언은 기존과 동일)
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderDigitController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- 포커스 노드 ---
  // (포커스 노드 선언은 기존과 동일)
  final _birthDateFocus = FocusNode();
  final _genderDigitFocus = FocusNode();
  final _phoneFocus = FocusNode();

  // --- 타이머 및 이미지 피커 ---
  Timer? _timer;
  int _remainingSeconds = 180;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // 모든 컨트롤러에 리스너 연결
    _nameController.addListener(_updateButtonState);
    _birthDateController.addListener(_updateAutomaticSubSteps); // 하위 단계 자동 전환 리스너
    _genderDigitController.addListener(_updateAutomaticSubSteps);
    _phoneController.addListener(_updateButtonState);
    _codeController.addListener(_updateButtonState);
    _idController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    _confirmPasswordController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    // 모든 컨트롤러 및 리소스 해제 (기존과 동일)
    _nameController.dispose();
    _birthDateController.dispose();
    _genderDigitController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateFocus.dispose();
    _genderDigitFocus.dispose();
    _phoneFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // --- 로직 함수들 ---

  // 버튼 활성화 로직
  void _updateButtonState() {
    bool isEnabled = false;
    // 현재 주 단계(_step)에 따라 버튼 활성화 조건 분기
    switch (_step) {
      case 0: // 본인인증 단계
        // 현재 하위 단계(_infoSubStep)에 따라 버튼 활성화 조건 분기
        if (_infoSubStep == 0) { // 이름 입력 시
          isEnabled = _nameController.text.isNotEmpty;
        } else if (_infoSubStep == 2) { // 휴대폰 입력 시
          isEnabled = _phoneController.text.length == 11;
        }
        break;
      case 1: // 인증번호 확인 단계
        isEnabled = _codeController.text.length == 6;
        break;
      case 2: // 세부정보 입력 단계
        isEnabled = _idController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty &&
            _confirmPasswordController.text.isNotEmpty &&
            _passwordController.text == _confirmPasswordController.text;
        break;
    }
    if (_isButtonEnabled != isEnabled) {
      setState(() {
        _isButtonEnabled = isEnabled;
      });
    }
  }

  // 생년월일 -> 휴대폰 하위 단계 자동 전환 로직
  void _updateAutomaticSubSteps() {
    if (_step == 0 && _infoSubStep == 1) { // 생년월일 입력 단계일 때만 실행
      if (_birthDateController.text.length == 6 &&
          _genderDigitController.text.length == 1) {
        setState(() {
          _infoSubStep = 2; // 휴대폰 입력 하위 단계로 전환
        });
        FocusScope.of(context).requestFocus(_phoneFocus);
      }
    }
    _updateButtonState(); // 버튼 상태도 함께 업데이트
  }

  // 메인 버튼 클릭 로직
  void _onButtonPressed() {
    if (!_isButtonEnabled) return;
    
    // 0단계(본인인증)의 마지막(휴대폰 입력 완료)에서 버튼을 누르면
    if (_step == 0) {
      setState(() {
        _step = 1; // 1단계(인증번호)로 전환
        _isButtonEnabled = false; 
      });
      _startTimer();
      // TODO: 서버에 인증번호 전송 API 호출
    }
    // 1단계(인증번호)에서 버튼을 누르면
    else if (_step == 1) {
      setState(() {
        _step = 2; // 2단계(세부정보)로 전환
        _isButtonEnabled = false;
      });
      _timer?.cancel();
    }
    // 2단계(세부정보)에서 버튼을 누르면
    else if (_step == 2) {
      // TODO: 최종 회원가입 API 호출
      print('회원가입 완료!');
    }
  }

  // 타이머 로직
  void _startTimer() {
    _remainingSeconds = 180;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$sec';
  }

  // 이미지 피커 로직
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // 3. build 메소드 통합
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF262626),
    appBar: AppBar( iconTheme: const IconThemeData(
    color: Colors.white,
  ),backgroundColor: const Color(0xFF262626), // 배경색을 명시적으로 지정
  elevation: 0, // AppBar 하단의 그림자 제거
  ),
    body: LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Round',
                      style: TextStyle(
                          fontFamily: 'WantedSans',
                          color: Color(0xFFB2F142),
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepUI(),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  
                  // ## 1. 이 부분을 수정: 0단계가 아닐 때만 하단 버튼을 표시 ##
                  Visibility(
                    visible: _step == 2, // 1단계 또는 2단계일 때만 보임
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isButtonEnabled ? _onButtonPressed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB2F142),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              const Color(0xFFB2F142).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('가입',
                            style: const TextStyle(
                                fontFamily: 'WantedSans',
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }),
  );
}


  // 4. 각 단계별 UI 빌더 함수
  // 현재 단계(_step)에 따라 적절한 UI 위젯을 반환
  Widget _buildStepUI() {
    switch (_step) {
      case 0:
        return _buildStep0_VerificationInfo();
      case 1:
        return _buildStep1_VerifyCode();
      case 2:
        return _buildStep2_UserDetails();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0_VerificationInfo() {
  return Column(
    key: const ValueKey(0),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('휴대폰 본인확인이 필요합니다',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
      const SizedBox(height: 12),
      Text(
        _subStepHeadlines[_infoSubStep],
        style: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white),
      ),
      const SizedBox(height: 30),

      // 이름 입력 필드
      TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(hint: '이름')),

      // 이름 입력 단계에서만 보이는 '다음' 버튼
      Visibility(
        visible: _infoSubStep == 0,
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isButtonEnabled
                  ? () {
                      setState(() {
                        _infoSubStep = 1;
                      });
                      FocusScope.of(context).requestFocus(_birthDateFocus);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB2F142),
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    const Color(0xFFB2F142).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),

      // 생년월일 입력 UI
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: Visibility(
          visible: _infoSubStep >= 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('생년월일/성별',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildBirthDateInput(),
            ],
          ),
        ),
      ),

      // 휴대폰 입력 UI
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: Visibility(
          visible: _infoSubStep >= 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('휴대폰번호',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '휴대폰번호')),
              
              // ## 2. 이 부분에 '인증번호 전송' 버튼을 직접 추가 ##
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isButtonEnabled ? _onButtonPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB2F142),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          const Color(0xFFB2F142).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('인증번호 전송',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// 1단계: 인증번호 확인 UI
Widget _buildStep1_VerifyCode() {
  return Column(
    key: const ValueKey(1),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('보내드린 인증번호 6자리를 입력해주세요', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 22, color: Colors.white)),
      const SizedBox(height: 30),
      Row(children: [
        Expanded(child: TextField(controller: _codeController, maxLength: 6, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration(hint: '인증번호'))),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () { _startTimer(); /* TODO: 재발송 API */ },
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('재발송'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(100, 58), side: BorderSide(color: Colors.white.withOpacity(0.6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.timer_outlined, color: Colors.grey[400], size: 20),
          const SizedBox(width: 8),
          Text('남은시간', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(width: 8),
          Text(_formatDuration(_remainingSeconds), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(onPressed: () {}, child: Text('시간연장', style: TextStyle(color: Colors.grey[400], decoration: TextDecoration.underline))),
        ]),
      ),

      // ## 2. 타이머 밑에 버튼을 추가하고 Spacer는 제거합니다. ##
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isButtonEnabled ? _onButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB2F142),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('인증번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );
}
// 2단계: 세부정보 입력 UI
Widget _buildStep2_UserDetails() {
  final bool passwordsMatch = _passwordController.text == _confirmPasswordController.text;

  return Column(
    key: const ValueKey(2),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('몇 가지 정보만 입력하면,\n바로 시작할 수 있어요.', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 22, color: Colors.grey[300])),
      const SizedBox(height: 40),
      _buildTextFieldSection(controller: _idController, label: '아이디', hint: '아이디 입력'),
      const SizedBox(height: 24),
      _buildTextFieldSection(controller: _passwordController, label: '비밀번호 입력', hint: '비밀번호 입력', isPassword: true),
      const SizedBox(height: 24),
      
      // ## '비밀번호 확인' 부분을 별도로 구현 ##
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('비밀번호 확인', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration(hint: '비밀번호 재입력'),
          ),
          // 확인 메시지를 보여주는 UI
          Visibility(
            // 비밀번호 확인 필드에 텍스트가 있을 때만 메시지를 표시
            visible: _confirmPasswordController.text.isNotEmpty,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                passwordsMatch ? '비밀번호가 일치합니다.' : '비밀번호가 일치하지 않습니다.',
                style: TextStyle(
                  color: passwordsMatch ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text('프로필 사진', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
          child: Center(child: _profileImage == null ? _buildPlaceholder() : _buildProfileImage()),
        ),
      ),
    ],
  );
}

// -- 이하 Helper 위젯 및 함수들 --

Widget _buildBirthDateInput() {
  return Row(children: [
    Expanded(flex: 2, child: TextField(controller: _birthDateController, focusNode: _birthDateFocus, style: const TextStyle(color: Colors.white, fontSize: 16), keyboardType: TextInputType.number, maxLength: 6, onChanged: (v) { if (v.length == 6) FocusScope.of(context).requestFocus(_genderDigitFocus); }, decoration: _buildInputDecoration(hint: '생년월일 6자리'))),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text('-', style: TextStyle(color: Colors.white, fontSize: 20))),
    Expanded(flex: 1, child: TextField(controller: _genderDigitController, focusNode: _genderDigitFocus, style: const TextStyle(color: Colors.white, fontSize: 16), keyboardType: TextInputType.number, maxLength: 1, decoration: _buildInputDecoration())),
    const SizedBox(width: 8),
    ...List.generate(6, (index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.circle, color: Colors.grey[700], size: 10))),
  ]);
}

Widget _buildTextFieldSection({required TextEditingController controller, required String label, required String hint, bool isPassword = false}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    const SizedBox(height: 12),
    TextField(controller: controller, obscureText: isPassword, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration(hint: hint)),
  ]);
}

Widget _buildProfileImage() {
  return CircleAvatar(radius: 60, backgroundImage: FileImage(_profileImage!));
}

Widget _buildPlaceholder() {
  return Container(
    width: 100, height: 100,
    decoration: BoxDecoration(color: Colors.grey.shade700.withOpacity(0.8), shape: BoxShape.circle),
    child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 40),
  );
}

InputDecoration _buildInputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
    counterText: '',
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5)),
  );
}
}
