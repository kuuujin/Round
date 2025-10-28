import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:round/api_client.dart';
import 'package:dio/dio.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with CodeAutoFill {
  // --- 상태 변수 ---
  bool _isLoading = false;
  int _step = 0; // 주 단계 (0: 본인인증, 1: 인증번호, 2: 세부정보)
  int _infoSubStep = 0; // 0단계의 하위 단계 (0: 이름, 1: 생년월일, 2: 휴대폰)
  bool _isButtonEnabled = false;
  String? _genderErrorText;
  String? _birthDateErrorText;

  final Dio dio = ApiClient().dio;
  final List<String> _subStepHeadlines = [
    '이름을 입력해 주세요',      // 0단계의 하위 0단계
    '생년월일/성별을 입력해 주세요', // 0단계의 하위 1단계
    '휴대폰번호를 입력해 주세요',   // 0단계의 하위 2단계
  ];

  bool _validateBirthDate(String yymmdd) {
  if (yymmdd.length != 6) return false;

  try {
    // 월(MM)과 일(DD)을 숫자로 변환합니다.
    final month = int.parse(yymmdd.substring(2, 4));
    final day = int.parse(yymmdd.substring(4, 6));

    // 1. 월이 1~12 사이인지 확인
    if (month < 1 || month > 12) return false;
    // 2. 일이 1~31 사이인지 확인
    if (day < 1 || day > 31) return false;

    // 3. 각 월의 마지막 날짜보다 큰일이 입력되었는지 확인
    if ([4, 6, 9, 11].contains(month) && day > 30) {
      // 30일까지 있는 달
      return false;
    } else if (month == 2 && day > 29) {
      // 2월 (윤년 고려하여 29일까지 허용)
      return false;
    }

    return true; // 모든 검사를 통과하면 유효
  } catch (e) {
    // 숫자로 변환 중 에러가 나면 유효하지 않음
    return false;
  }
}

  Future<void> _sendVerificationRequest() async {
    try {
      final response = await dio.post(
        '/send-verification',
        data: {
          'phone': _phoneController.text,
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _step = 1;
          _isButtonEnabled = false;
        });
        _startTimer();
      }
    } on DioException catch (e) { 
      _showErrorDialog('인증번호 요청에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
  }
  
  // 서버에 인증번호가 맞는지 확인을 요청하는 함수 (Dio 버전)
  Future<void> _verifyCodeWithServer() async {
    try {
      final response = await dio.post(
        '/verify-code',
        data: {
          'code': _codeController.text,
        },
      );
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _step = 2;
          _isButtonEnabled = false;
        });
        _timer?.cancel();
      }
    } on DioException catch (e) {
    // 👇👇👇 이 부분도 안전하게 바꿔줍니다 👇👇👇

    String errorMessage = '인증에 실패했습니다.';
    if (e.response?.data is Map) {
      errorMessage = e.response?.data['error'] ?? errorMessage;
    }
    
    print('인증 실패: ${e.response?.data}');
    _showErrorDialog(errorMessage);
  }
}

// 휴대폰 번호가 이미 가입되었는지 서버에 확인하는 함수
Future<void> _checkPhoneNumber() async {
  setState(() { _isLoading = true; });
  try {
    final response = await dio.post(
      '/check-phone',
      data: {'phone': _phoneController.text},
    );

    if (response.statusCode == 200 && response.data['exists'] == true) {
      // 이미 가입된 번호일 경우
      _showErrorDialogWithAction(
        '이미 가입된 번호입니다. 로그인 화면으로 이동하시겠습니까?',
        () {
          Navigator.of(context).pop(); // 다이얼로그 닫기
          Navigator.of(context).pushReplacementNamed('/login'); // 로그인 화면으로 이동
        },
      );
    } else {
      // 가입되지 않은 번호면 인증번호 전송 진행
      _sendVerificationRequest();
    }
  } on DioException {
    _showErrorDialog('서버와 통신 중 오류가 발생했습니다.');
  } finally {
    setState(() { _isLoading = false; });
  }
}

