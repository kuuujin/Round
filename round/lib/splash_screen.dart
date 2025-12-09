import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'package:round/user_provider.dart';
import 'package:round/fcm_utils.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Dio dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// 앱 초기화 로직 (로그인 체크 + 최소 대기 시간)
  Future<void> _initializeApp() async {
    // 1. 로그인 체크와 최소 대기 시간(1.5초)을 병렬로 실행
    // API가 빨리 끝나도 최소 1.5초는 로고를 보여줍니다.
    final results = await Future.wait([
      _checkSession(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    final bool isLoggedIn = results[0] as bool;

    if (!mounted) return;

    if (isLoggedIn) {
      // 2-a. 로그인 성공 시 홈으로 이동
      final userId = UserProvider().userId;
      Navigator.pushReplacementNamed(context, '/home', arguments: userId);
    } else {
      // 2-b. 실패 시 로그인 화면으로 이동 (애니메이션 효과)
      _navigateToLogin();
    }
  }

  /// 세션 확인 API 호출
  Future<bool> _checkSession() async {
    try {
      final response = await dio.get('/api/check-login');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final userData = response.data['user'];
        
        // Provider 상태 업데이트
        UserProvider().setUser(
          userData['user_id'], 
          userData['name'], 
          userData['role']
        );
        
        // FCM 토큰 갱신 (백그라운드 처리)
        updateServerToken(); 
        
        return true;
      }
    } on DioException catch (e) {
      debugPrint("자동 로그인 실패 (세션 만료 등): ${e.message}");
    } catch (e) {
      debugPrint("초기화 오류: $e");
    }
    return false;
  }

  /// 로그인 화면으로 슬라이드 전환
  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(0.0, 1.0); // 아래에서 위로
          const end = Offset.zero;
          const curve = Curves.easeOutQuart; // 부드러운 감속 커브

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기에 비례한 로고 크기 설정
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      body: Center(
        child: Image.asset(
          'assets/images/Round.png', 
          width: width * 0.6, // 화면 너비의 60%
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}