import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';

// --- 앱 내 화면들 import ---
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
import 'package:round/user_provider.dart'; 
import 'package:round/friendly_match_detail_screen.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("백그라운드 메시지 수신: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Firebase.initializeApp();
  await ApiClient.init();
  

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
        _MyAppState.onNotificationTap(details);
    },
  );


  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _initGlobalFCM();    // 알림 리스너
    _initGlobalSocket(); // 소켓 리스너
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  // --- A. Global FCM Listeners ---

  void _initGlobalFCM() async {
    // 1. Terminated State (앱 꺼짐 -> 알림 클릭)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageNavigation(initialMessage.data);
    }

    // 2. Background State (앱 백그라운드 -> 알림 클릭)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageNavigation(message.data);
    });

    // 3. Foreground State (앱 켜짐 -> 알림 수신)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(message.data), 
        );
      }
    });
  }


  static void onNotificationTap(NotificationResponse details) {
    if (details.payload != null) {
      try {
        Map<String, dynamic> data = jsonDecode(details.payload!);
        _handleMessageNavigationStatic(data);
      } catch (e) {
        debugPrint("Payload parsing error: $e");
      }
    }
  }


  void _handleMessageNavigation(Map<String, dynamic> data) {
    if (data['type'] == 'MATCH_FOUND') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => FriendlyMatchDetailScreen(
            matchId: data['match_id'],
            opponentName: data['opponent_name'] ?? '상대팀',
          ),
        ),
      );
    }
  }


  static void _handleMessageNavigationStatic(Map<String, dynamic> data) {
    if (data['type'] == 'MATCH_FOUND') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => FriendlyMatchDetailScreen(
            matchId: data['match_id'],
            opponentName: data['opponent_name'] ?? '상대팀',
          ),
        ),
      );
    }
  }

  // --- B. Global Socket Listeners ---

  void _initGlobalSocket() {
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.on('match_found', (data) {
      // 전역 알림 다이얼로그 (앱 사용 중 매칭 성사 시)
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF333333),
            title: const Text("🎉 매칭 성공!", style: TextStyle(color: Color(0xFFB7F34D), fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("상대팀: ${data['opponent_name']}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                 const SizedBox(height: 10),
                 const Text("채팅방으로 이동하시겠습니까?", style: TextStyle(color: Colors.white70)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final myId = UserProvider().userId;
                  if (myId != null) {
                    navigatorKey.currentState!.push(
                      MaterialPageRoute(
                        builder: (_) => FriendlyMatchDetailScreen(
                          matchId: data['match_id'],
                          opponentName: data['opponent_name'],
                        ),
                      ),
                    );
                  }
                },
                child: const Text("이동", style: TextStyle(color: Color(0xFFB7F34D), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    });
    
    // 로그인 상태라면 소켓 연결
    final myId = UserProvider().userId;
    if (myId != null) {
        socket.connect();
        socket.emit('join', {'user_id': myId});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 전역 키 등록
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WantedSans'),
      home: const SplashScreen(),
      routes: {
        // Auth
        '/login': (context) => const LoginScreen(),

        // Main Tabs
        '/home': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return HomeScreen(userId: userId);
        },
        '/club': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ClubListScreen(userId: userId); 
        },
        '/community': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityScreen(userId: userId);
        },
        '/mypage': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return MyPageScreen(userId: userId);
        },

        // Community Sub-Tabs
        '/communityFriendly': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityFriendlyTab(userId: userId); 
        },
        '/communityRanking': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityRankingTab(userId: userId);
        },

        // Club Detail Screens
        '/clubSchedule': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubScheduleScreen(userId: args['userId'], clubId: args['clubId']);
        },
        '/clubBoard': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubBoardScreen(userId: args['userId'], clubId: args['clubId']);
        },
        '/clubMembers': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClubMembersScreen(userId: args['userId'], clubId: args['clubId']);
        },

        // Others
        '/createClub': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CreateClubScreen(userId: userId);
        }
      },
    );
  }
}