// lib/pages/round5_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/* -------------------- Safe map coercion -------------------- */
Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

class Round5Page extends StatefulWidget {
  const Round5Page({super.key});
  @override
  State<Round5Page> createState() => _Round5PageState();
}

class _Round5PageState extends State<Round5Page> {
  static const int roundNumber = 5;

  // Platform capability: allow inline player on Web/Android/iOS/macOS only
  bool get _supportsInlineYouTube {
    if (kIsWeb) return true;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android ||
        p == TargetPlatform.iOS ||
        p == TargetPlatform.macOS;
  }

  // YouTube
  YoutubePlayerController? _yt;
  bool _ytReady = false;

  final _answerCtrl = TextEditingController();
  bool _submitting = false;

  // Attempts & lockout
  int _attempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTicker;

  static const _videoId = '9KMsucl3nvQ'; // https://youtu.be/9KMsucl3nvQ
  static final _videoUrl = Uri.parse('https://youtu.be/$_videoId');

  @override
  void initState() {
    super.initState();

    if (_supportsInlineYouTube) {
      _yt = YoutubePlayerController.fromVideoId(
        videoId: _videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          showVideoAnnotations: false,
          strictRelatedVideos: true,
          playsInline: true,
          enableCaption: false,
        ),
      );

      _yt!.listen((event) {
        if (!mounted) return;
        if (!_ytReady && event.playerState != PlayerState.unknown) {
          setState(() => _ytReady = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _lockTicker?.cancel();
    _answerCtrl.dispose();
    _yt?.close();
    super.dispose();
  }

  // Normalize: remove spaces, dashes, underscores; lowercase.
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
        setState(() {});
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

  Future<void> _openExternalVideo() async {
    if (!await launchUrl(_videoUrl, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open YouTube.')));
    }
  }

  Future<void> _submit() async {
    if (_locked || _submitting) return;

    final raw = _answerCtrl.text.trim();
    if (raw.isEmpty) return;

    const target = 'firebase8';
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

        // Require Round 4 completion
        final r4done = (_asMap(t['r4']))['completed'] == true;
        if (!r4done) throw 'Round 4 not completed yet';

        // Idempotency
        final r5 = _asMap(t['r5']);
        if (r5['completed'] == true) return;

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
          'r5': {
            'completed': true,
            'attempts': _attempts,
            'answer': target,
            'points': points,
            'completedAt': FieldValue.serverTimestamp(),
          },
        });
      });

      if (!mounted) return;

      // ✅ Success: jump straight to Round 6 (no dialog)
      Navigator.of(context).pushReplacementNamed('/round6');
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
            final r4done = (_asMap(t['r4']))['completed'] == true;
            if (!r4done) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Round 5 • Surveillance Hack'),
                ),
                body: const Center(
                  child: Text('Locked — complete Round 4 first'),
                ),
              );
            }
            final r5done = (_asMap(t['r5']))['completed'] == true;

            return Scaffold(
              appBar: AppBar(title: const Text('Round 5 • Surveillance Hack')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      attempts: _attempts,
                      lockRemaining: _lockRemaining,
                      r5done: r5done,
                    ),
                    const SizedBox(height: 12),

                    // Video area
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _supportsInlineYouTube
                                ? Container(
                                    color: Colors.black,
                                    child: Stack(
                                      children: [
                                        if (_yt != null)
                                          YoutubePlayer(controller: _yt!),
                                        if (!_ytReady)
                                          const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        if (_yt != null)
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: Tooltip(
                                              message: 'Fullscreen',
                                              child: InkWell(
                                                onTap: () =>
                                                    _yt!.enterFullScreen(),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.35),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.fullscreen,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : _ExternalVideoCard(
                                    onOpen: _openExternalVideo,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Hint
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb, color: Color(0xFFFFD54A)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hint: Think Google’s app “foundry” where data burns bright—'
                              'split the flame in two words, then count the corners of a cube.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Answer input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _answerCtrl,
                            onSubmitted: (_) => _submit(),
                            enabled: !_locked && !r5done && !_submitting,
                            decoration: InputDecoration(
                              labelText: r5done
                                  ? 'Already solved'
                                  : 'Enter password',
                              hintText: r5done ? 'Completed' : '••••••',
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: (_locked || r5done || _submitting)
                              ? null
                              : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit'),
                        ),
                      ],
                    ),
                    if (_locked) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Locked after wrong attempt: ${_lockRemaining}s',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],

                    const SizedBox(height: 6),
                    if (r5done)
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('Completed — continue to Round 6.'),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/round6',
                              (_) => false,
                            ),
                            child: const Text('Go to Round 6'),
                          ),
                        ],
                      ),
                  ],
                ),
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
  final bool r5done;
  const _Header({
    required this.attempts,
    required this.lockRemaining,
    required this.r5done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Surveillance Hack',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFFFD54A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        const _Badge(label: 'Round 5', color: Colors.teal),
        const SizedBox(width: 8),
        _Badge(label: 'Attempts: $attempts', color: Colors.blueGrey),
        const Spacer(),
        if (lockRemaining > 0)
          _Badge(label: 'LOCKED ${lockRemaining}s', color: Colors.red),
        if (r5done) const _Badge(label: 'COMPLETED', color: Colors.green),
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

/* =================== External video fallback =================== */

class _ExternalVideoCard extends StatelessWidget {
  final Future<void> Function() onOpen;
  const _ExternalVideoCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0A0A),
      child: Ink(
        height: 300,
        child: InkWell(
          onTap: onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_fill,
                  size: 72,
                  color: Colors.white70,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Watch on YouTube',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
