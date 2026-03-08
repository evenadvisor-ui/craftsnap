import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import 'mode_picker_screen.dart';
import 'history_screen.dart';
import 'favourites_screen.dart';
import 'social_feed_screen.dart';
import 'friends_screen.dart';

// ─── YOLOv8 parser ────────────────────────────────────────────────────────────

class YoloParser {
  static const int inputSize = 640;
  static const int numClasses = 19;
  static const int numPredictions = 8400;
  static const double confThreshold = 0.60;
  static const double nmsIouThreshold = 0.50;

  static List<Detection> parse(List<dynamic> rawOutput, List<String> labels) {
    final tensor = rawOutput[0] as List<dynamic>;
    final List<Detection> candidates = [];

    for (int p = 0; p < numPredictions; p++) {
      final double cx = (tensor[0] as List<dynamic>)[p] as double;
      final double cy = (tensor[1] as List<dynamic>)[p] as double;
      final double w = (tensor[2] as List<dynamic>)[p] as double;
      final double h = (tensor[3] as List<dynamic>)[p] as double;

      double maxScore = -1e9;
      int maxIdx = 0;
      for (int c = 0; c < numClasses; c++) {
        final double score = (tensor[4 + c] as List<dynamic>)[p] as double;
        if (score > maxScore) {
          maxScore = score;
          maxIdx = c;
        }
      }

      final double confidence = 1.0 / (1.0 + exp(-maxScore));
      if (confidence < confThreshold) continue;

      candidates.add(
        Detection(
          x1: (cx - w / 2).clamp(0.0, 1.0),
          y1: (cy - h / 2).clamp(0.0, 1.0),
          x2: (cx + w / 2).clamp(0.0, 1.0),
          y2: (cy + h / 2).clamp(0.0, 1.0),
          classIndex: maxIdx,
          label: maxIdx < labels.length ? labels[maxIdx] : 'unknown',
          confidence: confidence,
        ),
      );
    }
    return _nms(candidates);
  }

