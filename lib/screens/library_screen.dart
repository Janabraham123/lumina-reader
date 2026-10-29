import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book_model.dart';
import '../services/storage_service.dart';
import '../widgets/book_card.dart';
import '../widgets/continue_reading_card.dart';
import 'reader_screen.dart';

/// Halaman utama rak buku (Library) dengan pelacakan progres membaca, impor file, dan hapus buku.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<BookModel> _books = [];
  String _selectedFilter = 'semua';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final books = await StorageService.instance.getBooks();
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  Future<void> _importPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;

        final newBook = BookModel(
          id: 'pdf_${DateTime.now().millisecondsSinceEpoch}',
          title: file.name.replaceAll('.pdf', '').replaceAll('_', ' '),
          author: 'Dokumen Saya',
          filePath: filePath,
          totalPages: 1, // Akan otomatis diperbarui oleh SfPdfViewer saat dibuka
          lastReadPage: 1,
          lastReadAt: DateTime.now(),
          status: 'unread',
        );

        await StorageService.instance.addBook(newBook);
        await _loadBooks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Buku "${newBook.title}" ($totalPages halaman) berhasil ditambahkan'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih file PDF: $e')),
        );
      }
    }
  }

  Future<void> _deleteBook(BookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Buku?'),
        content: Text('Apakah Anda yakin ingin menghapus "${book.title}" dari rak buku?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.deleteBook(book.id);
      await _loadBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Buku "${book.title}" telah dihapus')),
        );
      }
    }
  }

  void _openReader(BookModel book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(book: book),
      ),
    );
    // Refresh rak buku setelah kembali dari layar baca
    _loadBooks();
  }

  List<BookModel> get _filteredBooks {
    return _books.where((b) {
      final matchesSearch = b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.author.toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesFilter = true;
      if (_selectedFilter == 'sedang') {
        matchesFilter = b.lastReadPage > 1 && b.lastReadPage < b.totalPages;
      } else if (_selectedFilter == 'selesai') {
        matchesFilter = b.lastReadPage >= b.totalPages;
      } else if (_selectedFilter == 'favorit') {
        matchesFilter = b.isFavorite;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final continueBook = _books.isNotEmpty ? _books.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Lumina Reader',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: _importPDF,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Import PDF', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBooks,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Banner Lanjutkan Membaca
                  if (continueBook != null) ...[
                    ContinueReadingCard(
                      book: continueBook,
                      onResume: () => _openReader(continueBook),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Kolom Pencarian
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari judul buku atau nama penulis...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tab Filter Status
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Semua', 'semua'),
                        _buildFilterChip('Sedang Dibaca', 'sedang'),
                        _buildFilterChip('Selesai', 'selesai'),
                        _buildFilterChip('Favorit', 'favorit'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Grid Rak Buku
                  if (_filteredBooks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Rak buku kosong.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ketuk tombol "Import PDF" di atas untuk menambahkan buku Anda.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredBooks.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, idx) {
                        final book = _filteredBooks[idx];
                        return BookCard(
                          book: book,
                          onTap: () => _openReader(book),
                          onFavoriteToggle: () async {
                            await StorageService.instance.toggleFavorite(book.id);
                            _loadBooks();
                          },
                          onDelete: () => _deleteBook(book),
                        );
                      },
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : null,
        ),
        selectedColor: Colors.blue.shade600,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) {
          setState(() => _selectedFilter = value);
        },
      ),
    );
  }
}
