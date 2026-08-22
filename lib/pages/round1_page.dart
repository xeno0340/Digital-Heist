// lib/pages/round1_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/* ===== UI constants (high contrast on dark) ===== */
const kAccent = Color(0xFFFFD54A);
const kTitle = Color(0xFFE6EEF5);
const kMuted = Colors.white70;
/* =============================================== */

class Round1Page extends StatefulWidget {
  const Round1Page({super.key});
  @override
  State<Round1Page> createState() => _Round1PageState();
}

class _Round1PageState extends State<Round1Page> {
  final _answerCtrl = TextEditingController();
  bool _submitting = false;

  // 10s lockout after a wrong attempt
  DateTime? _lockedUntil;
  Timer? _ticker;
  int _wrongAttempts = 0;

  static const _roundNumber = 1;
  static const _correct = 'GITHUB'; // never shown in UI

  @override
  void dispose() {
    _answerCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  // Normalize to A–Z0–9, uppercase
  String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Safely coerce dynamic Firestore map values
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
    if (e is FirebaseException) {
      return '${e.code}: ${e.message ?? ''}';
    }
    return e.toString();
  }

  Future<void> _submit() async {
    if (_submitting || _lockRemaining > 0) return;

    final guess = _norm(_answerCtrl.text);
    if (guess.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an answer')));
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

      // ✅ Success: go straight to Round 2 (no dialog)
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/round2');
    } catch (e, st) {
      // ignore: avoid_print
      print('Round1 submit error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: ${_prettyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Simple, idempotent write.
  Future<void> _completeRoundAndScore() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    // user -> teamId
    final userDoc = await fs.collection('users').doc(uid).get();
    if (!userDoc.exists) throw Exception('User profile not found');
    final u = _asMap(userDoc.data());
    final teamId = (u['teamId'] ?? '').toString();
    if (teamId.isEmpty) throw Exception('No team configured');

    final teamRef = fs.collection('teams').doc(teamId);
    final teamSnap = await teamRef.get();
    if (!teamSnap.exists) {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'not-found',
        message: 'Team not found',
      );
    }

    final t = _asMap(teamSnap.data());
    final r1 = _asMap(t['r1']);
    if ((r1['completed'] ?? false) == true) return; // idempotent

    final roundAny = t['round'];
    final currentRound = roundAny is int
        ? roundAny
        : (roundAny is num ? roundAny.toInt() : 0);

    // Scoring: 100 - (5 × wrong attempts); minimum 70
    final penalty = _wrongAttempts * 5;
    final num points = (100 - penalty).clamp(70, 100);

    await teamRef.update({
      'score': FieldValue.increment(points),
      // store highest completed round; Home uses +1 for next playable
      'round': currentRound >= _roundNumber ? currentRound : _roundNumber,
      'lastUpdate': FieldValue.serverTimestamp(),
      'r1': {
        'completed': true,
        'attempts': _wrongAttempts + 1, // includes the successful try
        'completedAt': FieldValue.serverTimestamp(),
        'points': points,
        'answer': _correct,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    const numbers = [20, 21, 2, 8, 7, 9];
    const hint = 'Where your code lives';

    return Scaffold(
      appBar: AppBar(title: const Text('Round 1 • Firewall Bypass')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          Text(
            'Firewall Bypass',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: kAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Solve the clue using the numbers below. Enter the single-word answer.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: kMuted),
          ),
          const SizedBox(height: 16),

          // Numbers card
          _TileGroup(
            title: 'Numbers',
            titleColor: kMuted,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: numbers
                  .map((n) => _NumberPill(text: '$n', color: Colors.white))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Hint card
          _TileGroup(
            title: 'Hint',
            titleColor: kMuted,
            child: Text(
              hint,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: kTitle),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Your answer',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: kMuted),
          ),
          const SizedBox(height: 6),

          // Input
          TextField(
            controller: _answerCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Your answer',
              labelStyle: TextStyle(color: Colors.white70),
              hintText: 'TYPE HERE…',
              hintStyle: TextStyle(color: Colors.white54),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),

          // CTA + lockout state
          Row(
            children: [
              FilledButton.icon(
                onPressed: (_submitting || _lockRemaining > 0) ? null : _submit,
                icon: const Icon(Icons.vpn_key),
                label: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
              const SizedBox(width: 12),
              if (_lockRemaining > 0)
                Text(
                  'Locked: ${_lockRemaining}s',
                  style: const TextStyle(color: Colors.redAccent),
                ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Text(
            'Tip: A=1, Z=26.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/* ---------- Small UI helpers ---------- */

class _TileGroup extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Widget child;
  const _TileGroup({required this.title, required this.child, this.titleColor});

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
              color: titleColor ?? Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NumberPill extends StatelessWidget {
  final String text;
  final Color color;
  const _NumberPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
