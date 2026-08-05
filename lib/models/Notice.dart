class Notice {
  final String title; // e.g., "Classwork posted"
  final String notice; // e.g., "NURSERY Sunflower Gulshan"
  final String date; // e.g., "29-5-2025"
  final bool isUnread; // New field

  Notice({
    required this.title,
    required this.notice,
    required this.date,
    required this.isUnread,
  });
}

final noticeItems = [
  Notice(
    title: "Notice",
    notice: "5C Maymaar - Notice Posted",
    date: "Wed 02/07/2025",
    isUnread: true,
  ),

  // Add more items...
  Notice(
    title: "Notice",
    notice: "5C Maymaar - Notice Posted",
    date: "Wed 02/07/2025",
    isUnread: false,
  ),
  Notice(
    title: "Summer Vacations Circular",
    notice: "5C Maymaar - Notice Posted",
    date: "Wed 30/05/2025",
    isUnread: false,
  ),
];
