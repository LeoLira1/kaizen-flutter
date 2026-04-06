import 'dart:convert';
import 'package:http/http.dart' as http;

class TursoService {
  final String databaseUrl;
  final String authToken;

  TursoService({required this.databaseUrl, required this.authToken});

  Future<List<dynamic>> _pipeline(List<Map<String, dynamic>> requests) async {
    final resp = await http
        .post(
          Uri.parse('$databaseUrl/v2/pipeline'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'requests': requests}),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('Turso ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    final results = data['results'] as List;
    for (final r in results) {
      if (r['type'] == 'error') throw Exception('Turso: ${r['error']}');
    }
    return results;
  }

  Future<void> initDatabase() async {
    await _pipeline([
      {
        'type': 'execute',
        'stmt': {
          'sql': '''CREATE TABLE IF NOT EXISTS body_measurements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            measured_at TEXT,
            score REAL,
            weight REAL,
            fat REAL,
            muscle REAL,
            water REAL,
            visceral REAL,
            protein REAL,
            bone_mass REAL,
            bmi REAL,
            basal REAL,
            body_type TEXT,
            weight_status TEXT,
            fat_status TEXT,
            muscle_status TEXT,
            water_status TEXT,
            visceral_status TEXT,
            protein_status TEXT,
            created_at TEXT DEFAULT (datetime('now'))
          )''',
        }
      },
      {'type': 'close'},
    ]);
  }

  // Turso espera valor float como número JSON (não string)
  static double _f(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Future<void> saveMeasurement(Map<String, dynamic> d) async {
    String? _s(String key) {
      final v = d[key];
      return v == null ? null : v.toString();
    }

    await _pipeline([
      {
        'type': 'execute',
        'stmt': {
          'sql': '''INSERT INTO body_measurements
            (measured_at, score, weight, fat, muscle, water, visceral, protein,
             bone_mass, bmi, basal, body_type,
             weight_status, fat_status, muscle_status,
             water_status, visceral_status, protein_status)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
          'args': [
            {'type': 'text', 'value': _s('measured_at') ?? DateTime.now().toIso8601String()},
            {'type': 'float', 'value': _f(d['score'])},
            {'type': 'float', 'value': _f(d['weight'])},
            {'type': 'float', 'value': _f(d['fat'])},
            {'type': 'float', 'value': _f(d['muscle'])},
            {'type': 'float', 'value': _f(d['water'])},
            {'type': 'float', 'value': _f(d['visceral'])},
            {'type': 'float', 'value': _f(d['protein'])},
            {'type': 'float', 'value': _f(d['bone_mass'])},
            {'type': 'float', 'value': _f(d['bmi'])},
            {'type': 'float', 'value': _f(d['basal'])},
            {'type': 'text', 'value': _s('body_type') ?? ''},
            {'type': 'text', 'value': _s('weight_status') ?? ''},
            {'type': 'text', 'value': _s('fat_status') ?? ''},
            {'type': 'text', 'value': _s('muscle_status') ?? ''},
            {'type': 'text', 'value': _s('water_status') ?? ''},
            {'type': 'text', 'value': _s('visceral_status') ?? ''},
            {'type': 'text', 'value': _s('protein_status') ?? ''},
          ],
        }
      },
      {'type': 'close'},
    ]);
  }

  Future<List<Map<String, dynamic>>> getHistory({int limit = 30}) async {
    final results = await _pipeline([
      {
        'type': 'execute',
        'stmt': {
          'sql':
              'SELECT * FROM body_measurements ORDER BY created_at DESC LIMIT ?',
          'args': [
            {'type': 'integer', 'value': limit.toString()}
          ],
        }
      },
      {'type': 'close'},
    ]);

    final rows =
        results[0]['response']['result']['rows'] as List? ?? [];
    final cols =
        results[0]['response']['result']['cols'] as List? ?? [];
    final names = cols.map((c) => c['name'] as String).toList();

    return rows.map<Map<String, dynamic>>((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < names.length; i++) {
        final cell = row[i] as Map;
        map[names[i]] = cell['type'] == 'null' ? null : cell['value'];
      }
      return map;
    }).toList();
  }
}