// 로그인 화면 이동 버튼이 포함된 에러 다이얼로그
void _showErrorDialogWithAction(String message, VoidCallback onConfirm) {
  if (!mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('알림'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
        TextButton(onPressed: onConfirm, child: const Text('이동')),
      ],
    ),
  );
}

  Future<void> _registerUser() async {
    
    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      String fileName = _profileImage!.path.split('/').last;
      final String genderDigit = _genderDigitController.text;
    String genderValue;

    if (genderDigit == '1' || genderDigit == '3') {
      genderValue = 'Male';
    } else if (genderDigit == '2' || genderDigit == '4') {
      genderValue = 'Female';
    } else {
      // 혹시 모를 예외 처리
      _showErrorDialog('올바른 성별 값이 아닙니다.');
      setState(() { _isLoading = false; });
      return;
    }

      // 1. 텍스트 데이터와 이미지 파일을 FormData로 묶습니다.
      FormData formData = FormData.fromMap({
        'name': _nameController.text,
        'birthdate': _birthDateController.text,
        'gender': genderValue,
        'phone': _phoneController.text,
        'user_id': _idController.text,
        'password': _passwordController.text,
        'profile_image': await MultipartFile.fromFile(
          _profileImage!.path,
          filename: fileName,
        ),
      });

      if (_profileImage != null) {
      String fileName = _profileImage!.path.split('/').last;
      formData.files.add(MapEntry(
        'profile_image',
        await MultipartFile.fromFile(_profileImage!.path, filename: fileName),
      ));
    }

      // 2. 서버에 POST 요청을 보냅니다.
      final response = await dio.post('/register', data: formData);

      if (response.statusCode == 201) {
        _showSuccessDialog('회원가입이 완료되었습니다!');
      }

    } on DioException catch (e) {
      String errorMessage = '회원가입에 실패했습니다. 다시 시도해주세요.'; // 1. 기본 에러 메시지를 준비합니다.
    
    // 2. 서버 응답이 Map 형태인지 먼저 확인합니다.
    if (e.response?.data is Map) {
      // 3. Map이 맞으면 'error' 키로 메시지를 찾습니다.
      errorMessage = e.response?.data['error'] ?? errorMessage;
    }
    // 만약 다른 형태의 응답(예: 단순 텍스트)도 처리하고 싶다면 여기에 추가할 수 있습니다.
    // else if (e.response?.data is String) { errorMessage = e.response.data; }

    _showErrorDialog(errorMessage); // 4. 안전하게 처리된 메시지를 다이얼로그에 전달합니다.

  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  // 가입 성공 시 보여줄 다이얼로그
  void _showSuccessDialog(String message) {
  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false, // 바깥 영역을 눌러도 닫히지 않도록 설정
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF333333),
      title: const Text('가입 완료', style: TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () {
            // 👇👇👇 여기에 로그인 화면으로 이동하는 코드를 추가합니다. 👇👇👇
            Navigator.of(ctx).pop(); // 먼저 다이얼로그를 닫고,
            Navigator.of(context).pushReplacementNamed('/login'); // 로그인 화면으로 이동
          },
          child: const Text('로그인 화면으로', style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

  void _showErrorDialog(String message) {
    if (!mounted) return; // 위젯이 화면에 없을 때는 실행하지 않음

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333), 
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                '오류 발생',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '확인',
                style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop(); //
              },
            ),
          ],
        );
      },
    );
  }



  // --- 컨트롤러 ---
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderDigitController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- 포커스 노드 ---
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
    listenForCode();
    // 모든 컨트롤러에 리스너 연결
    _nameController.addListener(_updateButtonState);
    // _birthDateController.addListener(_updateAutomaticSubSteps); // 하위 단계 자동 전환 리스너
    // _genderDigitController.addListener(_updateAutomaticSubSteps);
    _phoneController.addListener(_updateButtonState);
    _codeController.addListener(_updateButtonState);
    _idController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    _confirmPasswordController.addListener(_updateButtonState);
  }


  @override
  void dispose() {
    cancel();
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


  // CodeAutoFill mixin을 사용하기 위해 구현해야 하는 메소드
  @override
  void codeUpdated() {
    // SMS에서 코드가 감지되면 이 함수가 호출됩니다.
    // _codeController.text에 자동으로 값이 채워집니다.
    setState(() {
      _codeController.text = code!;
    });
  }

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
  if (_step == 0 && _infoSubStep == 1) {
    final birthDate = _birthDateController.text;
    final genderDigit = _genderDigitController.text;
    bool isBirthDateValid = true;
    
    // --- 생년월일 유효성 검사 ---
    if (birthDate.length == 6) {
      isBirthDateValid = _validateBirthDate(birthDate);
      setState(() {
        _birthDateErrorText = isBirthDateValid ? null : '올바른 날짜 형식이 아닙니다.';
      });
    } else {
      setState(() { _birthDateErrorText = null; });
    }
    
    // 성별 입력란에 한 글자가 입력되었는지 확인
    if (genderDigit.length == 1) {
      // 1, 2, 3, 4 중 하나가 맞는지 검사
      if (['1', '2', '3', '4'].contains(genderDigit)) {
        // ✅ 유효한 값이면 에러 메시지를 지우고 다음 단계로 진행
        setState(() {
          _genderErrorText = null; 
        });
        if (_birthDateController.text.length == 6) {
          setState(() {
            _infoSubStep = 2;
          });
          FocusScope.of(context).requestFocus(_phoneFocus);
        }
      } else {
        // ❌ 유효하지 않은 값이면 에러 메시지 설정
        setState(() {
          _genderErrorText = '';
        });
      }
    } else {
      // 입력이 없으면 에러 메시지도 없음
      setState(() {
        _genderErrorText = null;
      });
    }
  }
  _updateButtonState();
}

  // 메인 버튼 클릭 로직
  void _onButtonPressed() {
    if (!_isButtonEnabled || _isLoading) return;
    
    // 0단계(본인인증)의 마지막(휴대폰 입력 완료)에서 버튼을 누르면
    if (_step == 0) {
      setState(() {
        _checkPhoneNumber();
      });
      _startTimer();
    }
    // 1단계(인증번호)에서 버튼을 누르면
    else if (_step == 1) {
      setState(() {
        _verifyCodeWithServer();
      });
      _timer?.cancel();
    }
    // 2단계(세부정보)에서 버튼을 누르면
    else if (_step == 2) {
      _registerUser();
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
                  const SizedBox(height: 40),
                  
                  // ## 1. 이 부분을 수정: 0단계가 아닐 때만 하단 버튼을 표시 ##
                  Visibility(
                    visible: _step == 2, // 1단계 또는 2단계일 때만 보임
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isButtonEnabled && !_isLoading) ? _onButtonPressed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB2F142),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              const Color(0xFFB2F142).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.black) // 로딩 중이면 인디케이터 표시
            : const Text('가입',
                            style: TextStyle(
                                fontFamily: 'WantedSans',
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
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
        Expanded(
          child: TextField(
            controller: _codeController,
            // 1. 키보드를 숫자 전용으로 변경
            keyboardType: TextInputType.number,
            // 2. 입력되는 텍스트를 숫자만으로 제한
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            // 3. 최대 길이를 6자리로 제한
            maxLength: 6,
            // 4. 글자 스타일 및 커서 꾸미기
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 16, // 글자 사이 간격으로 박스 효과 연출
            ),
            cursorColor: const Color(0xFFB2F142),
            // 6. 값이 바뀔 때마다 버튼 상태 업데이트
            onChanged: (value) => _updateButtonState(),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () { 
            _sendVerificationRequest();
            _startTimer(); },
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
  // 1. Row를 Column으로 감싸서 수직 공간을 확보합니다.
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 2. 정렬 기준을 위쪽으로 맞춥니다.
        children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _birthDateController,
            focusNode: _birthDateFocus,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (v) {
              _updateAutomaticSubSteps();
              if (v.length == 6 && _birthDateErrorText == null) {
                FocusScope.of(context).requestFocus(_genderDigitFocus);
              }
            },
            // 3. 내장 errorText 대신, helperText로 공간만 확보합니다.
            decoration: _buildInputDecoration(
              hint: '생년월일 6자리',
            ).copyWith(
              helperText: ' ', // 에러 메시지가 나타날 때 레이아웃이 흔들리지 않도록 최소 공간 확보
              helperStyle: const TextStyle(height: 0.5), // 공간을 최소화
            ),
          ),
        ),
        // TextField 높이를 맞추기 위해 Padding을 추가합니다.
        const Padding(
          padding: EdgeInsets.only(top: 18.0, left: 12.0, right: 12.0),
          child: Text('-', style: TextStyle(color: Colors.white, fontSize: 20)),
        ),
        Expanded(
          flex: 1,
          child: TextField(
            controller: _genderDigitController,
            focusNode: _genderDigitFocus,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            keyboardType: TextInputType.number,
            maxLength: 1,
            onChanged: (v) => _updateAutomaticSubSteps(),
            decoration: _buildInputDecoration().copyWith(
              helperText: ' ',
              helperStyle: const TextStyle(height: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 점 아이콘들의 높이를 맞추기 위해 Padding을 추가합니다.
        Padding(
          padding: const EdgeInsets.only(top: 22.0),
          child: Row(
            children: List.generate(
              6,
              (index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(Icons.circle, color: Colors.grey, size: 10),
              ),
            ),
          ),
        ),
      ]),
      // 4. 에러 메시지를 여기에 별도로 표시합니다.
      if (_birthDateErrorText != null || _genderErrorText != null)
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
          child: Text(
            // 생년월일 에러를 우선적으로 보여줍니다.
            _birthDateErrorText ?? _genderErrorText ?? '',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
    ],
  );
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
