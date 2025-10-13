import 'package:flutter/material.dart';
import 'verification_view.dart';

class ResetPwScreen extends StatefulWidget {
  const ResetPwScreen({super.key});

  @override
  State<ResetPwScreen> createState() => _ResetPwScreenState();
}

class _ResetPwScreenState extends State<ResetPwScreen> {
  // 상태를 3단계로 관리 (0: 아이디, 1: 휴대폰, 2: 인증번호)
  int _step = 0;
  bool _isButtonEnabled = false;

  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _idController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
    _codeController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      switch (_step) {
        case 0:
          _isButtonEnabled = _idController.text.isNotEmpty;
          break;
        case 1:
          _isButtonEnabled = _phoneController.text.length == 11;
          break;
        case 2:
          _isButtonEnabled = _codeController.text.length == 6;
          break;
      }
    });
  }

  void _onButtonPressed() {
    if (_step < 2) {
      setState(() {
        _step++;
        _isButtonEnabled = false;
      });
      if (_step == 1) FocusScope.of(context).requestFocus(_phoneFocusNode);
    } else {
      // 최종 인증번호 확인 로직
      print('최종 확인 로직 실행');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('비밀번호 재설정', style: TextStyle(fontFamily: 'WantedSans', fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: const Color(0xFF262626),
        elevation: 0,
      ),
      // ## 1. 레이아웃 위젯을 단순화 ##
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Round', style: TextStyle(fontFamily: 'WantedSans', color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 40),
              
              // ## 2. AnimatedSwitcher를 사용하여 각 단계의 전체 UI를 전환 ##
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepUI(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ## 3. 현재 단계에 맞는 UI를 빌드하는 함수 ##
  Widget _buildStepUI() {
    switch (_step) {
      case 0:
        return _buildIdStep();
      case 1:
        return _buildPhoneStep();
      case 2:
        return _buildVerificationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // 0단계: 아이디 입력 UI + '다음' 버튼
  Widget _buildIdStep() {
    return Column(
      key: const ValueKey('id_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('휴대폰 본인확인이 필요합니다', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.grey[300])),
        const SizedBox(height: 12),
        Text('아이디를 입력해 주세요', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white)),
        const SizedBox(height: 30),
        TextField(
          controller: _idController,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(hint: '아이디'),
        ),
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
            child: const Text('다음', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 1단계: 휴대폰 번호 입력 UI + '인증번호 전송' 버튼
  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('휴대폰 본인확인이 필요합니다', style: TextStyle(fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.grey[300])),
        const SizedBox(height: 12),
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
            child: const Text('인증번호 전송', style: TextStyle(fontFamily: 'WantedSans', fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 2단계: 인증 UI + '인증번호 확인' 버튼
  Widget _buildVerificationStep() {
    return Column(
      key: const ValueKey('verify_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VerificationView(controller: _codeController),
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