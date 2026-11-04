import 'package:flutter/material.dart';

import 'photo_processor_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BatchPhotoToolsApp());
}

class BatchPhotoToolsApp extends StatelessWidget {
  const BatchPhotoToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '靚仔相',
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
