import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import 'craft_ideas_screen.dart';
import 'history_screen.dart';

class ModePickerScreen extends StatefulWidget {
  final List<Detection> detections;
  final String imagePath;

  const ModePickerScreen({
    super.key,
    required this.detections,
    required this.imagePath,
  });

  @override
  State<ModePickerScreen> createState() => _ModePickerScreenState();
}

class _ModePickerScreenState extends State<ModePickerScreen> {
  // For modes that need past/future items
  ScanRecord? _selectedPastScan;
  final TextEditingController _futureItemController = TextEditingController();

  List<String> get _currentLabels =>
      widget.detections.map((d) => d.label).toList();

  @override
  void dispose() {
    _futureItemController.dispose();
    super.dispose();
  }

  void _onModeTap(CraftMode mode) async {
    List<String> pastObjects = [];
    List<String> futureObjects = [];

    if (mode == CraftMode.currentAndPast ||
        mode == CraftMode.pastPresentFuture) {
      if (_selectedPastScan == null) {
        final picked = await _pickPastScan();
        if (picked == null) return;
        _selectedPastScan = picked;
      }
      pastObjects = _selectedPastScan!.allLabels;
    }

    if (mode == CraftMode.currentAndFuture ||
        mode == CraftMode.pastPresentFuture) {
      final future = await _askFutureItem();
      if (future == null || future.isEmpty) return;
      futureObjects = future;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CraftIdeasScreen(
          currentObjects: _currentLabels,
          pastObjects: pastObjects,
          futureObjects: futureObjects,
          mode: mode,
        ),
      ),
    );
  }

  Future<ScanRecord?> _pickPastScan() async {
    final history = await StorageService.instance.loadHistory();
    if (history.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No past scans found. Scan some objects first!')),
        );
      }
      return null;
    }
    if (!mounted) return null;
    return showModalBottomSheet<ScanRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PastScanPicker(history: history),
    );
  }

  Future<List<String>?> _askFutureItem() async {
    _futureItemController.clear();
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Future Items'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'What recyclable items do you plan to get in the future?'),
            const SizedBox(height: 12),
            TextField(
              controller: _futureItemController,
              decoration: const InputDecoration(
                hintText: 'e.g. glass bottle, newspaper, tin can',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final items = _futureItemController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              Navigator.pop(ctx, items);
            },
            child:
                const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Craft Mode'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Detected objects banner
          Container(
            width: double.infinity,
            color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detected objects:',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _currentLabels
                      .map((l) => Chip(
                            label: Text(l,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'How do you want to craft?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: CraftMode.values
                  .map((mode) => _ModeCard(
                        mode: mode,
                        onTap: () => _onModeTap(mode),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode card widget ──────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final CraftMode mode;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.onTap});

  static const List<Color> _gradients = [
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _gradients[mode.index];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(mode.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(mode.subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Past scan picker bottom sheet ─────────────────────────────────────────────

class _PastScanPicker extends StatelessWidget {
  final List<ScanRecord> history;
  const _PastScanPicker({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Pick a Past Scan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shrinkWrap: true,
              itemCount: history.length,
              itemBuilder: (_, i) {
                final record = history[i];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(record.imagePath,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.green.shade100,
                            child: const Icon(Icons.image,
                                color: Colors.green))),
                  ),
                  title: Text(record.primaryLabel.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${record.allLabels.length} object(s) • ${_formatDate(record.scannedAt)}'),
                  onTap: () => Navigator.pop(context, record),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}