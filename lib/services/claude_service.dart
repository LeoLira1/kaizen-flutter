import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ClaudeService {
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  final String apiKey;
  ClaudeService(this.apiKey);

  Future<Map<String, dynamic>> analyzeZeppScreenshot(File image) async {
    final bytes = await image.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = image.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final resp = await http
        .post(
          Uri.parse(_url),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': 1024,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': mime,
                      'data': b64,
                    },
                  },
                  {
                    'type': 'text',
                    'text': '''Analise esta screenshot do app Zepp Life e extraia todos os dados visíveis de composição corporal.

Retorne APENAS um JSON válido, sem markdown, sem texto extra:
{
  "score": <número ou null>,
  "weight": <kg decimal ou null>,
  "fat": <% decimal ou null>,
  "muscle": <kg decimal ou null>,
  "water": <% decimal ou null>,
  "visceral": <inteiro ou null>,
  "protein": <% decimal ou null>,
  "bone_mass": <kg decimal ou null>,
  "bmi": <decimal ou null>,
  "basal": <kcal inteiro ou null>,
  "body_type": "<texto ou null>",
  "weight_status": "<status ou null>",
  "fat_status": "<Alta/Normal/Baixa ou null>",
  "muscle_status": "<Boa/Normal/Baixa ou null>",
  "water_status": "<Insuf./Normal/Boa ou null>",
  "visceral_status": "<Alta/Normal/Baixa ou null>",
  "protein_status": "<Normal/Alta/Baixa ou null>",
  "measured_at": "<data/hora exibida na tela ou null>"
}''',
                  },
                ],
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('Claude API ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body);
    final text = body['content'][0]['text'] as String;
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) throw Exception('JSON não encontrado na resposta do Claude');
    return jsonDecode(match.group(0)!);
  }
}
