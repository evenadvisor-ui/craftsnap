import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import 'profile_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHONE AUTH SCREEN — Step 1: Enter phone  Step 2: Enter OTP
// ─────────────────────────────────────────────────────────────────────────────

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────
  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _error;

  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  // ── Send OTP ──────────────────────────────────

  Future<void> _sendOtp() async {
    final raw = _phoneController.text.trim().replaceAll(' ', '');
    if (raw.length < 10) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }
    // Auto-prepend country code if needed
    final phone = raw.startsWith('+') ? raw : '+91$raw';

    setState(() {
      _loading = true;
      _error = null;
    });

    await FirebaseService.instance.sendOtp(
      phoneNumber: phone,
      onCodeSent: (vId) {
        setState(() {
          _verificationId = vId;
          _otpSent = true;
          _loading = false;
        });
        // Animate transition to OTP step
        _animCtrl.reset();
        _animCtrl.forward();
        Future.delayed(const Duration(milliseconds: 100), () {
          _otpFocusNodes[0].requestFocus();
        });
      },
      onError: (err) {
        setState(() {
          _error = err;
          _loading = false;
        });
      },
    );
  }

  // ── Verify OTP ────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    if (_verificationId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseService.instance.verifyOtp(
        verificationId: _verificationId!,
        otp: otp,
      );

      if (cred != null && mounted) {
        // Check if profile exists
        final user = await FirebaseService.instance.getCurrentUser();
        if (!mounted) return;

        if (user == null) {
          // New user — go to profile setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        } else {
          // Existing user — go back
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid code. Please try again.';
        _loading = false;
      });
    }
  }

  // ── OTP box handler ───────────────────────────

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Back button ──
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Logo ──
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('♻️', style: TextStyle(fontSize: 34)),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Title ──
                          Text(
                            _otpSent ? 'Enter the code' : 'Join EcoCraft',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpSent
                                ? 'We sent a 6-digit code to ${_phoneController.text.trim()}'
                                : 'Share your crafts and inspire the eco community',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // ── Phone input or OTP input ──
                          if (!_otpSent)
                            _buildPhoneInput()
                          else
                            _buildOtpInput(),

                          const SizedBox(height: 20),

                          // ── Error ──
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // ── Action button ──
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading
                                  ? null
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1B5E20),
                                disabledBackgroundColor: Colors.white
                                    .withOpacity(0.4),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
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
                                        color: Color(0xFF1B5E20),
                                      ),
                                    )
                                  : Text(
                                      _otpSent
                                          ? 'Verify & Continue'
                                          : 'Send Code',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          // ── Resend option ──
                          if (_otpSent) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _otpSent = false;
                                          for (final c in _otpControllers) {
                                            c.clear();
                                          }
                                        });
                                      },
                                child: Text(
                                  'Use a different number',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            child: const Text(
              '🇮🇳  +91',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: '98765 43210',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 1,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                counterText: '',
              ),
              onSubmitted: (_) => _sendOtp(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 46,
          height: 56,
          child: TextFormField(
            controller: _otpControllers[i],
            focusNode: _otpFocusNodes[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
            onChanged: (v) => _onOtpChanged(v, i),
          ),
        );
      }),
    );
  }
}
