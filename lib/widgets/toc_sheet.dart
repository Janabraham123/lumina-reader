import 'package:flutter/material.dart';
import '../models/bookmark_model.dart';

/// Modal bottom sheet untuk melihat Daftar Isi dan Penanda Halaman (Bookmarks).
class TocSheet extends StatelessWidget {
  final String bookTitle;
  final int totalPages;
  final List<BookmarkModel> bookmarks;
  final ValueChanged<int> onSelectPage;

  const TocSheet({
    super.key,
    required this.bookTitle,
    required this.totalPages,
    required this.bookmarks,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Tab Bar
            const TabBar(
              tabs: [
                Tab(text: 'Daftar Isi (Bab)'),
                Tab(text: 'Penanda Halaman'),
              ],
            ),

            // Content
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Daftar Isi Otomatis
                  ListView.separated(
                    itemCount: (totalPages / 25).ceil().clamp(1, 50),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final targetPage = (idx * 25) + 1;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          idx == 0 ? 'Bagian Pembuka' : 'Bab $idx: Pembahasan Utama $idx',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          'Hal $targetPage',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onSelectPage(targetPage);
                        },
                      );
                    },
                  ),

                  // Tab 2: Bookmark Pengguna
                  bookmarks.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada halaman yang ditandai.\nKetuk ikon pita di layar baca untuk menambahkan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: bookmarks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final bm = bookmarks[idx];
                            return ListTile(
                              leading: const Icon(Icons.bookmark, color: Colors.blue),
                              title: Text(
                                'Penanda Halaman ${bm.pageNumber}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: bm.note != null ? Text(bm.note!) : null,
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () {
                                Navigator.pop(context);
                                onSelectPage(bm.pageNumber);
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
