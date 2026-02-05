import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'shop_page.dart';

class OrderPaymentPage extends StatefulWidget {
  final ShopProduct product;
  final int quantity;

  const OrderPaymentPage({
    super.key,
    required this.product,
    required this.quantity,
  });

  @override
  State<OrderPaymentPage> createState() => _OrderPaymentPageState();
}

class _OrderPaymentPageState extends State<OrderPaymentPage> {
  int _paymentMethod = 0; // 0 微信 1 支付宝

  double get totalPrice => widget.product.priceValue * widget.quantity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('确认支付'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildPaymentOptions(),
          _buildHint(),
          const Spacer(),
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FadeInImage.assetNetwork(
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: 'assets/icon/app_icon.png',
              image: widget.product.imageUrl,
              imageErrorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(Icons.image, color: Colors.black26),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('数量：${widget.quantity}'),
                const SizedBox(height: 6),
                Text(
                  '总计：¥${totalPrice.toStringAsFixed(2)}',
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
    );
  }

  Widget _buildPaymentOptions() {
    Widget buildOption({
      required int value,
      required String title,
      required Color color,
      required String logoUrl,
    }) {
      return RadioListTile<int>(
        value: value,
        groupValue: _paymentMethod,
        onChanged: (v) => setState(() => _paymentMethod = v ?? value),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FadeInImage.assetNetwork(
                placeholder: 'assets/icon/app_icon.png',
                image: logoUrl,
                fit: BoxFit.contain,
                imageErrorBuilder: (_, __, ___) =>
                    Icon(Icons.qr_code, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        contentPadding: EdgeInsets.zero,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择支付方式',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          buildOption(
            value: 0,
            title: '微信支付',
            color: const Color(0xFF09BB07),
            logoUrl:
                'https://upload.wikimedia.org/wikipedia/commons/7/7c/WeChat_logo.png',
          ),
          buildOption(
            value: 1,
            title: '支付宝支付',
            color: const Color(0xFF1677FF),
            logoUrl:
                'https://upload.wikimedia.org/wikipedia/commons/0/0d/Alipay_logo.png',
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        '提示：支付完成后，请耐心等待跳转结果。如遇问题，可重新进入或联系人工客服。',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
    );
  }

  Widget _buildPayButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFBE9C5),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBE9C5).withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: _simulatePayment,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '¥${totalPrice.toStringAsFixed(2)} 立即支付',
                  style: GoogleFonts.zcoolKuaiLe(
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _simulatePayment() async {
    // TODO: 在此处调用后端支付接口
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已选择${_paymentMethod == 0 ? '微信支付' : '支付宝'}，模拟支付成功（待接入后端接口）',
        ),
      ),
    );
  }
}
