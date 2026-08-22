// lib/pages/home_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/* ======= Shared constants (library-wide) ======= */
const kAccent = Color(0xFFFFD54A);
const kTitleColor = Color(0xFFE6EEF5); // high-contrast heading
const kMuted = Colors.white70;
const int kTotalRounds = 6;

/* ============================================== */

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Match main.dart canonical routes: '/round1'..'/round6'
  String _roundRoute(int n) => '/round$n';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const _ScaffoldLoading();
        }
        if (userSnap.hasError) {
          return _ErrorScaffold(
            title: 'Digital Heist',
            message: 'Failed to load your profile.\n${userSnap.error}',
          );
        }
        final uDoc = userSnap.data;
        if (uDoc == null || !uDoc.exists) {
          return const _ErrorScaffold(
            title: 'Digital Heist',
            message: 'Profile not found. Please complete setup.',
            showBackToSetup: true,
          );
        }

        final u = uDoc.data() ?? {};
        final isAdmin = (u['isAdmin'] ?? false) == true;
        final teamId = (u['teamId'] ?? '').toString();
        final teamName = (u['teamName'] ?? 'Team').toString();

        if (teamId.isEmpty) {
          return const _ErrorScaffold(
            title: 'Digital Heist',
            message: 'No team configured. Please complete setup.',
            showBackToSetup: true,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .snapshots(),
          builder: (context, teamSnap) {
            if (teamSnap.connectionState == ConnectionState.waiting) {
              return const _ScaffoldLoading();
            }
            if (teamSnap.hasError) {
              return _ErrorScaffold(
                title: 'Digital Heist',
                message: 'Failed to load your team.\n${teamSnap.error}',
              );
            }

            final tDoc = teamSnap.data;
            if (tDoc == null || !tDoc.exists) {
              return const _ErrorScaffold(
                title: 'Digital Heist',
                message:
                    'Team document not found. Ask an admin to verify setup.',
              );
            }

            final t = tDoc.data() ?? {};
            final num scoreNum = (t['score'] ?? 0) as num;
            final dynamic roundRaw = (t['round'] ?? 0);
            final int currentRound = roundRaw is int
                ? roundRaw
                : int.tryParse('$roundRaw') ?? 0; // 0..6
            final int playableRound = (currentRound + 1).clamp(1, kTotalRounds);
            final lastUpdateTs = t['lastUpdate'];
            final DateTime? lastUpdate = lastUpdateTs is Timestamp
                ? lastUpdateTs.toDate()
                : null;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Digital Heist'),
                actions: [
                  IconButton(
                    tooltip: 'Leaderboard',
                    onPressed: () =>
                        Navigator.pushNamed(context, '/leaderboard'),
                    icon: const Icon(Icons.leaderboard),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: 'Admin',
                      onPressed: () => Navigator.pushNamed(context, '/admin'),
                      icon: const Icon(Icons.shield),
                    ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/landing', (_) => false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth > 980;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome line — high contrast
                              Row(
                                children: [
                                  Text(
                                    'Welcome, ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: kTitleColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    teamName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: kAccent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (isAdmin)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.5),
                                        ),
                                      ),
                                      child: const Text(
                                        'ADMIN',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Start/continue your rounds below. Rounds unlock sequentially.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(color: kMuted),
                              ),
                              const SizedBox(height: 16),

                              _ProgressHeader(
                                totalRounds: kTotalRounds,
                                score: scoreNum.toInt(),
                                round: currentRound,
                                lastUpdate: lastUpdate,
                              ),

                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    _roundRoute(playableRound),
                                  ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text('Resume Round $playableRound'),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Round cards
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: List.generate(kTotalRounds, (idx) {
                                  final n = idx + 1;

                                  late final _RoundState state;
                                  if (n <= currentRound) {
                                    state = _RoundState.completed;
                                  } else if (n == currentRound + 1) {
                                    state = _RoundState.playable;
                                  } else {
                                    state = _RoundState.future;
                                  }

                                  return _RoundTile(
                                    round: n,
                                    state: state,
                                    onTap: state == _RoundState.playable
                                        ? () => Navigator.pushNamed(
                                            context,
                                            _roundRoute(n),
                                          )
                                        : null,
                                  );
                                }),
                              ),

                              const SizedBox(height: 24),

                              // Admin-only quick actions
                              if (isAdmin)
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        '/leaderboard',
                                      ),
                                      icon: const Icon(Icons.leaderboard),
                                      label: const Text('Open Leaderboard'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        '/leaderboard',
                                      ),
                                      icon: const Icon(Icons.tv),
                                      label: const Text(
                                        'Projector (from leaderboard)',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        '/admin',
                                      ),
                                      icon: const Icon(Icons.shield),
                                      label: const Text('Admin Dashboard'),
                                    ),
                                  ],
                                ),

                              // Inline leaderboard for small screens (visible to everyone)
                              if (!isWide) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Live Leaderboard',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: kTitleColor),
                                ),
                                const SizedBox(height: 10),
                                const _LiveLeaderboardBox(maxHeight: 260),
                              ],
                            ],
                          ),
                        ),

                        if (isWide) const SizedBox(width: 24),

                        // RIGHT: live leaderboard for EVERYONE on wide screens
                        if (isWide)
                          const Expanded(flex: 1, child: _LiveLeaderboardBox()),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* ----------------- UI Widgets ----------------- */

