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

class BatchPhotoToolsApp extends StatelessWidget {
  const BatchPhotoToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '堅棟堅企',
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
    final sh = prefs.getInt('startHour') ?? 9;
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
  }

  void _setStateAndSave(VoidCallback action) {
    if (!mounted) return;
    setState(action);
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
  double _fontSize = 32;
  int _colorR = 255;
  int _colorG = 255;
  int _colorB = 255;
  double _opacity = 0.85;
  double _margin = 24;
  String _extraWatermarkText = '';

  // Bitmap watermark fonts (.fnt + page0.png).
  String _fontFamily = 'Film_Camera';

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
  };

  // Filter/output.
  int _filterMode = 0;
  int _grainAmount = 0;
  int _noiseAmount = 0;
  // 0 = evenly spaced, 1 = randomly distributed in chronological order.
  int _timeDistributionMode = 0;
  int _randomTimeSeed = DateTime.now().microsecondsSinceEpoch;
  int _jpegQuality = 88;
  int _maxWidth = 1600;

  // Rename.
  int _renameMode = 0;
  String _customPrefix = 'IMG';
  bool _includeDateInCustom = true;

  // Output folder.
  bool _createWorkFolder = true;

  bool _isProcessing = false;
  bool _cancelRequested = false;
  double _progress = 0;
  String _statusMessage = '請先選擇相片';

  Future<void> _pickImages() async {
    try {
      // file_picker 10.3.10 uses FilePicker.platform.
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: false,
      );

      if (result == null) return;

      final files = result.files
          .where((file) => file.path != null && file.path!.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _selectedFiles = files;
        _resultFiles.clear();
        _errors.clear();
        _statusMessage = files.isEmpty
            ? '沒有選到可讀取的相片'
            : '已選取 ${files.length} 張相片';
      });
    } catch (e) {
      _showError('選擇相片失敗：$e');
    }
  }

  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw Exception('檔案沒有可讀取路徑');
    }
    return File(path).readAsBytes();
  }


  Future<void> _pickStartDateTime() async {
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
  }

  Future<void> _pickEndDateTime() async {
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

  Future<String?> _chooseOutputDirectory() async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: '選擇輸出位置',
      );
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

  String _buildFileName(int index, DateTime target) {
    final seq = (index + 1).toString().padLeft(3, '0');
    final date = DateFormat('yyyyMMdd').format(target);

    if (_renameMode == 0) {
      return 'IMG${date}_$seq.jpg';
    }

    final cleanPrefix = _customPrefix.trim().isEmpty
        ? 'IMG'
        : _customPrefix
            .trim()
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    if (_includeDateInCustom) {
      return '${cleanPrefix}_${date}_$seq.jpg';
    }
    return '${cleanPrefix}_$seq.jpg';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('堅棟堅企'),
        actions: const [],
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

          _sectionTitle('時間設定'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('加入時間水印 + 修改輸出檔案時間'),
            value: _applyTime,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _applyTime = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用今日日期'),
            subtitle: const Text('只把日期改成今日，開始／結束時間保持設定'),
            value: _useTodayDate,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _useTodayDate = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('開始時間'),
            subtitle: Text(
              DateFormat('d/M/yyyy HH:mm').format(_startDateTime),
            ),
            trailing: const Icon(Icons.edit),
            onTap: _isProcessing ? null : _pickStartDateTime,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('結束時間'),
            subtitle: Text(
              DateFormat('d/M/yyyy HH:mm').format(_endDateTime),
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
              DropdownMenuItem(
                value: 0,
                child: Text('平均分配'),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text('隨機分配'),
              ),
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

          _sectionTitle('水印設定'),
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
          Text('字體大小：${_fontSize.round()} px'),
          Slider(
            value: _fontSize,
            min: 14,
            max: 160,
            divisions: 42,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _fontSize = v),
          ),
          Text('邊距：${_margin.round()} px'),
          Slider(
            value: _margin,
            min: 8,
            max: 80,
            divisions: 36,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _margin = v),
          ),
          Text('透明度：${(_opacity * 100).round()}%'),
          Slider(
            value: _opacity,
            min: 0.2,
            max: 1,
            divisions: 16,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _opacity = v),
          ),
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
          Text(
            _grainAmount == 0
                ? '顆粒：關閉'
                : '顆粒：$_grainAmount%',
          ),
          Slider(
            value: _grainAmount.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: _grainAmount == 0 ? '關閉' : '$_grainAmount%',
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() {
                    _grainAmount = v.round();
                                }),
          ),
          const Text(
            '左右拖動調整顆粒強度；0 = 關閉',
            style: TextStyle(fontSize: 12),
          ),
          Text(
            _noiseAmount == 0 ? '噪點：關閉' : '噪點：$_noiseAmount%',
          ),
          Slider(
            value: _noiseAmount.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: _noiseAmount == 0 ? '關閉' : '$_noiseAmount%',
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() {
                    _noiseAmount = v.round();
                  }),
          ),
          const Text(
            '左右拖動調整噪點強度；0 = 關閉',
            style: TextStyle(fontSize: 12),
          ),

          _sectionTitle('輸出設定'),
          Text('JPG 品質：$_jpegQuality'),
          Slider(
            value: _jpegQuality.toDouble(),
            min: 60,
            max: 98,
            divisions: 38,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _jpegQuality = v.round()),
          ),
          Text('輸出尺寸（寬度）：$_maxWidth px'),
          Slider(
            value: _maxWidth.toDouble().clamp(500, 4000),
            min: 500,
            max: 4000,
            divisions: 70,
            onChanged: _isProcessing
                ? null
                : (v) => _setStateAndSave(() => _maxWidth = v.round()),
          ),
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
                child: Text('IMG日期_001.jpg'),
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
                  child: OutlinedButton(
                    onPressed:
                        _selectedFiles.isEmpty ? null : _previewFirstImage,
                    child: const Text('預覽第一張'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
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
    return Row(
      children: [
        SizedBox(width: 32, child: Text('$name:$value')),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: _isProcessing
                ? null
                : (v) => setState(() => setValue(v.round())),
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
  // 32 px is the reference size at a 1920 px wide image.
  final scale = image.width / 1920.0;
  final targetHeight =
      (fontSize * scale).round().clamp(8, 160).toInt();
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
