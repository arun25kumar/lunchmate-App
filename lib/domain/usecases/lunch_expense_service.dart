// lib/domain/usecases/lunch_expense_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _fullMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatNumber(double a) =>
    a % 1 == 0 ? a.toStringAsFixed(0) : a.toStringAsFixed(2);

String formatMoney(double a) => '₹${formatNumber(a)}';

String formatShortDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';

String formatFullDate(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]} ${d.year}';

String formatMonthYear(DateTime d) =>
    '${_fullMonthNames[d.month - 1]} ${d.year}';

class MemberInfo {
  final String id; // 'admin' for the team admin, otherwise the member doc id
  final String name;

  const MemberInfo({required this.id, required this.name});
}

/// One item on the team's food menu.
class FoodItem {
  final String id;
  final String name;
  final double price; // 0 = no price set

  const FoodItem({required this.id, required this.name, required this.price});
}

/// What the admin typed for one person on one day (used when saving).
class EntryInput {
  final double amount;
  final String? foodId;
  final String foodName;
  final String note;

  const EntryInput({
    required this.amount,
    this.foodId,
    this.foodName = '',
    this.note = '',
  });
}

class LunchEntry {
  final String memberId;
  final String memberName;
  final String date; // yyyy-MM-dd
  final double amount;
  final String foodId;
  final String foodName;
  final String note;

  const LunchEntry({
    required this.memberId,
    required this.memberName,
    required this.date,
    required this.amount,
    this.foodId = '',
    this.foodName = '',
    this.note = '',
  });
}

/// Who members should pay (the admin) and where.
class PaymentInfo {
  final String upiId; // empty if the admin has not added it yet
  final String payeeName;

  const PaymentInfo({required this.upiId, required this.payeeName});
}

class LunchExpenseService {
  final FirebaseFirestore firestore;

  LunchExpenseService(this.firestore);

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  // teams/{teamId}/lunch_entries/{yyyy-MM-dd}_{memberId}
  CollectionReference<Map<String, dynamic>> _entries(String teamId) =>
      firestore.collection('teams').doc(teamId).collection('lunch_entries');

  // teams/{teamId}/foods/{foodId}
  CollectionReference<Map<String, dynamic>> _foods(String teamId) =>
      firestore.collection('teams').doc(teamId).collection('foods');

  // teams/{teamId}/cash_collections/{auto-id}
  CollectionReference<Map<String, dynamic>> _collections(String teamId) =>
      firestore.collection('teams').doc(teamId).collection('cash_collections');

  LunchEntry _entryFromMap(Map<String, dynamic> data) => LunchEntry(
    memberId: (data['memberId'] ?? '') as String,
    memberName: (data['memberName'] ?? '') as String,
    date: (data['date'] ?? '') as String,
    amount: (data['amount'] as num).toDouble(),
    foodId: (data['foodId'] ?? '') as String,
    foodName: (data['foodName'] ?? '') as String,
    note: (data['note'] ?? '') as String,
  );

  // ---------------- PEOPLE ----------------

