// ignore_for_file: invalid_use_of_protected_member

part of 'photo_processor_page.dart';

extension _PhotoProcessorActionsPart on _PhotoProcessorPageState {
  Future<void> _pickImages() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final selected = files
          .where((file) => file.path != null && file.path!.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _selectedFiles = selected;
        _resultFiles.clear();
        _errors.clear();
        _statusMessage = selected.isEmpty
            ? '沒有選到可讀取的相片'
            : '已選取 ${selected.length} 張相片';
      });
    } catch (e) {
      _showError('選擇相片失敗：$e');
    }
  }

  Future<void> _pickStartDateTime() async {
    if (_useTodayDate) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDateTime),
        helpText: '開始時間',
      );
      if (time == null || !mounted) return;
      final current = DateTime.now();
      setState(() {
        _startDateTime = DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
        );
      });
      _saveSettings();
      // 只有一張圖片時只設定開始時間，不自動彈出結束時間。
      if (_selectedFiles.length > 1) {
        await _pickEndDateTime();
      } else {
        setState(() => _endDateTime = _startDateTime);
        _saveSettings();
      }
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _startDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDateTime),
    );
    if (time == null) return;
    setState(() {
      _startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _saveSettings();
    if (_selectedFiles.length > 1) {
      await _pickEndDateTime();
    } else {
      setState(() => _endDateTime = _startDateTime);
      _saveSettings();
    }
  }

  Future<void> _pickEndDateTime() async {
    if (_useTodayDate) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDateTime),
        helpText: '結束時間',
      );
      if (time == null || !mounted) return;
      final current = DateTime.now();
      setState(() {
        _endDateTime = DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
        );
      });
      _saveSettings();
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _endDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endDateTime),
    );
    if (time == null) return;
    setState(() {
      _endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _saveSettings();
  }

  DateTime _targetTime(int index, int total) {
    DateTime start = _startDateTime;
    DateTime end = _endDateTime;
    if (_useTodayDate) {
      final now = DateTime.now();
      start = DateTime(
          now.year, now.month, now.day, start.hour, start.minute, start.second);
      end = DateTime(
          now.year, now.month, now.day, end.hour, end.minute, end.second);
    }
    if (total <= 1) return start;
    final totalSeconds = end.difference(start).inSeconds;
    if (_timeDistributionMode == 1) {
      final random = math.Random(_randomTimeSeed ^ total);
      final offsets = List<double>.generate(
        total,
        (_) => random.nextDouble(),
      )..sort();
      final seconds = (totalSeconds * offsets[index]).round();
      return start.add(Duration(seconds: seconds));
    }
    final seconds = (totalSeconds * index / (total - 1)).round();
    return start.add(Duration(seconds: seconds));
  }

  Future<String?> _chooseOutputDirectory() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      if (Platform.isAndroid) {
        final savedUri = prefs.getString('outputDirectorySafUri');
        final savedLabel = prefs.getString('outputDirectoryLabel');
        if (savedUri != null && savedUri.isNotEmpty) {
          final grants = await _saf.persistedPermissions();
          final stillGranted = grants.any((g) => g.uri == savedUri);
          if (stillGranted) {
            _safOutputDirectoryUri = savedUri;
            return savedLabel?.isNotEmpty == true
                ? savedLabel
                : '已授權輸出資料夾';
          }
          await prefs.remove('outputDirectorySafUri');
          await prefs.remove('outputDirectoryLabel');
        }

        final selected = await _saf.pickDirectory(
          writePermission: true,
          persistablePermission: true,
        );
        if (selected == null) return null;
        _safOutputDirectoryUri = selected.uri;
        await prefs.setString('outputDirectorySafUri', selected.uri);
        await prefs.setString('outputDirectoryLabel', selected.name);
        return selected.name;
      }

      final savedDirectory = prefs.getString('outputDirectory');
      if (savedDirectory != null && savedDirectory.isNotEmpty) {
        final savedDir = Directory(savedDirectory);
        if (await savedDir.exists()) return savedDirectory;
        await prefs.remove('outputDirectory');
      }

      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: '第一次使用：選擇輸出資料夾（之後會自動記住）',
      );
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        return null;
      }
      await prefs.setString('outputDirectory', selectedDirectory);
      return selectedDirectory;
    } catch (e) {
      _showError('選擇輸出資料夾失敗：$e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _buildProcessConfig(DateTime target) async {
    if (_cachedFontFamily != _fontFamily ||
        _cachedFontFntBytes == null ||
        _cachedFontPngBytes == null) {
      final fontBase = 'assets/fonts/$_fontFamily';
      _cachedFontFntBytes =
          (await rootBundle.load('$fontBase/$_fontFamily.fnt'))
              .buffer
              .asUint8List();
      _cachedFontPngBytes =
          (await rootBundle.load('$fontBase/page0.png'))
              .buffer
              .asUint8List();
      _cachedFontFamily = _fontFamily;
    }
    return <String, dynamic>{
      'applyTime': _applyTime,
      'filterMode': _filterMode,
      'addGrain': _grainAmount > 0,
      'grainAmount': _grainAmount,
      'noiseAmount': _noiseAmount,
      'maxWidth': _maxWidth,
      'jpegQuality': _jpegQuality,
      'applyWatermark': _applyWatermark,
      'watermarkText': _watermarkText(target),
      'fontSize': _fontSize,
      'fontFamily': _fontFamily,
      'fontFntBytes': _cachedFontFntBytes!,
      'fontPngBytes': _cachedFontPngBytes!,
      'colorR': _colorR,
      'colorG': _colorG,
      'colorB': _colorB,
      'opacity': _opacity,
      'margin': _margin,
    };
  }

  List<int> _outputWidthChoices() {
    final widths = <int>{0, ..._PhotoProcessorPageState._commonOutputWidths};
    if (_maxWidth > 0 &&
        _maxWidth <= 4000 &&
        !_PhotoProcessorPageState._commonOutputWidths.contains(_maxWidth)) {
      widths.add(_maxWidth);
    }
    return widths.toList()..sort();
  }

  String _outputWidthLabel(int width) {
    switch (width) {
      case 0:
        return '原圖';
      case 480:
        return '480 px';
      case 640:
        return '640 px';
      case 720:
        return '720 px · 小圖';
      case 1080:
        return '1080 px · 社群';
      case 1280:
        return '1280 px · HD';
      case 1600:
        return '1600 px';
      case 1920:
        return '1920 px · Full HD';
      case 2560:
        return '2560 px · 2K';
      case 3840:
        return '3840 px · 4K';
      default:
        return '$width px（自訂）';
    }
  }

  String _watermarkText(DateTime target) {
    final timeText = _applyTime
        ? DateFormat('d/M/yyyy HH:mm').format(target)
        : '';
    final extra = _extraWatermarkText.trim();
    if (timeText.isEmpty) return extra;
    if (extra.isEmpty) return timeText;
    return '$timeText $extra';
  }

  Future<void> _indexOutputInGallery(String documentUri) async {
    if (!Platform.isAndroid || documentUri.isEmpty) return;
    try {
      await _PhotoProcessorPageState._mediaChannel.invokeMethod<void>('scanDocument', <String, dynamic>{
        'uri': documentUri,
      });
    } catch (_) {}
  }

  Future<String> _makeSafeOutputPath(String originalPath) async {
    final original = File(originalPath);
    if (!await original.exists()) return originalPath;

    final directory = original.parent.path;
    final name = original.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';

    int n = 2;
    while (true) {
      final candidate = File(
        '$directory${Platform.pathSeparator}$base($n)$extension',
      );
      if (!await candidate.exists()) return candidate.path;
      n++;
    }
  }
}
