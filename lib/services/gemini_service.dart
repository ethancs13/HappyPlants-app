import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:happy_plants/models/plant.dart';

typedef FunctionHandler =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> args,
    );

class GeminiService {
  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyASUR9ywaJXQI3N5rdb9Kh7HhVOa8MaD_A',
  );
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  static const _preferred = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-preview-05-20',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro',
  ];

  // ── Tool declarations ──────────────────────────────────────────────────────

  static const _tools = [
    {
      'functionDeclarations': [
        {
          'name': 'add_plant',
          'description':
              'Add a new plant to the user\'s collection in the HappyPlants app.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'name': {
                'type': 'STRING',
                'description': 'Friendly nickname the user uses for this plant.',
              },
              'species': {
                'type': 'STRING',
                'description': 'Scientific or common species name.',
              },
              'watering_interval_days': {
                'type': 'INTEGER',
                'description': 'Recommended days between waterings.',
              },
              'notes': {
                'type': 'STRING',
                'description': 'Optional care notes.',
              },
              'plant_key': {
                'type': 'STRING',
                'description':
                    'Icon key for the animated illustration. '
                    'Available keys: plant_01, plant_02, plant_03, plant_05, '
                    'plant_07, plant_14, plant_15. Pick the closest visual match '
                    'or omit for a generic illustration.',
              },
            },
            'required': ['name', 'species', 'watering_interval_days'],
          },
        },
        {
          'name': 'update_plant',
          'description': 'Update one or more fields of an existing plant.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'plant_id': {
                'type': 'INTEGER',
                'description': 'ID of the plant to update.',
              },
              'name': {'type': 'STRING'},
              'species': {'type': 'STRING'},
              'watering_interval_days': {'type': 'INTEGER'},
              'notes': {'type': 'STRING'},
            },
            'required': ['plant_id'],
          },
        },
        {
          'name': 'delete_plant',
          'description': 'Permanently delete a plant from the collection.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'plant_id': {
                'type': 'INTEGER',
                'description': 'ID of the plant to delete.',
              },
            },
            'required': ['plant_id'],
          },
        },
        {
          'name': 'log_care',
          'description':
              'Log a watering or fertilizing event for a plant.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'plant_id': {
                'type': 'INTEGER',
                'description': 'ID of the plant.',
              },
              'type': {
                'type': 'STRING',
                'description': '"watering" or "fertilizing".',
              },
            },
            'required': ['plant_id', 'type'],
          },
        },
      ],
    },
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  final String _model;
  final List<Map<String, dynamic>> _history;
  final _client = http.Client();

  GeminiService._(this._model, this._history);

  static Future<GeminiService> create({List<Plant> plants = const []}) async {
    final model = await _detectModel();
    final prompt = _buildSystemPrompt(plants);
    return GeminiService._(model, [
      {
        'role': 'user',
        'parts': [{'text': prompt}],
      },
      {
        'role': 'model',
        'parts': [
          {
            'text':
                "Understood! I'm PlantBot, your expert plant care assistant. "
                "I can identify plants, diagnose ailments, answer care questions, "
                "and manage your plant collection directly.",
          },
        ],
      },
    ]);
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  String get model => _model;

  void injectPlantContext(String contextText) {
    _history.addAll([
      {
        'role': 'user',
        'parts': [{'text': contextText}],
      },
      {
        'role': 'model',
        'parts': [
          {
            'text':
                'Got it! I now have full context for this plant and will '
                'use it to give you personalised advice.',
          },
        ],
      },
    ]);
  }

  // ── Streaming with function-call support ───────────────────────────────────

  /// Streams text chunks to the caller. If Gemini decides to call a tool,
  /// [onFunctionCall] is awaited with the function name + args; its return
  /// value is fed back to Gemini as a functionResponse, then streaming resumes.
  Stream<String> sendMessageStream(
    String text, {
    Uint8List? imageBytes,
    FunctionHandler? onFunctionCall,
  }) async* {
    final parts = <Map<String, dynamic>>[];
    if (imageBytes != null) {
      parts.add({
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
      });
    }
    parts.add({'text': text.isNotEmpty ? text : 'Analyse this plant image.'});
    _history.add({'role': 'user', 'parts': parts});

    // Loop to handle chained function calls
    while (true) {
      final textBuffer = StringBuffer();
      Map<String, dynamic>? functionCall;

      final uri = Uri.parse(
        '$_base/models/$_model:streamGenerateContent?key=$_apiKey&alt=sse',
      );
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'contents': _history,
          'tools': _tools,
          'generationConfig': {'maxOutputTokens': 2048},
        });

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final candidates = json['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;
          final content = (candidates[0] as Map)['content'] as Map?;
          if (content == null) continue;
          final partsList = content['parts'] as List?;
          if (partsList == null) continue;

          for (final part in partsList) {
            final p = part as Map<String, dynamic>;
            if (p.containsKey('functionCall')) {
              final fc = p['functionCall'] as Map<String, dynamic>;
              functionCall = {
                'name': fc['name'] as String,
                'args': (fc['args'] as Map? ?? {}).cast<String, dynamic>(),
              };
            } else {
              final chunk = p['text'] as String?;
              if (chunk != null && chunk.isNotEmpty) {
                textBuffer.write(chunk);
                yield chunk;
              }
            }
          }
        } catch (_) {}
      }

      if (functionCall != null && onFunctionCall != null) {
        // Add the model's function-call turn to history
        _history.add({
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': functionCall['name'],
                'args': functionCall['args'],
              },
            },
          ],
        });

        // Execute the function in the app
        final result = await onFunctionCall(
          functionCall['name'] as String,
          functionCall['args'] as Map<String, dynamic>,
        );

        // Feed the result back to Gemini
        _history.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': functionCall['name'],
                'response': result,
              },
            },
          ],
        });
        // Continue the loop — Gemini will now produce a text confirmation
      } else {
        // Normal text turn — save to history and exit loop
        _history.add({
          'role': 'model',
          'parts': [
            {'text': textBuffer.toString()},
          ],
        });
        break;
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<String> _detectModel() async {
    try {
      final uri = Uri.parse('$_base/models?key=$_apiKey&pageSize=50');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final available = ((json['models'] as List?) ?? [])
            .map((m) => (m as Map)['name'] as String)
            .map((n) => n.replaceFirst('models/', ''))
            .toSet();
        for (final candidate in _preferred) {
          if (available.contains(candidate)) return candidate;
        }
        for (final m in (json['models'] as List? ?? [])) {
          final methods =
              (m as Map)['supportedGenerationMethods'] as List?;
          if (methods != null && methods.contains('generateContent')) {
            return (m['name'] as String).replaceFirst('models/', '');
          }
        }
      }
    } catch (_) {}
    return 'gemini-2.0-flash';
  }

  static String _buildSystemPrompt(List<Plant> plants) {
    final buffer = StringBuffer()
      ..writeln(
        'You are PlantBot, an expert botanist and plant care specialist '
        'built into the HappyPlants app.',
      )
      ..writeln(
        '- Identify plant species from photos (common name, scientific name, '
        'key visual traits)',
      )
      ..writeln(
        '- Diagnose ailments: yellowing, brown spots, drooping, root rot, '
        'pests (spider mites, aphids, mealybugs, fungus gnats)',
      )
      ..writeln(
        '- Give specific care guidance: watering, light, humidity, soil, '
        'fertilising, propagation',
      )
      ..writeln(
        '- Manage the user\'s plant collection using the provided tools '
        '(add_plant, update_plant, delete_plant, log_care). '
        'When the user asks to add, change, delete, or log care for a plant, '
        'call the appropriate tool without asking for confirmation — just do it '
        'and briefly confirm what you did.',
      )
      ..writeln()
      ..writeln(
        'RESPONSE STYLE: Short and direct — 2 to 4 sentences max. '
        'Offer a follow-up at the end. No markdown, no asterisks, no hashtags. '
        'Plain text only.',
      );

    if (plants.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln("Current plant collection (use these IDs with the tools):");
      for (final p in plants) {
        final lastWatered = p.lastWateredDate != null
            ? _daysAgo(p.lastWateredDate!)
            : 'never';
        final overdue = p.isOverdueForWater ? ' OVERDUE' : '';
        buffer.writeln(
          '- ID ${p.id}: "${p.name}" (${p.species}), water every '
          '${p.wateringIntervalDays} days, last watered $lastWatered$overdue'
          '${p.notes != null ? ", notes: ${p.notes}" : ""}',
        );
      }
    } else {
      buffer.writeln(
        '\nThe user has no plants yet. '
        'Encourage them to add their first plant.',
      );
    }

    return buffer.toString();
  }

  static String _daysAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }
}
