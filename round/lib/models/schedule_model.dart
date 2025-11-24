class Schedule {
  final int id;
  final String title;
  final String description;
  final String location;
  final bool isMatch;
  final String? opponentName;
  final int maxParticipants;
  final int currentParticipants;
  final String dateStr; // "2023-09-17"
  final String timeStr; // "04:30"
  final String ampm;    // "PM"

  Schedule({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.isMatch,
    this.opponentName,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.dateStr,
    required this.timeStr,
    required this.ampm,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      location: json['location'],
      isMatch: json['is_match'] == 1, // DB Boolean -> Dart bool
      opponentName: json['opponent_name'],
      maxParticipants: json['max_participants'],
      currentParticipants: json['current_participants'],
      dateStr: json['date_str'],
      timeStr: json['time_str'],
      ampm: json['ampm'] == 'PM' ? '오후' : '오전', // 한글 변환
    );
  }
}