import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; 

class ApiClient {
  late Dio dio;
  late CookieJar cookieJar;

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal();

  //앱이 시작되기 전에 호출될 비동기 초기화 함수 ---
  static Future<void> init() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    
    //메모리(CookieJar) 대신 파일(PersistCookieJar)에 저장하도록 변경
    _instance.cookieJar = PersistCookieJar(
      ignoreExpires: true, // 만료 시간을 서버 세션(30일)에 맡김
      storage: FileStorage(appDocPath + "/.cookies/"),
    );

    //Dio 인스턴스 생성
    _instance.dio = Dio(BaseOptions(
      baseUrl: 'https://roundserver.win', 
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

    _instance.dio.interceptors.add(CookieManager(_instance.cookieJar));
  }
}