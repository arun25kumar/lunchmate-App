// lib/presentation/pages/admin/collect_cash_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dark_colors.dart';
import '../../../domain/usecases/collect_cash.dart';

/// Status colors that switch automatically between light and dark mode.
class _Palette {
  final Color success;
  final Color successLight;
  final Color error;

  const _Palette._(this.success, this.successLight, this.error);

  factory _Palette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _Palette._(AppDarkColors.success, AppDarkColors.successLight,
        AppDarkColors.error)
        : const _Palette._(
        AppColors.success, AppColors.successLight, AppColors.error);
  }
}

class CollectCashScreen extends StatefulWidget {
  final String teamId;
  final String adminId;

  const CollectCashScreen({
    super.key,
    required this.teamId,
    required this.adminId,
  });

  @override
  State<CollectCashScreen> createState() => _CollectCashScreenState();
}

class _CollectCashScreenState extends State<CollectCashScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _collectCash = CollectCash();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _entriesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _paidStream;

  /// memberId -> name, refreshed from the members stream.
  final Map<String, String> _memberNames = {};

  String? _selectedMemberId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final team =
    FirebaseFirestore.instance.collection('teams').doc(widget.teamId);
    _membersStream = team.collection('members').snapshots();
    _entriesStream = team.collection('lunch_entries').snapshots();
    _paidStream = team.collection('cash_collections').snapshots();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Sums `amount` grouped by `memberId`.
  Map<String, double> _sumByMember(QuerySnapshot<Map<String, dynamic>> snap) {
    final out = <String, double>{};
    for (final d in snap.docs) {
      final m = d.data();
      final id = m['memberId'] as String?;
      if (id == null) continue;
      out[id] = (out[id] ?? 0) + ((m['amount'] as num?)?.toDouble() ?? 0);
    }
    return out;
  }

  Future<void> _submit() async {
    final palette = _Palette.of(context);
    final amount = double.tryParse(_amountCtrl.text.trim());

    if (_selectedMemberId == null) {
      _snack('Select a member', palette.error);
      return;
    }
    if (amount == null || amount <= 0) {
      _snack('Enter a valid amount', palette.error);
      return;
    }

    setState(() => _saving = true);
    try {
      await _collectCash(
        teamId: widget.teamId,
        memberId: _selectedMemberId!,
        memberName: _memberNames[_selectedMemberId] ?? _selectedMemberId!,
        adminId: widget.adminId,
        amount: amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      _amountCtrl.clear();
      _noteCtrl.clear();
      _snack('₹${amount.toStringAsFixed(2)} collected. Balance updated.',
          palette.success);
    } catch (e) {
      _snack('Failed: $e', palette.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  Widget _memberDropdown(ColorScheme colors) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _membersStream,
      builder: (context, memSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _entriesStream,
          builder: (context, entSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _paidStream,
              builder: (context, paidSnap) {
                if (!memSnap.hasData ||
                    !entSnap.hasData ||
                    !paidSnap.hasData) {
                  return LinearProgressIndicator(color: colors.primary);
                }

                final spent = _sumByMember(entSnap.data!);
                final paid = _sumByMember(paidSnap.data!);
                final docs = memSnap.data!.docs;

                _memberNames
                  ..clear()
                  ..addEntries(docs.map((d) =>
                      MapEntry(d.id, (d.data()['name'] ?? d.id).toString())));

                // Guard against a selected member that no longer exists.
                final validValue =
                docs.any((d) => d.id == _selectedMemberId)
                    ? _selectedMemberId
                    : null;

                return DropdownButtonFormField<String>(
                  value: validValue,
                  hint: const Text('Select member'),
                  dropdownColor: colors.surface,
                  items: docs.map((d) {
                    final pending = (spent[d.id] ?? 0) - (paid[d.id] ?? 0);
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${_memberNames[d.id]}  (₹${pending.toStringAsFixed(2)} due)',
                        style: TextStyle(color: colors.onSurface),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedMemberId = v),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final labelStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Collect Cash')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member', style: labelStyle),
                const SizedBox(height: 8),
                _memberDropdown(colors),
                const SizedBox(height: 16),
                Text('Cash received', style: labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  style: TextStyle(color: colors.onSurface),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Note (optional)', style: labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  style: TextStyle(color: colors.onSurface),
                  decoration:
                  const InputDecoration(hintText: 'e.g. Lunch dues'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                        : const Text('Collect & Update Balance'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Recent collections',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _RecentCollections(teamId: widget.teamId),
        ],
      ),
    );
  }
}

class _RecentCollections extends StatelessWidget {
  final String teamId;
  const _RecentCollections({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = _Palette.of(context);

    final stream = FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('cash_collections')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No collections yet',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final m = d.data();
            final amt = (m['amount'] as num?)?.toDouble() ?? 0;
            final who = (m['memberName'] ?? m['memberId'] ?? '').toString();
            final note = (m['note'] as String?)?.trim();
            final hasNote = note != null && note.isNotEmpty;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, color: palette.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasNote ? '$who · $note' : who,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurface),
                    ),
                  ),
                  Text(
                    '+₹${amt.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: palette.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}