enum _RoundState { completed, playable, future }

class _RoundTile extends StatelessWidget {
  final int round;
  final _RoundState state;
  final VoidCallback? onTap;

  const _RoundTile({
    required this.round,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPlayable = state == _RoundState.playable;
    final bool isCompleted = state == _RoundState.completed;

    final borderColor = (isPlayable || isCompleted)
        ? kAccent
        : Colors.white.withOpacity(0.12);
    final bgColor = (isPlayable || isCompleted)
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.03);
    final textColor = isPlayable
        ? Colors.white
        : (isCompleted ? Colors.white : Colors.white70);
    final icon = isPlayable
        ? Icons.lock_open
        : (isCompleted ? Icons.check_circle_outline : Icons.lock_outline);
    final iconColor = isPlayable
        ? kAccent
        : (isCompleted ? Colors.greenAccent : Colors.white54);

    return InkWell(
      onTap: isPlayable ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 170,
        height: 110,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                'Round $round',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int totalRounds;
  final int score;
  final int round; // 0..totalRounds
  final DateTime? lastUpdate;
  const _ProgressHeader({
    required this.totalRounds,
    required this.score,
    required this.round,
    this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalRounds == 0
        ? 0.0
        : (round.clamp(0, totalRounds)) / totalRounds;
    final timeText = lastUpdate == null ? '' : 'updated ${_ago(lastUpdate!)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: kAccent),
              const SizedBox(width: 6),
              Text(
                'Score: $score',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: kTitleColor),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.flag, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'Round: $round / $totalRounds',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: kMuted),
              ),
              const Spacer(),
              if (timeText.isNotEmpty) ...[
                const Icon(
                  Icons.wifi_tethering,
                  size: 16,
                  color: Colors.lightGreenAccent,
                ),
                const SizedBox(width: 6),
                Text(timeText, style: const TextStyle(color: Colors.white60)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: kAccent,
              backgroundColor: Colors.white.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime d) {
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ago';
    final days = h ~/ 24;
    return '${days}d ago';
  }
}

/* ----------------- LIVE Leaderboard (everyone sees it) ----------------- */

class _LiveLeaderboardBox extends StatelessWidget {
  final double? maxHeight; // provide for inline (mobile) variant
  const _LiveLeaderboardBox({this.maxHeight});

  @override
  Widget build(BuildContext context) {
    // Single orderBy to avoid composite index; we’ll tie-break locally by lastUpdate.
    final q = FirebaseFirestore.instance
        .collection('teams')
        .orderBy('score', descending: true)
        .limit(20);

    final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Failed to load\n${snap.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No teams yet'));
        }

        // Sort locally: score DESC, then earliest lastUpdate wins
        final items = docs.map((d) {
          final m = d.data();
          final name = (m['teamName'] ?? 'Team').toString();
          final num score = (m['score'] ?? 0) as num;
          final ts = m['lastUpdate'];
          final DateTime? last = ts is Timestamp ? ts.toDate() : null;
          return (name: name, score: score, last: last);
        }).toList();

        items.sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
          final la = a.last ?? DateTime(2100);
          final lb = b.last ?? DateTime(2100);
          return la.compareTo(lb);
        });

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white12),
          itemBuilder: (_, i) {
            final it = items[i];
            return Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.right,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: kTitleColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    it.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTitleColor),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${it.score}', style: const TextStyle(color: kTitleColor)),
              ],
            );
          },
        );
      },
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Teams',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: kTitleColor),
          ),
          const SizedBox(height: 10),
          if (maxHeight == null)
            Expanded(child: list)
          else
            SizedBox(height: maxHeight, child: list),
          const SizedBox(height: 8),
          const Text(
            'Ties are broken by earliest completion.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/* ----------------- Small helpers ----------------- */

class _ScaffoldLoading extends StatelessWidget {
  const _ScaffoldLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showBackToSetup;
  const _ErrorScaffold({
    required this.title,
    required this.message,
    this.showBackToSetup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 46, color: Colors.white70),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (showBackToSetup) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/setup'),
                  child: const Text('Go to Profile Setup'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
