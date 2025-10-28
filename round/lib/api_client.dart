import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ApiClient {
  // 싱글톤 패턴: 앱 전체에서 단 하나의 Dio 인스턴스만 사용하도록 보장
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  late CookieJar cookieJar;

  ApiClient._internal() {
    // Dio 기본 설정
    dio = Dio(BaseOptions(
      // ❗️ 서버의 IP 주소를 여기에 입력하세요!
      baseUrl: 'https://roundserver.win',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

    // 쿠키를 저장하고 관리할 CookieJar 생성
    cookieJar = CookieJar();
    
    // Dio 인스턴스에 쿠키 매니저를 인터셉터로 추가
    // 이제부터 모든 요청/응답에서 쿠키가 자동으로 관리됩니다.
    dio.interceptors.add(CookieManager(cookieJar));
  }
}