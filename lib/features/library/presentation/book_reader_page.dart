import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_flip/page_flip.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/pet_diary.dart';

class BookReaderPage extends StatefulWidget {
  final String bookTitle;
  final Color coverColor;
  final List<PetDiary> entries;

  const BookReaderPage({
    super.key,
    required this.bookTitle,
    required this.coverColor,
    required this.entries,
  });

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final _controller = GlobalKey<PageFlipWidgetState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5), // Warm paper color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.bookTitle,
          style: GoogleFonts.notoSerif(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: PageFlipWidget(
        key: _controller,
        backgroundColor: const Color(0xFFFFFDF5), // Match scaffold
        lastPage: Container(
          color: const Color(0xFFFFFDF5),
          child: Center(
            child: Text(
              '完',
              style: GoogleFonts.notoSerif(
                fontSize: 24,
                color: Colors.black54,
              ),
            ),
          ),
        ),
        children: [
          // Cover Page (Optional, or just start with first entry)
          _buildCoverPage(),

          // Diary Pages
          ...widget.entries.asMap().entries.map((entry) {
            return _buildDiaryPage(entry.value, entry.key + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildCoverPage() {
    return Container(
      color: widget.coverColor,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.bookTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 2,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            "${widget.entries.length} 篇日记",
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryPage(PetDiary entry, int pageNum) {
    return Container(
      color: const Color(0xFFFFFDF5), // Warmer paper color
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Center(
            child: Text(
              DateFormat('yyyy年MM月dd日').format(entry.timestamp),
              style: GoogleFonts.lato(
                fontSize: 12,
                color: Colors.grey[500],
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            "${entry.style}日记",
            style: GoogleFonts.notoSerif(
              // Changed to notoSerif which supports many scripts or fallback
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Content
          Expanded(
            child: Text(
              entry.content,
              style: GoogleFonts.notoSerif(
                fontSize: 16,
                color: const Color(0xFF2C2C2C),
                height: 1.8, // Comfortable reading line height
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.justify,
            ),
          ),

          // Page Number
          Center(
            child: Text(
              "$pageNum",
              style: GoogleFonts.lato(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
