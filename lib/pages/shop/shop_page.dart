import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../live_shop/live_shop_page.dart';
import 'product_detail_page.dart';

class PetShopPage extends StatefulWidget {
  const PetShopPage({super.key});

  @override
  State<PetShopPage> createState() => _PetShopPageState();
}

class _PetShopPageState extends State<PetShopPage> {
  final PageController _bannerController = PageController();
  int _currentBanner = 0;
  Timer? _autoPlayTimer;

  static final List<_ShopCategory> _categories = [
    _ShopCategory('爆款推荐', Icons.local_fire_department, Colors.redAccent),
    _ShopCategory('智能硬件', Icons.smart_toy, Colors.blueAccent),
    _ShopCategory('营养美食', Icons.fastfood, Colors.orangeAccent),
    _ShopCategory('护理美容', Icons.spa_outlined, Colors.pinkAccent),
    _ShopCategory('玩具日用', Icons.toys, Colors.green),
    _ShopCategory('户外出行', Icons.hiking, Colors.purpleAccent),
  ];

  static final List<ShopProduct> _products = List.generate(40, (index) {
    final categories = ['爆款推荐', '智能硬件', '营养美食', '护理美容', '玩具日用', '户外出行'];
    return ShopProduct(
      name: '宠物好物 ${index + 1}',
      price: '¥${(49 + index * 3)}',
      sales: '月销 ${(800 + index * 120)}',
      tags: [
        if (index % 2 == 0) '热销',
        if (index % 3 == 0) '新品',
        '好评 ${(96 + index % 3)}%'
      ],
      category: categories[index % categories.length],
      imageUrl: 'https://dummyimage.com/600x600/fafafa/f1f1f1.png&text=Pet+${index + 1}',
    );
  });

  static const List<String> _bannerImages = [
    'https://images.unsplash.com/photo-1514986888952-8cd320577b68?w=800',
    'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=800',
    'https://images.unsplash.com/photo-1619983081593-a9a82f3cfee1?w=800',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800',
    'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=800',
  ];

  @override
  void initState() {
    super.initState();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        final nextPage = (_currentBanner + 1) % _bannerImages.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: const [
              Icon(Icons.search, color: Colors.black54, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '搜索宠物好物，如“猫砂”',
                  style: TextStyle(color: Colors.black45, fontSize: 14),
                ),
              ),
              Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 20),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildBanner()),
          SliverToBoxAdapter(child: _buildCategorySection()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildFlashSaleButtons(context)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '猜你喜欢',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemBuilder: (context, index) => _ProductCard(product: _products[index]),
              childCount: _products.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: _bannerImages.length,
                onPageChanged: (index) => setState(() => _currentBanner = index),
                itemBuilder: (context, index) => FadeInImage.assetNetwork(
                  placeholder: 'assets/icon/app_icon.png',
                  image: _bannerImages[index],
                  fit: BoxFit.cover,
                  imageErrorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.pets, size: 60, color: Colors.black26),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: List.generate(
                    _bannerImages.length,
                    (index) => Container(
                      width: _currentBanner == index ? 14 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _currentBanner == index ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetShopCategoryPage(
                    category: category.name,
                    products: _products.where((p) => p.category == category.name).toList(),
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(category.icon, color: category.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlashSaleButtons(BuildContext context) {
    final List<_FlashButton> buttons = [
      _FlashButton('限时秒杀', Colors.redAccent, Icons.flash_on, () {}),
      _FlashButton('领券中心', Colors.orange, Icons.card_giftcard, () {}),
      _FlashButton('品牌馆', Colors.purple, Icons.workspace_premium_outlined, () {}),
      _FlashButton('直播福利', Colors.blueAccent, Icons.live_tv, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LiveShopPage()),
        );
      }),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: buttons
            .map(
              (b) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: b.onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: b.color.withOpacity(0.15),
                      foregroundColor: b.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Column(
                      children: [
                        Icon(b.icon),
                        const SizedBox(height: 4),
                        Text(b.title, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ShopProduct product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1,
                child: FadeInImage.assetNetwork(
                  placeholder: 'assets/icon/app_icon.png',
                  image: product.imageUrl,
                  fit: BoxFit.cover,
                  imageErrorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[100],
                    child: const Icon(Icons.pets, size: 32, color: Colors.black26),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.sales,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: -6,
                    children: product.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 10)),
                            backgroundColor: const Color(0xFFF5F5F5),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5722),
                    ),
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

class ShopProduct {
  final String name;
  final String price;
  final String sales;
  final List<String> tags;
  final String category;
  final String imageUrl;

  const ShopProduct({
    required this.name,
    required this.price,
    required this.sales,
    required this.tags,
    required this.category,
    required this.imageUrl,
  });

  double get priceValue {
    final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}

class _ShopCategory {
  final String name;
  final IconData icon;
  final Color color;

  const _ShopCategory(this.name, this.icon, this.color);
}

class _FlashButton {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  _FlashButton(this.title, this.color, this.icon, this.onTap);
}

class PetShopCategoryPage extends StatelessWidget {
  final String category;
  final List<ShopProduct> products;

  const PetShopCategoryPage({
    super.key,
    required this.category,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: products.isEmpty
          ? Center(
              child: Text(
                '该分类下暂无商品',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemBuilder: (_, index) => _ProductCard(product: products[index]),
              itemCount: products.length,
            ),
    );
  }
}


