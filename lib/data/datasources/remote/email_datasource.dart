import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailDataSource {
  static const _serviceId = 'service_s4r4wa5';
  static const _templateId = 'template_g9oax0j';
  static const _publicKey = 'PpmiHlu7JZpOhI77z';

  Future<void> sendTeamInvite({
    required String toEmail,
    required String adminName,
    required String teamName,
    required String teamCode,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': toEmail,
          'admin_name': adminName,
          'team_name': teamName,
          'team_code': teamCode,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Email failed: ${response.body}');
    }
  }
}