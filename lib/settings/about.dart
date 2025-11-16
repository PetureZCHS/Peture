import 'package:flutter/material.dart';

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('关于智宠合生'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Logo部分
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    'https://picsum.photos/200/200',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                '智宠合生',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '版本 1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 50),

              // 主要内容区域
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 免责条款
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('我们没有责任嘿嘿嘿'),
                            duration: Duration(milliseconds: 1200),
                            backgroundColor: Color(0xFF666666),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                '免责条款',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Color(0xFFBBBBBB),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Divider(height: 1, color: Colors.grey[200]),

                    // 隐私条款
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('您点击了 隐私条款'),
                            duration: Duration(milliseconds: 1200),
                            backgroundColor: Color(0xFF666666),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                '隐私条款',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Color(0xFFBBBBBB),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Divider(height: 1, color: Colors.grey[200]),

                    // 用户协议
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('您点击了 用户协议'),
                            duration: Duration(milliseconds: 1200),
                            backgroundColor: Color(0xFF666666),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                '用户协议',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Color(0xFFBBBBBB),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Divider(height: 1, color: Colors.grey[200]),

                    // 加入我们
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('您点击了 加入我们'),
                            duration: Duration(milliseconds: 1200),
                            backgroundColor: Color(0xFF666666),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                '加入我们',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Color(0xFFBBBBBB),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
