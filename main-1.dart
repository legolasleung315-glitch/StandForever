import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

const MethodChannel _mediaScannerChannel =
    MethodChannel('batch_photo_tools/media');

Future<void> _scanImageInGallery(String path) async {
  if (!Platform.isAndroid || path.isEmpty) return;
  try {
    await _mediaScannerChannel.invokeMethod<void>(
      'scanFile',
      <String, dynamic>{'path': path},
    );
  } catch (_) {
    // Gallery indexing must never make image generation fail.
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BatchPhotoToolsApp());
}

class _GeneratedImagesPage extends StatelessWidget {
  const _GeneratedImagesPage({required this.files});

  final List<String> files;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('剛才生成的圖片（${files.length} 張）'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final path = files[index];
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _GeneratedImageViewer(
                    files: files,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GeneratedImageViewer extends StatefulWidget {
  const _GeneratedImageViewer({
    required this.files,
    required this.initialIndex,
  });

  final List<String> files;
  final int initialIndex;

  @override
  State<_GeneratedImageViewer> createState() => _GeneratedImageViewerState();
}

class _GeneratedImageViewerState extends State<_GeneratedImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_index + 1} / ${widget.files.length}'),
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.files.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.file(
                File(widget.files[index]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BatchPhotoToolsApp extends StatelessWidget {
  const BatchPhotoToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const PhotoProcessorPage(),
    );
  }
}

class PhotoProcessorPage extends StatefulWidget {
  const PhotoProcessorPage({super.key});

  @override
  State<PhotoProcessorPage> createState() => _PhotoProcessorPageState();
}

class _PhotoProcessorPageState extends State<PhotoProcessorPage> {
  SharedPreferences? _prefs;
  Uint8List? _cachedFontFntBytes;
  Uint8List? _cachedFontPngBytes;
  String? _cachedFontFamily;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final now = DateTime.now();

    // One-time reset to the requested initial parameters.
    // After this migration runs once, normal user changes are persisted.
    const defaultsVersion = 1;
    if (prefs.getInt('settingsDefaultsVersion') != defaultsVersion) {
      await prefs.setBool('applyTime', true);
      await prefs.setInt('startHour', 8);
      await prefs.setInt('startMinute', 35);
      await prefs.setInt('endHour', 8);
      await prefs.setInt('endMinute', 55);
      await prefs.setBool('applyWatermark', true);
      await prefs.setDouble('fontSize', 70);
      await prefs.setInt('colorR', 255);
      await prefs.setInt('colorG', 255);
      await prefs.setInt('colorB', 255);
      await prefs.setDouble('opacity', 1.0);
      await prefs.setDouble('margin', 8);
      await prefs.setString('extraWatermarkText', '');
      await prefs.setString('fontFamily', 'lato_bold');
      await prefs.setInt('filterMode', 2);
      await prefs.setInt('grainAmount', 0);
      await prefs.setInt('noiseAmount', 0);
      await prefs.setInt('timeDistributionMode', 0);
      await prefs.setInt('jpegQuality', 80);
      await prefs.setInt('maxWidth', 1000);
      await prefs.setInt('renameMode', 0);
      await prefs.setString('customPrefix', 'IMG');
      await prefs.setBool('includeDateInCustom', true);
      await prefs.setBool('createWorkFolder', true);
      await prefs.setInt('adjustmentMode', 0);
      await prefs.setInt('settingsDefaultsVersion', defaultsVersion);
    }

    final sh = prefs.getInt('startHour') ?? 8;
    final sm = prefs.getInt('startMinute') ?? 0;
    final eh = prefs.getInt('endHour') ?? 11;
    final em = prefs.getInt('endMinute') ?? 30;
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
      _extraWatermarkText = prefs.getString('extraWatermarkText') ?? _extraWatermarkText;
      _fontFamily = prefs.getString('fontFamily') ?? _fontFamily;
      _filterMode = prefs.getInt('filterMode') ?? _filterMode;
      final savedGrain = prefs.getInt('grainAmount');
      _grainAmount = savedGrain ?? ((prefs.getBool('addGrain') ?? false) ? 25 : 0);
      _noiseAmount = prefs.getInt('noiseAmount') ?? _noiseAmount;
      _timeDistributionMode = prefs.getInt('timeDistributionMode') ?? _timeDistributionMode;
      _jpegQuality = prefs.getInt('jpegQuality') ?? _jpegQuality;
      _maxWidth = (prefs.getInt('maxWidth') ?? _maxWidth).clamp(500, 4000);
      _renameMode = prefs.getInt('renameMode') ?? _renameMode;
      _customPrefix = prefs.getString('customPrefix') ?? _customPrefix;
      _includeDateInCustom = prefs.getBool('includeDateInCustom') ?? _includeDateInCustom;
      _createWorkFolder = prefs.getBool('createWorkFolder') ?? _createWorkFolder;
      _adjustmentMode = prefs.getInt('adjustmentMode') ?? _adjustmentMode;
      // Always refresh the watermark date to today's date on app start.
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

  VoidCallback? _settingsPageRefresh;
  Timer? _precisionRepeatTimer;

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


  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  final List<String> _resultFiles = <String>[];
  final List<String> _errors = <String>[];

  // Time.
  bool _applyTime = true;
  bool _useTodayDate = true;
  DateTime _startDateTime = DateTime.now();
  DateTime _endDateTime = DateTime.now().add(const Duration(hours: 1));

  // Watermark.
  bool _applyWatermark = true;
  double _fontSize = 70;
  int _colorR = 255;
  int _colorG = 255;
  int _colorB = 255;
  double _opacity = 1.0;
  double _margin = 8;
  String _extraWatermarkText = '';

  // Bitmap watermark fonts (.fnt + page0.png).
  String _fontFamily = 'lato_bold';

  static const Map<String, String> _fontLabels = <String, String>{
    '7_Segment': '7 Segment',
    '7_Segment_Bold': '7 Segment Bold',
    'Film_Camera': 'Film Camera',
    'Film_Camera_Bold': 'Film Camera Bold',
    'serif_regular': 'Serif Regular',
    'serif_bold': 'Serif Bold',
    'lato_regular': 'Lato Regular',
    'lato_bold': 'Lato Bold',
    'noto_regular': 'Noto Sans Regular',
    'noto_bold': 'Noto Sans Bold',
    'Retro_Camera': 'Retro Camera',
  };

  // Filter/output.
  int _filterMode = 2;
  int _grainAmount = 0;
  int _noiseAmount = 0;
  // 0 = evenly spaced, 1 = randomly distributed in chronological order.
  int _timeDistributionMode = 0;
  int _randomTimeSeed = DateTime.now().microsecondsSinceEpoch;
  int _jpegQuality = 80;
  int _maxWidth = 1000;

  // Rename.
  int _renameMode = 0;
  String _customPrefix = 'IMG';
  bool _includeDateInCustom = true;
  // Continue filename numbering across multiple runs on the same day.
  final Map<String, int> _nextSequenceByKey = <String, int>{};

  // Output folder.
  bool _createWorkFolder = true;

  // 0 = Slider 快速調整，1 = 精調模式。
  int _adjustmentMode = 0;

  bool _isProcessing = false;
  bool _cancelRequested = false;
  double _progress = 0;
  String _statusMessage = '請先選擇相片';

  Future<void> _pickImages() async {
    try {
      // file_picker 12.x：pickFiles() 直接回傳 List<PlatformFile>。
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

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

  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    // file_picker 12.x 改用 PlatformFile.readAsBytes()。
    return file.readAsBytes();
  }


  Future<void> _pickStartDateTime() async {
    if (_useTodayDate) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDateTime),
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
      await _pickEndDateTime();
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
    await _pickEndDateTime();
  }

  Future<void> _pickEndDateTime() async {
    if (_useTodayDate) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDateTime),
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
        now.year,
        now.month,
        now.day,
        start.hour,
        start.minute,
        start.second,
      );
      end = DateTime(
        now.year,
        now.month,
        now.day,
        end.hour,
        end.minute,
        end.second,
      );
    }

