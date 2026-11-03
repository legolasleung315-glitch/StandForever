part of 'photo_processor_page.dart';

extension _PhotoProcessorSettingsAdvancedPart on _PhotoProcessorPageState {
  List<Widget> _buildSettingsAdvancedChildren() {
    return [
      _sectionTitle('畫質模式'),
      DropdownButtonFormField<int>(
        initialValue: _filterMode,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: '模式',
        ),
        items: const [
          DropdownMenuItem(
            value: 0,
            child: Text('0 = 原始畫質（不調色）'),
          ),
          DropdownMenuItem(
            value: 1,
            child: Text('1 = Note 2（低對比、低飽和、偏灰）'),
          ),
          DropdownMenuItem(
            value: 2,
            child: Text('2 = Note 7（較輕的舊手機效果）'),
          ),
        ],
        onChanged: _isProcessing
            ? null
            : (v) {
                if (v != null) {
                  _setStateAndSave(() => _filterMode = v);
                }
              },
      ),
      if (_adjustmentMode == 0) ...[
        Text(_grainAmount == 0 ? '顆粒：關閉' : '顆粒：$_grainAmount%'),
        Slider(
            value: _grainAmount.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: _grainAmount == 0 ? '關閉' : '$_grainAmount%',
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(
                    () => _grainAmount = v.round())),
        Text(_noiseAmount == 0 ? '噪點：關閉' : '噪點：$_noiseAmount%'),
        Slider(
            value: _noiseAmount.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: _noiseAmount == 0 ? '關閉' : '$_noiseAmount%',
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(
                    () => _noiseAmount = v.round())),
      ] else ...[
        _precisionControl(
            title: '顆粒',
            value: _grainAmount,
            min: 0,
            max: 100,
            step: 5,
            unit: '%',
            disabled: _isProcessing,
            onChanged: (v) =>
                _setStateAndSave(() => _grainAmount = v.round())),
        _precisionControl(
            title: '噪點',
            value: _noiseAmount,
            min: 0,
            max: 100,
            step: 5,
            unit: '%',
            disabled: _isProcessing,
            onChanged: (v) =>
                _setStateAndSave(() => _noiseAmount = v.round())),
      ],
      _sectionTitle('輸出設定'),
      const Text(
        '輸出尺寸（寬度）',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      Text(_maxWidth == 0 ? '目前：原圖' : '目前：$_maxWidth px'),
      if (_adjustmentMode == 0) ...[
        Slider(
          value: _maxWidth.toDouble().clamp(500, 4000),
          min: 500,
          max: 4000,
          divisions: 70,
          label: _maxWidth == 0 ? '原圖' : '$_maxWidth px',
          onChanged: _isProcessing
              ? null
              : (v) => _setStateAndSave(() => _maxWidth = v.round()),
        ),
      ] else ...[
        _precisionControl(
          title: '輸出尺寸',
          value: _maxWidth,
          min: 500,
          max: 4000,
          step: 10,
          unit: ' px',
          disabled: _isProcessing,
          onChanged: (v) =>
              _setStateAndSave(() => _maxWidth = v.round()),
        ),
      ],
      const SizedBox(height: 10),
      if (_adjustmentMode == 0)
        const Text(
          'Slider：500–4000 px，可快速拖動調整',
          style: TextStyle(fontSize: 12),
        )
      else
        const Text(
          '精調：500–4000 px，可用 −／＋ 或點擊數值輸入',
          style: TextStyle(fontSize: 12),
        ),
      const SizedBox(height: 12),
      if (_adjustmentMode == 0) ...[
        Text('JPG 品質：$_jpegQuality'),
        Slider(
          value: _jpegQuality.toDouble().clamp(60, 98),
          min: 60,
          max: 98,
          divisions: 38,
          onChanged: _isProcessing
              ? null
              : (v) => _setStateAndSave(() => _jpegQuality = v.round()),
        ),
      ] else ...[
        _precisionControl(
          title: 'JPG 品質',
          value: _jpegQuality,
          min: 60,
          max: 98,
          step: 1,
          unit: '',
          disabled: _isProcessing,
          onChanged: (v) =>
              _setStateAndSave(() => _jpegQuality = v.round()),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('自動建立「日期 + 工作記錄」資料夾'),
        value: _createWorkFolder,
        onChanged: _isProcessing
            ? null
            : (v) => _setStateAndSave(() => _createWorkFolder = v),
      ),
      _sectionTitle('批量改名'),
      DropdownButtonFormField<int>(
        initialValue: _renameMode,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: '命名模式',
        ),
        items: const [
          DropdownMenuItem(
            value: 0,
            child: Text('IMG日期_001.jpg（同日續號）'),
          ),
          DropdownMenuItem(
            value: 1,
            child: Text('自定義前綴'),
          ),
        ],
        onChanged: _isProcessing
            ? null
            : (v) {
                if (v != null) {
                  _setStateAndSave(() => _renameMode = v);
                }
              },
      ),
      if (_renameMode == 1) ...[
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _customPrefix,
          decoration: const InputDecoration(
            labelText: '自定義前綴',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _customPrefix = v;
            _saveSettings();
          },
          enabled: !_isProcessing,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('前綴後面加日期'),
          value: _includeDateInCustom,
          onChanged: _isProcessing
              ? null
              : (v) => _setStateAndSave(
                  () => _includeDateInCustom = v),
        ),
      ],
    ];
  }
}
