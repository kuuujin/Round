class MyClub {
  final int id;
  final String name;
  final String description;
  final String clubImage;
  final int memberCount;
  

  final String sport;
  final String sido;
  final String sigungu;

  MyClub({
    required this.id,
    required this.name,
    required this.description,
    required this.clubImage,
    required this.memberCount,
    required this.sport,
    required this.sido,
    required this.sigungu,
  });

  factory MyClub.fromJson(Map<String, dynamic> json) {
    return MyClub(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      clubImage: json['club_image_url'] ?? '',
      memberCount: json['member_count'] ?? 0,
      sport: json['sport'] ?? '기타',
      sido: json['sido'] ?? '',
      sigungu: json['sigungu'] ?? '',
    );
  }
}

// 목록 조회용 모델 (필요 시 models 폴더로 이동 권장)
class CommunityClub {
  final int id;
  final String name;
  final String description;
  final String tags;
  final String? imageUrl;
  final int memberCount;
  final int maxCapacity;

  CommunityClub({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    this.imageUrl,
    required this.memberCount,
    required this.maxCapacity,
  });

  factory CommunityClub.fromJson(Map<String, dynamic> json) {
    return CommunityClub(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      tags: "${json['sido']} ${json['sigungu']}",
      imageUrl: json['club_image_url'],
      memberCount: json['member_count'] ?? 0,
      maxCapacity: json['max_capacity'] ?? 0,
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
      
      startTime: json['schedule_date'].toString(),
    );
  }
}

class Post {
  final int id;
  final String title;
  final String content;
  final String time;        
  final int likes;         
  final int comments;
  final String? imageUrl;   
  final String authorName; 
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

class RecentMatch {
  final int myScore;
  final int opScore;
  final String matchDate;
  final String matchTime;
  final String opponentName;
  final String? opponentImage;

  RecentMatch({
    required this.myScore,
    required this.opScore,
    required this.matchDate,
    required this.matchTime,
    required this.opponentName,
    this.opponentImage,
  });

  factory RecentMatch.fromJson(Map<String, dynamic> json) {
    return RecentMatch(
      myScore: json['my_score'] ?? 0,
      opScore: json['op_score'] ?? 0,
      
      matchDate: json['match_date'] ?? '날짜 미정',
      matchTime: json['match_time'] ?? '',
      
      opponentName: json['opponent_name'] ?? '알 수 없는 팀',
      
      opponentImage: json['opponent_image'],
    );
  }
}

class ActiveMatch {
  final String matchId;
  final String opponentName;
  final String? opponentImage;
  final String status;
  final String sport;
  final String location;

  ActiveMatch({
    required this.matchId,
    required this.opponentName,
    this.opponentImage,
    required this.status,
    required this.sport,
    required this.location,
  });

  factory ActiveMatch.fromJson(Map<String, dynamic> json) {
    return ActiveMatch(
      matchId: json['match_id'],
      opponentName: json['opponent_name'],
      opponentImage: json['opponent_image'],
      status: json['status'],
      sport: json['sport'],
      location: "${json['sido']} ${json['sigungu']}",
    );
  }
}