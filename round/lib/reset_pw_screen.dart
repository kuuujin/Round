import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'verification_view.dart';
import 'new_password_screen.dart';

class ResetPwScreen extends StatefulWidget {
  const ResetPwScreen({super.key});

  @override
  State<ResetPwScreen> createState() => _ResetPwScreenState();
}

class _ResetPwScreenState extends State<ResetPwScreen> {
  // 1. 상태를 3단계로 관리 (0: 아이디 입력, 1: 휴대폰 입력, 2: 인증번호 입력)
  int _step = 0;
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  final _idController = TextEditingController();
  final _phoneController = TextEditingController();

  final _idFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _idFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    bool isEnabled = false;
    switch (_step) {
      case 0: // 아이디 입력 단계
        isEnabled = _idController.text.isNotEmpty;
        break;
      case 1: // 휴대폰 입력 단계
        isEnabled = _phoneController.text.length == 11;
        break;
    }
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  void _resetToIdStep() {
    setState(() {
      _step = 0; // 아이디 입력 단계로 변경
      _phoneController.clear(); // 입력했던 휴대폰 번호 초기화
      _isButtonEnabled = _idController.text.isNotEmpty; // 버튼 상태 다시 체크
    });
    // 아이디 필드로 다시 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
       FocusScope.of(context).requestFocus(_idFocusNode);
    });
  }

  // --- 버튼 액션 함수들 ---

  // '다음' 버튼 (아이디 입력 후)
  void _goToPhoneStep() {
    // ## 아이디 존재 여부 확인 API를 호출할 수도 있지만,
    // ## 여기서는 UI만 변경하고 실제 확인은 다음 단계에서 한번에 처리합니다.
    setState(() {
      _step = 1; // 휴대폰 입력 단계로 UI 변경
      _isButtonEnabled = false; // 버튼 비활성화
    });
    // 휴대폰 필드에 자동으로 포커스 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  // '인증번호 전송' 버튼 (휴대폰 입력 후)
  Future<void> _handlePhoneSubmission() async {
    setState(() => _isLoading = true);
    try {
      // 서버 API는 아이디와 휴대폰 번호가 DB와 일치하는지 확인 후, 맞으면 SMS 전송
      await dio.post('/reset-pw/send-code', data: {
        'user_id': _idController.text,
        'phone': _phoneController.text,
      });
      
      if (!mounted) return;

      // ### 변경된 부분 ###
      // 성공 시 UI 변경 대신, _VerificationScreen으로 화면 이동
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => _VerificationScreen( // 같은 파일 내에 정의된 위젯 호출
          userId: _idController.text,
          phone: _phoneController.text,
        ),
      ));

    } on DioException catch (e) {
      String errorMessage = "가입된 아이디가 없거나 휴대폰번호가 일치하지 않습니다.";
      if (e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }


  // 공통 에러 다이얼로그
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Row(children: [Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('알림', style: TextStyle(color: Colors.white)),]),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인', style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold)),
    ),
    ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('비밀번호 재설정', style: TextStyle(fontFamily: 'WantedSans', color:Colors.white,fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: const Color(0xFF262626),
        elevation: 0, ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 40),

              // --- UI 빌더 로직 변경 ---
              _buildIdAndPhoneStep(), // 아이디와 휴대폰 UI를 항상 표시 (휴대폰은 숨김 처리)

            ],
          ),
        ),
      ),
    );
  }

  // --- UI 빌더 함수들 ---

  // 아이디 + 휴대폰 입력 UI (하나로 통합)
  Widget _buildIdAndPhoneStep() {
    return Column(
      key: const ValueKey('id_phone_step'), // AnimatedSwitcher를 사용하지 않으므로 Key는 선택사항
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 아이디 입력 부분 ---
        Text('휴대폰 본인확인이 필요합니다', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.grey[300])),
        const SizedBox(height: 12),
        Text('아이디를 입력해 주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
        const SizedBox(height: 30),
        TextField(
          controller: _idController,
          focusNode: _idFocusNode, // 포커스 노드 연결
          readOnly: _step >= 1, // 스텝 1 이상이면 기본적으로 읽기 전용
          style: TextStyle(color: _step >= 1 ? Colors.grey : Colors.white),
          decoration: _buildInputDecoration(hint: '아이디').copyWith(
            // _step 1 이상일 때만 '수정' 아이콘 버튼 표시
            suffixIcon: _step >= 1
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                    onPressed: _resetToIdStep, // 아이디 입력 단계로 되돌리는 함수 연결
                  )
                : null, // _step 0일 때는 아이콘 없음
          ),
        ),
        const SizedBox(height: 24),

        // --- 휴대폰 입력 부분 (조건부 표시) ---
        // AnimatedSize를 사용하여 부드럽게 나타나도록 함
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Visibility(
            visible: _step >= 1, // _step이 1 이상일 때만 보임
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('휴대폰번호를 입력해 주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
                const SizedBox(height: 30),
                TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(hint: '휴대폰번호'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // --- 하단 버튼 ---
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            // 버튼 액션과 텍스트를 _step에 따라 변경
            onPressed: (_isButtonEnabled && !_isLoading)
                ? (_step == 0 ? _goToPhoneStep : _handlePhoneSubmission) // 0단계면 다음, 1단계면 전송
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB2F142),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : Text(
                    _step == 0 ? '다음' : '인증번호 전송', // 버튼 텍스트 변경
                    style: const TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold))
                  ),
          ),
      ],
    );
  }

  // 반복되는 TextField 스타일을 위한 Helper 함수
  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5)),
      // 읽기 전용일 때의 테두리 스타일
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700)),
    );
  }
}

