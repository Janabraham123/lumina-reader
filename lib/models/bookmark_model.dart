import 'dart:convert';

/// Model penanda halaman (Bookmark) untuk menandai halaman penting di buku.
class BookmarkModel {
  final String id;
  final String bookId;
  final int pageNumber;
  final String? note;
  final DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'] ?? '',
      bookId: map['bookId'] ?? '',
      pageNumber: map['pageNumber'] ?? 1,
      note: map['note'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BookmarkModel.fromJson(String source) =>
      BookmarkModel.fromMap(json.decode(source));
}
