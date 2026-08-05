class Comment {
  final String userName;
  final String avatarUrl; // or use initials
  final String text;
  final String date;
  final bool hasEmoji;

  Comment({
    required this.userName,
    this.avatarUrl = '',
    required this.text,
    required this.date,
    this.hasEmoji = false,
  });
}

// Example data:
final comments = [
  Comment(
    userName: "Ahmar Mansoob",
    text: "Thank you so much miss Fozia, 💬 💬",
    date: "Tue, 24/06/2025 09:01:02",
    hasEmoji: true,
  ),
  Comment(
    userName: "Muhammad Raheel Ahmed",
    text: "Thank you miss never gonna forget",
    date: "Wed, 02/07/2025 03:22:08 AM",
  ),
];
