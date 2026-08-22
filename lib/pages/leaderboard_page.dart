// lib/pages/leaderboard_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ===================== Admin Gate (shared) =====================
class _AdminGate extends StatelessWidget {
  final WidgetBuilder builder;
  const _AdminGate({required this.builder});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _BlockedScaffold(
        title: 'Live Leaderboard',
        message: 'You must be signed in.',
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _BlockedScaffold(
            title: 'Live Leaderboard',
            message: 'Failed to verify admin.\n${snap.error}',
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const _BlockedScaffold(
            title: 'Live Leaderboard',
            message: 'Profile not found.',
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final isAdmin = (data['isAdmin'] ?? false) == true;
        if (!isAdmin) {
          return const _BlockedScaffold(
            title: 'Live Leaderboard',
            message: 'Admins only.',
          );
        }
        return builder(context);
      },
    );
  }
}

class _BlockedScaffold extends StatelessWidget {
  final String title;
  final String message;
  const _BlockedScaffold({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 46, color: Colors.white70),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================== Leaderboard (admin only) =====================
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminGate(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Live Leaderboard'),
          actions: [
            IconButton(
              tooltip: 'Projector mode',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardProjector()),
              ),
              icon: const Icon(Icons.tv),
            ),
          ],
        ),
        body: const _LeaderboardList(padded: true),
      ),
    );
  }
}

/// Shared list widget (used by normal + projector)
class _LeaderboardList extends StatelessWidget {
  final bool padded;
  const _LeaderboardList({required this.padded});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('teams')
        .orderBy('score', descending: true)
        .orderBy('lastUpdate', descending: false) // earlier = better tie-break
        .limit(200);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Failed to load leaderboard\n${snap.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No teams yet'));
        }

        return ListView.separated(
          padding: padded ? const EdgeInsets.all(16) : EdgeInsets.zero,
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final name = (d['teamName'] ?? 'Team').toString();
            final score = (d['score'] ?? 0) as num;
            final round = (d['round'] ?? 0) as num;
            final updatedTs = d['lastUpdate'];
            final lastUpdate = updatedTs is Timestamp
                ? updatedTs.toDate()
                : null;

            return _LeaderboardRow(
              rank: i + 1,
              teamName: name,
              score: score.toInt(),
              round: round.toInt(),
              lastUpdate: lastUpdate,
            );
          },
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String teamName;
  final int score;
  final int round;
  final DateTime? lastUpdate;

  const _LeaderboardRow({
    required this.rank,
    required this.teamName,
    required this.score,
    required this.round,
    this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final topBadge = _badgeForRank(rank);
    final timeText = lastUpdate == null ? '' : '• updated ${_ago(lastUpdate!)}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: SizedBox(
        width: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$rank', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              teamName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (topBadge != null) ...[const SizedBox(width: 8), topBadge],
        ],
      ),
      subtitle: Text(
        'Round $round $timeText',
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 18, color: Color(0xFFFFD54A)),
          const SizedBox(width: 6),
          Text('$score', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  // Small crown/medal for top 3
  Widget? _badgeForRank(int r) {
    switch (r) {
      case 1:
        return const _ChipBadge(
          icon: Icons.emoji_events,
          label: '1st',
          color: Color(0xFFFFD54A),
        );
      case 2:
        return const _ChipBadge(
          icon: Icons.emoji_events_outlined,
          label: '2nd',
          color: Color(0xFFB0BEC5),
        );
      case 3:
        return const _ChipBadge(
          icon: Icons.emoji_events_outlined,
          label: '3rd',
          color: Color(0xFFCD7F32), // bronze
        );
      default:
        return null;
    }
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

class _ChipBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ChipBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

/// ===================== Projector (admin only) =====================
class LeaderboardProjector extends StatelessWidget {
  const LeaderboardProjector({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminGate(
      builder: (_) => Scaffold(
        backgroundColor: const Color(0xFF0C1016),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE LEADERBOARD',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleLarge!,
                  child: const _LeaderboardList(padded: false),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ties are broken by earliest completion.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
