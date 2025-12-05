import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:round/api_client.dart';
import 'login_screen.dart';
import 'package:round/user_provider.dart';
import 'package:round/fcm_utils.dart';

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
    _checkLoginStatus(); 
  }

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); // 아래에서 위로 올라오는 애니메이션
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    ));
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 1)); 
    try {
      final response = await dio.get('/api/check-login');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final String userId = response.data['user']['user_id'];
        final userData = response.data['user'];
        UserProvider().setUser(
          userData['user_id'], 
          userData['name'], 
          userData['role']
        );
        await updateServerToken();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home', arguments: userId);
      } else {
        _navigateToLogin();
      }
    } on DioException {
      _navigateToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/Round.png', 
              width: 800, 
            ),
          ],
        ),
      ),
    );
  }
}