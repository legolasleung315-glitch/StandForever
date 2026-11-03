import 'dart:io';

import 'package:flutter/material.dart';

class GeneratedImagesPage extends StatelessWidget {
  const GeneratedImagesPage({super.key, required this.files});

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
                  builder: (_) => GeneratedImageViewer(
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

class GeneratedImageViewer extends StatefulWidget {
  const GeneratedImageViewer({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  final List<String> files;
  final int initialIndex;

  @override
  State<GeneratedImageViewer> createState() => _GeneratedImageViewerState();
}

class _GeneratedImageViewerState extends State<GeneratedImageViewer> {
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
