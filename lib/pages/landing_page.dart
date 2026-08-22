import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Landing page – Digital Heist (poster-friendly, no-crop)
/// Requires: assets/poster.jpg in pubspec.yaml
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final headline = GoogleFonts.orbitron(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: _C.yellow,
    );

    return Scaffold(
      backgroundColor: _C.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B0E13), Color(0xFF121722)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _TopBar(onLogin: () => showAuthDialog(context)),
                    const SizedBox(height: 18),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final isSmall = c.maxWidth < 960;
                          final double? tileHeight = isSmall ? null : 640;
                          return Flex(
                            direction: isSmall
                                ? Axis.vertical
                                : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _PosterCard(height: tileHeight),
                              ),
                              SizedBox(
                                width: isSmall ? 0 : 16,
                                height: isSmall ? 16 : 0,
                              ),
                              Expanded(
                                flex: 5,
                                child: _DetailsCard(
                                  headline: headline,
                                  height: tileHeight,
                                  onLogin: () => showAuthDialog(context),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onLogin;
  const _TopBar({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
              color: _C.red,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            'MAD • Digital Heist',
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _C.offWhite,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.yellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Login / Signup'),
          ),
        ],
      ),
    );
  }
}

/// Poster card – full image (no crop) + neutral blend
class _PosterCard extends StatelessWidget {
  final double? height;
  const _PosterCard({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black.withOpacity(0.18)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Image.asset(
                  'assets/poster.jpg',
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.28)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final TextStyle headline;
  final double? height;
  final VoidCallback onLogin;

  const _DetailsCard({
    required this.headline,
    required this.onLogin,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 28,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _C.yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Engineers Day • LORDS Institute',
                style: GoogleFonts.inter(color: _C.offWhite.withOpacity(0.9)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('DIGITAL HEIST', style: headline),
          const SizedBox(height: 8),
          Text(
            'Presented by MAD Club',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: _C.offWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          _kv('Event Timing', '10:00 AM – 2:00 PM'),
          _kv('Venue', 'LORDS Institute'),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'A 7-round heist of riddles, puzzles and hacking mini-games. Clear rounds to unlock the next. '
            'The sooner you crack a round, the more points you earn. Top 3 teams win.',
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.5,
              color: _C.offWhite.withOpacity(0.95),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.yellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Login / Signup'),
              ),
              const SizedBox(width: 12),
              Text(
                'Bring 1 laptop per team • Google sign-in allowed',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: GoogleFonts.inter(color: Colors.white70)),
        ),
        Expanded(
          child: Text(
            v,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: _C.offWhite,
            ),
          ),
        ),
      ],
    ),
  );
}

class _C {
  static const bg = Color(0xFF0C1016);
  static const red = Color(0xFFE53935);
  static const yellow = Color(0xFFFFD54A);
  static const offWhite = Color(0xFFE6EEF5);
}

/// ---------- AUTH POPUP (Google, Register confirm, Forgot password) ----------
void showAuthDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierLabel: 'Auth',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved = Curves.easeOutCubic.transform(anim.value);
      return Opacity(
        opacity: curved,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.shrink(),
              ),
            ),
            Center(
              child: Transform.scale(
                scale: 0.95 + 0.05 * curved,
                child: const _AuthPopup(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AuthPopup extends StatefulWidget {
  const _AuthPopup();

  @override
  State<_AuthPopup> createState() => _AuthPopupState();
}

class _AuthPopupState extends State<_AuthPopup> {
  bool isLogin = true;
  bool rememberMe = false;
  bool obscure = true;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  bool _validEmail(String e) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

  Future<void> _forgotPassword() async {
    final tmpEmail = TextEditingController(text: emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121722),
        title: const Text('Reset password'),
        content: TextField(
          controller: tmpEmail,
          style: const TextStyle(color: _C.offWhite),
          decoration: const InputDecoration(labelText: 'Registered email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, tmpEmail.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Failed to send reset email', error: true);
    } catch (_) {
      _snack('Failed to send reset email', error: true);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
        if (gUser == null) return; // cancelled
        final gAuth = await gUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(cred);
      }
      if (mounted) Navigator.pop(context);
      // Navigator.pushReplacementNamed(context, '/round/1');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Google sign-in failed', error: true);
    } catch (_) {
      _snack('Google sign-in failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width;
    final cardWidth = maxWidth < 480 ? maxWidth - 32 : 440.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: const Color(0xFF0F141D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 36,
              spreadRadius: -6,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  isLogin ? 'Login' : 'Create account',
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _C.offWhite,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Google button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  foregroundColor: _C.offWhite,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: const [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR', style: TextStyle(color: Colors.white54)),
                ),
                Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: _C.offWhite),
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              style: const TextStyle(color: _C.offWhite),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),

            if (!isLogin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                style: const TextStyle(color: _C.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Re-enter Password',
                  hintText: 'Type the same password again',
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: (v) => setState(() => rememberMe = v ?? false),
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  final pass = passCtrl.text;

                  if (!_validEmail(email)) {
                    _snack('Enter a valid email', error: true);
                    return;
                  }
                  if (pass.length < 6) {
                    _snack(
                      'Password must be at least 6 characters',
                      error: true,
                    );
                    return;
                  }
                  if (!isLogin && pass != confirmCtrl.text) {
                    _snack('Passwords do not match', error: true);
                    return;
                  }

                  try {
                    if (isLogin) {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: email,
                        password: pass,
                      );
                    } else {
                      await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                            email: email,
                            password: pass,
                          );
                    }
                    if (mounted) Navigator.pop(context); // close dialog
                    // Navigator.pushReplacementNamed(context, '/round/1');
                  } on FirebaseAuthException catch (e) {
                    _snack(e.message ?? 'Authentication failed', error: true);
                  } catch (_) {
                    _snack('Authentication failed', error: true);
                  }
                },
                child: Text(isLogin ? 'Login' : 'Create account'),
              ),
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(
                isLogin
                    ? "Don't have an account? Register"
                    : "Already have an account? Login",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
