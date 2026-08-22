// lib/gate/auth_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Base pages (adjust paths if yours differ)
import '../pages/landing_page.dart';
import '../pages/profile_setup_page.dart';
import '../pages/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Change this to your admin email
  static const String _adminEmail = 'abdul.23w8@gmail.com';

  /// Idempotently seed admin flags for the configured admin email.
  Future<void> _seedAdminIfNeeded(User u) async {
    final email = (u.email ?? '').toLowerCase();
    if (email != _adminEmail) return;

    final fs = FirebaseFirestore.instance;

    // Mark in /admins and set isAdmin on user doc. Both are merge-safe & idempotent.
    await fs.collection('admins').doc(u.uid).set({
      'uid': u.uid,
      'email': email,
      'seededAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await fs.collection('users').doc(u.uid).set({
      'uid': u.uid,
      'email': email,
      'isAdmin': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Minimal placeholder user doc so later reads don’t 404.
  Future<void> _ensureUserDocExists(User u) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': u.uid,
        'email': u.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  bool _profileComplete(Map<String, dynamic> data) {
    // Include teamId/teamName since HomePage expects them
    const required = [
      'name',
      'roll',
      'branch',
      'section',
      'year',
      'phone',
      'email',
      'teamId',
      'teamName',
    ];
    for (final k in required) {
      final v = (data[k] ?? '').toString().trim();
      if (v.isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        final user = authSnap.data;
        if (user == null) {
          // Not signed in
          return const LandingPage();
        }

        // Once signed in: seed admin (if needed) and ensure a user doc exists.
        return FutureBuilder<void>(
          future: Future.wait([
            _seedAdminIfNeeded(user),
            _ensureUserDocExists(user),
          ]),
          builder: (context, seedSnap) {
            if (seedSnap.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }

            // Now listen reactively to the user's profile to decide Home vs Setup.
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const _Loading();
                }

                final data = userSnap.data?.data() ?? {};
                final email = (user.email ?? '').toLowerCase();
                final isAdmin =
                    (data['isAdmin'] == true) || email == _adminEmail;

                // Admins go straight to Home (bypass profile)
                if (isAdmin) return const HomePage();

                // Regular users need a complete profile first
                if (_profileComplete(data)) {
                  return const HomePage();
                } else {
                  return const ProfileSetupPage();
                }
              },
            );
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
    );
  }
}
