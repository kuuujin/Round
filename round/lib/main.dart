import 'package:flutter/material.dart';
import 'package:round/create_club.dart';
import 'package:round/api_client.dart';
import 'splash_screen.dart'; // 스플래시 화면 임포트
import 'package:round/login_screen.dart';
import 'package:round/home_screen.dart';
import 'package:round/club_list.dart';
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
          // 👇 ClubMainScreen 대신 ClubListScreen을 반환
          return ClubListScreen(userId: userId); 
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
          // 1. 인자를 Map 형태로 받습니다 (userId, clubId 포함)
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          
          // 2. ClubScheduleScreen을 반환하고 필요한 인자를 넘겨줍니다.
          return ClubScheduleScreen(
            userId: args['userId'],
            clubId: args['clubId'],
          );
        },
        // 2. ClubBoardScreen (게시판)
        '/clubBoard': (context) {
          // arguments를 Map<String, dynamic>으로 받습니다.
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubBoardScreen(
            userId: args['userId'], 
            clubId: args['clubId']
          );
        },

        // 3. ClubMembersScreen (클럽 정보)
        '/clubMembers': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubMembersScreen(
            userId: args['userId'], 
            clubId: args['clubId']
          );
        },
        '/createClub' : (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CreateClubScreen(userId: userId);
        }
      },
    );
  }
}
