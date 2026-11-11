// lib/domain/usecases/join_team.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/pin_hasher.dart';

class JoinTeam {
  final FirebaseFirestore firestore;

  JoinTeam(this.firestore);

  Future<Map<String, dynamic>> call({
    required String teamCode,
    required String employeeName,
    required String email,
    required String mobile,
    required String pin,
  }) async {
    final code = teamCode.trim();
    final name = employeeName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanMobile = mobile.trim();
    final cleanPin = pin.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw Exception('Enter a valid 6-digit team code.');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(cleanPin)) {
      throw Exception('PIN must contain exactly 4 digits.');
    }

    // Signed-in (anonymous) user.
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    if (user == null) {
      throw Exception('Could not sign in. Check your internet connection.');
    }
    final uid = user.uid;

    // 1. Validate the invitation code.
    final codeSnap =
    await firestore.collection('team_invite_codes').doc(code).get();
    if (!codeSnap.exists) throw Exception('Invalid team code.');

    final teamId = codeSnap.data()!['teamId'] as String;
    final teamRef = firestore.collection('teams').doc(teamId);
    final teamSnap = await teamRef.get();
    if (!teamSnap.exists) throw Exception('Team not found.');

    final team = teamSnap.data()!;
    if (team['isActive'] == false) {
      throw Exception('This team is no longer active.');
    }

    // 2. Block duplicates (login finds users by email/mobile).
    final dupMobile = await firestore
        .collectionGroup('members')
        .where('mobile', isEqualTo: cleanMobile)
        .limit(1)
        .get();
    if (dupMobile.docs.isNotEmpty) {
      throw Exception('This mobile number is already registered.');
    }
    final dupEmail = await firestore
        .collectionGroup('members')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (dupEmail.docs.isNotEmpty) {
      throw Exception('This email is already registered.');
    }

    // 3. Create the member and add to the team.
    final memberRef = teamRef.collection('members').doc(uid);
    final batch = firestore.batch();

    batch.set(memberRef, {
      'userId': uid,
      'name': name,
      'email': cleanEmail,
      'mobile': cleanMobile,
      'role': 'member',
      'balance': 0,
      'teamCode': code,
      'pinHash': PinHasher.hash(cleanPin, uid),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(teamRef, {
      'memberIds': FieldValue.arrayUnion([uid]),
    });

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception(
        'Firebase error: ${e.code}: ${e.message ?? 'Unknown error'}',
      );
    }

    return {
      'teamName': team['teamName'],
      'teamCode': code,
      'teamId': teamId,
    };
  }
}