    if (total <= 1) return start;

    final totalSeconds = end.difference(start).inSeconds;

    if (_timeDistributionMode == 1) {
      // Generate the same sorted random sequence for this batch so the
      // selected photo order remains chronological while each timestamp
      // is randomly placed inside the start/end interval.
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

  /// 第一次使用時讓 Android 選擇一次輸出資料夾；
  /// 選定後把路徑記住，之後直接使用，不再每次跳出資料夾授權畫面。
  Future<String?> _chooseOutputDirectory() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      final savedDirectory = prefs.getString('outputDirectory');
      if (savedDirectory != null && savedDirectory.isNotEmpty) {
        final savedDir = Directory(savedDirectory);
        if (await savedDir.exists()) {
          return savedDirectory;
        }
        // 原資料夾已不存在，清掉舊設定，下一步重新授權一次。
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

  Future<void> _previewFirstImage() async {
    if (_selectedFiles.isEmpty) return;

    final path = _selectedFiles.first.path;
    if (path == null) {
      _showError('第一張相片沒有可讀取路徑');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _statusMessage = '產生預覽中…';
    });

    try {
      final bytes = await File(path).readAsBytes();
      final target = _targetTime(0, _selectedFiles.length);
      final config = await _buildProcessConfig(target);

      final output = await compute< Map<String, dynamic>, Uint8List>(
        _processImageCompute,
        <String, dynamic>{
          'bytes': bytes,
          'config': config,
        },
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('預覽效果'),
            content: InteractiveViewer(
              minScale: 0.2,
              maxScale: 4,
              child: Image.memory(output, fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showError('預覽失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '預覽完成';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _buildProcessConfig(DateTime target) async {
    if (_cachedFontFamily != _fontFamily ||
        _cachedFontFntBytes == null ||
        _cachedFontPngBytes == null) {
      final selectedFamily = _fontFamily;
      try {
        final fontBase = 'assets/fonts/$selectedFamily';
        _cachedFontFntBytes =
            (await rootBundle.load('$fontBase/$selectedFamily.fnt'))
                .buffer
                .asUint8List();
        _cachedFontPngBytes =
            (await rootBundle.load('$fontBase/page0.png'))
                .buffer
                .asUint8List();
      } catch (_) {
        // Keep processing even if a font asset is missing from the package.
        // Film_Camera is the built-in fallback font.
        const fallbackFamily = 'Film_Camera';
        final fontBase = 'assets/fonts/$fallbackFamily';
        _cachedFontFntBytes =
            (await rootBundle.load('$fontBase/$fallbackFamily.fnt'))
                .buffer
                .asUint8List();
        _cachedFontPngBytes =
            (await rootBundle.load('$fontBase/page0.png'))
                .buffer
                .asUint8List();
      }
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

  String _watermarkText(DateTime target) {
    final timeText = _applyTime
        ? DateFormat('d/M/yyyy HH:mm').format(target)
        : '';
    final extra = _extraWatermarkText.trim();
    if (timeText.isEmpty) return extra;
    if (extra.isEmpty) return timeText;
    return '$timeText $extra';
  }

  Future<void> _processImages() async {
    await _saveSettings();
    if (_selectedFiles.isEmpty) {
      _showError('請先選擇相片');
      return;
    }

    if (_endDateTime.isBefore(_startDateTime) && !_useTodayDate) {
      _showError('結束時間不能早過開始時間');
      return;
    }

    final baseDirectory = await _chooseOutputDirectory();
    if (baseDirectory == null || baseDirectory.isEmpty) return;

    String outputDirectory = baseDirectory;

    if (_createWorkFolder) {
      final folderDate = _useTodayDate ? DateTime.now() : _startDateTime;
      final folderName =
          '${DateFormat('yyyyMMdd').format(folderDate)}_工作記錄';
      outputDirectory =
          '$baseDirectory${Platform.pathSeparator}$folderName';
      await Directory(outputDirectory).create(recursive: true);
    }

    // Read existing output names once so a new run continues the sequence
    // instead of starting from 001 again.
    await _prepareRenameSequences(outputDirectory);

    _cancelRequested = false;
    _resultFiles.clear();
    _errors.clear();

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _statusMessage = '開始處理…';
    });

    final total = _selectedFiles.length;
    _randomTimeSeed = DateTime.now().microsecondsSinceEpoch;

    try {
      // Process a small number of photos concurrently. This keeps several CPU
      // cores busy without launching one isolate per photo (which can exhaust
      // RAM on phones with large images).
      const workerCount = 3;
      var completed = 0;

      for (int batchStart = 0; batchStart < total; batchStart += workerCount) {
        if (_cancelRequested) break;

        final batchEnd = math.min(batchStart + workerCount, total);
        final futures = <Future<Map<String, dynamic>>>[];

        for (int i = batchStart; i < batchEnd; i++) {
          futures.add(() async {
            final picked = _selectedFiles[i];
            final path = picked.path;
            if (path == null || path.isEmpty) {
              return <String, dynamic>{
                'index': i,
                'name': picked.name,
                'error': '沒有可讀取路徑',
              };
            }

            try {
              final inputBytes = await _readPlatformFileBytes(picked);
              if (_cancelRequested) {
                return <String, dynamic>{
                  'index': i,
                  'name': picked.name,
                  'cancelled': true,
                };
              }

              final target = _targetTime(i, total);
              final config = await _buildProcessConfig(target);
              final outputBytes =
                  await compute<Map<String, dynamic>, Uint8List>(
                _processImageCompute,
                <String, dynamic>{
                  'bytes': inputBytes,
                  'config': config,
                },
              );

              return <String, dynamic>{
                'index': i,
                'name': picked.name,
                'target': target,
                'bytes': outputBytes,
              };
            } catch (e) {
              return <String, dynamic>{
                'index': i,
                'name': picked.name,
                'error': '$e',
              };
            }
          }());
        }

        final results = await Future.wait(futures);

        for (final result in results) {
          if (_cancelRequested) break;

          final name = result['name'] as String;
          final error = result['error'] as String?;
          if (error != null) {
            _errors.add('$name：$error');
            completed++;
            if (mounted) {
              setState(() {
                _progress = completed / total;
                _statusMessage = '第 $completed / $total 張失敗，繼續下一批…';
              });
            }
            continue;
          }

          if (result['cancelled'] == true) continue;

          try {
            final index = result['index'] as int;
            final target = result['target'] as DateTime;
            final outputBytes = result['bytes'] as Uint8List;
            final fileName = _buildFileName(index, target);
            final outPath =
                '$outputDirectory${Platform.pathSeparator}$fileName';
            final safePath = await _makeSafeOutputPath(outPath);

            final outFile = File(safePath);
            await outFile.writeAsBytes(outputBytes);

            if (_applyTime) {
              try {
                await outFile.setLastModified(target);
              } catch (e) {
                _errors.add(
                  '$name：圖片已輸出，但無法修改檔案修改時間：$e',
                );
              }
            }

            await _scanImageInGallery(safePath);
            _resultFiles.add(safePath);
            completed++;

            if (mounted) {
              setState(() {
                _progress = completed / total;
                _statusMessage = '處理中：$completed / $total';
              });
            }
          } catch (e) {
            _errors.add('$name：$e');
            completed++;
            if (mounted) {
              setState(() {
                _progress = completed / total;
                _statusMessage = '第 $completed / $total 張失敗，繼續下一張…';
              });
            }
          }
        }
      }

      if (!mounted) return;

      if (_cancelRequested) {
        setState(() {
          _statusMessage =
              '已取消。已完成 ${_resultFiles.length} / $total 張';
        });
      } else {
        setState(() {
          _progress = 1;
          _statusMessage =
              '完成：${_resultFiles.length} / $total 張\n$outputDirectory';
        });
      }

      await _showResults(outputDirectory);
    } catch (e) {
      _showError('批量處理失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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

  Future<void> _prepareRenameSequences(String directory) async {
    _nextSequenceByKey.clear();
    final dir = Directory(directory);
    if (!await dir.exists()) return;

    // Match names generated by this app, including custom prefixes.
    final pattern = RegExp(r'^(.+?)_(\d{8})_(\d+)\.jpg$', caseSensitive: false);
    final patternWithoutDate = RegExp(r'^(.+?)_(\d+)\.jpg$', caseSensitive: false);

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;

      final withDate = pattern.firstMatch(name);
      if (withDate != null) {
        final prefix = withDate.group(1)!;
        final date = withDate.group(2)!;
        final number = int.tryParse(withDate.group(3)!) ?? 0;
        final key = '$prefix|$date';
        final next = (number + 1);
        if (next > (_nextSequenceByKey[key] ?? 1)) {
          _nextSequenceByKey[key] = next;
        }
        continue;
      }

      final withoutDate = patternWithoutDate.firstMatch(name);
      if (withoutDate != null) {
        final prefix = withoutDate.group(1)!;
        final number = int.tryParse(withoutDate.group(2)!) ?? 0;
        final key = '$prefix|';
        final next = number + 1;
        if (next > (_nextSequenceByKey[key] ?? 1)) {
          _nextSequenceByKey[key] = next;
        }
      }
    }
  }

  String _buildFileName(int index, DateTime target) {
    final date = DateFormat('yyyyMMdd').format(target);

    if (_renameMode == 0) {
      const prefix = 'IMG';
      final key = '$prefix|$date';
      final seq = _nextSequenceByKey[key] ?? 1;
      _nextSequenceByKey[key] = seq + 1;
      return '$prefix${date}_${seq.toString().padLeft(3, '0')}.jpg';
    }

    final cleanPrefix = _customPrefix.trim().isEmpty
        ? 'IMG'
        : _customPrefix
            .trim()
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final key = _includeDateInCustom ? '$cleanPrefix|$date' : '$cleanPrefix|';
    final seq = _nextSequenceByKey[key] ?? 1;
    _nextSequenceByKey[key] = seq + 1;

    if (_includeDateInCustom) {
      return '${cleanPrefix}_${date}_${seq.toString().padLeft(3, '0')}.jpg';
    }
    return '${cleanPrefix}_${seq.toString().padLeft(3, '0')}.jpg';
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

      await SharePlus.instance.share(
        ShareParams(
          files: files,
            ),
      );
    } catch (e) {
      if (mounted) {
        _showError('分享失敗：$e');
      }
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
        builder: (_) => _GeneratedImagesPage(files: files),
      ),
    );
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            decoration: InputDecoration(
              suffixText: title.contains('透明度') || title.contains('顆粒') || title.contains('噪點') ? '%' : null,
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
    return d.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildSettingsChildren() {
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
              ButtonSegment<int>(value: 0, icon: Icon(Icons.swipe), label: Text('Slider 快速')),
              ButtonSegment<int>(value: 1, icon: Icon(Icons.tune), label: Text('精調')),
            ],
            selected: <int>{_adjustmentMode},
            onSelectionChanged: _isProcessing ? null : (selection) {
              _setStateAndSave(() => _adjustmentMode = selection.first);
            },
          ),
          const SizedBox(height: 4),
          Text(_adjustmentMode == 0 ? '左右滑動快速調整參數' : '使用 −／＋ 或點擊數值精確調整', style: const TextStyle(fontSize: 12)),
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
            Slider(value: _fontSize, min: 14, max: 160, divisions: 42, onChanged: _isProcessing ? null : (v) => _setStateAndSave(() => _fontSize = v)),
            Text('邊距：${_margin.round()} px'),
            Slider(value: _margin, min: 8, max: 80, divisions: 36, onChanged: _isProcessing ? null : (v) => _setStateAndSave(() => _margin = v)),
            Text('透明度：${(_opacity * 100).round()}%'),
            Slider(value: _opacity, min: 0.2, max: 1, divisions: 16, onChanged: _isProcessing ? null : (v) => _setStateAndSave(() => _opacity = v)),
          ] else ...[
            _precisionControl(title: '字體大小', value: _fontSize.round(), min: 14, max: 160, step: 1, unit: ' px', disabled: _isProcessing, onChanged: (v) => _setStateAndSave(() => _fontSize = v.toDouble())),
            _precisionControl(title: '邊距', value: _margin.round(), min: 8, max: 80, step: 1, unit: ' px', disabled: _isProcessing, onChanged: (v) => _setStateAndSave(() => _margin = v.toDouble())),
            _precisionControl(title: '透明度', value: (_opacity * 100).round(), min: 20, max: 100, step: 1, unit: '%', disabled: _isProcessing, onChanged: (v) => _setStateAndSave(() => _opacity = v.toDouble() / 100)),
          ],
          TextFormField(
            initialValue: _extraWatermarkText,
            decoration: const InputDecoration(
              labelText: '其他水印文字（可留空）',
              hintText: '例如：Tokyo / Work',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) { _extraWatermarkText = v; _saveSettings(); },
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
                    if (v != null) _setStateAndSave(() => _filterMode = v);
                  },
          ),
          if (_adjustmentMode == 0) ...[
            Text(_grainAmount == 0 ? '顆粒：關閉' : '顆粒：$_grainAmount%'),
            Slider(value: _grainAmount.toDouble(), min: 0, max: 100, divisions: 20, label: _grainAmount == 0 ? '關閉' : '$_grainAmount%', onChanged: _isProcessing ? null : (v) => _setStateAndSave(() => _grainAmount = v.round())),
            Text(_noiseAmount == 0 ? '噪點：關閉' : '噪點：$_noiseAmount%'),
            Slider(value: _noiseAmount.toDouble(), min: 0, max: 100, divisions: 20, label: _noiseAmount == 0 ? '關閉' : '$_noiseAmount%', onChanged: _isProcessing ? null : (v) => _setStateAndSave(() => _noiseAmount = v.round())),
          ] else ...[
            _precisionControl(title: '顆粒', value: _grainAmount, min: 0, max: 100, step: 5, unit: '%', disabled: _isProcessing, onChanged: (v) => _setStateAndSave(() => _grainAmount = v.round())),
            _precisionControl(title: '噪點', value: _noiseAmount, min: 0, max: 100, step: 5, unit: '%', disabled: _isProcessing, onChanged: (v) => _setStateAndSave(() => _noiseAmount = v.round())),
          ],

          _sectionTitle('輸出設定'),
          const Text(
            '輸出尺寸（寬度）',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('目前：$_maxWidth px'),
          if (_adjustmentMode == 0) ...[
            Slider(
              value: _maxWidth.toDouble().clamp(500, 4000),
              min: 500,
              max: 4000,
              divisions: 70,
              label: '$_maxWidth px',
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
              onChanged: (v) => _setStateAndSave(() => _jpegQuality = v.round()),
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
                    if (v != null) _setStateAndSave(() => _renameMode = v);
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
              onChanged: (v) { _customPrefix = v; _saveSettings(); },
              enabled: !_isProcessing,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('前綴後面加日期'),
              value: _includeDateInCustom,
              onChanged: _isProcessing
                  ? null
                  : (v) => _setStateAndSave(() => _includeDateInCustom = v),
            ),
          ],

    ];
  }

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
            children: _buildSettingsChildren(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _precisionRepeatTimer?.cancel();
    _precisionRepeatTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _buildSettingsPage(),
                      ),
                    ).then((_) {
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
            initialValue: _maxWidth >= 500 && _maxWidth <= 1200
                ? _maxWidth
                : _maxWidth,
            decoration: const InputDecoration(
              labelText: '輸出尺寸（寬度）500–1200 px',
              border: OutlineInputBorder(),
            ),
            items: [
              if (_maxWidth > 1200)
                DropdownMenuItem(
                  value: _maxWidth,
                  enabled: false,
                  child: Text('目前 $_maxWidth px（請選 500–1200）'),
                ),
              const DropdownMenuItem(value: 500, child: Text('500 px')),
              const DropdownMenuItem(value: 600, child: Text('600 px')),
              const DropdownMenuItem(value: 700, child: Text('700 px')),
              const DropdownMenuItem(value: 800, child: Text('800 px')),
              const DropdownMenuItem(value: 900, child: Text('900 px')),
              const DropdownMenuItem(value: 1000, child: Text('1000 px')),
              const DropdownMenuItem(value: 1100, child: Text('1100 px')),
              const DropdownMenuItem(value: 1200, child: Text('1200 px')),
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
                  Text('輸出：$_maxWidth px · JPG $_jpegQuality'),
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
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed:
                        _selectedFiles.isEmpty ? null : _previewFirstImage,
                    child: const Text('預覽第一張'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed:
                        _selectedFiles.isEmpty ? null : _processImages,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('開始批量處理'),
                  ),
                ),
              ],
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

/// Heavy image work lives outside the Flutter UI isolate.
Future<Uint8List> _processImageCompute(
  Map<String, dynamic> message,
) {
  final inputBytes = message['bytes'] as Uint8List;
  final config = Map<String, dynamic>.from(
    message['config'] as Map,
  );
  return _processImageInIsolate(inputBytes, config);
}

Future<Uint8List> _processImageInIsolate(
  Uint8List inputBytes,
  Map<String, dynamic> config,
) async {
  // Decode the original JPEG bytes. Do not strip ICC/EXIF segments before
  // decoding: some WhatsApp/camera JPEGs carry color information there, and
  // stripping it can cause severe color shifts. Metadata is removed only from
  // the output object before re-encoding.
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    throw Exception('無法解碼圖片');
  }

  img.Image image = decoded;

  // Do not preserve source metadata into the output.
  image.exif.clear();
  // Keep the embedded ICC profile when available so wide-gamut photos do not
  // get reinterpreted as a different color space on output.
  image.textData = null;

  final maxWidth = (config['maxWidth'] as int).clamp(500, 4000).toInt();
  if (maxWidth > 0 && image.width > maxWidth) {
    image = img.copyResize(
      image,
      width: maxWidth,
      interpolation: img.Interpolation.linear,
    );
  }

  final filterMode = config['filterMode'] as int;

  // Quality modes are real image treatments again. The previous safety patch
  // intentionally made modes 1/2 identical to mode 0, so the UI could not
  // visibly change the photo. These settings are deliberately moderate and
  // are inspired by the softer, lower-contrast look of the supplied Note 2
  // reference samples. Mode 1 is warmer/punchier; mode 2 is softer/cooler.
  if (filterMode == 1) {
    // Note 2 final agreed look:
    // contrast 86%, saturation 68%, gray mix 32%, gamma 103%, blur 1px.
    image = img.adjustColor(
      image,
      contrast: 0.86,
      saturation: 0.68,
      gamma: 1.03,
    );

    const grayMix = 0.32;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance =
            0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        pixel.r = (pixel.r * (1.0 - grayMix) + luminance * grayMix)
            .round()
            .clamp(0, 255);
        pixel.g = (pixel.g * (1.0 - grayMix) + luminance * grayMix)
            .round()
            .clamp(0, 255);
        pixel.b = (pixel.b * (1.0 - grayMix) + luminance * grayMix)
            .round()
            .clamp(0, 255);
      }
    }

    image = img.gaussianBlur(image, radius: 1);
  } else if (filterMode == 2) {
    // Note 7 final agreed look: deliberately weaker than Note 2.
    // contrast 94%, saturation 82%, gray mix 18%, gamma 101%, blur 1px.
    image = img.adjustColor(
      image,
      contrast: 0.94,
      saturation: 0.82,
      gamma: 1.01,
    );

    const grayMix = 0.18;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance =
            0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        pixel.r = (pixel.r * (1.0 - grayMix) + luminance * grayMix)
            .round()
            .clamp(0, 255);
        pixel.g = (pixel.g * (1.0 - grayMix) + luminance * grayMix)
            .round()
            .clamp(0, 255);
        pixel.b = (pixel.b * (1.0 - grayMix) + luminance * grayMix)
            .round()
            .clamp(0, 255);
      }
    }

    image = img.gaussianBlur(image, radius: 1);
  }

