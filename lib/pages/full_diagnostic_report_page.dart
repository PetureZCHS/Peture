import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FullDiagnosticReportPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const FullDiagnosticReportPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final diagnosis = data['diagnosis'] as String? ?? '未知诊断';
    final possibleCauses = (data['possible_causes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final adviceSummary = data['advice_summary'] as String? ?? '';
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 灰色背景衬托纸张
      appBar: AppBar(
        title: const Text("诊断报告详情"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 600), // 限制最大宽度像A4纸
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部装饰条
                Container(
                  height: 8,
                  color: const Color(0xFF5D5FEF),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 医院标题
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              "Peture AI 宠物智能诊室",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "AI 辅助诊断报告单",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(thickness: 1.5, color: Colors.black87),
                      
                      // 病人信息栏
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem("姓名", "您的爱宠"),
                            _buildInfoItem("科室", "全科"),
                            _buildInfoItem("日期", DateFormat('yyyy-MM-dd').format(now)),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1.0, color: Colors.black26),
                      const SizedBox(height: 20),

                      // 检查所见 (Possible Causes)
                      _buildSectionHeader("检查所见 / 症状分析"),
                      const SizedBox(height: 8),
                      if (possibleCauses.isEmpty)
                        const Text("未提供详细症状分析。", style: TextStyle(fontSize: 15, height: 1.6))
                      else
                        ...possibleCauses.map((cause) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(fontSize: 15, height: 1.6)),
                                  Expanded(
                                    child: Text(
                                      cause,
                                      style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      const SizedBox(height: 24),

                      // 印象 (Diagnosis)
                      _buildSectionHeader("诊断印象"),
                      const SizedBox(height: 8),
                      Text(
                        diagnosis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 建议 (Advice)
                      _buildSectionHeader("处置建议"),
                      const SizedBox(height: 8),
                      Text(
                        adviceSummary,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // 底部签名区
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "诊断医师: Peture AI",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Cursive', // 尝试模拟手写体，或者直接用普通字体
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "报告时间: $formattedDate",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(thickness: 1.0, color: Colors.black26),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          "本报告由 AI 生成，仅供参考，不能替代线下兽医诊断。\n如遇紧急情况，请立即前往最近的宠物医院就诊。",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            decoration: TextDecoration.underline, // 模仿填空下划线
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
