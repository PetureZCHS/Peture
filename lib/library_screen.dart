import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/pet_diary.dart';
import 'services/supabase_service.dart';
import 'pages/library/diary_timeline_page.dart';

class Book {
  final String title;
  final String coverUrl;
  final int entryCount;
  final Color color;
  final List<PetDiary> entries;

  Book({
    required this.title,
    required this.coverUrl,
    required this.entryCount,
    required this.entries,
    this.color = Colors.brown,
  });
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isLoading = true;
  List<PetDiary> _diaries = [];

  @override
  void initState() {
    super.initState();
    _fetchDiaries();
  }

  Future<void> _fetchDiaries() async {
    try {
      final diaries = await SupabaseService().getAllDiaries();
      setState(() {
        _diaries = diaries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching diaries: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create a single book containing all fetched diaries
    // In a real app, you might group these by Pet, Year, or Month.
    final List<Book> books = [];
    
    if (_diaries.isNotEmpty) {
      books.add(
        Book(
          title: "我的宠物日记",
          coverUrl: "https://images.unsplash.com/photo-1517849845537-4d257902454a?w=500&auto=format&fit=crop&q=60",
          entryCount: _diaries.length,
          color: Colors.amber.shade800,
          entries: _diaries,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Soft off-white
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFFF5F5F5),
            floating: true,
            pinned: true,
            elevation: 0,
            centerTitle: false,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                '书库',
                style: GoogleFonts.notoSerif(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 28, // Large title like Apple Books
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (books.isEmpty)
             SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "暂无日记",
                      style: GoogleFonts.notoSerif(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "创建你的第一篇宠物日记",
                      style: GoogleFonts.lato(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65, // Accommodate book + text
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 30,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = books[index];
                    return _BookItem(book: book);
                  },
                  childCount: books.length,
                ),
              ),
            ),
          // Add some bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }
}

class _BookItem extends StatelessWidget {
  final Book book;

  const _BookItem({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DiaryTimelinePage(),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: BookCover(
              imageUrl: book.coverUrl,
              fallbackColor: book.color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            book.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.merriweather(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${book.entryCount} 篇日记',
            style: GoogleFonts.lato( // Or system font
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class BookCover extends StatelessWidget {
  final String imageUrl;
  final Color fallbackColor;

  const BookCover({
    super.key,
    required this.imageUrl,
    this.fallbackColor = Colors.brown,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.7, // 2:3 ratio roughly
      child: Container(
        decoration: BoxDecoration(
          color: fallbackColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(6),
            bottomRight: Radius.circular(6),
            topLeft: Radius.circular(2),
            bottomLeft: Radius.circular(2),
          ),
          boxShadow: [
            // Deep soft shadow for floating effect
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(4, 8),
            ),
            // Subtle outline/rim shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              // Fallback if image fails
            },
          ),
        ),
        child: Stack(
          children: [
            // Spine Effect (Left side gradient)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 12, // Width of the spine crease
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Spine Highlight (Very thin line on the far left)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            // Sheen/Gloss (Top right gradient)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4],
                  ),
                ),
              ),
            ),
            // Inner shadow for depth (inset feel)
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
