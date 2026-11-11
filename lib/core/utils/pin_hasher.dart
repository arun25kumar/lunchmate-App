// lib/core/utils/pin_hasher.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hashes a 4-digit PIN with the member's userId as salt.
/// Used by create team, join team and login so all three always agree.
class PinHasher {
  static String hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:${pin.trim()}')).toString();
}