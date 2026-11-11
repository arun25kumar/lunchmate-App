// lib/domain/usecases/login_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/pin_hasher.dart';

class LoginUser {
  final FirebaseFirestore firestore;

  LoginUser(this.firestore);

  static const _invalid = 'Invalid email/mobile number or PIN';

  Future<Map<String, dynamic>> call({
    required String identifier,
    required String pin,
  }) async {
    final id = identifier.trim();
    final cleanPin = pin.trim();

    if (id.isEmpty || !RegExp(r'^\d{4}$').hasMatch(cleanPin)) {
      throw Exception(_invalid);
    }

    // Make sure Firestore requests carry an auth user.
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {
        throw Exception('Could not sign in. Check your internet connection.');
      }
    }

    final isEmail = id.contains('@');
    final field = isEmail ? 'email' : 'mobile';
    final value = isEmail ? id.toLowerCase() : id;

    final snap = await firestore
        .collectionGroup('members')
        .where(field, isEqualTo: value)
        .limit(10)
        .get();

    if (snap.docs.isEmpty) throw Exception(_invalid);

    // The same mobile could exist in more than one team:
    // pick the member whose PIN matches.
    for (final doc in snap.docs) {
      final m = doc.data();
      final userId = (m['userId'] as String?) ?? doc.id;
      final storedHash = m['pinHash'] as String?;

      if (storedHash == null) continue; // account created before PIN fix
      if (storedHash != PinHasher.hash(cleanPin, userId)) continue;

      final teamRef = doc.reference.parent.parent;
      if (teamRef == null) continue;

      final teamSnap = await teamRef.get();
      if (!teamSnap.exists) throw Exception('Your team no longer exists.');

      final t = teamSnap.data() ?? {};
      if (t['isActive'] == false) {
        throw Exception('This team is no longer active.');
      }

      return {
        'userId': userId,
        'memberId': userId,
        'name': m['name'],
        'email': m['email'],
        'mobile': m['mobile'],
        'role': m['role'],
        'balance': m['balance'] ?? 0,
        'teamId': teamRef.id,
        'teamName': t['teamName'],
        'teamCode': t['teamCode'],
        'adminId': t['adminId'],
        'adminName': (t['admin'] as Map?)?['name'],
        'upiId': t['upiId'],
      };
    }

    throw Exception(_invalid);
  }
}