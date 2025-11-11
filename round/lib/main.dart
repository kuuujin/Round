import 'package:flutter/material.dart';
import 'package:round/create_club.dart';
import 'package:round/api_client.dart';
import 'splash_screen.dart'; // 스플래시 화면 임포트
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:round/login_screen.dart';
import 'package:round/home_screen.dart';
import 'package:round/club.dart';
import 'package:round/community.dart';
import 'package:round/my_page.dart';
import 'package:round/community_friendly.dart';
import 'package:round/community_ranking.dart';            
import 'package:round/club_schedule.dart';    
import 'package:round/club_board.dart';       
import 'package:round/club_members.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WantedSans'),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return HomeScreen(userId: userId);
        },
        '/club': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ClubScreen(userId: userId);
        },
        '/mypage': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return MyPageScreen(userId: userId);
        },
        '/community': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityScreen(userId: userId);      // ← 초기 진입화면
        },
        '/communityFriendly': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityFriendlyScreen(userId: userId);
        },
        '/communityRanking': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityRankingScreen(userId: userId);
        },
        '/clubSchedule': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ClubScheduleScreen(userId: userId);
        },
        '/clubBoard': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ClubBoardScreen(userId: userId);
        },
        '/clubMembers': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ClubMembersScreen(userId: userId);
        },
        '/createClub' : (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CreateClubScreen(userId: userId);
        }
      },
    );
  }
}
