import 'dart:convert';

import 'package:http/http.dart' as http;

class FamilyCompassApi {
  FamilyCompassApi({this.baseUrl = 'http://10.0.2.2:8000/api/v1'});

  final String baseUrl;

  Future<Map<String, dynamic>> health() async {
    final response = await http
        .get(Uri.parse('${baseUrl.replaceFirst('/api/v1', '')}/health'));
    if (response.statusCode != 200) throw Exception('Backend unavailable');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> askAssistant(String prompt) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/assistant'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'family_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'user_id': '11111111-1111-1111-1111-111111111111',
        'prompt': prompt,
      }),
    );
    if (response.statusCode != 200) throw Exception('Assistant request failed');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
