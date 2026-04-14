import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/pet_diary.dart';
import '../../../services/supabase_service.dart';
import '../../diary/presentation/diary_timeline_page.dart';

class Book {
  final String? id; // Pet ID (null for "Other")
  final String title;
  final String coverUrl;
  final int entryCount;
  final Color color;
  final List<PetDiary> entries;

  Book({
    this.id,
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
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final service = SupabaseService();

      // 并行获取宠物列表和所有日记
      final results = await Future.wait([
        service.getAllPets(),
        service.getAllDiaries(),
      ]);

      final petsData = results[0] as List<Map<String, dynamic>>;
      final diaries = results[1] as List<PetDiary>;

      // 按 petId 分组日记
      final Map<String, List<PetDiary>> diariesByPetId = {};
      final List<PetDiary> unknownPetDiaries = [];

      for (var diary in diaries) {
        if (diary.petId != null) {
          if (!diariesByPetId.containsKey(diary.petId)) {
            diariesByPetId[diary.petId!] = [];
          }
          diariesByPetId[diary.petId!]!.add(diary);
        } else {
          unknownPetDiaries.add(diary);
        }
      }

      final List<Book> books = [];

      // 为每个宠物创建一个"书"
      for (var pet in petsData) {
        final petId = pet['id'] as String;
        final petName = pet['name'] as String? ?? '未命名';
        final petAvatar = pet['avatar'] as String?;
        final petDiaries = diariesByPetId[petId] ?? [];

        books.add(Book(
          id: petId,
          title: "$petName 的日记",
          coverUrl: petAvatar ??
              "https://images.unsplash.com/photo-1517849845537-4d257902454a?w=500&auto=format&fit=crop&q=60",
          entryCount: petDiaries.length,
          color: _getPetColor(petId),
          entries: petDiaries,
        ));
      }

      // 如果有归属不明的日记，也创建一个书
      if (unknownPetDiaries.isNotEmpty) {
        books.add(Book(
          id: null,
          title: "其他的日记",
          coverUrl:
              "https://images.unsplash.com/photo-1544376798-89aa6b82c630?w=500&auto=format&fit=crop&q=60",
          entryCount: unknownPetDiaries.length,
          color: Colors.blueGrey.shade700,
          entries: unknownPetDiaries,
        ));
      }

      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching library data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPetColor(String id) {
    final colors = [
      Colors.amber.shade800,
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.purple.shade700,
      Colors.orange.shade800,
      Colors.teal.shade700,
      Colors.indigo.shade700,
      Colors.deepOrange.shade800,
      Colors.brown.shade700,
      Colors.red.shade700,
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Soft off-white
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            else if (_books.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined,
                          size: 64, color: Colors.grey[400]),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65, // Accommodate book + text
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 30,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = _books[index];
                      return _BookItem(
                        book: book,
                        onRefresh: _fetchData,
                      );
                    },
                    childCount: _books.length,
                  ),
                ),
              ),
            // Add some bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookItem extends StatelessWidget {
  final Book book;
  final VoidCallback onRefresh;

  const _BookItem({
    required this.book,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryTimelinePage(
              petId: book.id,
              bookTitle: book.title,
            ),
          ),
        );
        onRefresh();
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
            style: GoogleFonts.lato(
              // Or system font
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
    ImageProvider? imageProvider;
    if (imageUrl.startsWith('http')) {
      imageProvider = NetworkImage(imageUrl);
    } else {
      imageProvider = FileImage(File(imageUrl));
    }

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
            image: imageProvider,
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