  final grainAmount = (config['grainAmount'] as int?) ??
      ((config['addGrain'] as bool) ? 25 : 0);
  final noiseAmount = (config['noiseAmount'] as int?) ?? 0;
  _applyGrainAndNoise(
    image,
    grainAmount: grainAmount,
    noiseAmount: noiseAmount,
  );

  if (config['applyWatermark'] as bool) {
    _drawWatermark(
      image,
      text: config['watermarkText'] as String,
      fontSize: (config['fontSize'] as num).toDouble(),
      r: config['colorR'] as int,
      g: config['colorG'] as int,
      b: config['colorB'] as int,
      opacity: (config['opacity'] as num).toDouble(),
      margin: (config['margin'] as num).toDouble(),
      // BitmapFont.fromFnt already receives page 0 from page0.png.
      // Remove the page declaration from the text .fnt to avoid
      // `Duplicate font page id found: 0` in image 4.9.1.
      // image package 4.9.x receives page 0 separately via page0.png.
      // Strip BMFont `page ...` declarations without the fragile multiline RegExp.
      fontFnt: utf8
          .decode(config['fontFntBytes'] as Uint8List)
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('page '))
          .join('\n'),
      fontPngBytes: config['fontPngBytes'] as Uint8List,
    );
  }

  final quality =
      (config['jpegQuality'] as int).clamp(60, 98).toInt();
  final encoded = img.encodeJpg(image, quality: quality);

  return Uint8List.fromList(encoded);
}

