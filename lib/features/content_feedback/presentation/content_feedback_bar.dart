import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/content_feedback_repository.dart';
import '../domain/content_feedback_kind.dart';

/// 将 ref 转为仅含 JSON 可编码类型的 Map，避免 Postgrest 编码时抛错导致红屏
Map<String, dynamic> _jsonSafeRef(Map<String, dynamic> raw) {
  try {
    final encoded = jsonEncode(raw);
    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {
    // ignore
  }
  return {'hint': 'ref_serialization_failed'};
}

/// 举报 BottomSheet 内容：独立 StatefulWidget，避免父 builder 因键盘/Insets
/// 重建时丢失状态或触发 Column 溢出断言。
class _ReportFeedbackSheet extends StatefulWidget {
  const _ReportFeedbackSheet({
    required this.surface,
    required this.ref,
    required this.repo,
    required this.hostContext,
    this.messenger,
  });

  final ContentSurface surface;
  final Map<String, dynamic> ref;
  final ContentFeedbackRepository repo;
  final BuildContext hostContext;
  final ScaffoldMessengerState? messenger;

  @override
  State<_ReportFeedbackSheet> createState() => _ReportFeedbackSheetState();
}

class _ReportFeedbackSheetState extends State<_ReportFeedbackSheet> {
  late final TextEditingController _noteController;
  String? _selected = ContentReportReason.illegal;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final code = _selected ?? ContentReportReason.other;
    final note = _noteController.text;
    try {
      await widget.repo.submit(
        feedbackType: ContentFeedbackType.report,
        surface: widget.surface,
        ref: _jsonSafeRef(Map<String, dynamic>.from(widget.ref)),
        reasonCode: code,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      // pop 后会 dispose 本 State，不可在 PostFrameCallback 里再读 widget.*
      final host = widget.hostContext;
      final msg = widget.messenger;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!host.mounted) return;
        try {
          msg?.showSnackBar(
            const SnackBar(
              content: Text('已收到您的举报，我们会尽快处理'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (_) {
          // SnackBar 失败不应再抛给框架
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
      }
      if (widget.hostContext.mounted) {
        try {
          widget.messenger?.showSnackBar(
            SnackBar(
              content: Text('提交失败：$e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '举报内容',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...ContentReportReason.labels.entries.map((e) {
              return RadioListTile<String>(
                dense: true,
                value: e.key,
                groupValue: _selected,
                title: Text(e.value),
                onChanged: _submitting
                    ? null
                    : (v) {
                        setState(
                          () => _selected = v ?? ContentReportReason.other,
                        );
                      },
              );
            }),
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '补充说明（选填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _onSubmit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 内容下方的「举报」「不感兴趣」入口（满足应用商店对可见反馈入口的要求）
class ContentFeedbackBar extends StatelessWidget {
  const ContentFeedbackBar({
    super.key,
    required this.surface,
    required this.ref,
    this.onNotInterestedSuccess,
    this.dense = false,
  });

  final ContentSurface surface;
  final Map<String, dynamic> ref;
  final VoidCallback? onNotInterestedSuccess;
  final bool dense;

  static final _repo = ContentFeedbackRepository();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey.shade600,
          fontSize: dense ? 12 : 13,
        );

    return Padding(
      padding: EdgeInsets.only(top: dense ? 6 : 12),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.grey.shade700,
            ),
            onPressed: () => _openReportSheet(context),
            child: Text('举报', style: style),
          ),
          Text('·', style: style),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.grey.shade700,
            ),
            onPressed: () => _confirmNotInterested(context),
            child: Text('不感兴趣', style: style),
          ),
        ],
      ),
    );
  }

  Future<void> _openReportSheet(BuildContext hostContext) async {
    final messenger = ScaffoldMessenger.maybeOf(hostContext);

    await showModalBottomSheet<void>(
      context: hostContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return _ReportFeedbackSheet(
          surface: surface,
          ref: ref,
          repo: _repo,
          hostContext: hostContext,
          messenger: messenger,
        );
      },
    );
  }

  Future<void> _confirmNotInterested(BuildContext hostContext) async {
    final messenger = ScaffoldMessenger.maybeOf(hostContext);

    final ok = await showDialog<bool>(
      context: hostContext,
      builder: (ctx) => AlertDialog(
        title: const Text('不感兴趣'),
        content: Text(
          onNotInterestedSuccess != null
              ? '将记录您的偏好，并在当前对话中隐藏该条回复。'
              : '将记录您的偏好，用于改进内容推荐。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (ok != true || !hostContext.mounted) return;

    try {
      await _repo.submit(
        feedbackType: ContentFeedbackType.notInterested,
        surface: surface,
        ref: _jsonSafeRef(Map<String, dynamic>.from(ref)),
      );
      onNotInterestedSuccess?.call();
      if (hostContext.mounted) {
        try {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('已记录'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (_) {}
      }
    } catch (e) {
      if (hostContext.mounted) {
        try {
          messenger?.showSnackBar(
            SnackBar(
              content: Text('提交失败：$e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (_) {}
      }
    }
  }
}
