import 'package:flutter/material.dart';

import 'order_payment_page.dart';
import 'shop_page.dart';

class ProductDetailPage extends StatefulWidget {
  final ShopProduct product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;

  static final List<String> _comments = List.generate(
    6,
    (index) => '用户${index + 1}：东西很好，宠物超喜欢，物流也很快，下次还会回购！',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('商品详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _buildImageCarousel(),
                _buildProductInfo(),
                _buildQuantitySelector(),
                _buildTags(),
                _buildComments(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return SizedBox(
      height: 320,
      child: PageView.builder(
        itemCount: 4,
        itemBuilder: (_, index) => FadeInImage.assetNetwork(
          placeholder: 'assets/icon/app_icon.png',
          image: widget.product.imageUrl,
          fit: BoxFit.cover,
          imageErrorBuilder: (_, __, ___) => Container(
            color: Colors.white,
            child: const Icon(Icons.image, size: 60, color: Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.price,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF5722),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            widget.product.sales,
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '购买数量',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity', style: const TextStyle(fontSize: 16)),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: -6,
        children: widget.product.tags
            .map(
              (tag) => Chip(
                label: Text(tag),
                backgroundColor: const Color(0xFFF5F5F5),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildComments() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '宝贝评价',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._comments.map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                comment,
                style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '合计',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              Text(
                '¥${(widget.product.priceValue * _quantity).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5722),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('加入购物车'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderPaymentPage(
                      product: widget.product,
                      quantity: _quantity,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('立即购买'),
            ),
          ),
        ],
      ),
    );
  }
}


