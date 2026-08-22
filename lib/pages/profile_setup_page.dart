import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _form = GlobalKey<FormState>();

  final _team = TextEditingController();
  final _name = TextEditingController();
  final _roll = TextEditingController();
  final _branch = TextEditingController();
  final _section = TextEditingController();
  final _phone = TextEditingController();

  String _year = '1st';
  bool _busy = false;

  // Light text style to avoid black-on-dark in web textfields
  static const _fieldStyle = TextStyle(color: Color(0xFFE6EEF5));
  static const _hintStyle = TextStyle(color: Color(0xFF8A95A3));

  @override
  void dispose() {
    _team.dispose();
    _name.dispose();
    _roll.dispose();
    _branch.dispose();
    _section.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String? _req(String? v, {int min = 1}) {
    final s = v?.trim() ?? '';
    return (s.length < min) ? 'Required' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final u = FirebaseAuth.instance.currentUser!;
      final fs = FirebaseFirestore.instance;

      // Case-insensitive team id key
      final teamName = _team.text.trim();
      final teamId = teamName.toLowerCase();

      // Check if team exists
      final teamRef = fs.collection('teams').doc(teamId);
      final teamSnap = await teamRef.get();
      final teamExists = teamSnap.exists;

      if (teamExists) {
        final data = teamSnap.data() as Map<String, dynamic>;
        final leaderUid = (data['leaderUid'] ?? '').toString();
        // Allow the *same* user to re-run setup without being blocked.
        if (leaderUid.isNotEmpty && leaderUid != u.uid) {
          _toast('Team name already taken. Try a different name.', error: true);
          setState(() => _busy = false);
          return;
        }
      } else {
        // Create team if not exists
        await teamRef.set({
          'teamId': teamId,
          'teamName': teamName,
          'leaderUid': u.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdate': FieldValue.serverTimestamp(),
          'score': 0,
          'round': 0, // 0 = not started
          // Per-round status buckets reserved (avoid null checks later)
          'r1': {'completed': false},
          'r2': {'completed': false},
          'r3': {'completed': false},
          'r4': {'completed': false},
          'r5': {'completed': false},
          'r6': {'completed': false},
        }, SetOptions(merge: true));
      }

      // Normalize a few text fields
      final name = _name.text.trim();
      final roll = _roll.text.trim().toUpperCase();
      final branch = _branch.text.trim().toUpperCase();
      final section = _section.text.trim().toUpperCase();
      final phone = _phone.text.trim();

      // Create/merge user profile
      await fs.collection('users').doc(u.uid).set({
        'uid': u.uid,
        'email': (u.email ?? '').toLowerCase(),
        'name': name,
        'roll': roll,
        'branch': branch,
        'section': section,
        'year': _year,
        'phone': phone,
        'teamName': teamName,
        'teamId': teamId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _toast('Profile saved!');
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _toast('Failed to save: ${e.code}', error: true);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to save: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team & Player Setup'),
        backgroundColor: const Color(0xFF0C1016),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _form,
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Enter required details (one player per team).',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFADB7C2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Team Name
                  TextFormField(
                    controller: _team,
                    style: _fieldStyle,
                    decoration: const InputDecoration(
                      labelText: 'Team name *',
                      hintText: 'Example: Red Hackers',
                      hintStyle: _hintStyle,
                    ),
                    validator: (v) => _req(v, min: 2),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.organizationName],
                  ),
                  const SizedBox(height: 12),

                  // Full name
                  TextFormField(
                    controller: _name,
                    style: _fieldStyle,
                    decoration: const InputDecoration(
                      labelText: 'Full name *',
                      hintText: 'Your full name',
                      hintStyle: _hintStyle,
                    ),
                    validator: _req,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),
                  const SizedBox(height: 12),

                  // Roll + Branch
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _roll,
                          style: _fieldStyle,
                          decoration: const InputDecoration(
                            labelText: 'Roll number *',
                            hintText: 'e.g. 22CS123',
                            hintStyle: _hintStyle,
                          ),
                          validator: _req,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _branch,
                          style: _fieldStyle,
                          decoration: const InputDecoration(
                            labelText: 'Branch *',
                            hintText: 'e.g. CSE / ECE',
                            hintStyle: _hintStyle,
                          ),
                          validator: _req,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section + Year
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _section,
                          style: _fieldStyle,
                          decoration: const InputDecoration(
                            labelText: 'Section *',
                            hintText: 'e.g. A / B',
                            hintStyle: _hintStyle,
                          ),
                          validator: _req,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _year,
                          decoration: const InputDecoration(
                            labelText: 'Year *',
                          ),
                          dropdownColor: const Color(0xFF0F141D),
                          style: _fieldStyle, // dropdown item text color
                          items: const ['1st', '2nd', '3rd', '4th', '5th']
                              .map(
                                (y) =>
                                    DropdownMenuItem(value: y, child: Text(y)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _year = v ?? '1st'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phone + Email
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phone,
                          style: _fieldStyle,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Phone number *',
                            hintText: '10–15 digits',
                            hintStyle: _hintStyle,
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.length < 10) return 'Enter valid phone';
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.telephoneNumber],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: email,
                          style: _fieldStyle,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Email (from login)',
                            hintStyle: _hintStyle,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Text('Save & Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
