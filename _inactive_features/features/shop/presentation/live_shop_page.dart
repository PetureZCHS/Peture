import 'package:flutter/material.dart';

class LiveShopPage extends StatelessWidget {
  const LiveShopPage({super.key});

  static final List<_LiveRoom> _rooms = List.generate(10, (index) {
    final anchors = ['小萌', 'MOMO', '汪小主', '猫猫子', '果冻', '柠檬'];
    return _LiveRoom(
      title: '宠物好物直播间 ${index + 1}',
      anchor: anchors[index % anchors.length],
      viewers: '${(3.5 + index * 0.6).toStringAsFixed(1)} 万观看',
      description: index % 2 == 0 ? '今日新品 • 限时福利' : '秒杀 5 折 • 抢到赚到',
      imageUrl:
          'https://dummyimage.com/600x800/f7f7f7/e0e0e0&text=Live+${index + 1}',
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('直播福利'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => _LiveRoomCard(room: _rooms[index]),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemCount: _rooms.length,
      ),
    );
  }
}

class _LiveRoomCard extends StatelessWidget {
  final _LiveRoom room;

  const _LiveRoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFE3F2FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: FadeInImage.assetNetwork(
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: 'assets/icon/app_icon.png',
                image: room.imageUrl,
                imageErrorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: Colors.grey[200],
                  child: const Icon(Icons.live_tv,
                      size: 48, color: Colors.black26),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '直播中',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        room.viewers,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    room.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${room.anchor} · $room.description',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
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

class _LiveRoom {
  final String title;
  final String anchor;
  final String viewers;
  final String description;
  final String imageUrl;

  const _LiveRoom({
    required this.title,
    required this.anchor,
    required this.viewers,
    required this.description,
    required this.imageUrl,
  });
}
