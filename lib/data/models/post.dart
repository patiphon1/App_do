import 'package:cloud_firestore/cloud_firestore.dart';

enum PostTag { announce, donate, swap }

PostTag tagFromString(String s) {
  switch (s) {
    case 'donate': return PostTag.donate;
    case 'swap':   return PostTag.swap;
    default:       return PostTag.announce;
  }
}

String tagToString(PostTag t) {
  switch (t) {
    case PostTag.donate: return 'donate';
    case PostTag.swap:   return 'swap';
    case PostTag.announce:
    default:             return 'announce';
  }
}

class Post {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String title;
  final String? imageUrl;
  final PostTag tag;
  final int comments;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.title,
    required this.tag,
    required this.comments,
    required this.createdAt,
    this.imageUrl,
    this.expiresAt, 
  });

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Post(
      id: doc.id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userAvatar: d['userAvatar'] ?? '',
      title: d['title'] ?? '',
      imageUrl: d['imageUrl'],
      tag: tagFromString(d['tag'] ?? 'announce'),
      comments: (d['comments'] ?? 0) as int,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(), 
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userAvatar': userAvatar,
    'title': title,
    'imageUrl': imageUrl,
    'tag': tagToString(tag),
    'comments': comments,
    'createdAt': FieldValue.serverTimestamp(),
    if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!), 
    'titleKeywords': _keywords(title),
  };

  static List<String> _keywords(String s) {
    final words = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ก-๙\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList();
    return words;
  }
}
