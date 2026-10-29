import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';

/// Layanan penyimpanan lokal untuk mengelola status rak buku, bookmark, dan posisi baca terakhir.
class StorageService {
  static const String _booksKey = 'lumina_books_cache';
  static const String _bookmarksKey = 'lumina_bookmarks_cache';

  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  /// Mengambil semua koleksi buku yang tersimpan.
  Future<List<BookModel>> getBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_booksKey);
    if (jsonString == null || jsonString.isEmpty) {
      final samples = _getInitialSampleBooks();
      await saveBooks(samples);
      return samples;
    }

    try {
      final List<dynamic> decoded = json.decode(jsonString);
      return decoded.map((e) => BookModel.fromMap(e)).toList();
    } catch (e) {
      return _getInitialSampleBooks();
    }
  }

  /// Menyimpan daftar buku secara persisten ke penyimpanan lokal.
  Future<void> saveBooks(List<BookModel> books) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(books.map((b) => b.toMap()).toList());
    await prefs.setString(_booksKey, jsonString);
  }

  /// Memperbarui progres baca halaman terakhir suatu buku.
  Future<void> updateReadingProgress(String bookId, int pageNumber) async {
    final books = await getBooks();
    final index = books.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      books[index].lastReadPage = pageNumber;
      books[index].lastReadAt = DateTime.now();
      if (pageNumber >= books[index].totalPages) {
        books[index].status = 'completed';
      } else if (pageNumber > 1) {
        books[index].status = 'reading';
      }
      await saveBooks(books);
    }
  }

  /// Mengubah status favorit buku.
  Future<void> toggleFavorite(String bookId) async {
    final books = await getBooks();
    final index = books.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      books[index].isFavorite = !books[index].isFavorite;
      await saveBooks(books);
    }
  }

  /// Menambahkan buku baru yang diimpor oleh pengguna.
  Future<void> addBook(BookModel newBook) async {
    final books = await getBooks();
    books.insert(0, newBook);
    await saveBooks(books);
  }

  /// Mengambil bookmark untuk buku tertentu.
  Future<List<BookmarkModel>> getBookmarks(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_bookmarksKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> decoded = json.decode(jsonString);
      return decoded
          .map((e) => BookmarkModel.fromMap(e))
          .where((bm) => bm.bookId == bookId)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Menyimpan bookmark baru.
  Future<void> addBookmark(BookmarkModel bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_bookmarksKey);
    List<BookmarkModel> all = [];
    if (jsonString != null && jsonString.isNotEmpty) {
      final List<dynamic> decoded = json.decode(jsonString);
      all = decoded.map((e) => BookmarkModel.fromMap(e)).toList();
    }
    all.add(bookmark);
    await prefs.setString(
      _bookmarksKey,
      json.encode(all.map((e) => e.toMap()).toList()),
    );
  }

  /// Contoh buku awal untuk pertama kali instalasi
  List<BookModel> _getInitialSampleBooks() {
    return [
      BookModel(
        id: 'sample_1',
        title: 'Filosofi Teras',
        author: 'Henry Manampiring',
        filePath: 'assets/samples/filosofi_teras.pdf',
        totalPages: 280,
        lastReadPage: 42,
        lastReadAt: DateTime.now().subtract(const Duration(hours: 2)),
        isFavorite: true,
        status: 'reading',
      ),
      BookModel(
        id: 'sample_2',
        title: 'Atomic Habits',
        author: 'James Clear',
        filePath: 'assets/samples/atomic_habits.pdf',
        totalPages: 320,
        lastReadPage: 180,
        lastReadAt: DateTime.now().subtract(const Duration(days: 1)),
        isFavorite: true,
        status: 'reading',
      ),
      BookModel(
        id: 'sample_3',
        title: 'Sapiens: Riwayat Singkat Umat Manusia',
        author: 'Yuval Noah Harari',
        filePath: 'assets/samples/sapiens.pdf',
        totalPages: 480,
        lastReadPage: 480,
        lastReadAt: DateTime.now().subtract(const Duration(days: 4)),
        isFavorite: false,
        status: 'completed',
      ),
      BookModel(
        id: 'sample_4',
        title: 'Laskar Pelangi',
        author: 'Andrea Hirata',
        filePath: 'assets/samples/laskar_pelangi.pdf',
        totalPages: 529,
        lastReadPage: 1,
        lastReadAt: DateTime.now().subtract(const Duration(days: 7)),
        isFavorite: false,
        status: 'unread',
      ),
    ];
  }
}
