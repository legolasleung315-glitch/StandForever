// ignore_for_file: invalid_use_of_protected_member

part of 'photo_processor_page.dart';

extension _PhotoProcessorResultsPart on _PhotoProcessorPageState {
  List<Widget> _buildPerformanceRows() {
    const labels = <String, String>{
      'read': '讀取原圖',
      'decode': '圖片解碼',
      'resize': '尺寸縮放',
      'color': '色彩／模糊處理',
      'grainNoise': '顆粒／噪點',
      'watermark': '字型／水印繪製',
      'jpegEncode': 'JPEG 編碼',
      'tempWrite': '暫存檔寫入',
      'configFont': '設定／字型載入',
      'safWrite': 'SAF 正式儲存',
      'localWrite': '本機正式儲存',
      'galleryIndex': '圖庫索引',
    };
    final entries = _performanceTotalsUs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTotal = entries.isEmpty
        ? 1
        : entries.first.value.clamp(1, 1 << 62);
    return entries.map((entry) {
      final average = _performanceImageCount == 0
          ? 0
          : (entry.value / _performanceImageCount).round();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                labels[entry.key] ?? entry.key,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LinearProgressIndicator(
                value: (entry.value / maxTotal).clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatPerformanceDuration(entry.value)}'
              ' · 均 ${_formatPerformanceDuration(average)}'
              ' · 峰 ${_formatPerformanceDuration(_performanceMaxUs[entry.key] ?? 0)}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
    }).toList(growable: false);
  }

  Future<void> _shareResults() async {
    if (_resultFiles.isEmpty) {
      _showError('沒有可分享的處理結果');
      return;
    }
    try {
      final files = _resultFiles
          .where((path) => path.isNotEmpty && File(path).existsSync())
          .map((path) => XFile(path, mimeType: 'image/jpeg'))
          .toList(growable: false);
      if (files.isEmpty) {
        _showError('找不到可分享的圖片檔案');
        return;
      }
      await SharePlus.instance.share(ShareParams(files: files));
    } catch (e) {
      if (mounted) _showError('分享失敗：$e');
    }
  }

  Future<void> _browseGeneratedImages() async {
    final files = _resultFiles
        .where((path) => path.isNotEmpty && File(path).existsSync())
        .toList(growable: false);
    if (files.isEmpty) {
      _showError('沒有可瀏覽的處理結果');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GeneratedImagesPage(files: files),
      ),
    );
  }

  Future<void> _deleteResults() async {
    if (_resultFiles.isEmpty || !mounted) return;

    final count = _resultFiles.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除處理結果？'),
        content:
            Text('確定要刪除剛才生成的 $count 張圖片嗎？\n\n刪除後無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    int deleted = 0;
    int failed = 0;
    for (final path in List<String>.from(_resultFiles)) {
      try {
        if (Platform.isAndroid) {
          final uri = _safUriByCachePath[path];
          if (uri != null) await _saf.delete(uri);
        }
        final file = File(path);
        if (await file.exists()) await file.delete();
        deleted++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    _resultFiles.clear();
    _safUriByCachePath.clear();
    _resultDisplayNames.clear();

    Navigator.of(context).pop();
    final message = failed == 0
        ? '已刪除 $deleted 張圖片'
        : '已刪除 $deleted 張圖片，$failed 張刪除失敗';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showResults(String outputDirectory) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('處理結果'),
          content: SizedBox(
            width: 500,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成功：${_resultFiles.length} 張'),
                if (_errors.isNotEmpty)
                  Text(
                    '失敗／警告：${_errors.length} 項',
                    style: const TextStyle(color: Colors.orange),
                  ),
                const SizedBox(height: 8),
                Text(
                  outputDirectory,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  leading: const Icon(Icons.speed),
                  title: const Text('處理效能分析'),
                  subtitle: Text(
                    '整批實際耗時：${_formatStopwatchElapsed(_batchStopwatch.elapsed)}'
                    ' · 已量測 ${_performanceImageCount} 張',
                  ),
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '以下為各張圖片階段時間累計；因多張並行處理，累計值可能大於整批實際耗時。',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 150,
                      child: SingleChildScrollView(
                        child: Column(
                          children: _buildPerformanceRows(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _resultFiles.length + _errors.length,
                    itemBuilder: (context, index) {
                      if (index < _resultFiles.length) {
                        final path = _resultFiles[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(
                            _resultDisplayNames[path] ??
                                path.split(Platform.pathSeparator).last,
                          ),
                        );
                      }
                      final error = _errors[index - _resultFiles.length];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber),
                        title: Text(error),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actionsOverflowButtonSpacing: 16,
          actions: [
            if (_resultFiles.isNotEmpty)
              FilledButton.icon(
                onPressed: _browseGeneratedImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('瀏覽'),
              ),
            if (_resultFiles.isNotEmpty)
              FilledButton.icon(
                onPressed: _shareResults,
                icon: const Icon(Icons.share),
                label: const Text('分享'),
              ),
            if (_resultFiles.isNotEmpty)
              FilledButton.icon(
                onPressed: _deleteResults,
                icon: const Icon(Icons.delete_outline),
                label: const Text('刪除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    setState(() {
      _statusMessage = message;
    });
  }
}
