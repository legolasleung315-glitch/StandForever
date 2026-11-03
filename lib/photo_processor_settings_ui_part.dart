part of 'photo_processor_page.dart';

extension _PhotoProcessorSettingsUiPart on _PhotoProcessorPageState {
  Widget _buildSettingsPage() {
    return StatefulBuilder(
      builder: (context, settingsSetState) {
        _settingsPageRefresh = () {
          if (context.mounted) {
            settingsSetState(() {});
          }
        };
        return Scaffold(
          appBar: AppBar(title: const Text('水印與輸出')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._buildSettingsTopChildren(),
              ..._buildSettingsAdvancedChildren(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSettingsTopChildren() {
    return [
      _sectionTitle('時間水印'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('加入時間水印'),
        subtitle: const Text('同時修改輸出檔案時間'),
        value: _applyTime,
        onChanged: _isProcessing
            ? null
            : (v) => _setStateAndSave(() => _applyTime = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('使用今日日期'),
        subtitle: const Text('開始／結束只設定時間'),
        value: _useTodayDate,
        onChanged: _isProcessing
            ? null
            : (v) => _setStateAndSave(() => _useTodayDate = v),
      ),
      _sectionTitle('水印設定'),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(
              value: 0, icon: Icon(Icons.swipe), label: Text('Slider 快速')),
          ButtonSegment<int>(
              value: 1, icon: Icon(Icons.tune), label: Text('精調')),
        ],
        selected: <int>{_adjustmentMode},
        onSelectionChanged: _isProcessing
            ? null
            : (selection) {
                _setStateAndSave(() => _adjustmentMode = selection.first);
              },
      ),
      const SizedBox(height: 4),
      Text(
        _adjustmentMode == 0
            ? '左右滑動快速調整參數'
            : '使用 −／＋ 或點擊數值精確調整',
        style: const TextStyle(fontSize: 12),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('顯示水印'),
        value: _applyWatermark,
        onChanged: _isProcessing
            ? null
            : (v) => _setStateAndSave(() => _applyWatermark = v),
      ),
      DropdownButtonFormField<String>(
        initialValue: _fontLabels.containsKey(_fontFamily)
            ? _fontFamily
            : 'Film_Camera',
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: '水印字體',
        ),
        items: _fontLabels.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: _isProcessing
            ? null
            : (v) {
                if (v != null) {
                  _setStateAndSave(() {
                    _fontFamily = v;
                    _cachedFontFamily = null;
                    _cachedFontFntBytes = null;
                    _cachedFontPngBytes = null;
                  });
                }
              },
      ),
      const SizedBox(height: 10),
      if (_adjustmentMode == 0) ...[
        Text('字體大小：${_fontSize.round()} px'),
        Slider(
            value: _fontSize,
            min: 14,
            max: 160,
            divisions: 42,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _fontSize = v)),
        Text('邊距：${_margin.round()} px'),
        Slider(
            value: _margin,
            min: 8,
            max: 80,
            divisions: 36,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _margin = v)),
        Text('透明度：${(_opacity * 100).round()}%'),
        Slider(
            value: _opacity,
            min: 0.2,
            max: 1,
            divisions: 16,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _opacity = v)),
      ] else ...[
        _precisionControl(
            title: '字體大小',
            value: _fontSize.round(),
            min: 14,
            max: 160,
            step: 1,
            unit: ' px',
            disabled: _isProcessing,
            onChanged: (v) =>
                _setStateAndSave(() => _fontSize = v.toDouble())),
        _precisionControl(
            title: '邊距',
            value: _margin.round(),
            min: 8,
            max: 80,
            step: 1,
            unit: ' px',
            disabled: _isProcessing,
            onChanged: (v) =>
                _setStateAndSave(() => _margin = v.toDouble())),
        _precisionControl(
            title: '透明度',
            value: (_opacity * 100).round(),
            min: 20,
            max: 100,
            step: 1,
            unit: '%',
            disabled: _isProcessing,
            onChanged: (v) =>
                _setStateAndSave(() => _opacity = v.toDouble() / 100)),
      ],
      TextFormField(
        initialValue: _extraWatermarkText,
        decoration: const InputDecoration(
          labelText: '其他水印文字（可留空）',
          hintText: '例如：Tokyo / Work',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          _extraWatermarkText = v;
          _saveSettings();
        },
        enabled: !_isProcessing,
      ),
      const SizedBox(height: 10),
      const Text('水印顏色 RGB'),
      _rgbSlider('R', _colorR, (v) => _colorR = v),
      _rgbSlider('G', _colorG, (v) => _colorG = v),
      _rgbSlider('B', _colorB, (v) => _colorB = v),
      Container(
        height: 28,
        decoration: BoxDecoration(
          color: Color.fromARGB(255, _colorR, _colorG, _colorB),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ];
  }
}
