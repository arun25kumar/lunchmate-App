// lib/core/services/biometric_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / face login helper.
///
/// After a successful PIN login the user can enable biometric login.
/// The login id and PIN are then kept in the phone's secure storage
/// (Android Keystore / iOS Keychain) and are only used after the
/// fingerprint check succeeds.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kIdentifier = 'bio_identifier';
  static const _kPin = 'bio_pin';

  /// True if the phone has biometrics set up (fingerprint / face enrolled).
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;

      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e) {
      debugPrint('Biometric check failed: $e');
      return false;
    }
  }

  /// Shows the system fingerprint prompt. Returns true on success.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }

  /// Whether credentials are saved for biometric login.
  Future<bool> isEnabled() async {
    final id = await _storage.read(key: _kIdentifier);
    final pin = await _storage.read(key: _kPin);
    return id != null && pin != null;
  }

  /// The login id saved for biometric login (null if not enabled).
  Future<String?> savedIdentifier() => _storage.read(key: _kIdentifier);

  Future<void> enable({required String identifier, required String pin}) async {
    await _storage.write(key: _kIdentifier, value: identifier.trim());
    await _storage.write(key: _kPin, value: pin.trim());
  }

  /// Returns {'identifier': ..., 'pin': ...} or null if not enabled.
  Future<Map<String, String>?> readCredentials() async {
    final id = await _storage.read(key: _kIdentifier);
    final pin = await _storage.read(key: _kPin);
    if (id == null || pin == null) return null;
    return {'identifier': id, 'pin': pin};
  }

  Future<void> disable() async {
    await _storage.delete(key: _kIdentifier);
    await _storage.delete(key: _kPin);
  }
}