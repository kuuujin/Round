import 'package:flutter/material.dart';
import 'splash_screen.dart'; // 스플래시 화면 임포트
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:round/login_screen.dart';
import 'package:round/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'WantedSans'),
      home: SplashScreen(),
      routes: {'/login': (context) => const LoginScreen(),
      '/home': (context) {
        final userId = ModalRoute.of(context)!.settings.arguments as String;
        return HomeScreen(userId: userId);
      }},
    );
  }
}