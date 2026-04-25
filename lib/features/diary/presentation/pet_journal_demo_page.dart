import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

class PetJournalDemoPage extends StatefulWidget {
  const PetJournalDemoPage({super.key});

  @override
  State<PetJournalDemoPage> createState() => _PetJournalDemoPageState();
}

class _PetJournalDemoPageState extends State<PetJournalDemoPage> {
  // Theme colors extracted from screenshots
  final Color _bgDark = const Color(0xFF141416); // Content background

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: _bgDark,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('书写手记', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              centerTitle: false,
              floating: true,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {},
                ),
              ],
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const SizedBox(height: 10),
              _buildAnalysisSection(),
              const SizedBox(height: 24),
              _buildMonthHeader("2026年3月"),
              const SizedBox(height: 12),
              _buildJournalCard(
                date: "3月23日",
                day: "周一",
                title: "我在其外 神在其中",
                content: "Only if one has truly lived a full life can they bear and face the inevitable end of death.",
                images: [
                  "https://images.unsplash.com/photo-1543852786-1cf6624b9987?w=500&auto=format&fit=crop&q=60",
                  "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=500&auto=format&fit=crop&q=60",
                ],
                location: "上海市 · 巨鹿路",
              ),
              const SizedBox(height: 16),
              _buildJournalCard(
                date: "3月21日",
                day: "周六",
                title: "一种宿命的必然性",
                content: "那数百年的沧桑并非漫无目的的流逝，而是一场漫长的预演。",
                images: [
                  "https://images.unsplash.com/photo-1574158622682-e40e69881006?w=500&auto=format&fit=crop&q=60"
                ],
              ),
               const SizedBox(height: 100), // Bottom padding for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSuggestionsSheet(context),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text("记录"),
      ),
    );
  }

  // Analysis Section (Screenshot 1)
  Widget _buildAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("分析 & 连续纪录", style: TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold
        )),
        const SizedBox(height: 12),
        // Streak Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF252535), // Dark blueish
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Align(alignment: Alignment.topRight, child: Icon(Icons.more_horiz, color: Colors.grey)),
              const SizedBox(height: 10),
              const Text("无当前连续纪录", style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Text("每周至少写一篇手记，构建连续纪录。", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
               const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.timer, size: 16),
                label: const Text("设置定时"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3A4A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              )
            ],
          ),
        ),
         const SizedBox(height: 12),
         Row(
           children: [
             Expanded(
               child: _buildStatCard(
                 title: "条",
                 value: "1",
                 subtitle: "今年",
                 color1: const Color(0xFF6A6AE4),
                 color2: const Color(0xFF9A9AE4),
               ),
             ),
             const SizedBox(width: 12),
              Expanded(
               child: _buildStatCard(
                 title: "天",
                 value: "5",
                 subtitle: "已写手记",
                 color1: const Color(0xFFE55D5D),
                 color2: const Color(0xFFE58D8D),
               ),
             ),
           ],
         )
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                TextSpan(text: " $title", style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.calendar_month, color: Colors.blue)),
      ],
    );
  }

  Widget _buildJournalCard({
    required String date,
    required String day,
    required String title,
    required String content,
    List<String>? images,
    String? location,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images != null && images.isNotEmpty)
             SizedBox(
               height: 180,
               child: Row(
                 children: images.map((img) => Expanded(
                   child: Image.network(img, fit: BoxFit.cover, height: 180),
                 )).toList(),
               ),
             ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 8),
                     Text(day, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(content, style: TextStyle(color: Colors.grey[400], height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                if (location != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(location, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  // Suggestions Sheet (Screenshot 2)
  void _showSuggestionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F2F7), // Light grey iOS style or White
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), 
                             child: const Text("取消", style: TextStyle(fontSize: 16))),
                  const SizedBox(width: 20),
                  // Segmented Control
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<int>(
                      children: const {
                        0: Text("推荐"),
                        1: Text("最近活动"),
                      },
                      groupValue: 0,
                      onValueChanged: (v) {},
                    ),
                  ),
                   const SizedBox(width: 60), // Balance the "Cancel" button
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Red Banner (Review)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE55D5D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("回顾", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 8),
                        Text("检视最近的时刻。选些本周给你带来欢乐的事，并写下来。", 
                             style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                   const Icon(Icons.refresh, color: Colors.white),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Grid of Moments
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                   _buildMomentCard(
                    title: "上午瑜伽",
                    subtitle: "8月14日 星期四",
                    image: "https://images.unsplash.com/photo-1544367563-12123d8965cd?w=500&auto=format&fit=crop&q=60", 
                    icon: Icons.fitness_center,
                    color: Colors.black,
                  ),
                   _buildMomentCard(
                    title: "下午去了肯德基",
                    subtitle: "8月13日 星期三",
                    image: "https://images.unsplash.com/photo-1513639776629-7b611594e99b?w=500&auto=format&fit=crop&q=60", 
                    icon: Icons.fastfood,
                    color: Colors.orange,
                    isMap: true,
                  ),
                   _buildMomentCard(
                    title: "晚上去了上海市 巨鹿路",
                    subtitle: "8月8日 星期五",
                    image: "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=500&auto=format&fit=crop&q=60", 
                    icon: Icons.restaurant,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
            
            // Bottom Bar
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 color: const Color(0xFF1C1C1E),
                 border: Border(top: BorderSide(color: Colors.grey[800]!)),
               ),
               child: SafeArea(
                 child: Row(
                   children: [
                     const Icon(Icons.edit, color: Colors.grey),
                     const SizedBox(width: 10),
                     const Text("说点什么...", style: TextStyle(color: Colors.grey, fontSize: 16)),
                     const Spacer(),
                     IconButton(onPressed: () {}, icon: const Icon(Icons.mic, color: Colors.grey)),
                     IconButton(onPressed: () {}, icon: const Icon(Icons.camera_alt, color: Colors.grey)),
                   ],
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildMomentCard({
    required String title,
    required String subtitle,
    required String image,
    required IconData icon,
    required Color color,
    bool isMap = false,
  }) {
    return GestureDetector(
      onTap: () {
        // Close sheet and navigate to compose with data
        Navigator.pop(context);
        // Navigate or populate
         _showToast("已选择: $title");
         // Wait for sheet to close then navigate? 
         // For demo, just show toast
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey[200],
                    child: image.startsWith("http")
                        ? Image.network(image, fit: BoxFit.cover)
                        : isMap
                            ? const Center(
                                child: Icon(Icons.map, size: 50, color: Colors.grey))
                            : const Center(
                                child: Icon(Icons.photo, size: 50, color: Colors.grey)),
                  ),
                  if (title.contains("瑜伽"))
                     Center(
                       child: Container(
                         width: 80, height: 80,
                         decoration: const BoxDecoration(
                           color: Colors.black, // Dark circle
                           shape: BoxShape.circle,
                         ),
                         child: const Center(child: Icon(Icons.self_improvement, color: Color.fromARGB(255, 172, 255, 47), size: 40)),
                       ),
                     ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(icon, size: 16, color: color),
                    ),
                  )
                ],
              ),
            ),
             Padding(
               padding: const EdgeInsets.all(12),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   const SizedBox(height: 4),
                   Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
