import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../services/storage_service.dart';
import '../services/audio_haptic_service.dart';
import '../widgets/toc_sheet.dart';

enum ReaderThemeMode { light, sepia, dark }

/// Layar pembaca buku PDF dengan render dokumen asli melalui Syncfusion PDF Viewer.
/// Mendukung pembalikan halaman horizontal, zoom pinch, audio gesekan kertas, haptic,
/// daftar isi, penanda, dan tema warna baca.
class ReaderScreen extends StatefulWidget {
  final BookModel book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PdfViewerController _pdfViewerController;
  late int _currentPage;
  late int _totalPages;
  bool _isHudVisible = true;
  ReaderThemeMode _themeMode = ReaderThemeMode.light;
  List<BookmarkModel> _bookmarks = [];
  bool _isReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPage;
    _totalPages = widget.book.totalPages > 0 ? widget.book.totalPages : 1;
    _pdfViewerController = PdfViewerController();
    _loadBookmarks();
    _validateFile();
  }

  void _validateFile() {
    final path = widget.book.filePath;
    if (!path.startsWith('assets/')) {
      final file = File(path);
      if (!file.existsSync()) {
        setState(() {
          _errorMessage = 'File PDF tidak ditemukan di memori HP:\n$path';
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
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

    // Simpan posisi baca secara otomatis
    StorageService.instance.updateReadingProgress(widget.book.id, newPage);

    // Mainkan efek audio lembaran kertas & haptic
    AudioHapticService.instance.playPageFlipSound();
    AudioHapticService.instance.triggerHaptic();
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
          _pdfViewerController.jumpToPage(page);
        },
      ),
    );
  }

  Color get _paperBackgroundColor {
    switch (_themeMode) {
      case ReaderThemeMode.sepia:
        return const Color(0xFFFBF0D9);
      case ReaderThemeMode.light:
        return const Color(0xFFF1F5F9);
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
            // Konten Viewer Dokumen Asli PDF
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isHudVisible = !_isHudVisible);
                },
                child: _buildPdfViewer(),
              ),
            ),

            // Top Header Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _isHudVisible ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.96),
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
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.96),
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
                              final target = val.round();
                              _pdfViewerController.jumpToPage(target);
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

  Widget _buildPdfViewer() {
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

    final path = widget.book.filePath;
    Widget viewer;

    if (path.startsWith('assets/')) {
      viewer = SfPdfViewer.asset(
        path,
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.single,
        scrollDirection: PdfScrollDirection.horizontal,
        pageSpacing: 4,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPages = details.document.pages.count;
            _isReady = true;
          });
          if (widget.book.totalPages != _totalPages) {
            widget.book.totalPages = _totalPages;
            StorageService.instance.updateReadingProgress(widget.book.id, _currentPage);
          }
          if (_currentPage > 1) {
            _pdfViewerController.jumpToPage(_currentPage);
          }
        },
        onPageChanged: (PdfPageChangedDetails details) {
          _onPageChanged(details.newPageNumber);
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          setState(() {
            _errorMessage = 'Buku contoh ini belum memiliki berkas PDF lokal.\nSilakan gunakan tombol "Import PDF" di rak buku untuk membuka dokumen asli Anda!';
          });
        },
      );
    } else {
      viewer = SfPdfViewer.file(
        File(path),
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.single,
        scrollDirection: PdfScrollDirection.horizontal,
        pageSpacing: 4,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPages = details.document.pages.count;
            _isReady = true;
          });
          if (widget.book.totalPages != _totalPages) {
            widget.book.totalPages = _totalPages;
            StorageService.instance.updateReadingProgress(widget.book.id, _currentPage);
          }
          if (_currentPage > 1) {
            _pdfViewerController.jumpToPage(_currentPage);
          }
        },
        onPageChanged: (PdfPageChangedDetails details) {
          _onPageChanged(details.newPageNumber);
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          setState(() {
            _errorMessage = 'Gagal memuat dokumen PDF:\n${details.description}';
          });
        },
      );
    }

    // Filter Tema Warna
    if (_themeMode == ReaderThemeMode.sepia) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0x208D6E63), BlendMode.multiply),
        child: viewer,
      );
    } else if (_themeMode == ReaderThemeMode.dark) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: viewer,
      );
    }

    return viewer;
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
