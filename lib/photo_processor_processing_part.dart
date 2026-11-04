// ignore_for_file: invalid_use_of_protected_member

part of 'photo_processor_page.dart';

extension _PhotoProcessorProcessingPart on _PhotoProcessorPageState {
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

    if (Platform.isAndroid) {
      final rootUri = _safOutputDirectoryUri;
      if (rootUri == null || rootUri.isEmpty) {
        _showError('輸出資料夾授權已失效，請重新選擇。');
        return;
      }
      var targetUri = rootUri;
      if (_createWorkFolder) {
        final folderDate = _useTodayDate ? DateTime.now() : _startDateTime;
        final folderName =
            '${DateFormat('yyyyMMdd').format(folderDate)}_工作記錄';
        final target = await _saf.mkdirp(rootUri, [folderName]);
        targetUri = target.uri;
        outputDirectory = '$baseDirectory/$folderName';
      }
      _safOutputDirectoryUri = targetUri;
    } else if (_createWorkFolder) {
      final folderDate = _useTodayDate ? DateTime.now() : _startDateTime;
      final folderName =
          '${DateFormat('yyyyMMdd').format(folderDate)}_工作記錄';
      outputDirectory = '$baseDirectory${Platform.pathSeparator}$folderName';
      await Directory(outputDirectory).create(recursive: true);
    }

    await _prepareRenameSequences(outputDirectory);

