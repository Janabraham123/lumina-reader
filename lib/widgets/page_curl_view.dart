import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_haptic_service.dart';

/// Widget animasi 3D Page Curl realistis ala Google Play Books.
/// Mendukung gestur drag tangan bebas, tap di tepi, efek bayangan lipatan dinamis,
/// serta audio dan haptic feedback.
class PageCurlView extends StatefulWidget {
  final int totalPages;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext context, int pageIndex) pageBuilder;
  final Color paperColor;

  const PageCurlView({
    super.key,
    required this.totalPages,
    required this.initialPage,
    required this.onPageChanged,
    required this.pageBuilder,
    this.paperColor = const Color(0xFFFBF0D9),
  });

  @override
  State<PageCurlView> createState() => _PageCurlViewState();
}

class _PageCurlViewState extends State<PageCurlView> with SingleTickerProviderStateMixin {
  late int _currentPage;
  late AnimationController _animController;
  late Animation<double> _curlAnimation;

  double _dragAmount = 0.0; // Rentang: -1.0 (prev) ke 1.0 (next)
  bool _isDragging = false;
  bool _isTurningNext = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _animController.addListener(() {
      setState(() {
        _dragAmount = _curlAnimation.value;
      });
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isTurningNext && _currentPage < widget.totalPages) {
          _currentPage++;
          widget.onPageChanged(_currentPage);
        } else if (!_isTurningNext && _currentPage > 1) {
          _currentPage--;
          widget.onPageChanged(_currentPage);
        }
        setState(() {
          _dragAmount = 0.0;
          _isDragging = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PageCurlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != _currentPage) {
      _currentPage = widget.initialPage;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _turnNext() {
    if (_currentPage >= widget.totalPages || _animController.isAnimating) return;
    _isTurningNext = true;
    _isDragging = false;
    AudioHapticService.instance.playPageFlipSound();
    AudioHapticService.instance.triggerHaptic();

    _curlAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    _animController.forward(from: 0.0);
  }

  void _turnPrev() {
    if (_currentPage <= 1 || _animController.isAnimating) return;
    _isTurningNext = false;
    _isDragging = false;
    AudioHapticService.instance.playPageFlipSound();
    AudioHapticService.instance.triggerHaptic();

    _curlAnimation = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    _animController.forward(from: 0.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_animController.isAnimating) return;
    _isDragging = true;
    AudioHapticService.instance.triggerHaptic();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (_animController.isAnimating || width <= 0) return;
    setState(() {
      final delta = -details.primaryDelta! / width;
      _dragAmount = (_dragAmount + delta).clamp(-1.0, 1.0);
      _isTurningNext = _dragAmount >= 0;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_animController.isAnimating) return;
    _isDragging = false;

    // Jika tarikan melewati ambang 25%, selesaikan pembalikan halaman
    if (_dragAmount.abs() > 0.25) {
      final target = _dragAmount > 0 ? 1.0 : -1.0;
      _isTurningNext = target > 0;
      if ((_isTurningNext && _currentPage < widget.totalPages) ||
          (!_isTurningNext && _currentPage > 1)) {
        AudioHapticService.instance.playPageFlipSound();
        _curlAnimation = Tween<double>(begin: _dragAmount, end: target).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
        _animController.forward(from: 0.0);
        return;
      }
    }

    // Jika tidak melewati batas, kembalikan posisi ke awal (cancel flip)
    _curlAnimation = Tween<double>(begin: _dragAmount, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Tentukan halaman aktif dan halaman tujuan di baliknya
        final underPageIndex = _isTurningNext
            ? (_currentPage < widget.totalPages ? _currentPage + 1 : _currentPage)
            : (_currentPage > 1 ? _currentPage - 1 : _currentPage);

        return GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, width),
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onTapUp: (details) {
            // Tap di sisi kiri untuk mundur, tap di sisi kanan untuk maju
            if (details.localPosition.dx < width * 0.2) {
              _turnPrev();
            } else if (details.localPosition.dx > width * 0.8) {
              _turnNext();
            }
          },
          child: Stack(
            children: [
              // 1. Layer Halaman Bawah (Under Page)
              Positioned.fill(
                child: widget.pageBuilder(context, underPageIndex),
              ),

              // 2. Layer Halaman Atas Aktif (Current Page) yang tergulung
              if (_dragAmount.abs() > 0.001)
                Positioned.fill(
                  child: ClipRect(
                    clipper: _PageCurlClipper(
                      progress: _dragAmount.abs(),
                      isTurningNext: _isTurningNext,
                    ),
                    child: widget.pageBuilder(context, _currentPage),
                  ),
                )
              else
                Positioned.fill(
                  child: widget.pageBuilder(context, _currentPage),
                ),

              // 3. Efek Visual Bayangan Lipatan Kertas (3D Page Curl Shading)
              if (_dragAmount.abs() > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CurlShadowPainter(
                        progress: _dragAmount.abs(),
                        isTurningNext: _isTurningNext,
                        paperColor: widget.paperColor,
                      ),
                    ),
                  ),
                ),

              // 4. Garis Tekukan Tulang Buku di Tengah (Spine Shadow)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.02),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.08),
                        ],
                        stops: const [0.0, 0.02, 0.06, 0.94, 0.98, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pemotong area halaman aktif berdasarkan progres tarikan lipatan kertas.
class _PageCurlClipper extends CustomClipper<Rect> {
  final double progress;
  final bool isTurningNext;

  _PageCurlClipper({required this.progress, required this.isTurningNext});

  @override
  Rect getClip(Size size) {
    if (isTurningNext) {
      // Membuka lembaran dari kanan ke kiri
      final visibleWidth = size.width * (1.0 - progress);
      return Rect.fromLTWH(0, 0, visibleWidth, size.height);
    } else {
      // Membuka lembaran dari kiri ke kanan
      final startX = size.width * progress;
      return Rect.fromLTWH(startX, 0, size.width - startX, size.height);
    }
  }

  @override
  bool shouldReclip(covariant _PageCurlClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.isTurningNext != isTurningNext;
  }
}

/// Pelukis bayangan 3D silinder realistis di tepi lekukan lembaran halaman.
class _CurlShadowPainter extends CustomPainter {
  final double progress;
  final bool isTurningNext;
  final Color paperColor;

  _CurlShadowPainter({
    required this.progress,
    required this.isTurningNext,
    required this.paperColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Titik X pertemuan lipatan kertas
    final foldX = isTurningNext ? width * (1.0 - progress) : width * progress;
    const shadowWidth = 36.0;

    // 1. Bayangan jatuh di halaman dasar (Drop shadow)
    final shadowRect = Rect.fromLTRB(
      foldX - (isTurningNext ? shadowWidth : 0),
      0,
      foldX + (isTurningNext ? 0 : shadowWidth),
      height,
    );

    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: isTurningNext ? Alignment.centerRight : Alignment.centerLeft,
        end: isTurningNext ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(0.24 * progress),
          Colors.black.withOpacity(0.04 * progress),
          Colors.transparent,
        ],
      ).createShader(shadowRect);

    canvas.drawRect(shadowRect, shadowPaint);

    // 2. Kilauan cahaya halus di puncak tekukan silinder (Cylinder highlight)
    final highlightRect = Rect.fromLTRB(
      foldX - 8,
      0,
      foldX + 8,
      height,
    );

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.20 * progress),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(highlightRect);

    canvas.drawRect(highlightRect, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _CurlShadowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isTurningNext != isTurningNext ||
        oldDelegate.paperColor != paperColor;
  }
}
