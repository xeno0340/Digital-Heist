import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  Future<void> _set(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('config')
        .doc('game')
        .set(data, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('config')
            .doc('game')
            .snapshots(),
        builder: (context, snap) {
          final d = (snap.data?.data() ?? {}) as Map<String, dynamic>;
          final isOpen = d['isOpen'] == true;
          final currentRound = (d['currentRound'] ?? 0) as int;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => _set({'isOpen': !isOpen}),
                  child: Text(isOpen ? 'Pause Game' : 'Start/Resume Game'),
                ),
                ElevatedButton(
                  onPressed: () => _set({'currentRound': currentRound + 1}),
                  child: Text('Advance Round → ${currentRound + 1}'),
                ),
                ElevatedButton(
                  onPressed: () => _set({'currentRound': 1, 'isOpen': true}),
                  child: const Text('Reset to Round 1'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () async {
                    // CAREFUL: wipes scores
                    final batch = FirebaseFirestore.instance.batch();
                    final teams = await FirebaseFirestore.instance
                        .collection('teams')
                        .get();
                    for (final t in teams.docs) {
                      batch.update(t.reference, {'score': 0, 'round': 0});
                    }
                    await batch.commit();
                  },
                  child: const Text('Reset All Scores'),
                ),
                const Divider(),
                Text(
                  'Status: ${isOpen ? 'OPEN' : 'PAUSED'} • Round: $currentRound',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