    _cancelRequested = false;
    _resultFiles.clear();
    _safUriByCachePath.clear();
    _resultDisplayNames.clear();
    _errors.clear();
    _performanceTotalsUs.clear();
    _performanceMaxUs.clear();
    _performanceImageCount = 0;
    _batchStopwatch
      ..reset()
      ..start();
    _stopwatchRefreshTimer?.cancel();
    _stopwatchRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted && _isProcessing) {
          setState(() => _stopwatchRefreshTick++);
        }
      },
    );

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _statusMessage = '開始處理…';
    });

    final total = _selectedFiles.length;
    _randomTimeSeed = DateTime.now().microsecondsSinceEpoch;

    // Find N5 有 8 核，主 isolate 佔 1 核，其餘用於圖片處理。
    // 上限 5 是兼顧記憶體（每張原圖峰值約 40MB）與吞吐的折衷。
    final workerCount =
        math.min(5, math.max(3, Platform.numberOfProcessors - 1));
    final batchSeed = DateTime.now().microsecondsSinceEpoch;

    try {
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
            if (_cancelRequested) {
              return <String, dynamic>{
                'index': i,
                'name': picked.name,
                'cancelled': true,
              };
            }
            try {
              final target = _targetTime(i, total);
              final config = await _buildProcessConfig(target);
              final tempPath =
                  '${Directory.systemTemp.path}${Platform.pathSeparator}batch_${batchSeed}_$i.jpg';

              // isolate 內直接讀檔、處理、寫檔；主 isolate 只傳路徑，
              // 避免每張幾 MB 的 inputBytes / outputBytes 在 isolate 間拷貝。
              final workerResult =
                  await compute<Map<String, dynamic>, Map<String, dynamic>>(
                processImageToTempFile,
                <String, dynamic>{
                  'inputPath': path,
                  'outputPath': tempPath,
                  'config': config,
                },
              );

              return <String, dynamic>{
                'index': i,
                'name': picked.name,
                'target': target,
                'tempPath': tempPath,
                'timings': workerResult['timings'],
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
            final tempPath = result['tempPath'] as String;
            final fileName = _buildFileName(index, target);
            final workerTimings =
                Map<String, dynamic>.from(result['timings'] as Map);
            for (final entry in workerTimings.entries) {
              // workerTotal is a roll-up, not a stage; excluding it keeps
              // the stage comparison bars meaningful.
              if (entry.key == 'workerTotal') continue;
              _recordPerformance(entry.key, (entry.value as num).toInt());
            }
            _performanceImageCount++;
            final saveWatch = Stopwatch()..start();
            String safePath;
            if (Platform.isAndroid) {
              final targetUri = _safOutputDirectoryUri;
              if (targetUri == null || targetUri.isEmpty) {
                throw StateError('SAF 輸出資料夾授權不存在');
              }
              final saved = await _saf.pasteLocalFile(
                tempPath,
                targetUri,
                fileName,
                'image/jpeg',
                overwrite: false,
              );
              _safUriByCachePath[tempPath] = saved.uri;
              _recordPerformance('safWrite', saveWatch.elapsedMicroseconds);
              final scanWatch = Stopwatch()..start();
              await _indexOutputInGallery(saved.uri);
              _recordPerformance('galleryIndex', scanWatch.elapsedMicroseconds);
              safePath = tempPath;
            } else {
              final outPath =
                  '$outputDirectory${Platform.pathSeparator}$fileName';
              safePath = await _makeSafeOutputPath(outPath);
              await File(tempPath).copy(safePath);
              _recordPerformance('localWrite', saveWatch.elapsedMicroseconds);
              try {
                await File(tempPath).delete();
              } catch (_) {}
              if (_applyTime) {
                try {
                  await File(safePath).setLastModified(target);
                } catch (e) {
                  _errors.add('$name：圖片已輸出，但無法修改檔案修改時間：$e');
                }
              }
            }

            _resultFiles.add(safePath);
            _resultDisplayNames[safePath] = fileName;
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
          _statusMessage = '已取消。已完成 ${_resultFiles.length} / $total 張';
        });
      } else {
        setState(() {
          _progress = 1;
          _statusMessage =
              '完成：${_resultFiles.length} / $total 張\n$outputDirectory';
        });
      }

      _batchStopwatch.stop();
      _stopwatchRefreshTimer?.cancel();
      _stopwatchRefreshTimer = null;
      await _showResults(outputDirectory);
      await _deletePrivatePreviewCopies();
    } catch (e) {
      _showError('批量處理失敗：$e');
    } finally {
      _batchStopwatch.stop();
      _stopwatchRefreshTimer?.cancel();
      _stopwatchRefreshTimer = null;
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _recordPerformance(String stage, int microseconds) {
    _performanceTotalsUs[stage] =
        (_performanceTotalsUs[stage] ?? 0) + microseconds;
    final previousMax = _performanceMaxUs[stage] ?? 0;
    if (microseconds > previousMax) {
      _performanceMaxUs[stage] = microseconds;
    }
  }

  String _formatStopwatchElapsed(Duration elapsed) {
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  String _formatPerformanceDuration(int microseconds) {
    final milliseconds = microseconds / 1000.0;
    if (milliseconds < 1000) return '${milliseconds.toStringAsFixed(1)} ms';
    return '${(milliseconds / 1000).toStringAsFixed(2)} s';
  }

  Future<void> _deletePrivatePreviewCopies() async {
    if (!Platform.isAndroid) return;
    for (final path in _resultFiles) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  String _sequenceStorageKey(String localKey) =>
      '$_sequenceFolderId|$localKey';

  Future<Map<String, int>> _readSequenceCounters() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getString('outputSequenceCountersV2');
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      final result = <String, int>{};
      decoded.forEach((key, value) {
        final number = value is num ? value.toInt() : int.tryParse('$value');
        if (number != null && number > 0) {
          result['$key'] = number;
        }
      });
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _writeSequenceCounters() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(
      'outputSequenceCountersV2',
      jsonEncode(_persistedSequenceCounters),
    );
  }

  Future<void> _prepareRenameSequences(String directory) async {
    _nextSequenceByKey.clear();
    _usedOutputNames.clear();

    _sequenceFolderId =
        Platform.isAndroid ? (_safOutputDirectoryUri ?? '') : directory;

    _persistedSequenceCounters = await _readSequenceCounters();

    final folderPrefix = '$_sequenceFolderId|';
    for (final entry in _persistedSequenceCounters.entries) {
      if (!entry.key.startsWith(folderPrefix)) continue;
      final localKey = entry.key.substring(folderPrefix.length);
      _nextSequenceByKey[localKey] = math.max(
        _nextSequenceByKey[localKey] ?? 1,
        entry.value,
      );
    }

    if (Platform.isAndroid) {
      final uri = _safOutputDirectoryUri;
      if (uri == null || uri.isEmpty) return;
      try {
        final entries = await _saf.list(uri);
        for (final entry in entries) {
          if (entry.isDir) continue;
          _usedOutputNames.add(entry.name.toLowerCase());
          _registerExistingOutputName(entry.name);
        }
      } catch (_) {}
      return;
    }

    final dir = Directory(directory);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        _usedOutputNames.add(name.toLowerCase());
        _registerExistingOutputName(name);
      }
    }
  }

  void _registerExistingOutputName(String name) {
    // Accept both legacy IMG20261104_001.jpg and current IMG-20261104-001.jpg.
    final withDate = RegExp(
      r'^(.+?)[_-]?(\d{8})[_-](\d+)\.jpg$',
      caseSensitive: false,
    ).firstMatch(name);
    if (withDate != null) {
      final prefix = withDate.group(1)!;
      final date = withDate.group(2)!;
      final number = int.tryParse(withDate.group(3)!) ?? 0;
      final key = '$prefix|$date';
      _nextSequenceByKey[key] = math.max(
        _nextSequenceByKey[key] ?? 1,
        number + 1,
      );
      return;
    }

    final withoutDate = RegExp(
      r'^(.+?)[_-](\d+)\.jpg$',
      caseSensitive: false,
    ).firstMatch(name);
    if (withoutDate != null) {
      final prefix = withoutDate.group(1)!;
      final number = int.tryParse(withoutDate.group(2)!) ?? 0;
      final key = '$prefix|';
      _nextSequenceByKey[key] = math.max(
        _nextSequenceByKey[key] ?? 1,
        number + 1,
      );
    }
  }

  String _buildFileName(int index, DateTime target) {
    final date = DateFormat('yyyyMMdd').format(target);

    String cleanPrefix;
    String key;
    bool hasDate;

    if (_renameMode == 0) {
      cleanPrefix = 'IMG';
      key = '$cleanPrefix|$date';
      hasDate = true;
    } else {
      cleanPrefix = _customPrefix.trim().isEmpty
          ? 'IMG'
          : _customPrefix
              .trim()
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      hasDate = _includeDateInCustom;
      key = hasDate ? '$cleanPrefix|$date' : '$cleanPrefix|';
    }

    var seq = _nextSequenceByKey[key] ?? 1;
    var candidate = hasDate
        ? '${cleanPrefix}-$date-${seq.toString().padLeft(3, '0')}.jpg'
        : '${cleanPrefix}-${seq.toString().padLeft(3, '0')}.jpg';

    while (_usedOutputNames.contains(candidate.toLowerCase())) {
      seq++;
      candidate = hasDate
          ? '${cleanPrefix}-$date-${seq.toString().padLeft(3, '0')}.jpg'
          : '${cleanPrefix}-${seq.toString().padLeft(3, '0')}.jpg';
    }

    _nextSequenceByKey[key] = seq + 1;
    _usedOutputNames.add(candidate.toLowerCase());
    _persistedSequenceCounters[_sequenceStorageKey(key)] = seq + 1;
    unawaited(_writeSequenceCounters());

    return candidate;
  }
}
