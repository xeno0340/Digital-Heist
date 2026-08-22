// lib/pages/round2_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/* ===== UI constants (high contrast on dark) ===== */
const kAccent = Color(0xFFFFD54A);
const kTitle = Color(0xFFE6EEF5);
const kMuted = Colors.white70;
/* =============================================== */

class Round2Page extends StatefulWidget {
  const Round2Page({super.key});

  @override
  State<Round2Page> createState() => _Round2PageState();
}

class _Round2PageState extends State<Round2Page> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;

  // 10s lockout after a wrong attempt
  DateTime? _lockedUntil;
  Timer? _ticker;
  int _wrongAttempts = 0;

  static const _roundNumber = 2;
  static const _correct = '396'; // secret in UI

  @override
  void dispose() {
    _codeCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  /* ---------- helpers ---------- */

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  int get _lockRemaining {
    if (_lockedUntil == null) return 0;
    final diff = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _startLockout() {
    _lockedUntil = DateTime.now().add(const Duration(seconds: 10));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lockRemaining == 0) {
        _ticker?.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {}); // repaint countdown
      }
    });
    setState(() {});
  }

  Future<Map<String, dynamic>> _getUserTeam() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    final uSnap =
        await fs.collection('users').doc(uid).get()
            as DocumentSnapshot<Map<String, dynamic>>;
    final uData = uSnap.data();
    if (uData == null) throw Exception('User profile not found');

    final teamId = (uData['teamId'] ?? '').toString();
    if (teamId.isEmpty) throw Exception('No team configured');

    final tSnap =
        await fs.collection('teams').doc(teamId).get()
            as DocumentSnapshot<Map<String, dynamic>>;
    final tData = tSnap.data();
    if (tData == null) throw Exception('Team not found');

    return {'teamId': teamId, 'team': tData};
  }

  /* ---------- submit ---------- */

  Future<void> _submit() async {
    if (_submitting || _lockRemaining > 0) return;

    final guess = _codeCtrl.text.trim();
    if (guess.length != 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a 3-digit code')));
      return;
    }

    if (guess != _correct) {
      _wrongAttempts += 1;
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
      await _completeRoundAndScore();

      // ✅ Success: go straight to Round 3 (no dialog)
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/round3');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Simple, idempotent write (no transaction)
  Future<void> _completeRoundAndScore() async {
    final fs = FirebaseFirestore.instance;
    final data = await _getUserTeam();
    final String teamId = data['teamId'] as String;

    final teamRef = fs.collection('teams').doc(teamId);
    final teamSnap =
        await teamRef.get() as DocumentSnapshot<Map<String, dynamic>>;
    final t = teamSnap.data();
    if (t == null) throw Exception('Team not found');

    // Must have finished R1
    final r1Done = (_asMap(t['r1'])['completed'] == true);
    if (!r1Done) {
      throw Exception('Round 1 not completed yet');
    }

    // Already completed? do nothing (idempotent)
    final r2 = _asMap(t['r2']);
    if ((r2['completed'] ?? false) == true) return;

    final roundAny = t['round'];
    final currentRound = roundAny is int
        ? roundAny
        : (roundAny is num ? roundAny.toInt() : 0);

    // Scoring: 100 - (5 × wrong attempts); minimum 70
    final penalty = _wrongAttempts * 5;
    final num points = (100 - penalty).clamp(70, 100);

    await teamRef.update({
      'score': FieldValue.increment(points),
      'round': currentRound >= _roundNumber ? currentRound : _roundNumber,
      'lastUpdate': FieldValue.serverTimestamp(),
      'r2': {
        'completed': true,
        'attempts': _wrongAttempts + 1,
        'completedAt': FieldValue.serverTimestamp(),
        'points': points,
        'answerLen': _correct.length, // no spoiler
      },
    });
  }

  /* ---------- UI ---------- */

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final uData = userSnap.data?.data();
        if (uData == null) {
          return const Scaffold(body: Center(child: Text('No user profile.')));
        }
        final teamId = (uData['teamId'] ?? '').toString();
        if (teamId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No team configured.')),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: fs.collection('teams').doc(teamId).snapshots(),
          builder: (context, teamSnap) {
            if (teamSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final tData = teamSnap.data?.data();
            if (tData == null) {
              return const Scaffold(
                body: Center(child: Text('Team document missing.')),
              );
            }
            final r1done = (_asMap(tData['r1'])['completed'] == true);
            final r2done = (_asMap(tData['r2'])['completed'] == true);

            if (!r1done) {
              return Scaffold(
                appBar: AppBar(title: const Text('Round 2 • System Breach')),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 10),
                      const Text('Locked — complete Round 1 first'),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (_) => false,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Home'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(title: const Text('Round 2 • System Breach')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text(
                        'System Breach',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: kAccent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(width: 12),
                      if (r2done)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.6),
                            ),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crack the 3-digit override lock using the constraints below. Enter the code to proceed.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMuted),
                  ),
                  const SizedBox(height: 16),

                  _TileGroup(
                    title: 'Constraints',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _RuleLine(text: '1) Divisible by 9'),
                        _RuleLine(text: '2) Sum of digits = 18'),
                        _RuleLine(
                          text: '3) Middle digit = square of first digit',
                        ),
                        _RuleLine(text: '4) All digits different'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter 3-digit code',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: '___',
                      hintStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: (_lockRemaining > 0)
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Center(
                                child: Text(
                                  '${_lockRemaining}s',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: (_submitting || _lockRemaining > 0 || r2done)
                            ? null
                            : _submit,
                        icon: const Icon(Icons.vpn_key),
                        label: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                      const SizedBox(width: 12),
                      if (_lockRemaining > 0)
                        Text(
                          'Locked for ${_lockRemaining}s after wrong attempt.',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    'Only one code fits all constraints. Choose wisely.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white54),
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

/* ---------- UI helpers ---------- */

class _TileGroup extends StatelessWidget {
  final String title;
  final Widget child;
  const _TileGroup({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: kTitle,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String text;
  const _RuleLine({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
