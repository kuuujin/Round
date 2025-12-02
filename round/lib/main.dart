import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:round/api_client.dart';
import 'package:round/splash_screen.dart';
import 'package:round/login_screen.dart';
import 'package:round/home_screen.dart';
import 'package:round/club_list.dart';
import 'package:round/community_screen.dart';
import 'package:round/my_page.dart'; 
import 'package:round/create_club.dart'; 
import 'package:round/club_schedule.dart';
import 'package:round/club_board.dart';
import 'package:round/club_members.dart';
import 'package:round/community_friendly.dart';
import 'package:round/community_ranking.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        // 1. 로그인
        '/login': (context) => const LoginScreen(),

        // 2. 메인 탭 (Bottom Navigation) - userId만 필요
        '/home': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return HomeScreen(userId: userId);
        },
        '/club': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ClubListScreen(userId: userId); // ClubListScreen 반환
        },
        '/community': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityScreen(userId: userId);
        },
        '/mypage': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return MyPageScreen(userId: userId);
        },

        // 3. 커뮤니티 내부 탭 바로가기 (필요한 경우)
        '/communityFriendly': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          // 탭 내부 화면을 직접 띄우기보다 CommunityScreen을 띄우고 초기 탭을 설정하는 방식이 좋지만,
          // 현재 구조상 직접 위젯을 반환한다면 Scaffold가 포함되어 있어야 함.
          // 일단 기존 코드 유지:
          return CommunityFriendlyTab(userId: userId); 
        },
        '/communityRanking': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityRankingTab(userId: userId);
        },

        // 4. 동호회 하위 화면 (ClubMainScreen 내부) - userId, clubId 필요
        // *주의: ClubMainScreen을 사용하면 이 라우트들은 잘 안 쓰이게 되지만,
        // 알림 등을 통해 직접 접근할 때를 대비해 유지합니다.
        '/clubSchedule': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubScheduleScreen(
            userId: args['userId'],
            clubId: args['clubId'],
          );
        },
        '/clubBoard': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubBoardScreen(
            userId: args['userId'],
            clubId: args['clubId'],
          );
        },
        '/clubMembers': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubMembersScreen(
            userId: args['userId'],
            clubId: args['clubId'],
          );
        },

        // 5. 기타 화면
        '/createClub': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CreateClubScreen(userId: userId);
        }
      },
    );
  }
}
