import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/date_symbol_data_local.dart';

// --- 앱 내 화면들 import ---
import 'package:round/api_client.dart';
import 'package:round/splash_screen.dart';
import 'package:round/login_screen.dart';
import 'package:round/home_screen.dart';
import 'package:round/club_list.dart';
import 'package:round/community_screen.dart'; // CommunityScreen
import 'package:round/my_page.dart'; 
import 'package:round/create_club.dart'; 
import 'package:round/club_schedule.dart';
import 'package:round/club_board.dart';
import 'package:round/club_members.dart';
import 'package:round/community_friendly.dart'; // CommunityFriendlyTab
import 'package:round/community_ranking.dart'; // CommunityRankingTab
import 'package:round/user_provider.dart'; // UserProvider
import 'package:round/friendly_match_detail_screen.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("백그라운드 메시지 수신: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Firebase.initializeApp(); // Firebase 초기화
  await ApiClient.init();         // API Client (CookieJar) 초기화
  
  // 백그라운드 메시지 핸들러 등록 (앱 꺼졌을 때)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id (Manifest와 일치해야 함)
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    // 알림 클릭 시 실행될 동작 (선택 사항)
    onDidReceiveNotificationResponse: (NotificationResponse details) {
        print("🔔 알림 클릭됨: ${details.payload}");
        // 여기서 navigatorKey를 사용해 화면 이동 가능
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
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
    _initGlobalFCM();    // FCM 리스너 (알림 클릭)
    _initGlobalSocket();
  }

  // --- A. 전역 FCM 리스너 (알림 클릭 시) ---
  void _initGlobalFCM() async {
    // (1) 앱이 꺼진 상태에서 알림 클릭으로 열렸을 때
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // (2) 앱이 백그라운드에 있을 때 알림 클릭으로 열렸을 때
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("✨ 포그라운드 메시지 수신: ${message.notification?.title}");
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // 알림 내용이 있고, 안드로이드 기기라면 -> 직접 알림창을 띄운다 (show)
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode, // 알림 ID (중복 방지용 해시코드)
          notification.title,    // 제목
          notification.body,     // 본문
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // main()에서 만든 채널 ID와 같아야 함
              'High Importance Notifications',
              channelDescription: '중요한 알림을 위한 채널입니다.',
              importance: Importance.max, // 상단에 팝업 뜨게 함
              priority: Priority.high,
              icon: '@mipmap/ic_launcher', // 아이콘 설정
            ),
          ),
          // 알림 클릭 시 전달할 데이터 (문자열로 변환)
          // payload가 있어야 클릭했을 때 채팅방으로 이동 가능
          payload: message.data.toString(), 
        );
      }
      
      // (선택) 만약 매칭 화면이라면 여기서 바로 다이얼로그를 띄울 수도 있음
      if (message.data['type'] == 'MATCH_FOUND') {
         // 필요하다면 소켓 이벤트와 중복되지 않게 처리
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    // 데이터 페이로드에 'type'이 'MATCH_FOUND'인지 확인
    if (message.data['type'] == 'MATCH_FOUND') {
      print("🔔 알림 클릭! 채팅방으로 이동");
      
      final myId = UserProvider().userId; // 전역 저장소에서 내 ID 가져오기
      
      if (myId != null) {
        // 전역 키를 사용하여 채팅방으로 이동
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => FriendlyMatchDetailScreen(
              matchId: message.data['match_id'],
              opponentName: message.data['opponent_name'] ?? '상대팀',
            ),
          ),
        );
      } else {
        print("❌ 오류: 사용자 정보가 없습니다. (로그인 필요)");
        // 필요시 로그인 화면으로 이동
        navigatorKey.currentState!.pushNamed('/login');
      }
    }
  }

  // --- B. 전역 소켓 리스너 (앱이 켜져 있을 때) ---
  void _initGlobalSocket() {
    // 주의: CommunityFriendlyTab 등 다른 곳의 소켓과 연결이 중복될 수 있으나,
    // 전역 알림을 위해 별도로 리스닝하는 것이 가장 확실합니다.
    socket = IO.io('https://roundserver.win', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.on('match_found', (data) {
      print("🌍 [Global Socket] 매칭 발견! 어디서든 이동합니다.");
      
      // 현재 화면 위에 다이얼로그 띄우기
      if (navigatorKey.currentContext != null) {
        // 이미 채팅방이나 매칭 화면에 있다면 중복 팝업 방지 로직을 추가할 수도 있음
        
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
                  Navigator.pop(ctx); // 다이얼로그 닫기
                  
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
    
    // 로그인 상태라면 소켓 연결 및 방 입장
    final myId = UserProvider().userId;
    if (myId != null) {
        socket.connect();
        socket.emit('join', {'user_id': myId});
    }
  }


  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 👈 3. 여기에 전역 키 등록 필수!
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WantedSans'),
      home: const SplashScreen(),
      routes: {
        // 1. 로그인
        '/login': (context) => const LoginScreen(),

        // 2. 메인 탭
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

        // 3. 커뮤니티 내부 탭 (직접 접근용)
        '/communityFriendly': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityFriendlyTab(userId: userId); 
        },
        '/communityRanking': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CommunityRankingTab(userId: userId);
        },

        // 4. 동호회 하위 화면
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

        // 5. 기타 화면
        '/createClub': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return CreateClubScreen(userId: userId);
        }
      },
    );
  }
}