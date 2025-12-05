import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  // 1. 싱글톤 패턴 구현 (어디서든 똑같은 인스턴스에 접근)
  static final UserProvider _instance = UserProvider._internal();
  factory UserProvider() => _instance;
  UserProvider._internal();

  // 2. 저장할 데이터
  String? _userId;
  String? _userName;
  String? _userRole;
  // 필요하다면 프로필 이미지 URL 등 추가 가능

  // 3. 데이터 접근자 (Getter)
  String? get userId => _userId;
  String? get userName => _userName;
  bool get isLoggedIn => _userId != null;

  // 4. 데이터 설정 함수 (Setter)
  void setUser(String id, String name, String role) {
    _userId = id;
    _userName = name;
    _userRole = role;
    notifyListeners(); // 데이터가 바뀌었다고 알림 (필요시 UI 갱신)
  }

  // 5. 로그아웃 시 데이터 초기화
  void clearUser() {
    _userId = null;
    _userName = null;
    _userRole = null;
    notifyListeners();
  }
}