void _applyGrainAndNoise(
  img.Image image, {
  required int grainAmount,
  required int noiseAmount,
}) {
  if (grainAmount <= 0 && noiseAmount <= 0) return;

  // One pixel pass instead of two. The two random generators and their
  // strengths remain separate so the Grain and Noise sliders keep their
  // independent behavior.
  final grainRandom = math.Random(20260823);
  final noiseRandom = math.Random(20260824);
  final grainEnabled = grainAmount > 0;
  final noiseEnabled = noiseAmount > 0;
  final grainStrength = math.max(1, (grainAmount * 0.18).round());
  final grainCoverage =
      (0.55 + grainAmount * 0.004).clamp(0.55, 0.95);
  final noiseStrength = math.max(1, (noiseAmount * 0.30).round());

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      var delta = 0;

      if (grainEnabled && grainRandom.nextDouble() <= grainCoverage) {
        delta += grainRandom.nextInt(grainStrength * 2 + 1) - grainStrength;
      }
      if (noiseEnabled) {
        delta += noiseRandom.nextInt(noiseStrength * 2 + 1) - noiseStrength;
      }

      if (delta == 0) continue;
      final pixel = image.getPixel(x, y);
      pixel.r = (pixel.r + delta).clamp(0, 255);
      pixel.g = (pixel.g + delta).clamp(0, 255);
      pixel.b = (pixel.b + delta).clamp(0, 255);
    }
  }
}

