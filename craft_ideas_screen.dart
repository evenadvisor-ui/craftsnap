import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/craft_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadIdeas();
  }

  Future<void> _loadIdeas() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ideas = await CraftService.instance.getCraftIdeas(
        currentObjects: widget.currentObjects,
        pastObjects: widget.pastObjects,
        futureObjects: widget.futureObjects,
        mode: widget.mode,
      );
      setState(() {
        _ideas = ideas;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load ideas. Please try again.';
        _loading = false;
      });
    }
  }

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
          // Object combo banner
          _buildBanner(),
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
            builder: (_) => CraftDetailScreen(craft: _ideas[i]),
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
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
