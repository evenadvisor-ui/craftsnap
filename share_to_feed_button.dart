import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'phone_auth_screen.dart';

/// Drop this widget anywhere — e.g. at the bottom of CraftDetailScreen
/// just before the reference image button.
class ShareToFeedButton extends StatefulWidget {
  final CraftIdea craft;
  final List<String> detectedObjects; // pass the scan's detected labels

  const ShareToFeedButton({
    super.key,
    required this.craft,
    this.detectedObjects = const [],
  });

  @override
  State<ShareToFeedButton> createState() => _ShareToFeedButtonState();
}

class _ShareToFeedButtonState extends State<ShareToFeedButton> {
  bool _sharing = false;
  bool _shared = false;

  Future<void> _share() async {
    if (!FirebaseService.instance.isLoggedIn) {
      // Prompt login
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
      );
      if (!FirebaseService.instance.isLoggedIn) return;
    }

    setState(() => _sharing = true);
    try {
      await FirebaseService.instance.shareToFeed(
        craftTitle: widget.craft.title,
        craftDescription: widget.craft.description,
        materials: widget.craft.materials,
        detectedObjects: widget.detectedObjects,
      );
      setState(() {
        _sharing = false;
        _shared = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌿 Shared to the community feed!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _sharing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share. Check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shared) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Shared to community!',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _sharing ? null : _share,
        icon: _sharing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              )
            : const Icon(Icons.share_outlined),
        label: Text(_sharing ? 'Sharing...' : 'Share to Community 🌍'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green.shade700,
          side: BorderSide(color: Colors.green.shade400, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
