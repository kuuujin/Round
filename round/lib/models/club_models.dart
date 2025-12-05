class MyClub {
  final int id;
  final String name;

  MyClub({required this.id, required this.name});

  factory MyClub.fromJson(Map<String, dynamic> json) {
    return MyClub(
      id: json['id'],
      name: json['name'],
    );
  }
}

// 2. 추천 동호회 (목록용 정보)
class RecommendedClub {
  final String name;
  final String description;
  final String tags;
  final String? imageUrl;

  RecommendedClub({
    required this.name,
    required this.description,
    required this.tags,
    this.imageUrl,
  });

  factory RecommendedClub.fromJson(Map<String, dynamic> json) {
    String tags = "${json['sport']} · ${json['sido']} ${json['sigungu']} · 멤버 ${json['member_count']}";
    return RecommendedClub(
      name: json['name'],
      description: json['description'],
      tags: tags,
      imageUrl: json['club_image_url'],
    );
  }
}

// 3. 동호회 상세 정보 (ClubMembersScreen용)
class ClubInfo {
  final int id;
  final String name;
  final String bannerUrl;
  final int point;
  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final String rankText;
  final String area;
  final int members;

  ClubInfo({
    required this.id,
    required this.name,
    required this.bannerUrl,
    required this.point,
    required this.totalMatches,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.rankText,
    required this.area,
    required this.members,
  });

  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: json['id'],
      name: json['name'],
      bannerUrl: json['club_image_url'] ?? '',
      point: json['point'],
      totalMatches: json['total_matches'],
      wins: json['wins'],
      draws: json['draws'],
      losses: json['losses'],
      rankText: json['rank_text'],
      area: "${json['sido']} ${json['sigungu']}",
      members: json['member_count'],
    );
  }
}

class ClubRank {
  final int id;
  final String name;
  final String imageUrl;
  final int point;
  final int ranking;

  ClubRank({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.point,
    required this.ranking,
  });

  factory ClubRank.fromJson(Map<String, dynamic> json) {
    return ClubRank(
      id: json['id'],
      name: json['name'],
      imageUrl: json['club_image_url'] ?? '',
      point: json['point'],
      ranking: json['ranking'],
    );
  }
}

class Schedule {
  final int id;
  final String title;
  final String description;
  final String location;
  final bool isMatch;
  final String? opponentName;
  final int maxParticipants;
  final int currentParticipants;
  
  // 👇👇👇 [수정] 쪼개진 변수들을 지우고 이거 하나로 통합합니다.
  final String startTime; // 예: "2025-12-05 14:30:00"

  Schedule({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.isMatch,
    this.opponentName,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.startTime, // 생성자 수정
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      location: json['location'],
      isMatch: (json['is_match'] == 1 || json['is_match'] == true),
      opponentName: json['opponent_name'],
      maxParticipants: json['max_participants'],
      currentParticipants: json['current_participants'] ?? 0,
      
      // 👇👇👇 [수정] DB의 'schedule_date'를 그대로 문자열로 받습니다.
      startTime: json['schedule_date'].toString(),
    );
  }
}

class Post {
  final int id;
  final String title;
  final String content;
  final String time;        // UI에서는 createdAt으로 쓰려던 것
  final int likes;          // UI에서는 likeCount로 쓰려던 것
  final int comments;
  final String? imageUrl;   // 게시글 이미지
  final String authorName;  // UI에서는 userName으로 쓰려던 것
  
  // 👇👇👇 [추가] 프로필 이미지 필드 추가
  final String? profileImage; 

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.likes,
    required this.comments,
    this.imageUrl,
    required this.authorName,
    this.profileImage, // 생성자 추가
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // 날짜 포맷팅 (YYYY-MM-DD)
    String rawDate = json['created_at'].toString();
    String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;

    return Post(
      id: json['id'],
      title: json['title'] ?? '', // null 방지
      content: json['content'] ?? '',
      time: formattedDate, 
      likes: json['likes'] ?? 0,
      comments: json['comment_count'] ?? 0,
      imageUrl: json['image_url'],
      authorName: json['author_name'] ?? '익명', 
      
      // 👇👇👇 [추가] JSON 매핑
      profileImage: json['profile_image'], 
    );
  }
}

class Comment {
  final int id;
  final String content;
  final String time;        // UI에서 comment.time 사용 중
  final String authorName;  // UI에서 comment.authorName 사용 중
  final String? authorImage;

  Comment({
    required this.id,
    required this.content,
    required this.time,
    required this.authorName,
    this.authorImage,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      // 1. created_at -> time
      time: json['created_at'].toString().substring(0, 16), 
      // 2. user_name -> authorName
      authorName: json['user_name'] ?? '익명', 
      authorImage: json['user_image'],
    );
  }
}