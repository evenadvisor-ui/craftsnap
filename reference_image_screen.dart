import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class ReferenceImageScreen extends StatefulWidget {
  final CraftIdea craft;
  const ReferenceImageScreen({super.key, required this.craft});

  @override
  State<ReferenceImageScreen> createState() => _ReferenceImageScreenState();
}

class _ReferenceImageScreenState extends State<ReferenceImageScreen> {
  String? _localImagePath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  // ── Build a clean AI image prompt from the craft title ──

  String _buildPrompt() {
    final title = widget.craft.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
        .trim();
    return 'DIY handmade craft $title upcycled recycled materials finished result '
        'bright natural lighting clean background studio photography';
  }

  // ── Check if we already have a cached image ──

  Future<String> _getCachePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = widget.craft.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
    return '${dir.path}/ref_$safeName.jpg';
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Check cache first
      final cachePath = await _getCachePath();
      final cacheFile = File(cachePath);
      if (await cacheFile.exists()) {
        setState(() {
          _localImagePath = cachePath;
          _loading = false;
        });
        return;
      }

      // Generate via Pollinations.ai — free, no API key needed!
      // Returns a real AI-generated image as PNG/JPG directly
      final prompt = Uri.encodeComponent(_buildPrompt());
      final imageUrl =
          'https://image.pollinations.ai/prompt/$prompt'
          '?width=800&height=600&nologo=true&enhance=true';

      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Save to app folder
        await cacheFile.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            _localImagePath = cachePath;
            _loading = false;
          });
        }
      } else {
        throw Exception('Image fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Reference image error: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not generate image. Check your internet connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _regenerate() async {
    // Delete cached image so a new one is generated
    final cachePath = await _getCachePath();
    final cacheFile = File(cachePath);
    if (await cacheFile.exists()) await cacheFile.delete();
    _loadImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      appBar: AppBar(
        title: const Text('Reference Image'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _regenerate,
            tooltip: 'Generate new image',
          ),
        ],
      ),
      body: Column(
        children: [
          // Craft title banner
          Container(
            width: double.infinity,
            color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              widget.craft.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          Expanded(
            child: _loading
                ? _buildLoading()
                : _error != null
                ? _buildError()
                : _buildImage(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Generating AI reference image...',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'This may take up to 30 seconds',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // AI generated image
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(_localImagePath!),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildError(),
            ),
          ),

          const SizedBox(height: 16),

          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI-generated reference image. Your craft will '
                    'look different — that\'s the beauty of DIY! '
                    'Image saved to your app for offline use.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Back to home button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Could not load image',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadImage,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
