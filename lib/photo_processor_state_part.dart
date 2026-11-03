// ignore_for_file: invalid_use_of_protected_member

part of 'photo_processor_page.dart';

extension _PhotoProcessorStatePart on _PhotoProcessorPageState {
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final now = DateTime.now();
    final sh = prefs.getInt('startHour') ?? 8;
    final sm = prefs.getInt('startMinute') ?? 35;
    final eh = prefs.getInt('endHour') ?? 8;
    final em = prefs.getInt('endMinute') ?? 55;
    setState(() {
      _prefs = prefs;
      _applyTime = prefs.getBool('applyTime') ?? _applyTime;
      _applyWatermark = prefs.getBool('applyWatermark') ?? _applyWatermark;
      _fontSize = prefs.getDouble('fontSize') ?? _fontSize;
      _colorR = prefs.getInt('colorR') ?? _colorR;
      _colorG = prefs.getInt('colorG') ?? _colorG;
      _colorB = prefs.getInt('colorB') ?? _colorB;
      _opacity = prefs.getDouble('opacity') ?? _opacity;
      _margin = prefs.getDouble('margin') ?? _margin;
      _extraWatermarkText =
          prefs.getString('extraWatermarkText') ?? _extraWatermarkText;
      _fontFamily = prefs.getString('fontFamily') ?? _fontFamily;
      _filterMode = prefs.getInt('filterMode') ?? _filterMode;
      final savedGrain = prefs.getInt('grainAmount');
      _grainAmount =
          savedGrain ?? ((prefs.getBool('addGrain') ?? false) ? 25 : 0);
      _noiseAmount = prefs.getInt('noiseAmount') ?? _noiseAmount;
      _timeDistributionMode =
          prefs.getInt('timeDistributionMode') ?? _timeDistributionMode;
      _jpegQuality = prefs.getInt('jpegQuality') ?? _jpegQuality;
      final savedWidth = prefs.getInt('maxWidth') ?? _maxWidth;
      if (savedWidth == 0 || _PhotoProcessorPageState._commonOutputWidths.contains(savedWidth)) {
        _maxWidth = savedWidth;
      } else {
        _maxWidth = savedWidth.clamp(500, 4000);
      }
      _renameMode = prefs.getInt('renameMode') ?? _renameMode;
      _customPrefix = prefs.getString('customPrefix') ?? _customPrefix;
      _includeDateInCustom =
          prefs.getBool('includeDateInCustom') ?? _includeDateInCustom;
      _createWorkFolder =
          prefs.getBool('createWorkFolder') ?? _createWorkFolder;
      _adjustmentMode = prefs.getInt('adjustmentMode') ?? _adjustmentMode;
      _useTodayDate = true;
      _startDateTime = DateTime(now.year, now.month, now.day, sh, sm);
      _endDateTime = DateTime(now.year, now.month, now.day, eh, em);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool('applyTime', _applyTime);
    await prefs.setInt('startHour', _startDateTime.hour);
    await prefs.setInt('startMinute', _startDateTime.minute);
    await prefs.setInt('endHour', _endDateTime.hour);
    await prefs.setInt('endMinute', _endDateTime.minute);
    await prefs.setBool('applyWatermark', _applyWatermark);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('colorR', _colorR);
    await prefs.setInt('colorG', _colorG);
    await prefs.setInt('colorB', _colorB);
    await prefs.setDouble('opacity', _opacity);
    await prefs.setDouble('margin', _margin);
    await prefs.setString('extraWatermarkText', _extraWatermarkText);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setInt('filterMode', _filterMode);
    await prefs.setBool('addGrain', _grainAmount > 0);
    await prefs.setInt('grainAmount', _grainAmount);
    await prefs.setInt('noiseAmount', _noiseAmount);
    await prefs.setInt('timeDistributionMode', _timeDistributionMode);
    await prefs.setInt('jpegQuality', _jpegQuality);
    await prefs.setInt('maxWidth', _maxWidth);
    await prefs.setInt('renameMode', _renameMode);
    await prefs.setString('customPrefix', _customPrefix);
    await prefs.setBool('includeDateInCustom', _includeDateInCustom);
    await prefs.setBool('createWorkFolder', _createWorkFolder);
    await prefs.setInt('adjustmentMode', _adjustmentMode);
  }

  void _startPrecisionRepeat(VoidCallback action) {
    _precisionRepeatTimer?.cancel();
    action();
    _precisionRepeatTimer = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) => action(),
    );
  }

  void _stopPrecisionRepeat() {
    _precisionRepeatTimer?.cancel();
    _precisionRepeatTimer = null;
  }

  void _setStateAndSave(VoidCallback action) {
    if (!mounted) return;
    setState(action);
    _settingsPageRefresh?.call();
    _saveSettings();
  }
}
