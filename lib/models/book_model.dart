import 'dart:convert';

/// Model representasi buku PDF di dalam aplikasi.
class BookModel {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverImagePath;
  final int totalPages;
  int lastReadPage;
  DateTime lastReadAt;
  bool isFavorite;
  String status; // 'unread', 'reading', 'completed'

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverImagePath,
    required this.totalPages,
    this.lastReadPage = 1,
    required this.lastReadAt,
    this.isFavorite = false,
    this.status = 'unread',
  });

  /// Menghitung persentase progres membaca (0.0 sampai 1.0).
  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return (lastReadPage / totalPages).clamp(0.0, 1.0);
  }

  /// Menghasilkan format persentase bilangan bulat (misal: "45%").
  String get progressPercentText {
    return '${(progressPercentage * 100).round()}%';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverImagePath': coverImagePath,
      'totalPages': totalPages,
      'lastReadPage': lastReadPage,
      'lastReadAt': lastReadAt.toIso8601String(),
      'isFavorite': isFavorite,
      'status': status,
    };
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Tanpa Judul',
      author: map['author'] ?? 'Penulis Tidak Dikenal',
      filePath: map['filePath'] ?? '',
      coverImagePath: map['coverImagePath'],
      totalPages: map['totalPages'] ?? 1,
      lastReadPage: map['lastReadPage'] ?? 1,
      lastReadAt: map['lastReadAt'] != null 
          ? DateTime.parse(map['lastReadAt']) 
          : DateTime.now(),
      isFavorite: map['isFavorite'] ?? false,
      status: map['status'] ?? 'unread',
    );
  }

  String toJson() => json.encode(toMap());

  factory BookModel.fromJson(String source) => 
      BookModel.fromMap(json.decode(source));
}
