import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../services/storage_service.dart';
import '../services/audio_haptic_service.dart';
import '../widgets/page_curl_view.dart';
import '../widgets/toc_sheet.dart';

enum ReaderThemeMode { sepia, light, dark }

/// Layar pembaca buku PDF dengan animasi 3D Page Curl realistis,
/// scrubber progres, daftar isi, penanda halaman, dan tema warna baca.
class ReaderScreen extends StatefulWidget {
  final BookModel book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _currentPage;
  bool _isHudVisible = true;
  ReaderThemeMode _themeMode = ReaderThemeMode.sepia;
  List<BookmarkModel> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final list = await StorageService.instance.getBookmarks(widget.book.id);
    setState(() => _bookmarks = list);
  }

  void _onPageChanged(int newPage) {
    setState(() {
      _currentPage = newPage;
    });
    // Simpan progres baca secara otomatis dan persisten
    StorageService.instance.updateReadingProgress(widget.book.id, newPage);
  }

  void _toggleBookmark() async {
    final existingIndex = _bookmarks.indexWhere((bm) => bm.pageNumber == _currentPage);
    if (existingIndex != -1) {
      // Hapus bookmark
      setState(() => _bookmarks.removeAt(existingIndex));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Penanda halaman $_currentPage dihapus')),
      );
    } else {
      // Tambah bookmark
      final newBm = BookmarkModel(
        id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
        bookId: widget.book.id,
        pageNumber: _currentPage,
        createdAt: DateTime.now(),
      );
      await StorageService.instance.addBookmark(newBm);
      await _loadBookmarks();
      AudioHapticService.instance.triggerHaptic();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Halaman $_currentPage berhasil ditandai')),
        );
      }
    }
  }

  void _openTOC() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TocSheet(
        bookTitle: widget.book.title,
        totalPages: widget.book.totalPages,
        bookmarks: _bookmarks,
        onSelectPage: (page) {
          _onPageChanged(page);
        },
      ),
    );
  }

  Color get _paperBackgroundColor {
    switch (_themeMode) {
      case ReaderThemeMode.sepia:
        return const Color(0xFFFBF0D9);
      case ReaderThemeMode.light:
        return const Color(0xFFFFFFFF);
      case ReaderThemeMode.dark:
        return const Color(0xFF18181B);
    }
  }

  Color get _textColor {
    switch (_themeMode) {
      case ReaderThemeMode.sepia:
        return const Color(0xFF382918);
      case ReaderThemeMode.light:
        return const Color(0xFF1E293B);
      case ReaderThemeMode.dark:
        return const Color(0xFFE4E4E7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBookmarked = _bookmarks.any((bm) => bm.pageNumber == _currentPage);
    final percent = widget.book.totalPages > 0
        ? ((_currentPage / widget.book.totalPages) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: _paperBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Konten Buku Utama dengan Animasi 3D Page Curl
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isHudVisible = !_isHudVisible);
                },
                child: PageCurlView(
                  totalPages: widget.book.totalPages,
                  initialPage: _currentPage,
                  paperColor: _paperBackgroundColor,
                  onPageChanged: _onPageChanged,
                  pageBuilder: (context, pageIndex) {
                    return _buildPageContent(pageIndex);
                  },
                ),
              ),
            ),

            // Top HUD (Toolbar Atas)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _isHudVisible ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Kembali ke Rak',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Bab ${((_currentPage / 20).ceil())}: Halaman $_currentPage',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isBookmarked ? Colors.blue : null,
                      ),
                      onPressed: _toggleBookmark,
                      tooltip: 'Tandai Halaman',
                    ),
                    IconButton(
                      icon: const Icon(Icons.list_alt),
                      onPressed: _openTOC,
                      tooltip: 'Daftar Isi',
                    ),
                    _buildThemeMenu(),
                  ],
                ),
              ),
            ),

            // Bottom HUD (Scrubber Slider & Progres Baca)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _isHudVisible ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$_currentPage',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Slider(
                            value: _currentPage.toDouble(),
                            min: 1.0,
                            max: widget.book.totalPages.toDouble(),
                            onChanged: (val) {
                              _onPageChanged(val.round());
                            },
                          ),
                        ),
                        Text(
                          '${widget.book.totalPages}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Halaman $_currentPage dari ${widget.book.totalPages} ($percent%)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Sisa ${widget.book.totalPages - _currentPage} hal',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeMenu() {
    return PopupMenuButton<ReaderThemeMode>(
      icon: const Icon(Icons.palette_outlined),
      tooltip: 'Pilih Tema Kertas',
      onSelected: (mode) => setState(() => _themeMode = mode),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: ReaderThemeMode.sepia,
          child: Row(
            children: [
              CircleAvatar(radius: 8, backgroundColor: Color(0xFFFBF0D9)),
              SizedBox(width: 10),
              Text('Sepia (Kertas Hangat)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: ReaderThemeMode.light,
          child: Row(
            children: [
              CircleAvatar(radius: 8, backgroundColor: Colors.white),
              SizedBox(width: 10),
              Text('Terang (Light)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: ReaderThemeMode.dark,
          child: Row(
            children: [
              CircleAvatar(radius: 8, backgroundColor: Color(0xFF18181B)),
              SizedBox(width: 10),
              Text('Gelap (Dark)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageContent(int pageIndex) {
    return Container(
      color: _paperBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Halaman
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.book.title,
                style: TextStyle(
                  fontSize: 11,
                  color: _textColor.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Bab ${((pageIndex / 20).ceil())}',
                style: TextStyle(
                  fontSize: 11,
                  color: _textColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),

          // Teks Isi Halaman
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembahasan Halaman $pageIndex',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ketenangan batin tidak hadir dari mengendalikan dunia di sekitar kita, melainkan dari kemampuan kita mengendalikan persepsi dan respons kita terhadap kenyataan hidup.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: Colors.blue.shade600, width: 3),
                      ),
                    ),
                    child: Text(
                      '"Bukan hal di luar kendali kita yang merisaukan manusia, melainkan penilaian manusia itu sendiri."',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        color: _textColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Setiap kali Anda membalik halaman dengan menggeser jari, posisi terakhir selalu dicatat secara otomatis. Anda dapat keluar kapan pun dan melanjutkan membaca persis di titik ini.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Nomor Halaman
          Center(
            child: Text(
              '$pageIndex',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _textColor.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