class _VerificationScreen extends StatefulWidget {
  // 데이터는 여전히 API 요청을 위해 필요합니다.
  final String userId;
  final String phone;

  const _VerificationScreen({
    required this.userId,
    required this.phone,
  });

  @override
  State<_VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<_VerificationScreen> {
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  // --- 수정된 부분 ---
  // 인증번호 컨트롤러만 남깁니다.
  final _codeController = TextEditingController();
  // final _idController = TextEditingController(); // 제거
  // final _phoneController = TextEditingController(); // 제거
  // ---

  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    // --- 수정된 부분 ---
    // _idController, _phoneController 초기화 로직 제거
    // ---

    // 인증번호 입력 감지
    _codeController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    // --- 수정된 부분 ---
    _codeController.dispose();
    // _idController.dispose(); // 제거
    // _phoneController.dispose(); // 제거
    super.dispose();
    // ---
  }

  void _updateButtonState() {
    final isEnabled = _codeController.text.length == 6;
    if (_isButtonEnabled != isEnabled) {
      setState(() => _isButtonEnabled = isEnabled);
    }
  }

  // (이하 _handleCodeVerification, _handleResend, _showErrorDialog 함수는
  //  기존과 동일하게 유지합니다. _handleResend는 widget.userId를 사용해야 합니다.)

  // '인증번호 확인' 버튼
  Future<void> _handleCodeVerification() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post('/reset-pw/verify-code', data: {
        'code': _codeController.text,
      });

      final String token = response.data['token'];
      if (!mounted) return;

      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => NewPasswordScreen(token: token),
      ));
    } on DioException catch (e) {
      _showErrorDialog(e.response?.data['error'] ?? "인증에 실패했습니다.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // '재전송' 버튼 로직 (widget.userId와 widget.phone을 그대로 사용)
  Future<bool> _handleResend() async {
    try {
      await dio.post('/reset-pw/send-code', data: {
        'user_id': widget.userId,
        'phone': widget.phone,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증번호를 다시 전송했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } on DioException catch (e) {
      String errorMessage = "인증번호 전송에 실패했습니다.";
      if (e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      _showErrorDialog(errorMessage);
      return false;
    }
  }


  // 공통 에러 다이얼로그
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Row(children: [Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('알림', style: TextStyle(color: Colors.white)),]),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인', style: TextStyle(color: Color(0xFFB2F142), fontWeight: FontWeight.bold)),
      ),
    ]),
    );
  }

  // --- _buildInputDecoration 함수 제거 ---
  // 이 클래스에서 더 이상 TextField를 사용하지 않으므로 Helper 함수도 제거합니다.
  // InputDecoration _buildInputDecoration({ ... }) // 제거
  // ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('인증번호 입력', style: TextStyle(fontFamily: 'WantedSans', color:Colors.white,fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: const Color(0xFF262626),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 수정된 부분 ---
              // 아이디와 휴대폰번호 TextField 및 SizedBox 제거
              /*
              TextField(
                controller: _idController, ...
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController, ...
              ),
              const SizedBox(height: 30),
              */
              // ---

              // 인증 뷰
              VerificationView(
                controller: _codeController,
                onResend: () async {
                  return await _handleResend(); // 재전송 로직 연결
                },
              ),
              const SizedBox(height: 24),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isButtonEnabled && !_isLoading) ? _handleCodeVerification : null,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB2F142),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('인증번호 확인', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}