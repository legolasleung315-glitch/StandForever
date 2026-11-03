library photo_processor_page;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'generated_images_page.dart';
import 'image_processor.dart';

part 'photo_processor_state_part.dart';
part 'photo_processor_actions_part.dart';
part 'photo_processor_processing_part.dart';
part 'photo_processor_results_part.dart';
part 'photo_processor_main_ui_part.dart';
part 'photo_processor_settings_ui_part.dart';

class PhotoProcessorPage extends StatefulWidget {
  const PhotoProcessorPage({super.key});

  @override
  State<PhotoProcessorPage> createState() => _PhotoProcessorPageState();
}

class _PhotoProcessorPageState extends State<PhotoProcessorPage> {
  static const MethodChannel _mediaChannel =
      MethodChannel('batch_photo_tools/media');

  SharedPreferences? _prefs;
  final Saf _saf = Saf();
  String? _safOutputDirectoryUri;
  final Map<String, String> _safUriByCachePath = <String, String>{};
  Uint8List? _cachedFontFntBytes;
  Uint8List? _cachedFontPngBytes;
  String? _cachedFontFamily;

  VoidCallback? _settingsPageRefresh;
  Timer? _precisionRepeatTimer;

  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  final List<String> _resultFiles = <String>[];
  final List<String> _errors = <String>[];

  bool _applyTime = true;
  bool _useTodayDate = true;
  DateTime _startDateTime = DateTime.now();
  DateTime _endDateTime = DateTime.now().add(const Duration(hours: 1));

  bool _applyWatermark = true;
  double _fontSize = 70;
  int _colorR = 255;
  int _colorG = 255;
  int _colorB = 255;
  double _opacity = 1.0;
  double _margin = 8;
  String _extraWatermarkText = '';

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

  int _filterMode = 2;
  int _grainAmount = 0;
  int _noiseAmount = 0;
  int _timeDistributionMode = 0;
  int _randomTimeSeed = DateTime.now().microsecondsSinceEpoch;
  int _jpegQuality = 80;
  int _maxWidth = 1000;
  static const List<int> _commonOutputWidths = <int>[
    480,
    640,
    720,
    1080,
    1280,
    1600,
    1920,
    2560,
    3840,
  ];

  int _renameMode = 0;
  String _customPrefix = 'IMG';
  bool _includeDateInCustom = true;
  final Map<String, int> _nextSequenceByKey = <String, int>{};
  final Set<String> _usedOutputNames = <String>{};
  Map<String, int> _persistedSequenceCounters = <String, int>{};
  String _sequenceFolderId = '';

  bool _createWorkFolder = true;
  int _adjustmentMode = 0;

  bool _isProcessing = false;
  bool _cancelRequested = false;
  double _progress = 0;
  String _statusMessage = '請先選擇相片';

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _precisionRepeatTimer?.cancel();
    _precisionRepeatTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainPage(context);
  }
}
