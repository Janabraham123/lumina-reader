import 'package:flutter/material.dart';
import '../models/book_model.dart';

/// Banner interaktif 'Lanjutkan Membaca' di bagian atas rak buku untuk buku terakhir yang dibuka.
class ContinueReadingCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onResume;

  const ContinueReadingCard({
    super.key,
    required this.book,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (book.progressPercentage * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C4A6E).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Cover Mini
          Container(
            width: 58,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF9A3412),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Center(
              child: Text(
                book.title,
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Deskripsi & Progres
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LANJUTKAN MEMBACA',
                  style: TextStyle(
                    color: Color(0xFF7DD3FC),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${book.author} • Hal ${book.lastReadPage} dari ${book.totalPages}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),

                // Bar Progres
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progres Membaca',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: book.progressPercentage,
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Tombol Buka
          IconButton.filled(
            onPressed: onResume,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0C4A6E),
            ),
            icon: const Icon(Icons.arrow_forward, size: 20),
            tooltip: 'Lanjutkan membaca sekarang',
          ),
        ],
      ),
    );
  }
}