  /// Admin + all active members of the team.
  Future<List<MemberInfo>> getPeople(String teamId) async {
    final teamRef = firestore.collection('teams').doc(teamId);
    final teamDoc = await teamRef.get();
    final admin = (teamDoc.data()?['admin'] as Map<String, dynamic>?) ?? {};
    final membersSnap = await teamRef.collection('members').get();

    final members = membersSnap.docs
        .where((d) => d.data()['isActive'] != false)
        .map((d) => MemberInfo(
      id: d.id,
      name: (d.data()['name'] ?? '') as String,
    ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return [
      MemberInfo(id: 'admin', name: (admin['name'] ?? 'Admin') as String),
      ...members,
    ];
  }

  // ---------------- FOOD MENU ----------------

  Future<List<FoodItem>> getFoods(String teamId) async {
    final snap = await _foods(teamId).get();

    return snap.docs.map((d) {
      final data = d.data();
      return FoodItem(
        id: d.id,
        name: (data['name'] ?? '') as String,
        price: ((data['price'] ?? 0) as num).toDouble(),
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> addFood(String teamId, String name, double price) {
    return _foods(teamId).add({
      'name': name.trim(),
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addFoods(String teamId, List<String> names) async {
    final batch = firestore.batch();
    for (final name in names) {
      batch.set(_foods(teamId).doc(), {
        'name': name.trim(),
        'price': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateFood(
      String teamId,
      String foodId,
      String name,
      double price,
      ) {
    return _foods(teamId).doc(foodId).update({
      'name': name.trim(),
      'price': price,
    });
  }

  Future<void> deleteFood(String teamId, String foodId) {
    return _foods(teamId).doc(foodId).delete();
  }

  // ---------------- DAILY ENTRIES ----------------

  /// memberId -> entry for one day.
  Future<Map<String, LunchEntry>> getEntriesForDate(
      String teamId,
      DateTime date,
      ) async {
    final snap =
    await _entries(teamId).where('date', isEqualTo: dateKey(date)).get();

    final map = <String, LunchEntry>{};
    for (final d in snap.docs) {
      final e = _entryFromMap(d.data());
      map[e.memberId] = e;
    }
    return map;
  }

  /// Saves one day. Amount > 0 creates/updates the entry, 0 or empty removes it.
  Future<void> saveDay({
    required String teamId,
    required DateTime date,
    required List<MemberInfo> people,
    required Map<String, EntryInput> inputs,
  }) async {
    final key = dateKey(date);
    final batch = firestore.batch();

    for (final p in people) {
      final ref = _entries(teamId).doc('${key}_${p.id}');
      final input = inputs[p.id];

      if (input != null && input.amount > 0) {
        batch.set(ref, {
          'date': key,
          'memberId': p.id,
          'memberName': p.name,
          'amount': input.amount,
          'foodId': input.foodId ?? '',
          'foodName': input.foodName,
          'note': input.note,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.delete(ref);
      }
    }

    await batch.commit();
  }

  /// Entries between [start] and [end] (inclusive).
  /// Only one field is filtered in Firestore, so no extra index is needed;
  /// the member filter is applied here in code.
  Future<List<LunchEntry>> getEntries({
    required String teamId,
    required DateTime start,
    required DateTime end,
    String? memberId,
  }) async {
    final snap = await _entries(teamId)
        .where('date', isGreaterThanOrEqualTo: dateKey(start))
        .where('date', isLessThanOrEqualTo: dateKey(end))
        .get();

    final list = snap.docs
        .map((d) => _entryFromMap(d.data()))
        .where((e) => memberId == null || e.memberId == memberId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  // ---------------- PENDING BALANCE ----------------

  /// memberId -> amount still unpaid (all time):
  ///   sum(lunch_entries) - sum(cash_collections)
  /// Pass [memberId] to load just one person. A negative value means the
  /// person has paid in advance.
  Future<Map<String, double>> getPendingByMember(
      String teamId, {
        String? memberId,
      }) async {
    Query<Map<String, dynamic>> entriesQ = _entries(teamId);
    Query<Map<String, dynamic>> paidQ = _collections(teamId);

    if (memberId != null) {
      entriesQ = entriesQ.where('memberId', isEqualTo: memberId);
      paidQ = paidQ.where('memberId', isEqualTo: memberId);
    }

    final results = await Future.wait([entriesQ.get(), paidQ.get()]);
    final out = <String, double>{};

    for (final d in results[0].docs) {
      final m = d.data();
      final id = (m['memberId'] ?? '') as String;
      out[id] = (out[id] ?? 0) + ((m['amount'] as num?)?.toDouble() ?? 0);
    }
    for (final d in results[1].docs) {
      final m = d.data();
      final id = (m['memberId'] ?? '') as String;
      out[id] = (out[id] ?? 0) - ((m['amount'] as num?)?.toDouble() ?? 0);
    }
    return out;
  }

  // ---------------- PAYMENT ----------------

  /// Admin's UPI ID (saved on the team document) and display name.
  Future<PaymentInfo> getPaymentInfo(String teamId) async {
    final doc = await firestore.collection('teams').doc(teamId).get();
    final data = doc.data() ?? {};
    final admin = (data['admin'] as Map<String, dynamic>?) ?? {};

    return PaymentInfo(
      upiId: (data['upiId'] ?? '') as String,
      payeeName: (admin['name'] ?? 'Admin') as String,
    );
  }

  Future<void> saveUpiId(String teamId, String upiId) {
    return firestore
        .collection('teams')
        .doc(teamId)
        .update({'upiId': upiId.trim()});
  }
}