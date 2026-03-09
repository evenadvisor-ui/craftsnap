import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// A button widget that can be embedded anywhere (e.g. craft results screen)
/// to share a detected object craft idea to the social feed.
class ShareToFeedButton extends StatefulWidget {
  /// Name of the craft (e.g. "Pencil Holder")
  final String craftName;

  /// The detected recyclable object (e.g. "plastic-bottle")
  final String objectDetected;

  /// Optional description / craft instructions summary
  final String description;

  /// Optional compact style (icon + label vs full-width button)
  final bool compact;

  const ShareToFeedButton({
    super.key,
    required this.craftName,
    required this.objectDetected,
    this.description = '',
    this.compact = false,
  });

  @override
  State<ShareToFeedButton> createState() => _ShareToFeedButtonState();
}

class _ShareToFeedButtonState extends State<ShareToFeedButton>
    with SingleTickerProviderStateMixin {
  final _firebase = FirebaseService();
  bool _loading = false;
  bool _shared = false;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_loading || _shared) return;

    // Check auth
    if (_firebase.currentUser == null) {
      _showSnack('Sign in to share crafts');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showShareDialog();
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await _firebase.createFeedPost(
        craftName: widget.craftName,
        objectDetected: widget.objectDetected,
        description: widget.description,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _shared = true;
        });
        _bounceController.forward(from: 0);
        _showSnack('Shared to the EcoCraft feed! 🌿');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Failed to share. Please try again.');
      }
    }
  }

  Future<bool> _showShareDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ShareDialog(
        craftName: widget.craftName,
        objectDetected: widget.objectDetected,
        description: widget.description,
        onShare: (desc) => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();
    return _buildFull();
  }

  Widget _buildFull() {
    return ScaleTransition(
      scale: _bounceAnim,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _share,
          style: ElevatedButton.styleFrom(
            backgroundColor: _shared
                ? const Color(0xFF4ADE80).withOpacity(0.15)
                : const Color(0xFF4ADE80),
            foregroundColor: _shared
                ? const Color(0xFF4ADE80)
                : const Color(0xFF0D111C),
            disabledBackgroundColor: const Color(0xFF4ADE80).withOpacity(0.3),
            elevation: 0,
            side: _shared
                ? const BorderSide(color: Color(0xFF4ADE80), width: 1.5)
                : BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0D111C),
                  ),
                )
              : Icon(
                  _shared ? Icons.check_circle_outline : Icons.share_outlined,
                  size: 20,
                ),
          label: Text(
            _loading
                ? 'Sharing...'
                : _shared
                ? 'Shared to Feed!'
                : 'Share to EcoCraft Feed',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return ScaleTransition(
      scale: _bounceAnim,
      child: GestureDetector(
        onTap: _loading ? null : _share,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _shared
                ? const Color(0xFF4ADE80).withOpacity(0.12)
                : const Color(0xFF4ADE80).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4ADE80),
                      ),
                    )
                  : Icon(
                      _shared
                          ? Icons.check_circle_outline
                          : Icons.share_outlined,
                      size: 16,
                      color: const Color(0xFF4ADE80),
                    ),
              const SizedBox(width: 6),
              Text(
                _shared ? 'Shared!' : 'Share',
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareDialog extends StatefulWidget {
  final String craftName;
  final String objectDetected;
  final String description;
  final void Function(String desc) onShare;
  final VoidCallback onCancel;

  const _ShareDialog({
    required this.craftName,
    required this.objectDetected,
    required this.description,
    required this.onShare,
    required this.onCancel,
  });

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Share to Feed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your craft will be visible to all EcoCrafters',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Craft preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high,
                    color: Color(0xFF4ADE80),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.craftName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.objectDetected.replaceAll('-', ' '),
                        style: const TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Caption
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Add a caption (optional)...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onShare(_descController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ADE80),
                    foregroundColor: const Color(0xFF0D111C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
