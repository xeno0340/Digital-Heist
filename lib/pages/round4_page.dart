// lib/pages/round4_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/* ===== UI constants (high contrast on dark) ===== */
const kAccent = Color(0xFFFFD54A);
const kTitle = Color(0xFFE6EEF5);
const kMuted = Colors.white70;
/* =============================================== */

class Round4Page extends StatefulWidget {
  const Round4Page({super.key});
  @override
  State<Round4Page> createState() => _Round4PageState();
}

class _Round4PageState extends State<Round4Page> {
  final _answerCtrl = TextEditingController();
  bool _submitting = false;

  // 10s lockout after each wrong attempt (client-side)
  DateTime? _lockedUntil;
  Timer? _ticker;
  int _wrong = 0;

  static const _roundNumber = 4;
  static const _correct = 'PELE';

  @override
  void dispose() {
    _answerCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String _norm(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

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

  Future<Map<String, dynamic>> _userTeam() async {
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

    final guess = _norm(_answerCtrl.text);
    if (guess.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your answer')));
      return;
    }

    if (guess != _correct) {
      _wrong += 1;
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

      // ✅ Success — go straight to Round 5 (no dialog)
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/round5');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _completeRoundAndScore() async {
    final fs = FirebaseFirestore.instance;
    final data = await _userTeam();
    final teamId = data['teamId'] as String;
    final teamRef = fs.collection('teams').doc(teamId);

    await fs.runTransaction((txn) async {
      final snap = await txn.get(teamRef);
      final t = _asMap(snap.data());
      if (t.isEmpty) throw Exception('Team not found');

      // Require Round 3 completion
      final r3 = _asMap(t['r3']);
      if ((r3['completed'] ?? false) != true) {
        throw Exception('Round 3 not completed yet');
      }

      // Idempotent
      final r4 = _asMap(t['r4']);
      if ((r4['completed'] ?? false) == true) return;

      final roundAny = t['round'];
      final currentRound = roundAny is int
          ? roundAny
          : (roundAny is num ? roundAny.toInt() : 0);

      // Scoring: base 100 - wrong*5 (min 70)
      final penalty = _wrong * 5;
      final num points = (100 - penalty).clamp(70, 100);

      txn.update(teamRef, {
        'score': FieldValue.increment(points),
        'round': currentRound >= _roundNumber ? currentRound : _roundNumber,
        'lastUpdate': FieldValue.serverTimestamp(),
        'r4': {
          'completed': true,
          'attempts': _wrong + 1,
          'completedAt': FieldValue.serverTimestamp(),
          'points': points,
          'answer': _correct,
        },
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Live guard — ensure Round 3 is done
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

        final userDoc = uSnap.data!;
        final u = _asMap(userDoc.data());
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

            final teamDoc = tSnap.data!;
            final t = _asMap(teamDoc.data());
            final r3done = _asMap(t['r3'])['completed'] == true;

            if (!r3done) {
              return Scaffold(
                appBar: AppBar(title: const Text('Round 4 • Geoguesser')),
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
                      const Text('Locked — complete Round 3 first'),
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

            final r4done = _asMap(t['r4'])['completed'] == true;

            return Scaffold(
              appBar: AppBar(title: const Text('Round 4 • Geoguesser')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _GeoHeader(done: r4done),
                  const SizedBox(height: 12),
                  _GeoPanel(
                    title: 'Field Reconnaissance',
                    lines: const [
                      'Coordinates: 40.7580° N, 73.9855° W',
                      '',
                      'Riddle:',
                      '“Beneath the neon sky,',
                      'crowds climb the great red stairs.',
                      'But don’t look left — look right.',
                      'There, a football legend lends his name.',
                      'What word guards the store of goals?”',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TipCard(
                    title: 'How to investigate (recommended)',
                    lines: const [
                      '1) Open Google Maps.',
                      '2) Paste the coordinates and switch to 3D / Street View.',
                      '3) Scan the surroundings to the RIGHT of the red TKTS stairs.',
                      '4) Identify the store name tied to a football legend.',
                    ],
                    action: () async {
                      const url =
                          'https://www.google.com/maps?q=40.7580,-73.9855';
                      await Clipboard.setData(const ClipboardData(text: url));
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Google Maps link copied'),
                        ),
                      );
                    },
                    actionLabel: 'Copy Google Maps link',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _answerCtrl,
                    enabled: !r4done && _lockRemaining == 0 && !_submitting,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9 ]'),
                      ),
                    ],
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      letterSpacing: 1.1,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: r4done
                          ? 'Already solved'
                          : 'Enter the single word (answer)',
                      hintText: r4done ? 'Completed' : 'Type your answer…',
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
                        onPressed: (_submitting || _lockRemaining > 0 || r4done)
                            ? null
                            : _submit,
                        icon: const Icon(Icons.map),
                        label: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit'),
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
                    'Note: Keep answers concise. No extra symbols or spaces.',
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

/* ---------- GeoGuessr-like UI bits ---------- */

class _GeoHeader extends StatelessWidget {
  final bool done;
  const _GeoHeader({required this.done});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Geoguesser',
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

class _GeoPanel extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _GeoPanel({required this.title, required this.lines});

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

class _TipCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final VoidCallback? action;
  final String actionLabel;

  const _TipCard({
    required this.title,
    required this.lines,
    this.action,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
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
          const SizedBox(height: 8),
          ...lines.map(
            (l) => Text(l, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.link),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
