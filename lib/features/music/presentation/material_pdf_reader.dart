import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/member_choir_visuals.dart';

class MaterialPdfReader extends StatefulWidget {
  const MaterialPdfReader({
    super.key,
    required this.filePath,
    required this.initialPage,
    required this.busy,
    required this.onPageChanged,
    required this.onReload,
  });

  final String filePath;
  final int initialPage;
  final bool busy;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onReload;

  @override
  State<MaterialPdfReader> createState() => _MaterialPdfReaderState();
}

class _MaterialPdfReaderState extends State<MaterialPdfReader> {
  PDFViewController? _controller;
  late int _page = widget.initialPage;
  int? _pages;
  bool _turning = false;
  String? _error;

  Future<void> _goToPage(int page) async {
    final controller = _controller;
    if (controller == null || _turning) return;
    setState(() => _turning = true);
    try {
      await controller.setPage(page);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể chuyển trang PDF.');
    } finally {
      if (mounted) setState(() => _turning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pages;
    return Column(
      children: [
        Material(
          color: MemberChoirStyle.paper,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Trang trước',
                onPressed: _turning || _controller == null || _page <= 0
                    ? null
                    : () => _goToPage(_page - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Flexible(
                child: Text(
                  pageCount == null
                      ? 'Trang ${_page + 1}'
                      : 'Trang ${_page + 1} / $pageCount',
                  style: AppTypography.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Trang sau',
                onPressed:
                    _turning ||
                        _controller == null ||
                        pageCount == null ||
                        _page + 1 >= pageCount
                    ? null
                    : () => _goToPage(_page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PDFView(
            filePath: widget.filePath,
            defaultPage: widget.initialPage,
            swipeHorizontal: true,
            onViewCreated: (controller) {
              if (mounted) setState(() => _controller = controller);
            },
            onRender: (pages) {
              if (mounted) setState(() => _pages = pages);
            },
            onPageChanged: (page, pages) {
              if (!mounted || page == null) return;
              setState(() {
                _page = page;
                _pages = pages ?? _pages;
                _error = null;
              });
              widget.onPageChanged(page);
            },
            onError: (_) {
              if (mounted) setState(() => _error = 'Không thể hiển thị PDF.');
            },
            onPageError: (_, _) {
              if (mounted) {
                setState(() => _error = 'Không thể hiển thị trang PDF này.');
              }
            },
          ),
        ),
        if (_error case final message?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: widget.busy ? null : widget.onReload,
                  child: const Text('Tải lại'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