  static List<Detection> _nms(List<Detection> dets) {
    dets.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];
    final suppressed = List.filled(dets.length, false);
    for (int i = 0; i < dets.length; i++) {
      if (suppressed[i]) continue;
      kept.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (!suppressed[j] && _iou(dets[i], dets[j]) > nmsIouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  static double _iou(Detection a, Detection b) {
    final ix1 = max(a.x1, b.x1), iy1 = max(a.y1, b.y1);
    final ix2 = min(a.x2, b.x2), iy2 = min(a.y2, b.y2);
    if (ix2 <= ix1 || iy2 <= iy1) return 0.0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    return inter /
        ((a.x2 - a.x1) * (a.y2 - a.y1) + (b.x2 - b.x1) * (b.y2 - b.y1) - inter);
  }
}

// ─── Tap-to-label overlay (fixed fade animation) ─────────────────────────────

class TapLabelOverlay extends StatefulWidget {
  final List<Detection> detections;

  const TapLabelOverlay({super.key, required this.detections});

  @override
  State<TapLabelOverlay> createState() => _TapLabelOverlayState();
}

class _TapLabelOverlayState extends State<TapLabelOverlay>
    with SingleTickerProviderStateMixin {
  String? _activeLabel;
  Offset? _labelPos;
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap(TapUpDetails details, BoxConstraints constraints) {
    final pos = details.localPosition;
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    for (final det in widget.detections) {
      final rect = Rect.fromLTRB(
        det.x1 * w,
        det.y1 * h,
        det.x2 * w,
        det.y2 * h,
      );
      if (rect.contains(pos)) {
        setState(() {
          _activeLabel = det.label;
          _labelPos = Offset(
            rect.center.dx.clamp(60, w - 60),
            rect.center.dy.clamp(24, h - 24),
          );
        });
        _ctrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _ctrl.reverse();
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) => _onTap(d, constraints),
          child: Stack(
            children: [
              if (_activeLabel != null && _labelPos != null)
                Positioned(
                  left: _labelPos!.dx - 60,
                  top: _labelPos!.dy - 18,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 80,
                        maxWidth: 160,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _activeLabel!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── App shell ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final GlobalKey<_ScanTabState> _scanTabKey = GlobalKey();

  void _onNavTap(int index) {
    if (index == 2) {
      setState(() => _tab = 0);
      Future.delayed(const Duration(milliseconds: 100), () {
        _scanTabKey.currentState?.triggerScan();
      });
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _ScanTab(key: _scanTabKey),
          const FriendsScreen(),
          const SizedBox(),
          const HistoryScreen(),
          const SocialFeedScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                current: _tab,
                onTap: _onNavTap,
              ),
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Friends',
                index: 1,
                current: _tab,
                onTap: _onNavTap,
              ),

              // Centre camera notch
              GestureDetector(
                onTap: () => _onNavTap(2),
                child: Container(
                  width: 58,
                  height: 58,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              _NavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'History',
                index: 3,
                current: _tab,
                onTap: _onNavTap,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chat',
                index: 4,
                current: _tab,
                onTap: _onNavTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? Colors.green : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? Colors.green : Colors.grey,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoCraft ♻️'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.green.shade200),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scan Tab ─────────────────────────────────────────────────────────────────

class _ScanTab extends StatefulWidget {
  const _ScanTab({super.key});

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  File? _scannedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  bool _modelReady = false;
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<Detection> _detections = [];
  final TextEditingController _addObjectController = TextEditingController();
  List<String> _manuallyAdded = [];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    _addObjectController.dispose();
    super.dispose();
  }

  void triggerScan() => _scanObject();

  // ── Model loading — runs async so UI never freezes ──

  Future<void> _loadModel() async {
    try {
      // Load interpreter options with reduced threads for low-spec device
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/final_waste_detector_float32.tflite',
        options: options,
      );
      final raw = await rootBundle.loadString('assets/labels.txt');
      _labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (mounted) setState(() => _modelReady = true);
      debugPrint('✅ Model ready. ${_labels.length} labels.');
    } catch (e) {
      debugPrint('❌ Model load error: $e');
    }
  }

  Future<void> _scanObject() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85, // slightly compress to speed up processing
    );
    if (photo == null) return;
    setState(() {
      _scannedImage = File(photo.path);
      _isAnalyzing = true;
      _detections = [];
      _manuallyAdded = [];
    });
    // Run inference in a compute-friendly way
    await _runInference(_scannedImage!);
  }

  Future<void> _runInference(File imageFile) async {
    try {
      if (_interpreter == null) {
        setState(() => _isAnalyzing = false);
        return;
      }

      // Decode and resize image
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        setState(() => _isAnalyzing = false);
        return;
      }

      final resized = img.copyResize(
        decoded,
        width: YoloParser.inputSize,
        height: YoloParser.inputSize,
      );

      // Build input tensor
      final input = List.generate(
        1,
        (_) => List.generate(
          YoloParser.inputSize,
          (y) => List.generate(YoloParser.inputSize, (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          }),
        ),
      );

      // Output buffer [1][23][8400]
      final output = List.generate(
        1,
        (_) => List.generate(
          23,
          (_) => List.filled(YoloParser.numPredictions, 0.0),
        ),
      );

      // Run model
      _interpreter!.run(input, output);

      // Parse detections
      final detections = YoloParser.parse(output, _labels);
      debugPrint('✅ Detections: ${detections.length}');

      // Save to history if something detected
      if (detections.isNotEmpty) {
        final savedPath = await _saveImageLocally(imageFile);
        await StorageService.instance.addScan(
          ScanRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            imagePath: savedPath,
            detections: detections,
            scannedAt: DateTime.now(),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _detections = detections;
          _isAnalyzing = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ Inference error: $e\n$st');
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<String> _saveImageLocally(File original) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await original.copy(dest);
    return dest;
  }

  Map<String, int> get _detectionCounts {
    final map = <String, int>{};
    for (final d in _detections) {
      map[d.label] = (map[d.label] ?? 0) + 1;
    }
    for (final m in _manuallyAdded) {
      map[m] = (map[m] ?? 0) + 1;
    }
    return map;
  }

  void _showAddObjectDialog() {
    _addObjectController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Missed Object'),
        content: TextField(
          controller: _addObjectController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. plastic bottle, newspaper...',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green, width: 2),
            ),
          ),
          onSubmitted: (_) => _submitAddObject(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _submitAddObject(ctx),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitAddObject(BuildContext ctx) {
    final val = _addObjectController.text.trim();
    if (val.isNotEmpty) {
      setState(() => _manuallyAdded.add(val));
      Navigator.pop(ctx);
    }
  }

  void _removeItem(String label) {
    setState(() {
      if (_manuallyAdded.contains(label)) {
        _manuallyAdded.remove(label);
      } else {
        final idx = _detections.indexWhere((d) => d.label == label);
        if (idx != -1) _detections.removeAt(idx);
      }
    });
  }

  List<Detection> get _allDetectionsForCraft {
    final manual = _manuallyAdded.map(
      (m) => Detection(
        x1: 0,
        y1: 0,
        x2: 0,
        y2: 0,
        classIndex: -1,
        label: m,
        confidence: 1.0,
      ),
    );
    return [..._detections, ...manual];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('♻️', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'EcoCraft',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_modelReady)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.check_circle, color: Colors.white, size: 22),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image area ──
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _scannedImage != null
                  ? Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.file(
                            _scannedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                        // Tap-to-label overlay
                        if (_detections.isNotEmpty)
                          Positioned.fill(
                            child: TapLabelOverlay(detections: _detections),
                          ),
                        // Clear button
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _scannedImage = null;
                              _detections = [];
                              _manuallyAdded = [];
                            }),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(7),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        // Hint text
                        if (_detections.isNotEmpty)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '👆 Tap on an object to identify it',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : GestureDetector(
                      onTap: (_isAnalyzing || !_modelReady)
                          ? null
                          : _scanObject,
                      child: Container(
                        width: double.infinity,
                        height: 220,
                        color: Colors.white,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 64,
                              color: Colors.green.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _modelReady
                                  ? 'Tap to scan a recyclable object'
                                  : 'Loading model...',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'or press the 📷 button below',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // ── Analysing indicator ──
            if (_isAnalyzing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    CircularProgressIndicator(
                      color: Colors.green,
                      strokeWidth: 2,
                    ),
                    SizedBox(width: 16),
                    Text('Analysing image...', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),

            // ── Detections list ──
            if (!_isAnalyzing &&
                (_detections.isNotEmpty || _manuallyAdded.isNotEmpty)) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detected Objects',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddObjectDialog,
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'Add missed',
                            style: TextStyle(color: Colors.green, fontSize: 13),
                          ),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    ..._detectionCounts.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '× ${entry.key}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeItem(entry.key),
                              child: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Get craft ideas button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModePickerScreen(
                        detections: _allDetectionsForCraft,
                        imagePath: _scannedImage?.path ?? '',
                      ),
                    ),
                  ),
                  icon: const Text('🎨', style: TextStyle(fontSize: 20)),
                  label: const Text('Get Craft Ideas!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],

            // ── Scan button when no image ──
            if (_scannedImage == null && !_isAnalyzing) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isAnalyzing || !_modelReady)
                      ? null
                      : _scanObject,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan Object'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
