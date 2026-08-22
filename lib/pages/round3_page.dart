// lib/pages/round3_page.dart
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

class Round3Page extends StatefulWidget {
  const Round3Page({super.key});
  @override
  State<Round3Page> createState() => _Round3PageState();
}

class _Round3PageState extends State<Round3Page> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;

  DateTime? _lockedUntil;
  Timer? _ticker;
  int _wrongAttempts = 0;

  static const _roundNumber = 3;
  static const _correct = 'BUGD052017'; // AAAABBCCCC (4 letters + 6 digits)

  @override
  void dispose() {
    _codeCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

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

  String _prettyError(Object e) {
    if (e is FirebaseException) return '${e.code}: ${e.message ?? ''}';
    return e.toString();
  }

  Future<Map<String, dynamic>> _getUserAndTeam() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    final uSnap = await fs.collection('users').doc(uid).get();
    final u = _asMap(uSnap.data());
    if (u.isEmpty) throw Exception('User profile not found');

    final teamId = (u['teamId'] ?? '').toString();
    if (teamId.isEmpty) throw Exception('No team configured');

    final tSnap = await fs.collection('teams').doc(teamId).get();
    final t = _asMap(tSnap.data());
    if (t.isEmpty) throw Exception('Team not found');

    return {'teamId': teamId, 'team': t};
  }

  Future<void> _submit() async {
    if (_submitting || _lockRemaining > 0) return;

    final guess = _norm(_codeCtrl.text);
    if (guess.length != 10 || !RegExp(r'^[A-Z]{4}[0-9]{6}$').hasMatch(guess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format must be AAAABBCCCC (4 letters + 6 digits)'),
        ),
      );
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

      // ✅ Success: go straight to Round 4 (no dialog)
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/round4');
    } catch (e, st) {
      // ignore: avoid_print
      print('Round3 submit error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: ${_prettyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _completeRoundAndScore() async {
    final fs = FirebaseFirestore.instance;
    final data = await _getUserAndTeam();
    final teamId = data['teamId'] as String;
    final teamRef = fs.collection('teams').doc(teamId);

    await fs.runTransaction((txn) async {
      final snap = await txn.get(teamRef);
      final t = _asMap(snap.data());
      if (t.isEmpty) throw Exception('Team not found');

      // Require Round 2 completion
      final r2 = _asMap(t['r2']);
      if ((r2['completed'] ?? false) != true) {
        throw Exception('Round 2 not completed yet');
      }

      // Idempotent
      final r3 = _asMap(t['r3']);
      if ((r3['completed'] ?? false) == true) return;

      final roundAny = t['round'];
      final currentRound = roundAny is int
          ? roundAny
          : (roundAny is num ? roundAny.toInt() : 0);

      // Scoring: 100 - (5 × wrong attempts); minimum 70
      final penalty = _wrongAttempts * 5;
      final num points = (100 - penalty).clamp(70, 100);

      txn.update(teamRef, {
        'score': FieldValue.increment(points),
        'round': currentRound >= _roundNumber ? currentRound : _roundNumber,
        'lastUpdate': FieldValue.serverTimestamp(),
        'r3': {
          'completed': true,
          'attempts': _wrongAttempts + 1,
          'completedAt': FieldValue.serverTimestamp(),
          'points': points,
          'answerLen': _correct.length, // no spoiler
        },
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: fs.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userDoc = userSnap.data!;
        final u = _asMap(userDoc.data());
        final teamId = (u['teamId'] ?? '').toString();
        if (teamId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No team configured.')),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: fs.collection('teams').doc(teamId).snapshots(),
          builder: (context, teamSnap) {
            if (!teamSnap.hasData || !teamSnap.data!.exists) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final teamDoc = teamSnap.data!;
            final t = _asMap(teamDoc.data());

            final r2done = _asMap(t['r2'])['completed'] == true;
            if (!r2done) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Round 3 • Database Break-In'),
                ),
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
                      const Text('Locked — complete Round 2 first'),
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

            final r3done = _asMap(t['r3'])['completed'] == true;

            return Scaffold(
              appBar: AppBar(title: const Text('Round 3 • Database Break-In')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _DbHeader(done: r3done),
                  const SizedBox(height: 12),
                  _DbPanel(
                    title: 'Rebuild the record',
                    lines: const [
                      'A) Android robot’s nickname — take the FIRST 4 letters only.',
                      'B) Year Google acquired Android Inc. — take the LAST 2 digits.',
                      'C) Year Kotlin became an official Android language — take the FULL 4-digit year.',
                      '',
                      'Format: AAAABBCCCC (no spaces or symbols).',
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeCtrl,
                    enabled: !r3done && _lockRemaining == 0 && !_submitting,
                    inputFormatters: [
                      UppercaseTextFormatter(),
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: r3done
                          ? 'Already solved'
                          : 'Enter reconstructed code',
                      hintText: r3done ? 'Completed' : 'AAAAAAAAAA',
                      labelStyle: const TextStyle(color: Colors.white70),
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
                        onPressed: (_submitting || _lockRemaining > 0 || r3done)
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
                            : const Text('Commit'),
                      ),
                      const SizedBox(width: 12),
                      if (_lockRemaining > 0)
                        const Text(
                          'Locked after wrong attempt…',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    'Hint: Verify each field from reliable sources before assembling.',
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

/* ---------- Small UI helpers (DB/terminal look) ---------- */

class _DbHeader extends StatelessWidget {
  final bool done;
  const _DbHeader({required this.done});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Database Break-In',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: kAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        if (done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.green.withOpacity(0.6)),
            ),
            child: const Text(
              'COMPLETED',
              style: TextStyle(color: Colors.green),
            ),
          ),
      ],
    );
  }
}

class _DbPanel extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _DbPanel({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 14,
          height: 1.45,
          color: Colors.white,
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
            const SizedBox(height: 8),
            ...lines.map((l) => Text('> $l')),
          ],
        ),
      ),
    );
  }
}

class UppercaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