void _drawWatermark(
  img.Image image, {
  required String text,
  required double fontSize,
  required int r,
  required int g,
  required int b,
  required double opacity,
  required double margin,
  required String fontFnt,
  required Uint8List fontPngBytes,
}) {
  if (text.isEmpty || image.width < 20 || image.height < 20) return;

  final page = img.decodePng(fontPngBytes);
  if (page == null) return;

  final font = img.readFont(fontFnt, page);

  int textWidth = 0;
  int textHeight = font.lineHeight;

  for (final codeUnit in text.codeUnits) {
    final char = font.characters[codeUnit];
    if (char == null) {
      textWidth += font.base ~/ 2;
      continue;
    }
    textWidth += char.xAdvance;
    textHeight = math.max(textHeight, char.height + char.yOffset);
  }

  if (textWidth <= 0 || textHeight <= 0) return;

  final rawWidth = textWidth + 20;
  final rawHeight = textHeight + 20;

  var overlay = img.Image(
    width: rawWidth,
    height: rawHeight,
    numChannels: 4,
  );
  overlay.clear(img.ColorRgba8(0, 0, 0, 0));

  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  final color = img.ColorRgba8(
    r.clamp(0, 255).toInt(),
    g.clamp(0, 255).toInt(),
    b.clamp(0, 255).toInt(),
    alpha,
  );
img.drawString(
    overlay,
    text,
    font: font,
    x: 8,
    y: 8,
    color: color,
  );

  // IMPORTANT for 500/600/800 px outputs: the BMFont lineHeight includes
  // transparent leading/trailing space. If we resize that whole box to 8-15
  // px, the actual digits become much smaller than the requested font size.
  // Tight-crop the rendered glyphs first, then scale the glyph itself. This
  // preserves the configured watermark size while giving every final pixel a
  // useful part of the glyph instead of wasting pixels on empty padding.
  int minX = overlay.width;
  int minY = overlay.height;
  int maxX = -1;
  int maxY = -1;

  for (var yy = 0; yy < overlay.height; yy++) {
    for (var xx = 0; xx < overlay.width; xx++) {
      if (overlay.getPixel(xx, yy).a > 8) {
        if (xx < minX) minX = xx;
        if (yy < minY) minY = yy;
        if (xx > maxX) maxX = xx;
        if (yy > maxY) maxY = yy;
      }
    }
  }

  if (maxX < minX || maxY < minY) return;

  const cropPad = 1;
  final cropX = math.max(0, minX - cropPad);
  final cropY = math.max(0, minY - cropPad);
  final cropRight = math.min(overlay.width - 1, maxX + cropPad);
  final cropBottom = math.min(overlay.height - 1, maxY + cropPad);

  overlay = img.copyCrop(
    overlay,
    x: cropX,
    y: cropY,
    width: cropRight - cropX + 1,
    height: cropBottom - cropY + 1,
  );

  // Keep the watermark at the same relative size on every output width.
  // Reference size is relative to the final output width.
  // 32 px at 2000 px output width becomes about 8 px at 500 px,
  // preventing small outputs from making the timestamp look oversized.
  final scale = image.width / 2000.0;
  final targetHeight =
      (fontSize * scale).round().clamp(7, 160).toInt();
  final targetWidth = math.max(1,
      (overlay.width * targetHeight / overlay.height).round());

  // High-quality watermark renderer.
  // Render the glyph at high resolution first, then downsample by alpha
  // coverage. This gives anti-aliased edges even when the final timestamp
  // is only about 10-20 px high at 500 px output width.
  //
  // IMPORTANT: RGB always remains the user's selected RGB. Only alpha is
  // averaged, so white stays white instead of being mixed toward gray.
  final bool small = targetHeight <= 40;
  final int supersample = small ? 8 : 4;
  final workWidth = math.max(1, targetWidth * supersample);
  final workHeight = math.max(1, targetHeight * supersample);

  final dense = img.copyResize(
    overlay,
    width: workWidth,
    height: workHeight,
    interpolation: img.Interpolation.cubic,
  );

  final scaled = img.Image(
    width: targetWidth,
    height: targetHeight,
    numChannels: 4,
  );
  scaled.clear(img.ColorRgba8(0, 0, 0, 0));

  final sr = r.clamp(0, 255).toInt();
  final sg = g.clamp(0, 255).toInt();
  final sb = b.clamp(0, 255).toInt();

  for (var yy = 0; yy < targetHeight; yy++) {
    final sy0 = (yy * workHeight / targetHeight).floor();
    final sy1 = math.min(
      workHeight,
      math.max(sy0 + 1, ((yy + 1) * workHeight / targetHeight).ceil()),
    );

    for (var xx = 0; xx < targetWidth; xx++) {
      final sx0 = (xx * workWidth / targetWidth).floor();
      final sx1 = math.min(
        workWidth,
        math.max(sx0 + 1, ((xx + 1) * workWidth / targetWidth).ceil()),
      );

      var alphaSum = 0;
      var count = 0;

      for (var sy = sy0; sy < sy1; sy++) {
        for (var sx = sx0; sx < sx1; sx++) {
          alphaSum += dense.getPixel(sx, sy).a.toInt();
          count++;
        }
      }

      if (count == 0) continue;
      final aa = (alphaSum / count).round().clamp(0, 255).toInt();
      if (aa == 0) continue;

      scaled.setPixelRgba(xx, yy, sr, sg, sb, aa);
    }
  }

  final x = math.max(
    0,
    image.width - scaled.width - margin.round(),
  );
  final y = math.max(
    0,
    image.height - scaled.height - margin.round(),
  );

  img.compositeImage(
    image,
    scaled,
    dstX: x,
    dstY: y,
    blend: img.BlendMode.alpha,
  );
}
