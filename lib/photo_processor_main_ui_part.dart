part of 'photo_processor_page.dart';

extension _PhotoProcessorMainUiPart on _PhotoProcessorPageState {
  Widget _buildMainPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('靚仔相'),
        actions: [
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => _buildSettingsPage(),
                          ),
                        )
                        .then((_) {
                      _settingsPageRefresh = null;
                      if (mounted) setState(() {});
                    });
                  },
            icon: const Icon(Icons.tune),
            label: const Text('水印與輸出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _pickImages,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text('選擇相片（${_selectedFiles.length} 張）'),
          ),
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '已選 ${_selectedFiles.length} 張。原圖不會被覆蓋。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('開始時間'),
            subtitle: Text(
              _useTodayDate
                  ? DateFormat('HH:mm').format(_startDateTime)
                  : DateFormat('d/M/yyyy HH:mm').format(_startDateTime),
            ),
            trailing: const Icon(Icons.edit),
            onTap: _isProcessing ? null : _pickStartDateTime,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('結束時間'),
            subtitle: Text(
              _useTodayDate
                  ? DateFormat('HH:mm').format(_endDateTime)
                  : DateFormat('d/M/yyyy HH:mm').format(_endDateTime),
            ),
            trailing: const Icon(Icons.edit),
            onTap: _isProcessing ? null : _pickEndDateTime,
          ),
          DropdownButtonFormField<int>(
            initialValue: _timeDistributionMode,
            decoration: const InputDecoration(
              labelText: '多張相片時間分配',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('平均分配')),
              DropdownMenuItem(value: 1, child: Text('隨機分配')),
            ],
            onChanged: _isProcessing
                ? null
                : (v) {
                    if (v != null) {
                      _setStateAndSave(() => _timeDistributionMode = v);
                    }
                  },
          ),
          Text(
            _timeDistributionMode == 1
                ? '多張相片會在開始與結束時間之間隨機分配，並保持時間先後順序。'
                : '多張相片會在開始與結束時間之間平均分配。',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<int>(_maxWidth),
            initialValue: _maxWidth,
            decoration: const InputDecoration(
              labelText: '輸出尺寸（寬度）',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final width in _outputWidthChoices())
                DropdownMenuItem(
                  value: width,
                  child: Text(_outputWidthLabel(width)),
                ),
            ],
            onChanged: _isProcessing
                ? null
                : (v) {
                    if (v != null) {
                      _setStateAndSave(() => _maxWidth = v);
                    }
                  },
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '目前設定',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '日期：${_useTodayDate ? '今日' : DateFormat('d/M/yyyy').format(_startDateTime)}  '
                    '時間：${DateFormat('HH:mm').format(_startDateTime)}–${DateFormat('HH:mm').format(_endDateTime)}',
                  ),
                  Text(
                    '水印：${_applyWatermark ? '開啟' : '關閉'}${_applyWatermark ? ' · $_fontFamily · ${_fontSize.round()} px' : ''}',
                  ),
                  Text(
                      '輸出：${_outputWidthLabel(_maxWidth)} · JPG $_jpegQuality'),
                  Text(
                    '命名：${_renameMode == 0 ? 'IMG日期_001.jpg（同日續號）' : '自定義前綴'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isProcessing) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(_statusMessage),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _cancelRequested = true;
                  _statusMessage = '正在取消…目前這一張完成後停止';
                });
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('取消處理'),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedFiles.isEmpty ? null : _processImages,
                icon: const Icon(Icons.play_arrow),
                label: const Text('開始批量處理'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editNumber({
    required String title,
    required num value,
    required num min,
    required num max,
    required num step,
    required void Function(num) onChanged,
  }) async {
    final controller = TextEditingController(text: _formatEditValue(value));
    final result = await showDialog<num>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            decoration: InputDecoration(
              suffixText: title.contains('透明度') ||
                      title.contains('顆粒') ||
                      title.contains('噪點')
                  ? '%'
                  : null,
            ),
            onSubmitted: (_) {
              final parsed = num.tryParse(controller.text);
              if (parsed != null) Navigator.of(dialogContext).pop(parsed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = num.tryParse(controller.text);
                if (parsed != null) Navigator.of(dialogContext).pop(parsed);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) return;

    final clamped = result.clamp(min, max);
    final snapped = step == 0
        ? clamped
        : (min + (((clamped - min) / step).round() * step));
    onChanged(snapped.clamp(min, max));
    _saveSettings();
  }

  String _formatEditValue(num value) {
    if (value is int) return value.toString();
    final d = value.toDouble();
    if (d == d.roundToDouble()) return d.round().toString();
    return d
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Widget _precisionControl({
    required String title,
    required num value,
    required num min,
    required num max,
    required num step,
    required String unit,
    required void Function(num) onChanged,
    bool disabled = false,
  }) {
    final canMinus = value > min;
    final canPlus = value < max;
    return Row(
      children: [
        Expanded(child: Text(title)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled || !canMinus
              ? null
              : () {
                  final next = (value - step).clamp(min, max);
                  onChanged(next);
                  _saveSettings();
                },
          onLongPressStart: disabled || !canMinus
              ? null
              : (_) {
                  var current = value;
                  _startPrecisionRepeat(() {
                    if (!mounted || _isProcessing) return;
                    final next = (current - step).clamp(min, max);
                    if (next != current) {
                      current = next;
                      onChanged(current);
                      _saveSettings();
                    } else {
                      _stopPrecisionRepeat();
                    }
                  });
                },
          onLongPressEnd: (_) => _stopPrecisionRepeat(),
          onLongPressCancel: _stopPrecisionRepeat,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.remove_circle_outline),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: disabled
              ? null
              : () => _editNumber(
                    title: title,
                    value: value,
                    min: min,
                    max: max,
                    step: step,
                    onChanged: onChanged,
                  ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '${_formatEditValue(value)}$unit',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled || !canPlus
              ? null
              : () {
                  final next = (value + step).clamp(min, max);
                  onChanged(next);
                  _saveSettings();
                },
          onLongPressStart: disabled || !canPlus
              ? null
              : (_) {
                  var current = value;
                  _startPrecisionRepeat(() {
                    if (!mounted || _isProcessing) return;
                    final next = (current + step).clamp(min, max);
                    if (next != current) {
                      current = next;
                      onChanged(current);
                      _saveSettings();
                    } else {
                      _stopPrecisionRepeat();
                    }
                  });
                },
          onLongPressEnd: (_) => _stopPrecisionRepeat(),
          onLongPressCancel: _stopPrecisionRepeat,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.add_circle_outline),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _rgbSlider(String name, int value, void Function(int) setValue) {
    if (_adjustmentMode == 1) {
      return _precisionControl(
        title: name,
        value: value,
        min: 0,
        max: 255,
        step: 1,
        unit: '',
        disabled: _isProcessing,
        onChanged: (v) => _setStateAndSave(() => setValue(v.round())),
      );
    }
    return Row(
      children: [
        SizedBox(width: 58, child: Text('$name: $value')),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => setValue(v.round())),
          ),
        ),
      ],
    );
  }
}
