// lib/domain/usecases/collect_cash.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Records cash handed to the admin.
///
/// The member's pending balance is NOT stored. It is calculated as:
///   sum(lunch_entries.amount) - sum(cash_collections.amount)
/// so it updates automatically whenever either collection changes.
class CollectCash {
  final FirebaseFirestore _db;

  CollectCash({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Future<void> call({
    required String teamId,
    required String memberId,
    required String memberName,
    required String adminId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }

    await _db
        .collection('teams')
        .doc(teamId)
        .collection('cash_collections')
        .add({
      'memberId': memberId,
      'memberName': memberName,
      'collectedBy': adminId,
      'amount': amount,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}