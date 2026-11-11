// lib/data/datasources/remote/firestore_team_datasource.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/pin_hasher.dart';
import '../../../domain/entities/team.dart';

class FirestoreTeamDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  FirestoreTeamDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  String _generateTeamCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Makes sure we have a signed-in (anonymous) user, even if the
  /// start-up sign-in failed (for example, the phone was offline).
  Future<User> _ensureUser() async {
    var user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      user = cred.user;
    }
    if (user == null) {
      throw Exception('Could not sign in. Check your internet connection.');
    }
    return user;
  }

  // CREATE TEAM
  Future<Team> createTeam({
    required String teamName,
    required String adminName,
    required String email,
    required String mobile,
    required String pin,
  }) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw Exception('PIN must contain exactly 4 digits.');
    }

    final currentUser = await _ensureUser();
    final String adminId = currentUser.uid;
    final cleanEmail = email.trim().toLowerCase();
    final cleanMobile = mobile.trim();

    // Block duplicate accounts (login finds users by email/mobile).
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

    final teamRef = firestore.collection('teams').doc();

    for (int attempt = 0; attempt < 10; attempt++) {
      final String teamCode = _generateTeamCode();
      final codeRef = firestore.collection('team_invite_codes').doc(teamCode);
      final adminMemberRef = teamRef.collection('members').doc(adminId);

      try {
        await firestore.runTransaction((transaction) async {
          final codeSnapshot = await transaction.get(codeRef);
          if (codeSnapshot.exists) {
            throw const _DuplicateTeamCodeException();
          }

          final timestamp = FieldValue.serverTimestamp();

          transaction.set(teamRef, {
            'teamId': teamRef.id,
            'teamName': teamName.trim(),
            'teamCode': teamCode,
            'adminId': adminId,
            'createdAt': timestamp,
            'isActive': true,
            'memberIds': [adminId],
            'admin': {
              'name': adminName.trim(),
              'email': cleanEmail,
              'mobile': cleanMobile,
              'role': 'admin',
            },
          });

          transaction.set(adminMemberRef, {
            'userId': adminId,
            'name': adminName.trim(),
            'email': cleanEmail,
            'mobile': cleanMobile,
            'role': 'admin',
            'balance': 0,
            // PIN is stored as a salted hash (never the raw PIN).
            'pinHash': PinHasher.hash(pin, adminId),
            'createdAt': timestamp,
          });

          transaction.set(codeRef, {
            'teamId': teamRef.id,
            'teamCode': teamCode,
            'createdAt': timestamp,
          });
        });

        return Team(
          teamId: teamRef.id,
          teamName: teamName.trim(),
          teamCode: teamCode,
          adminId: adminId,
          adminName: adminName.trim(),
          email: cleanEmail,
          mobile: cleanMobile,
          createdAt: DateTime.now(),
        );
      } on _DuplicateTeamCodeException {
        continue;
      } on FirebaseException catch (e) {
        throw Exception(
          'Firebase error: ${e.code}: ${e.message ?? 'Unknown error'}',
        );
      }
    }

    throw Exception('Unable to generate a unique team code. Please try again.');
  }

  // SAVE ADMIN UPI ID
  Future<void> saveUpiId({
    required String teamId,
    required String upiId,
  }) async {
    await _ensureUser();

    if (upiId.trim().isEmpty) {
      throw Exception('UPI ID cannot be empty.');
    }

    await firestore.collection('teams').doc(teamId).update({
      'upiId': upiId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _DuplicateTeamCodeException implements Exception {
  const _DuplicateTeamCodeException();
}