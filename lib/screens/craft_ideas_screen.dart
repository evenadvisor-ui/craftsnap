import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/craft_service.dart';
import '../services/offline_craft_service.dart';
import 'craft_detail_screen.dart';

class CraftIdeasScreen extends StatefulWidget {
  final List<String> currentObjects;
  final List<String> pastObjects;
  final List<String> futureObjects;
  final CraftMode mode;

  const CraftIdeasScreen({
    super.key,
    required this.currentObjects,
    required this.pastObjects,
    required this.futureObjects,
    required this.mode,
  });

  @override
  State<CraftIdeasScreen> createState() => _CraftIdeasScreenState();
}

class _CraftIdeasScreenState extends State<CraftIdeasScreen> {
  List<CraftIdea> _ideas = [];
  bool _loading = true;
  String? _error;
  bool _isOffline = false; // true when showing offline results

  @override
  void initState() {
    super.initState();
    _loadIdeas();
  }

  Future<void> _loadIdeas() async {
    setState(() {
      _loading = true;
      _error = null;
      _isOffline = false;
    });

    // ── Try online first ─────────────────────────────────────────────────────
    try {
      final ideas = await CraftService.instance.getCraftIdeas(
        currentObjects: widget.currentObjects,
        pastObjects: widget.pastObjects,
        futureObjects: widget.futureObjects,
        mode: widget.mode,
      );
      if (mounted) {
        setState(() {
          _ideas = ideas;
          _loading = false;
        });
      }
      return;
    } catch (_) {
      // Online failed — fall through to offline
    }

    // ── Offline fallback ─────────────────────────────────────────────────────
    try {
      final allObjects = [
        ...widget.currentObjects,
        ...widget.pastObjects,
        ...widget.futureObjects,
      ];

      List<CraftIdea> offlineIdeas;

      if (allObjects.length == 1) {
        offlineIdeas = await OfflineCraftService.instance.getCraftsForObject(
          allObjects.first,
          count: 6,
        );
      } else {
        offlineIdeas = await OfflineCraftService.instance.getCraftsForObjects(
          allObjects,
          count: 6,
        );
      }

      if (mounted) {
        setState(() {
          _ideas = offlineIdeas;
          _loading = false;
          _isOffline = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load ideas. Please try again.';
          _loading = false;
        });
      }
    }
  }

  /// The primary detected object label — passed into CraftDetailScreen
  /// so the Share button knows what recyclable was scanned.
  String get _primaryLabel =>
      widget.currentObjects.isNotEmpty ? widget.currentObjects.first : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mode.emoji} Craft Ideas'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadIdeas,
            tooltip: 'Regenerate',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBanner(),
          if (_isOffline) _buildOfflineBadge(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final parts = <String>[];
    if (widget.currentObjects.isNotEmpty) {
      parts.add('Now: ${widget.currentObjects.join(', ')}');
    }
    if (widget.pastObjects.isNotEmpty) {
      parts.add('Past: ${widget.pastObjects.join(', ')}');
    }
    if (widget.futureObjects.isNotEmpty) {
      parts.add('Future: ${widget.futureObjects.join(', ')}');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.green.shade50,
      child: Text(
        parts.join('  •  '),
        style: const TextStyle(fontSize: 12, color: Colors.black54),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 15, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You\'re offline — showing saved craft ideas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadIdeas,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Finding craft ideas for you...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadIdeas,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_ideas.isEmpty) {
      return const Center(child: Text('No ideas found. Try again!'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _ideas.length,
      itemBuilder: (_, i) => _IdeaCard(
        idea: _ideas[i],
        index: i,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CraftDetailScreen(
              craft: _ideas[i],
              detectedLabel: _primaryLabel, // ← FIXED: passes detected object
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idea card ─────────────────────────────────────────────────────────────────

class _IdeaCard extends StatelessWidget {
  final CraftIdea idea;
  final int index;
  final VoidCallback onTap;

  const _IdeaCard({
    required this.idea,
    required this.index,
    required this.onTap,
  });

  static const _emojis = [
    '🌿',
    '🎨',
    '🏡',
    '🔧',
    '💡',
    '🌸',
    '🐦',
    '⭐',
    '🌊',
    '🎭',
  ];

  @override
  Widget build(BuildContext context) {
    final emoji = _emojis[index % _emojis.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      idea.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${idea.steps.length} steps',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
