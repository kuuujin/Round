class Post {
  final int id;
  final String title;
  final String content;
  final String time;
  final int likes;
  final int comments;
  final String? imageUrl;
  final String authorName; // 작성자 이름 추가

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.likes,
    required this.comments,
    this.imageUrl,
    required this.authorName,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      time: json['time'],
      likes: json['likes'],
      comments: json['comment_count'] ?? 0,
      imageUrl: json['image_url'],
      authorName: json['author_name'],
    );
  }
}

class Comment {
  final int id;
  final String content;
  final String time;
  final String authorName;
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
      time: json['time'],
      authorName: json['author_name'],
      authorImage: json['author_image'],
    );
  }
}