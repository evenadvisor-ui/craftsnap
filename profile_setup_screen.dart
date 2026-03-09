import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  File? _photoFile;
  bool _loading = false;
  String? _error;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (xfile != null) setState(() => _photoFile = File(xfile.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter a display name (min 2 chars)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? photoUrl;
      if (_photoFile != null) {
        photoUrl = await FirebaseService.instance.uploadProfilePhoto(
          _photoFile!,
        );
      }
      await FirebaseService.instance.createOrUpdateProfile(
        displayName: name,
        photoUrl: photoUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Could not save profile. Check internet connection.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      appBar: AppBar(
        title: const Text('Set Up Your Profile'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Welcome to EcoCraft! 🌿',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell the community a bit about you',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 40),

            // ── Avatar picker ──
            GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage: _photoFile != null
                        ? FileImage(_photoFile!)
                        : null,
                    child: _photoFile == null
                        ? Text(
                            '🌿',
                            style: TextStyle(
                              fontSize: 40,
                              color: Colors.green.shade700,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add photo',
              style: TextStyle(color: Colors.green.shade600, fontSize: 13),
            ),
            const SizedBox(height: 32),

            // ── Name field ──
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g. Arjun Eco Crafter',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Crafting! 🎨',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
