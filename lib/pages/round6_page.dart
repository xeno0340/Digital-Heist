// lib/pages/round6_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/* -------------------- Safe map coercion -------------------- */
Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

class Round6Page extends StatefulWidget {
  const Round6Page({super.key});
  @override
  State<Round6Page> createState() => _Round6PageState();
}

class _Round6PageState extends State<Round6Page> {
  static const int roundNumber = 6;

  // Passwords combined (R1..R5 + this round’s hint source)
  static const String _allPasswords = 'github396bugd052017pelefirebase8';

  // Assets (JPG → PNG → gradient)
  static const _vaultJpg = 'assets/round6_vault.jpg';
  static const _vaultPng = 'assets/round6_vault.png';

  // UI
  final _answerCtrl = TextEditingController();
  bool _submitting = false;

  // Attempts & lockout
  int _attempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTicker;

  // ----- Transformation rules -----
  // 1) concat all passwords (already in _allPasswords)
  // 2) lowercase + remove spaces/-/_
  // 3) remove vowels (a,e,i,o,u)
  // 4) reverse
  // 5) increment every digit by +1 (mod 10)
  String _computeMaster(String src) {
    final s1 = src.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final s2 = s1.replaceAll(RegExp(r'[aeiou]'), '');
    final s3 = String.fromCharCodes(s2.runes.toList().reversed);
    final buf = StringBuffer();
    for (final ch in s3.split('')) {
      if (RegExp(r'\d').hasMatch(ch)) {
        final d = (int.parse(ch) + 1) % 10;
        buf.write(d.toString());
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  // Normalize user input similarly
  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');

  bool get _locked => _lockRemaining > 0;
  int get _lockRemaining {
    if (_lockedUntil == null) return 0;
    final s = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return s > 0 ? s : 0;
  }

  void _startLockout() {
    _lockedUntil = DateTime.now().add(const Duration(seconds: 10));
    _lockTicker?.cancel();
    _lockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lockRemaining == 0) {
        _lockTicker?.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {}); // refresh countdown badge
      }
    });
    setState(() {});
  }

  Future<Map<String, dynamic>> _userTeam() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    final uSnap = await fs.collection('users').doc(uid).get();
    if (!uSnap.exists) throw 'User profile not found';
    final u = _asMap(uSnap.data());
    final teamId = (u['teamId'] ?? '').toString();
    if (teamId.isEmpty) throw 'No team configured';

    final tSnap = await fs.collection('teams').doc(teamId).get();
    if (!tSnap.exists) throw 'Team not found';
    final t = _asMap(tSnap.data());
    return {'teamId': teamId, 'team': t};
  }

  Future<void> _submit() async {
    if (_locked || _submitting) return;
    final raw = _answerCtrl.text.trim();
    if (raw.isEmpty) return;

    final target = _computeMaster(_allPasswords);
    if (_normalize(raw) != target) {
      _attempts += 1;
      _startLockout();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incorrect. Locked for ${_lockRemaining}s'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final fs = FirebaseFirestore.instance;
      final data = await _userTeam();
      final teamId = data['teamId'] as String;
      final teamRef = fs.collection('teams').doc(teamId);

      await fs.runTransaction((txn) async {
        final snap = await txn.get(teamRef);
        if (!snap.exists) throw 'Team not found';
        final t = _asMap(snap.data());

        // Require Round 5 completion
        final r5done = (_asMap(t['r5']))['completed'] == true;
        if (!r5done) throw 'Round 5 not completed yet';

        // Idempotency
        final r6 = _asMap(t['r6']);
        if (r6['completed'] == true) return;

        // Score
        final penalty = _attempts * 5;
        final num points = (120 - penalty).clamp(80, 120);

        final roundAny = t['round'];
        final currentRound = roundAny is int
            ? roundAny
            : (roundAny is num ? roundAny.toInt() : 0);

        txn.update(teamRef, {
          'score': FieldValue.increment(points),
          'round': currentRound >= roundNumber ? currentRound : roundNumber,
          'lastUpdate': FieldValue.serverTimestamp(),
          'r6': {
            'completed': true,
            'attempts': _attempts,
            'answer': target,
            'points': points,
            'completedAt': FieldValue.serverTimestamp(),
          },
        });
      });

      if (!mounted) return;
      // ✅ No dialog — go straight Home
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _lockTicker?.cancel();
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: fs.collection('users').doc(uid).snapshots(),
      builder: (context, uSnap) {
        if (!uSnap.hasData || !uSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final u = _asMap(uSnap.data?.data());
        final teamId = (u['teamId'] ?? '').toString();
        if (teamId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No team configured.')),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: fs.collection('teams').doc(teamId).snapshots(),
          builder: (context, tSnap) {
            if (!tSnap.hasData || !tSnap.data!.exists) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final t = _asMap(tSnap.data?.data());
            final r5done = (_asMap(t['r5']))['completed'] == true;
            if (!r5done) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Round 6 • Vault Master Code'),
                ),
                body: const Center(
                  child: Text('Locked — complete Round 5 first'),
                ),
              );
            }
            final r6done = (_asMap(t['r6']))['completed'] == true;

            return Scaffold(
              appBar: AppBar(title: const Text('Round 6 • Vault Master Code')),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // Background with fallback chain
                  _VaultBackground(jpgPath: _vaultJpg, pngPath: _vaultPng),

                  // Top → center dark overlay for readability
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0xAA000000), Color(0x55000000)],
                      ),
                    ),
                  ),

                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            attempts: _attempts,
                            lockRemaining: _lockRemaining,
                            r6done: r6done,
                          ),
                          const SizedBox(height: 18),

                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Card
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 22,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1FFFFFFF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.28),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.25,
                                            ),
                                            blurRadius: 22,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'MASTER CODE',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  letterSpacing: 4,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  shadows: const [
                                                    Shadow(
                                                      color: Colors.black54,
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                          ),
                                          const SizedBox(height: 10),

                                          const Text(
                                            'Combine the keys from every round. '
                                            'Remove vowels, reverse the string, '
                                            'then advance each digit by +1.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFFECEFF4),
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 18),

                                          Theme(
                                            data: Theme.of(context).copyWith(
                                              inputDecorationTheme:
                                                  Theme.of(
                                                    context,
                                                  ).inputDecorationTheme.copyWith(
                                                    fillColor: Colors.white
                                                        .withOpacity(0.14),
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                    hintStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFFFFD54A,
                                                                ),
                                                                width: 1.4,
                                                              ),
                                                        ),
                                                  ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: _answerCtrl,
                                                    onSubmitted: (_) =>
                                                        _submit(),
                                                    enabled:
                                                        !_locked &&
                                                        !r6done &&
                                                        !_submitting,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText: r6done
                                                          ? 'Already solved'
                                                          : 'Enter master code',
                                                      hintText: r6done
                                                          ? 'Completed'
                                                          : 'e.g. 9sbrfl…',
                                                      suffixIcon:
                                                          (_lockRemaining > 0)
                                                          ? Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: Center(
                                                                child: Text(
                                                                  '${_lockRemaining}s',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .redAccent,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFE53935),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 18,
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed:
                                                      (_locked ||
                                                          r6done ||
                                                          _submitting)
                                                      ? null
                                                      : _submit,
                                                  child: _submitting
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                      : const Text('Unlock'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Hint (outside card, bright)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1E272E,
                                        ).withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.18),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb,
                                            color: Color(0xFFFFD54A),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Hint: The vault loves silence (no vowels) and mirrors (reverse). '
                                              'Numbers tick forward by one.',
                                              style: TextStyle(
                                                color: Color(0xFFF1F5F9),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (_locked) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Locked after wrong attempt: ${_lockRemaining}s',
                                        style: const TextStyle(
                                          color: Color(0xFFFF8A80),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],

                                    if (r6done) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Completed — head to Home to continue.',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pushNamedAndRemoveUntil(
                                                  context,
                                                  '/home',
                                                  (_) => false,
                                                ),
                                            child: const Text('Go Home'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* ====================== Header badge ====================== */

class _Header extends StatelessWidget {
  final int attempts;
  final int lockRemaining;
  final bool r6done;
  const _Header({
    required this.attempts,
    required this.lockRemaining,
    required this.r6done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Vault Challenge',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFFFD54A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        const _Badge(label: 'Round 6', color: Colors.teal),
        const SizedBox(width: 8),
        _Badge(label: 'Attempts: $attempts', color: Colors.blueGrey),
        const Spacer(),
        if (lockRemaining > 0)
          _Badge(label: 'LOCKED ${lockRemaining}s', color: Colors.red),
        if (r6done) const _Badge(label: 'COMPLETED', color: Colors.green),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}

/* ===================== Background widget ===================== */

class _VaultBackground extends StatelessWidget {
  final String jpgPath;
  final String pngPath;
  const _VaultBackground({required this.jpgPath, required this.pngPath});

  @override
  Widget build(BuildContext context) {
    // Try JPG → PNG → gradient
    return Image.asset(
      jpgPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          pngPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0C1016), Color(0xFF151A22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
