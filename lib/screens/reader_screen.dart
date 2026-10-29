import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../services/storage_service.dart';
import '../services/audio_haptic_service.dart';
import '../widgets/page_curl_view.dart';
import '../widgets/toc_sheet.dart';

enum ReaderThemeMode { sepia, light, dark }

/// Layar pembaca buku PDF dengan render halaman asli dari file PDF,
/// animasi 3D Page Curl realistis, zoom, daftar isi, penanda, dan tema warna baca.
class ReaderScreen extends StatefulWidget {
  final BookModel book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _currentPage;
  late int _totalPages;
  bool _isHudVisible = true;
  ReaderThemeMode _themeMode = ReaderThemeMode.light;
  List<BookmarkModel> _bookmarks = [];

  PdfDocument? _pdfDocument;
  final Map<int, Uint8List> _renderedPageCache = {};
  final Set<int> _renderingPages = {};
  bool _isLoadingPdf = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _totalPages = widget.book.totalPages > 0 ? widget.book.totalPages : 1;
    _loadBookmarks();
    _openPdfDocument();
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _openPdfDocument() async {
    setState(() {
      _isLoadingPdf = true;
      _errorMessage = null;
    });

    try {
      final path = widget.book.filePath;

      if (path.startsWith('assets/')) {
        // Cek apakah file aset ada
        try {
          _pdfDocument = await PdfDocument.openAsset(path);
        } catch (_) {
          setState(() {
            _errorMessage = 'Ini adalah buku contoh pratinjau.\nSilakan impor file PDF Anda sendiri dari memori HP untuk membaca dokumen lengkap.';
            _isLoadingPdf = false;
          });
          return;
        }
      } else {
        // File PDF asli dari penyimpanan HP
        final file = File(path);
        if (!await file.exists()) {
          setState(() {
            _errorMessage = 'File PDF tidak ditemukan di lokasi penyimpanan:\n$path';
            _isLoadingPdf = false;
          });
          return;
        }
        _pdfDocument = await PdfDocument.openFile(path);
      }

      if (_pdfDocument != null) {
        setState(() {
          _totalPages = _pdfDocument!.pagesCount;
          _isLoadingPdf = false;
        });

        // Update total halaman buku jika berbeda
        if (widget.book.totalPages != _totalPages) {
          widget.book.totalPages = _totalPages;
          StorageService.instance.updateReadingProgress(widget.book.id, _currentPage);
        }

        // Render halaman saat ini dan halaman berikutnya untuk transisi mulus
        _renderPage(_currentPage);
        if (_currentPage < _totalPages) {
          _renderPage(_currentPage + 1);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat dokumen PDF: $e';
        _isLoadingPdf = false;
      });
    }
  }

  Future<void> _renderPage(int pageNumber) async {
    if (_pdfDocument == null ||
        _renderedPageCache.containsKey(pageNumber) ||
        _renderingPages.contains(pageNumber)) {
      return;
    }

    if (pageNumber < 1 || pageNumber > _totalPages) return;

    _renderingPages.add(pageNumber);

    try {
      final page = await _pdfDocument!.getPage(pageNumber);
      // Skala 2.0x agar teks dan gambar di halaman PDF sangat tajam dan jelas
      final pageImage = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      await page.close();

      if (pageImage != null && mounted) {
        setState(() {
          _renderedPageCache[pageNumber] = pageImage.bytes;
        });
      }
    } catch (e) {
      debugPrint('Error saat merender halaman $pageNumber: $e');
    } finally {
      _renderingPages.remove(pageNumber);
    }
  }

  Future<void> _loadBookmarks() async {
    final list = await StorageService.instance.getBookmarks(widget.book.id);
    setState(() => _bookmarks = list);
  }

  void _onPageChanged(int newPage) {
    if (newPage < 1 || newPage > _totalPages) return;

    setState(() {
      _currentPage = newPage;
    });

    // Simpan progres baca ke database
    StorageService.instance.updateReadingProgress(widget.book.id, newPage);

    // Render halaman sekitar secara cerdas (preloading)
    _renderPage(newPage);
    if (newPage < _totalPages) _renderPage(newPage + 1);
    if (newPage > 1) _renderPage(newPage - 1);
  }

  void _toggleBookmark() async {
    final existingIndex = _bookmarks.indexWhere((bm) => bm.pageNumber == _currentPage);
    if (existingIndex != -1) {
      setState(() => _bookmarks.removeAt(existingIndex));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Penanda halaman $_currentPage dihapus')),
      );
    } else {
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
        totalPages: _totalPages,
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

  @override
  Widget build(BuildContext context) {
    final isBookmarked = _bookmarks.any((bm) => bm.pageNumber == _currentPage);
    final percent = _totalPages > 0
        ? ((_currentPage / _totalPages) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: _paperBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Konten Halaman PDF dengan Animasi 3D Page Curl
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isHudVisible = !_isHudVisible);
                },
                child: _buildBody(),
              ),
            ),

            // Top Toolbar (Header)
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
                            'Halaman $_currentPage dari $_totalPages ($percent%)',
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

            // Bottom Scrubber Bar (Navigasi Halaman)
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
                            value: _currentPage.clamp(1, _totalPages).toDouble(),
                            min: 1.0,
                            max: _totalPages > 1 ? _totalPages.toDouble() : 1.0,
                            onChanged: (val) {
                              _onPageChanged(val.round());
                            },
                          ),
                        ),
                        Text(
                          '$_totalPages',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Halaman $_currentPage dari $_totalPages ($percent%)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Sisa ${_totalPages - _currentPage} hal',
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

  Widget _buildBody() {
    if (_isLoadingPdf) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Membuka dokumen PDF...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali ke Rak Buku'),
              ),
            ],
          ),
        ),
      );
    }

    return PageCurlView(
      totalPages: _totalPages,
      initialPage: _currentPage,
      paperColor: _paperBackgroundColor,
      onPageChanged: _onPageChanged,
      pageBuilder: (context, pageIndex) {
        return _buildPdfPageContent(pageIndex);
      },
    );
  }

  Widget _buildPdfPageContent(int pageIndex) {
    final imageBytes = _renderedPageCache[pageIndex];

    if (imageBytes == null) {
      _renderPage(pageIndex);
      return Container(
        color: _paperBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Memuat halaman $pageIndex...',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Render Gambar Asli Halaman PDF
    Widget pdfImage = Image.memory(
      imageBytes,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    // Filter Tema Warna
    if (_themeMode == ReaderThemeMode.sepia) {
      pdfImage = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0x228D6E63), BlendMode.multiply),
        child: pdfImage,
      );
    } else if (_themeMode == ReaderThemeMode.dark) {
      // Inversi warna untuk mode gelap (teks putih di latar hitam)
      pdfImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: pdfImage,
      );
    }

    return Container(
      color: _paperBackgroundColor,
      child: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 3.5,
          child: pdfImage,
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
          value: ReaderThemeMode.light,
          child: Row(
            children: [
              CircleAvatar(radius: 8, backgroundColor: Colors.white),
              SizedBox(width: 10),
              Text('Terang (Asli PDF)'),
            ],
          ),
        ),
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
          value: ReaderThemeMode.dark,
          child: Row(
            children: [
              CircleAvatar(radius: 8, backgroundColor: Color(0xFF18181B)),
              SizedBox(width: 10),
              Text('Gelap (Inversi Malam)'),
            ],
          ),
        ),
      ],
    );
  }
}
