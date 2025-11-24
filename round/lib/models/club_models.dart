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