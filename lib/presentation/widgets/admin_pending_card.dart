// lib/presentation/widgets/admin_pending_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../domain/usecases/lunch_expense_service.dart' show formatMoney;

/// Live card for the admin home screen: total amount still to be received
/// from all members.
///
///   pending (per member) = sum(lunch_entries) - sum(cash_collections)
///
/// - The admin's own lunch ('admin') is skipped (nobody can pay it).
/// - Members who paid in advance (negative) are ignored, so they don't
///   cancel out what others owe.
/// Updates instantly when an entry is saved or cash is collected.
class AdminPendingCard extends StatelessWidget {
  final String teamId;
  final VoidCallback? onTap; // e.g. open Collect Cash

  const AdminPendingCard({super.key, required this.teamId, this.onTap});

  Map<String, double> _sumByMember(QuerySnapshot<Map<String, dynamic>> snap) {
    final out = <String, double>{};
    for (final d in snap.docs) {
      final m = d.data();
      final id = m['memberId'] as String?;
      if (id == null || id == 'admin') continue;
      out[id] = (out[id] ?? 0) + ((m['amount'] as num?)?.toDouble() ?? 0);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final team = FirebaseFirestore.instance.collection('teams').doc(teamId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: team.collection('lunch_entries').snapshots(),
      builder: (context, entSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: team.collection('cash_collections').snapshots(),
          builder: (context, paidSnap) {
            double total = 0;
            int pendingMembers = 0;
            final loading = !entSnap.hasData || !paidSnap.hasData;

            if (!loading) {
              final spent = _sumByMember(entSnap.data!);
              final paid = _sumByMember(paidSnap.data!);
              for (final id in spent.keys) {
                final due =
                    ((spent[id] ?? 0) - (paid[id] ?? 0)) * 100;
                final rounded = due.round() / 100;
                if (rounded > 0) {
                  total += rounded;
                  pendingMembers++;
                }
              }
            }

            return Material(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: colors.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total to receive',
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loading
                                  ? 'Calculating...'
                                  : pendingMembers == 0
                                  ? 'All settled'
                                  : 'From $pendingMembers member'
                                  '${pendingMembers == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: colors.onPrimaryContainer
                                    .withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimaryContainer,
                        ),
                      )
                          : Text(
                        formatMoney(total),
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}