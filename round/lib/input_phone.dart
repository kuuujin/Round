import 'package:flutter/material.dart';
import 'verify_code_screen.dart';

// 1. StatefulWidget으로 변경
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderDigitController = TextEditingController();
  final _phoneController = TextEditingController();

  final _birthDateFocus = FocusNode();
  final _genderDigitFocus = FocusNode();
  final _phoneFocus = FocusNode();

  int _step = 0; // 0: 이름, 1: 생년월일, 2: 휴대폰, 3: 완료
  bool _isButtonEnabled = false; // 버튼 활성화 상태

  final List<String> _headlines = [
    '이름을 입력해 주세요',
    '생년월일/성별을 입력해 주세요',
    '휴대폰번호를 입력해 주세요',
    '휴대폰번호를 입력해 주세요',
  ];

  @override
  void initState() {
    super.initState();
    // 각 단계에 맞는 리스너를 연결
    _nameController.addListener(_updateNameStep);
    _birthDateController.addListener(_updateAutomaticSteps);
    _genderDigitController.addListener(_updateAutomaticSteps);
    _phoneController.addListener(_updateAutomaticSteps);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _genderDigitController.dispose();
    _phoneController.dispose();
    _birthDateFocus.dispose();
    _genderDigitFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // 이름 단계에서 '다음' 버튼의 활성화 상태만 제어
  void _updateNameStep() {
    setState(() {
      _isButtonEnabled = _nameController.text.isNotEmpty;
    });
  }

  // 생년월일과 휴대폰 단계의 자동 전환을 처리
  void _updateAutomaticSteps() {
    setState(() {
      // 생년월일 -> 휴대폰 자동 전환
      if (_step == 1 &&
          _birthDateController.text.length == 6 &&
          _genderDigitController.text.length == 1) {
        _step = 2;
        FocusScope.of(context).requestFocus(_phoneFocus);
      }
      // 휴대폰 -> 최종 버튼 자동 전환
      else if (_step == 2 && _phoneController.text.length == 11) {
        _step = 3;
      }
    });
  }

  // 버튼을 눌렀을 때의 동작
  void _onButtonPressed() {
    // 이름 단계에서 버튼을 누르면 다음 단계로 이동
    if (_step == 0) {
      setState(() {
        _step = 1;
      });
      FocusScope.of(context).requestFocus(_birthDateFocus);
    }
    // 마지막 단계에서 버튼을 누르면 인증번호 전송 로직 수행
    else if (_step == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VerifyCodeScreen()),
       );
    }
  }
  
  // 버튼의 onPressed 속성에 연결될 함수를 반환
  VoidCallback? _getOnPressedAction() {
    if (_step == 0) {
      return _isButtonEnabled ? _onButtonPressed : null;
    }
    if (_step == 3) {
      return _onButtonPressed; // 마지막 단계에서는 항상 활성화
    }
    return null;
  }

  // 생년월일/성별 입력 위젯
  Widget _buildBirthDateInput() {
    return Row(
      children: [
        // 생년월일 6자리
        Expanded(
          flex: 2,
          child: TextField(
            controller: _birthDateController,
            focusNode: _birthDateFocus,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (value) {
            // 입력된 값이 6자리가 되면 다음 필드로 포커스를 이동합니다.
            if (value.length == 6) {
              FocusScope.of(context).requestFocus(_genderDigitFocus);
            }
          },
            decoration: _buildInputDecoration(hint: '생년월일 6자리'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text('-', style: TextStyle(color: Colors.white, fontSize: 20)),
        ),
        // 성별 뒷자리 1자리
        Expanded(
          flex: 1,
          child: TextField(
            controller: _genderDigitController,
            focusNode: _genderDigitFocus,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            keyboardType: TextInputType.number,
            maxLength: 1,
            decoration: _buildInputDecoration(),
          ),
        ),
        const SizedBox(width: 8),
        // 마스킹된 부분
        ...List.generate(6, (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(Icons.circle, color: Colors.grey[700], size: 10),
        )),
      ],
    );
  }

  Widget _buildPhoneInput() {
  return TextField(
    controller: _phoneController,
    focusNode: _phoneFocus,
    style: const TextStyle(color: Colors.white, fontSize: 16),
    maxLength: 11,
    keyboardType: TextInputType.number,
    decoration: _buildInputDecoration(hint: '휴대폰번호'),
  );
}

  // 공통으로 사용될 TextField의 InputDecoration
  InputDecoration _buildInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      counterText: '', // maxLength 글자 수 표시 제거
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB2F142), width: 1.5),
      ),
    );
  }
  
  // 6. 위젯의 표시 여부를 결정하고 애니메이션을 적용하는 래퍼 위젯
  Widget _buildAnimatedSection({required bool show, required Widget child}) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: show ? child : const SizedBox.shrink(),
    );
  }

 @override
Widget build(BuildContext context) {
  const TextStyle headlineStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white);
  const TextStyle bodyStyle = TextStyle(fontWeight: FontWeight.w500, fontSize: 24, color: Colors.white);

  return Scaffold(
    backgroundColor: const Color(0xFF262626),
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('회원가입', style: TextStyle(fontSize: 18, color: Colors.white,fontWeight: FontWeight.w600)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    // ## 1. SingleChildScrollView로 전체를 감싸 스크롤을 적용합니다 ##
    body: SingleChildScrollView(
      // 키보드가 나타날 때 화면의 빈 공간을 탭하면 키보드가 내려가도록 설정
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Round', style: TextStyle(color: Color(0xFFB2F142), fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 40),
            const Text('휴대폰 본인확인이 필요합니다', style: headlineStyle),
            const SizedBox(height: 12),
            Text(_headlines[_step], style: bodyStyle),
            const SizedBox(height: 30),
            
            TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 16), decoration: _buildInputDecoration(hint: '이름')),
            
            Visibility(
              visible: _step == 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _getOnPressedAction(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB2F142),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFFB2F142).withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('다음', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
            
            _buildAnimatedSection(
              show: _step >= 1,
              child: Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildBirthDateInput()),
            ),
            
            _buildAnimatedSection(
              show: _step >= 2,
              child: Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildPhoneInput()),
            ),
            
            Visibility(
              visible: _step == 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _getOnPressedAction(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB2F142),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('인증번호 전송', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
             // 하단 여백
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
}